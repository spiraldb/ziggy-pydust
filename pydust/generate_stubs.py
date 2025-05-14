"""
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
"""

# Adapted from https://github.com/huggingface/tokenizers/blob/18bd5e8f9d3aa56612b8aeba5d0d8821e16b3105/bindings/python/stub.py under Apache 2.0 license # noqa: E501

import argparse
import importlib
import inspect
import os
from pathlib import Path

import black

INDENT = " " * 4

DUNDER_RETURNS = {
    "__init__": "None",
    "__init_subclass__": "None",
    "__del__": "None",
    "__delete__": "None",
    "__delattr__": "None",
    "__delitem__": "None",
    "__exit__": "None",
    "__set__": "None",
    "__setname__": "None",
    "__setattr__": "None",
    "__setattribute__": "None",
    "__setitem__": "None",
    "__contains__": "bool",
    "__len__": "int",
    "__length_hint__": "int",
    "__hash__": "int",
    "__index__": "int",
    "__bool__": "bool",
    "__int__": "int",
    "__float__": "float",
    "__complex__": "complex",
    "__repr__": "str",
    "__str__": "str",
    "__bytes__": "bytes",
    "__format__": "str",
    "__buffer__": "memoryview",
    "__release_buffer__": "None",
    # "__iadd__": "Self",
    # "__isub__": "Self",
    # "__imul__": "Self",
    # "__imatmul__": "Self",
    # "__ipow__": "Self",
    # "__itruediv__": "Self",
    # "__ifloordiv__": "Self",
    # "__imod__": "Self",
    # "__ilshift__": "Self",
    # "__irshift__": "Self",
    # "__iand__": "Self",
    # "__ixor__": "Self",
    # "__ior__": "Self",
    "__instancecheck__": "bool",
    "__subclasscheck__": "bool",
}


def do_indent(text: str, indent: str) -> str:
    return text.replace("\n", f"\n{indent}")


def function(obj, indent: str, text_signature: str | None = None) -> str:
    if text_signature is None:
        try:
            # This is how `inspect.getfullargspec` gets signature but instead of the tuple it returns
            #  we want to get the Signature object which handles string formatting for us
            text_signature = str(
                inspect._signature_from_callable(
                    obj,
                    follow_wrapper_chains=True,
                    skip_bound_arg=False,
                    sigcls=inspect.Signature,
                    eval_str=False,
                )
            )
        except Exception:
            text_signature = "(self)"

    if isinstance(obj, staticmethod):
        obj = obj.__func__

    if obj.__name__ in DUNDER_RETURNS:
        text_signature += " -> " + DUNDER_RETURNS[obj.__name__]

    string = f"{indent}def {obj.__name__}{text_signature}:"

    if obj.__doc__:
        string += "\n"
        string += doc(obj, indent + INDENT)
        string += "\n"
    else:
        string += " ..."

    return string + "\n"


def doc(obj, indent: str) -> str:
    if obj.__doc__:
        return f'{indent}"""\n{indent}{do_indent(obj.__doc__, indent)}\n{indent}"""\n'
    return ""


def member_sort(member: object) -> int:
    """Push classes and functions below attributes"""
    if inspect.isclass(member):
        return 10 + len(inspect.getmro(member))
    if inspect.isbuiltin(member):
        return 5
    return 1


def get_module_members(module) -> list[tuple[str, object]]:
    members = [
        (name, member)
        for name, member in inspect.getmembers(module, lambda obj: not inspect.ismodule(obj))
        if not name.startswith("_")
    ]
    members.sort(key=lambda member_tuple: (member_sort(member_tuple[1]), member_tuple[0]))
    return members


def pyi_file(obj, name: str, indent: str = "") -> str:
    if obj is None:
        return ""

    result_content = ""
    if inspect.ismodule(obj):
        result_content += doc(obj, indent)

        members = get_module_members(obj)
        members_string = ""
        for name, member in members:
            append = pyi_file(member, name, indent=indent)
            members_string += append

        submodules = inspect.getmembers(obj, inspect.ismodule)
        for name, submodule in submodules:
            members_string += f"{indent}class {submodule.__name__}:\n"

            submodule_members = get_module_members(submodule)
            if submodule.__doc__ or submodule_members:
                submod_indent = indent + INDENT

            if submodule.__doc__:
                members_string += doc(submodule, submod_indent)

            for name, member in submodule_members:
                append = pyi_file(member, name, indent=submod_indent)
                members_string += append

        result_content += members_string

    elif inspect.isclass(obj):
        mro = inspect.getmro(obj)
        if len(mro) > 2:
            inherit = f"({mro[1].__name__})"
        else:
            inherit = ""
        result_content += f"{indent}class {obj.__name__}{inherit}:\n"
        indent += INDENT

        class_body = doc(obj, indent)

        if obj.__text_signature__:
            class_body += f"{indent}def __init__{inspect.signature(obj)} -> None: ...\n"

        members = [
            (name, func)
            for name, func in vars(obj).items()
            if name not in ["__doc__", "__module__", "__new__", "__init__", "__del__"]
        ]

        for name, member in members:
            append = pyi_file(member, name, indent=indent)
            class_body += append

        if not class_body:
            class_body += f"{indent}...\n"

        result_content += class_body
        result_content += "\n\n"

    elif inspect.isbuiltin(obj):
        result_content += function(obj, indent)

    elif inspect.ismethoddescriptor(obj):
        result_content += function(obj, indent)

    elif inspect.isgetsetdescriptor(obj):
        # TODO it would be interesing to add the setter maybe ?
        result_content += f"{indent}@property\n"
        result_content += function(obj, indent, text_signature="(self, /)")

    elif inspect.ismemberdescriptor(obj):
        result_content += f"{indent}{obj.__name__}: ..."
    else:
        result_content += f"{indent}{name}: {type(obj).__qualname__}\n"
    return result_content


def do_black(content: str, is_pyi: bool) -> str:
    mode = black.Mode(
        target_versions={black.TargetVersion.PY311},
        line_length=119,
        is_pyi=is_pyi,
        string_normalization=True,
    )
    try:
        return black.format_file_contents(content, fast=True, mode=mode)
    except black.NothingChanged:
        return content


def simple_name(module_name: str) -> str:
    return module_name.split(".")[-1]


def module_dir(module_name: str) -> Path:
    return Path(*module_name.split(".")[:-1])


def module_pyi_path(directory: Path, module_name: str) -> Path:
    return directory.joinpath(module_dir(module_name)).joinpath(simple_name(module_name) + ".pyi")


def stub_contents(module, module_name: str) -> str:
    pyi_content = pyi_file(module, module_name)
    return do_black(pyi_content, is_pyi=True)


def write(module, directory: Path, module_name: str) -> None:
    pyi_content = stub_contents(module, module_name)
    os.makedirs(directory, exist_ok=True)
    module_pyi_path(directory, module_name).write_text(pyi_content, "utf-8")


def check_contents(module, directory: Path, module_name: str) -> None:
    pyi_path = module_pyi_path(directory, module_name)
    pyi_content = stub_contents(module, module_name)
    existing_contents = pyi_path.read_text("utf-8")

    assert pyi_content == existing_contents, f"Contents of {pyi_path} are out of date. Please run generate-stubs"


def generate_stubs(package_name: str, destination: str = ".", check: bool = False) -> None:
    module = importlib.import_module(package_name)
    directory = Path(destination).resolve()
    if check:
        check_contents(module, directory, package_name)
    else:
        write(module, directory, package_name)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("package_name")
    parser.add_argument("destination")
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    generate_stubs(args.package_name, args.destination, args.check)


if __name__ == "__main__":
    main()
