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
from pathlib import Path

from pydust import buildzig, config


class PyDust:
    """pydust frontend class"""

    def __init__(
        self,
        extensions: list[str] | None = None,
        zig_exe: str | None = None,
        build_zig: str = "build.zig",
        self_managed: bool = False,
        limited_api: bool = True,
        prefix: str = "",
    ):
        self.zig_exe = zig_exe
        self.build_zig = build_zig
        self.self_managed = self_managed
        self.limited_api = limited_api
        self.prefix = prefix
        self.extensions: list[config.ExtModule] = \
            self._parse_exts(extensions) if extensions else []

    def _parse_exts(
        self,
        exts: list[str],
        limited_api: bool | None = None,
        prefix: str | None = None,
    ) -> list[config.ExtModule]:
        """parses extensions entries, accepts '<name>=<path>' or <path>"""
        _exts = []
        limited_api = limited_api or self.limited_api
        prefix = prefix or self.prefix

        def _add_ext(name, path: Path):
            _exts.append(
                config.ExtModule(name=name, root=path, limited_api=limited_api)
            )

        def _check_path(path: Path):
            assert path.exists(), f"path does not exist: {path}"
            assert path.suffix == ".zig" and path.is_file(),\
                f"path must be a zig file: {path}"

        for elem in exts:
            if "=" in elem:
                name, path = elem.split("=")
                _path = Path(path)
                _check_path(_path)
                _add_ext(name, _path)
            else:  # assume elem is a <path>
                _path = Path(elem)
                _check_path(_path)
                if len(_path.parts) > 1:  # >1 part
                    parts = (_path.parent / (prefix + _path.stem)).parts
                    name = ".".join(parts)
                    _add_ext(name, _path)
                else:  # 1 part
                    name = prefix + _path.stem
                    _add_ext(name, _path)
        return _exts

    def add_extension(
        self,
        path: str,
        name: str | None = None,
        limited_api: bool | None = None,
        prefix: str | None = None,
    ):
        """Add a single extension"""
        exts = [f"{name}={path}"] if name else [path]
        self.extensions.extend(self._parse_exts(exts, limited_api, prefix))

    def add_extensions(
        self,
        extensions: list[str],
        limited_api: bool | None = None,
        prefix: str | None = None,
    ):
        """Add multiple extensions"""
        self.extensions.extend(self._parse_exts(extensions, limited_api, prefix))

    def build(self):
        """Builds zig-based python extensions

        Accepts a list of '<name>=<path>' or '<path>' entries
        """
        buildzig.zig_build(
            argv=[
                "install",
                f"-Dpython-exe={sys.executable}",
                "-Doptimize=ReleaseSafe",
            ],
            conf=config.ToolPydust(
                zig_exe=self.zig_exe,
                build_zig=self.build_zig,
                self_managed=self.self_managed,
                ext_module=self.extensions,
            ),
        )

    def debug(self, entrypoint: str):
        """Given an entrypoint file, compile it for test debugging."""
        buildzig.zig_build(["install", f"-Ddebug-root={entrypoint}"])

    @classmethod
    def commandline(cls):
        """commandline interface"""
        parser = argparse.ArgumentParser()
        sub = parser.add_subparsers(dest="command", required=True)

        debug_sp = sub.add_parser("debug",
            help="Compile a Zig file with debug symbols. Useful for running from an IDE.")
        debug_sp.add_argument("entrypoint")

        build_sp = sub.add_parser("build", help="Build a zig-based python extension.",
            formatter_class=argparse.ArgumentDefaultsHelpFormatter)
        build_sp.add_argument("-z", "--zig-exe", help="zig executable path")
        build_sp.add_argument("-b", "--build-zig", default="build.zig", help="build.zig file")
        build_sp.add_argument("-m", "--self-managed", default=False, action="store_true", help="self-managed mode")
        build_sp.add_argument("-a", "--limited-api", default=True, action="store_true", help="use limited python c-api")
        build_sp.add_argument("-p", "--prefix", default="", help="prefix of built extension")
        build_sp.add_argument("extensions", nargs="+",
            help="space separated list of '<path>' or '<name>=<path>' extension entries")

        args = parser.parse_args()
        app = cls(
            extensions=args.extensions,
            zig_exe=args.zig_exe,
            build_zig=args.build_zig,
            self_managed=args.self_managed,
            limited_api=args.limited_api,
            prefix=args.prefix,
        )

        if args.command == "debug":
            app.debug(args.entrypoint)

        elif args.command == "build":
            app.build()
