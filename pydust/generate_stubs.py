import argparse
import importlib
import inspect
import os
import sys
from pathlib import Path

import black

INDENT = " " * 4
GENERATED_COMMENT = "# Generated content DO NOT EDIT\n"


def do_indent(text: str, indent: str):
    return text.replace("\n", f"\n{indent}")


def function(obj, indent, text_signature=None):
    if text_signature is None:
        try:
            sig = inspect._signature_from_callable(
                obj, follow_wrapper_chains=True, skip_bound_arg=False, sigcls=inspect.Signature, eval_str=False
            )
            text_signature = str(sig)
        except:
            text_signature = "(self)"

    if isinstance(obj, staticmethod):
        obj = obj.__func__

    string = ""
    string += f"{indent}def {obj.__name__}{text_signature}:\n"
    indent += INDENT
    if obj.__doc__:
        string += f'{indent}"""\n'
        string += f"{indent}{do_indent(obj.__doc__, indent)}\n"
        string += f'{indent}"""\n'
    string += f"{indent}pass\n"
    string += "\n"
    string += "\n"
    return string


def member_sort(member):
    if inspect.isclass(member):
        value = 10 + len(inspect.getmro(member))
    else:
        value = 1
    return value


def get_module_members(module):
    members = [
        member
        for name, member in inspect.getmembers(module)
        if not name.startswith("_") and not inspect.ismodule(member)
    ]
    members.sort(key=member_sort)
    return members


def pyi_file(obj, indent=""):
    string = ""
    if inspect.ismodule(obj):
        string += GENERATED_COMMENT
        members = get_module_members(obj)
        for member in members:
            string += pyi_file(member, indent)

    elif inspect.isclass(obj):
        indent += INDENT
        mro = inspect.getmro(obj)
        if len(mro) > 2:
            inherit = f"({mro[1].__name__})"
        else:
            inherit = ""
        string += f"class {obj.__name__}{inherit}:\n"

        body = ""
        if obj.__doc__:
            body += f'{indent}"""\n{indent}{do_indent(obj.__doc__, indent)}\n{indent}"""\n'

        print(
            inspect.signature(obj),
            obj.__mro__,
            obj.__text_signature__,
            hasattr(obj, "__init__"),
            hasattr(obj, "__new__"),
        )

        fns = [func for name, func in vars(obj).items() if name not in ["__doc__", "__module__"]]

        for fn in fns:
            body += pyi_file(fn, indent=indent)

        if not body:
            body += f"{indent}pass\n"

        string += body
        string += "\n\n"

    elif inspect.isbuiltin(obj):
        string += function(obj, indent)

    elif inspect.ismethoddescriptor(obj):
        string += function(obj, indent)

    elif inspect.isgetsetdescriptor(obj):
        # TODO it would be interesing to add the setter maybe ?
        string += f"{indent}@property\n"
        string += function(obj, indent, text_signature="(self)")

    elif inspect.ismemberdescriptor(obj):
        string += f"{indent}{obj.__name__}: {type(obj.__objclass__().__getattribute__(obj.__name__)).__name__}"
    else:
        raise Exception(f"Object {obj} is not supported")
    return string


def py_file(module, origin):
    members = get_module_members(module)

    string = GENERATED_COMMENT
    string += "\n"
    for member in members:
        name = member.__name__
        string += f"from {origin} import {name} as {name}\n"
    return string


def do_black(content, is_pyi):
    mode = black.Mode(
        target_versions={black.TargetVersion.PY35},
        line_length=119,
        is_pyi=is_pyi,
        string_normalization=True,
        experimental_string_processing=False,
    )
    try:
        return black.format_file_contents(content, fast=True, mode=mode)
    except black.NothingChanged:
        return content


def simple_name(module_name: str) -> str:
    return module_name.split(".")[-1]


def module_dir(module_name: str) -> Path:
    return Path(*module_name.split(".")[:-1])


def write(module, directory, module_name):
    name = simple_name(module_name)
    filename = directory.joinpath(module_dir(module_name)).joinpath(name + ".pyi")
    pyi_content = pyi_file(module)
    pyi_content = do_black(pyi_content, is_pyi=True)
    os.makedirs(directory, exist_ok=True)

    with open(filename, "w") as f:
        f.write(pyi_content)

    # filename = directory.joinpath("__init__.py")
    # py_content = py_file(module, origin)
    # py_content = do_black(py_content, is_pyi=False)
    # os.makedirs(directory, exist_ok=True)

    # with open(filename, "w") as f:
    #     f.write(py_content)

    # submodules = [(name, member) for name, member in inspect.getmembers(module) if inspect.ismodule(member)]
    # for name, submodule in submodules:
    #     write(submodule, directory.joinpath(name), f"{name}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("package_name")
    parser.add_argument("destination")
    args = parser.parse_args()

    module = None
    try:
        module = importlib.import_module(args.package_name)
    except Exception as exc:
        print("Not a valid python module, skipping...", args.package_name, exc)
        sys.exit(0)

    if module:
        write(module, Path(args.destination).resolve(), args.package_name)
