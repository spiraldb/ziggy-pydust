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

import contextlib
import os
import shutil
import subprocess
import sys
import sysconfig
import textwrap
from pathlib import Path
from typing import TextIO

import pydust
from pydust import config

PYVER_MINOR = ".".join(str(v) for v in sys.version_info[:2])
PYVER_HEX = f"{sys.hexversion:#010x}"
PYLDLIB = sysconfig.get_config_var("LDLIBRARY")

# Strip libpython3.11.a.so => python3.11.a
PYLDLIB = PYLDLIB[3:] if PYLDLIB.startswith("lib") else PYLDLIB
PYLDLIB = os.path.splitext(PYLDLIB)[0]


def zig_build(argv: list[str], conf: config.ToolPydust | None = None):
    conf = conf or config.load()

    # Always generate the supporting pydist.build.zig
    shutil.copy(
        Path(pydust.__file__).parent.joinpath("src/pydust.build.zig"),
        conf.pydust_build_zig,
    )

    if not conf.self_managed:
        # Generate the build.zig if we're managing the ext_modules ourselves
        with conf.build_zig.open(mode="w") as f:
            generate_build_zig(f, conf)

    zig_exe = [os.path.expanduser(conf.zig_exe)] if conf.zig_exe else [sys.executable, "-m", "ziglang"]

    cmds = zig_exe + ["build", "--build-file", conf.build_zig] + argv

    subprocess.run(cmds, check=True)


def generate_build_zig(fileobj: TextIO, conf=None):
    """Generate the build.zig file for the current pyproject.toml.

    Initially we were calling `zig build-lib` directly, and this worked fine except it meant we
    would need to roll our own caching and figure out how to convince ZLS to pick up our dependencies.

    It's therefore easier, at least for now, to generate a build.zig in the project root and add it
    to the .gitignore. This means ZLS works as expected, we can leverage zig build caching, and the user
    can inspect the generated file to assist with debugging.
    """
    conf = conf or config.load()

    b = Writer(fileobj)

    b.writeln('const std = @import("std");')
    b.writeln('const py = @import("./pydust.build.zig");')
    b.writeln()

    with b.block("pub fn build(b: *std.Build) void"):
        b.write(
            """
            const target = b.standardTargetOptionsQueryOnly(.{});
            const optimize = b.standardOptimizeOption(.{});

            const test_step = b.step("test", "Run library tests");

            const pydust = py.addPydust(b, .{
                .test_step = test_step,
            });
            """
        )

        for ext_module in conf.ext_modules:
            # TODO(ngates): fix the out filename for non-limited modules
            assert ext_module.limited_api, "Only limited_api is supported for now"

            b.write(
                f"""
                _ = pydust.addPythonModule(.{{
                    .name = "{ext_module.name}",
                    .root_source_file = b.path("{ext_module.root}"),
                    .limited_api = {str(ext_module.limited_api).lower()},
                    .target = target,
                    .optimize = optimize,
                }});
                """
            )


class Writer:
    def __init__(self, fileobj: TextIO) -> None:
        self.f = fileobj
        self._indent = 0

    @contextlib.contextmanager
    def indent(self):
        self._indent += 4
        yield
        self._indent -= 4

    @contextlib.contextmanager
    def block(self, text: str = ""):
        self.write(text)
        self.writeln(" {")
        with self.indent():
            yield
        self.writeln()
        self.writeln("}")
        self.writeln()

    def write(self, text: str):
        if "\n" in text:
            text = textwrap.dedent(text).strip() + "\n\n"
        self.f.write(textwrap.indent(text, self._indent * " "))

    def writeln(self, text: str = ""):
        self.write(text)
        self.f.write("\n")
