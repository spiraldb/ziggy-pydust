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

import sys
import argparse

from pydust import buildzig


parser = argparse.ArgumentParser()
sub = parser.add_subparsers(dest="command", required=True)

debug_sp = sub.add_parser("debug", help="Compile a Zig file with debug symbols. Useful for running from an IDE.")
debug_sp.add_argument("entrypoint")

build_sp = sub.add_parser("build", help="Build a zig-based python extension.", 
    formatter_class=argparse.ArgumentDefaultsHelpFormatter)
# build_sp.add_argument("root")
build_sp.add_argument("-z", "--zig-exe", help="zig executable path")
build_sp.add_argument("-b", "--build-zig", default="build.zig", help="build.zig file")
build_sp.add_argument("-m", "--self-managed", default=False, action="store_true", help="self-managed mode")
build_sp.add_argument("-a", "--limited-api", default=True, action="store_true", help="use limited python c-api")
build_sp.add_argument("-n", "--ext-name", nargs=True, help="name of extension")
build_sp.add_argument("-p", "--ext-path", nargs=True, help="path of extension")


def main():
    args = parser.parse_args()

    if args.command == "debug":
        debug(args)

    elif args.command == "build":
        build(args)



def build(args):
    """Given a zig target, compile into a python-extension"""

    if args.ext_name and args.ext_path:

        buildzig.zig_build_config(
            argv=["install", f"-Dpython-exe={sys.executable}", "-Doptimize=ReleaseSafe"],
            zig_exe=args.zig_exe,
            build_zig=args.build_zig,
            self_managed=args.self_managed,
            limited_api=args.limited_api,
            names=args.ext_name,
            paths=args.ext_path,
        )
        return
    print("requires a single extension name and path pair")
    print("eg: python -m pydust build --ext-name 'fib._lib' --ext-path 'fib/fib.zig'")


def debug(args):
    """Given an entrypoint file, compile it for test debugging. Placing it in a well-known location."""
    entrypoint = args.entrypoint
    buildzig.zig_build(["install", f"-Ddebug-root={entrypoint}"])


if __name__ == "__main__":
    main()
