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

import argparse
import os
import sys

from pydust import buildzig, config

parser = argparse.ArgumentParser()
sub = parser.add_subparsers(dest="command", required=True)

debug_sp = sub.add_parser("debug",
    help="Compile a Zig file with debug symbols. Useful for running from an IDE.")
debug_sp.add_argument("entrypoint")

build_sp = sub.add_parser("build", help="Build a zig-based python extension.",
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)
build_sp.add_argument("-z", "--zig-exe", help="zig executable path")
build_sp.add_argument("-b", "--build-zig", default="build.zig", help="build.zig file")
build_sp.add_argument("-m", "--self-managed", default=False, action="store_true",
    help="self-managed mode")
build_sp.add_argument("-a", "--limited-api", default=True, action="store_true",
    help="use limited python c-api")
build_sp.add_argument("-p", "--prefix", default='', help="prefix of built extension")
build_sp.add_argument("extensions", nargs='+',
    help="space separated list of extension '<path>' or '<name>=<path>' entries")


def main():
    args = parser.parse_args()

    if args.command == "debug":
        debug(args)

    elif args.command == "build":
        build(args)


def _parse_exts(exts: list[str], limited_api: bool = True, prefix: str = '') -> list[config.ExtModule]:
    """parses extensions entries, accepts '<name>=<path>' or <path>"""
    _exts = []
    def add_ext(name, path):
        _exts.append(
            config.ExtModule(
                name=name, root=path, limited_api=limited_api, prefix=prefix)
        )
    def check_path(path):
        assert os.path.exists(path), f"path does not exist: {path}"
        assert os.path.splitext(path)[1]=='.zig', f"path must be a zig file: {path}"
    for elem in exts:
        if '=' in elem:
            name, path = elem.split('=')
            check_path(path)
            add_ext(name, path)
        else: # assume elem is a <path>
            path = elem
            check_path(path)
            if os.path.sep in path: # >1 part
                parts = path.split(os.path.sep)
                tail = parts.pop()
                stem, suffix = os.path.splitext(tail)
                parts = parts + [(prefix+stem)]
                name = '.'.join(parts)
                add_ext(name, path)
            else: # 1 part
                stem, suffix = os.path.splitext(path)
                name = prefix + stem
                add_ext(name, path)
    return _exts

def build(args):
    """Given a list of '<name>=<path>' or '<path>' entries, builds zig-based python extensions"""
    _extensions = _parse_exts(
        exts=args.extensions, limited_api=args.limited_api, prefix=args.prefix)
    buildzig.zig_build(
        argv=["install", f"-Dpython-exe={sys.executable}", "-Doptimize=ReleaseSafe"],
        conf=config.ToolPydust(
            zig_exe=args.zig_exe,
            build_zig=args.build_zig,
            self_managed=args.self_managed,
            ext_module=_extensions,
        )
    )

def debug(args):
    """Given an entrypoint file, compile it for test debugging. Placing it in a well-known location."""
    entrypoint = args.entrypoint
    buildzig.zig_build(["install", f"-Ddebug-root={entrypoint}"])


if __name__ == "__main__":
    main()
