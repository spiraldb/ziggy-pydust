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
import sys

from pydust import buildzig, config

parser = argparse.ArgumentParser()
sub = parser.add_subparsers(dest="command", required=True)

debug_sp = sub.add_parser("debug", help="Compile a Zig file with debug symbols. Useful for running from an IDE.")
debug_sp.add_argument("entrypoint")

build_sp = sub.add_parser("build", help="Build a zig-based python extension.",
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)
build_sp.add_argument("-z", "--zig-exe", help="zig executable path")
build_sp.add_argument("-b", "--build-zig", default="build.zig", help="build.zig file")
build_sp.add_argument("-m", "--self-managed", default=False, action="store_true", help="self-managed mode")
build_sp.add_argument("-a", "--limited-api", default=True, action="store_true", help="use limited python c-api")
build_sp.add_argument("-e", "--extensions", nargs='+', help="space separated list of extension '<name>=<path>' entries")

def main():
    args = parser.parse_args()

    if args.command == "debug":
        debug(args)

    elif args.command == "build":
        build(args)

def build(args):
    """Given a list of '<name>=<path>' entries, compiles corresponding zig-based python extensions"""
    assert args.extensions and all('=' in ext for ext in args.extensions), "requires at least one --extensions '<name>=<path>'"
    ext_items = [tuple(ext.split('=')) for ext in args.extensions]
    _extensions = []
    for name, path in ext_items:
        _extensions.append(
            config.ExtModule(name=name, root=path, limited_api=args.limited_api)
        )

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
