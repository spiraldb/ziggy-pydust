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

# Adapted from https://github.com/huggingface/tokenizers/blob/18bd5e8f9d3aa56612b8aeba5d0d8821e16b3105/bindings/python/stub.py under Apache 2.0 license

import argparse
import importlib
import inspect
import os
import sys
from pathlib import Path

import black

INDENT = " " * 4


def do_indent(text: str, indent: str):
    return text.replace("\n", f"\n{indent}")


def function(obj, indent, text_signature=None):
    if text_signature is None:
        try:
            # This is how `inspect.getfullargspec` gets signature but instead of the tuple it returns
            #  we want to get the Signature object which handles string formatting for us
            text_signature = str(
                inspect._signature_from_callable(
                    obj, follow_wrapper_chains=True, skip_bound_arg=False, sigcls=inspect.Signature, eval_str=False
                )
            )
        except:
            text_signature = "(self)"

    if isinstance(obj, staticmethod):
        obj = obj.__func__

    string = ""
    string += f"{indent}def {obj.__name__}{text_signature}:\n"
    indent += INDENT
    string += doc(obj, indent)
    string += f"{indent}pass\n"
    string += "\n"
    string += "\n"
    return string


def doc(obj, indent) -> str:
    if obj.__doc__:
        return f'{indent}"""\n{indent}{do_indent(obj.__doc__, indent)}\n{indent}"""\n'
    else:
        return ""


def member_sort(member):
    if inspect.isclass(member):
        value = 10 + len(inspect.getmro(member))
    else:
        value = 1
    return value


def get_module_members(module):
    members = [
        member
        for name, member in inspect.getmembers(module, lambda obj: not inspect.ismodule(obj))
        if not name.startswith("_")
    ]
    members.sort(key=member_sort)
    return members


def pyi_file(obj, indent="") -> tuple[str, list[str]]:
    symbols = []
    result_content = ""
    if inspect.ismodule(obj):
        result_content += doc(obj, indent)

        if indent == "":
            result_content += f"{indent}from __future__ import annotations\n"

        members = get_module_members(obj)
        members_string = ""
        for member in members:
            append, new_symbols = pyi_file(member, indent=indent)
            members_string += append
            symbols.extend(new_symbols)

        submodules = inspect.getmembers(module, inspect.ismodule)
        for name, submodule in submodules:
            symbols.append(submodule.__name__)
            members_string += f"{indent}class {submodule.__name__}:\n"
            submod_indent = indent + INDENT
            members_string += doc(submodule, submod_indent)
            submodule_members = get_module_members(submodule)
            for member in submodule_members:
                append, new_symbols = pyi_file(member, indent=submod_indent)
                members_string += append

        if indent == "":
            result_content += f"{indent}__all__ = {symbols}\n"
            result_content += members_string
        else:
            result_content += members_string

    elif inspect.isclass(obj):
        mro = inspect.getmro(obj)
        if len(mro) > 2:
            inherit = f"({mro[1].__name__})"
        else:
            inherit = ""
        result_content += f"{indent}class {obj.__name__}{inherit}:\n"
        symbols.append(obj.__name__)
        indent += INDENT

        class_body = doc(obj, indent)

        if obj.__text_signature__:
            class_body += f"{indent}def __init__{inspect.signature(obj)}:\n"
            class_body += f"{indent+INDENT}pass\n"
            class_body += "\n"

        members = [
            func for name, func in vars(obj).items() if name not in ["__doc__", "__module__", "__new__", "__init__"]
        ]

        for member in members:
            append, new_symbols = pyi_file(member, indent=indent)
            class_body += append
            symbols.extend(new_symbols)

        if not class_body:
            class_body += f"{indent}pass\n"

        result_content += class_body
        result_content += "\n\n"

    elif inspect.isbuiltin(obj):
        symbols.append(obj.__name__)
        result_content += function(obj, indent)

    elif inspect.ismethoddescriptor(obj):
        result_content += function(obj, indent)

    elif inspect.isgetsetdescriptor(obj):
        # TODO it would be interesing to add the setter maybe ?
        result_content += f"{indent}@property\n"
        result_content += function(obj, indent, text_signature="(self)")

    elif inspect.ismemberdescriptor(obj):
        result_content += f"{indent}{obj.__name__}: ..."
    else:
        raise Exception(f"Object {obj} is not supported")
    return result_content, symbols


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
    pyi_content, symbols = pyi_file(module)
    pyi_content = do_black(pyi_content, is_pyi=True)
    os.makedirs(directory, exist_ok=True)

    with open(filename, "w") as f:
        f.write(pyi_content)


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
