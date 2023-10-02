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


class Builder:
    """pydust frontend class"""

    def __init__(
        self,
        zig_exe: str = "zig",
        build_zig: str = "build.zig",
        self_managed: bool = False,
        limited_api: bool = True,
        generate_stubs: bool = False,
        extensions: list[tuple[str, str]] | None = None,
    ):
        self.zig_exe = zig_exe
        self.build_zig = build_zig
        self.self_managed = self_managed
        self.limited_api = limited_api
        self.generate_stubs = generate_stubs
        self.extensions = extensions or []

    def build(self):
        """build pydust python extension(s)"""
        assert self.extensions, "extension items [(name:str, path:str)] must be provided"
        buildzig.zig_build(
            argv=["install", f"-Dpython-exe={sys.executable}", "-Doptimize=ReleaseSafe"],
            zig_exe=self.zig_exe,
            build_zig=self.build_zig,
            self_managed=self.self_managed,
            limited_api=self.limited_api,
            generate_stubs=self.generate_stubs,
            extensions=self.extensions,
        )

    def debug(self, entrypoint: str):
        """Given an entrypoint file, compile it for test debugging. Placing it in a well-known location."""
        buildzig.zig_build(["install", f"-Ddebug-root={entrypoint}"])

    @classmethod
    def commandline(cls):
        parser = argparse.ArgumentParser()
        sub = parser.add_subparsers(dest="command", required=True)

        debug = sub.add_parser("debug", help="Compile a Zig file with debug symbols. Useful for running from an IDE.")
        debug.add_argument("entrypoint")

        build = sub.add_parser(
            "build",
            help="Build a set of zig-based python extensions.",
            formatter_class=argparse.ArgumentDefaultsHelpFormatter,
        )
        build.add_argument("-z", "--zig-exe", help="zig executable path")
        build.add_argument("-b", "--build-zig", default="build.zig", help="build.zig file")
        build.add_argument("-m", "--self-managed", default=False, action="store_true", help="self-managed mode")
        build.add_argument("-a", "--limited-api", default=True, action="store_true", help="use limited python c-api")
        build.add_argument("-g", "--generate-stubs", default=False, action="store_true", help="generate stubs")
        build.add_argument("-n", "--ext-name", nargs=True, help="name of extension")
        build.add_argument("-p", "--ext-path", nargs=True, help="path of extension")

        args = parser.parse_args()

        if args.command == "debug":
            builder = cls()
            builder.debug(args.entrypoint)

        elif args.command == "build":
            names = args.ext_name
            paths = args.ext_path
            assert (names and paths) and (
                len(names) == len(paths)
            ), "'build' subcmd requires --ext-name and -ext-path pairs"
            builder = cls(
                zig_exe=args.zig_exe,
                build_zig=args.build_zig,
                self_managed=args.self_managed,
                limited_api=args.limited_api,
                generate_stubs=args.generate_stubs,
                extensions=zip(names, paths),
            )
            builder.build()
