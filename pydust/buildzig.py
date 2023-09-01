import contextlib
import os
import subprocess
import sys
import sysconfig
import tempfile
import textwrap
from typing import TextIO

import pydust
from pydust import config

# We ship the PyDust Zig library inside our Python package to make it easier
# for us to auto-configure user projects.
PYDUST_ROOT = os.path.join(os.path.dirname(pydust.__file__), "src", "pydust.zig")

PYVER_MINOR = ".".join(str(v) for v in sys.version_info[:2])
PYVER_HEX = f"{sys.hexversion:#010x}"
PYINC = sysconfig.get_path("include")
PYLIB = sysconfig.get_config_var("LIBDIR")


def zig_build(argv: list[str], use_temp=False):
    if use_temp:
        with tempfile.NamedTemporaryFile(dir=".", prefix="build_", suffix=".zig") as temp_build_zig:
            generate_build_zig(temp_build_zig.name)
            subprocess.run(
                [sys.executable, "-m", "ziglang", "build", "--build-file", temp_build_zig.name] + argv, check=True
            )
    else:
        generate_build_zig()
        subprocess.run([sys.executable, "-m", "ziglang", "build"] + argv, check=True)


def generate_build_zig(build_zig_file="build.zig"):
    """Generate the build.zig file for the current pyproject.toml.

    Initially we were calling `zig build-lib` directly, and this worked fine except it meant we
    would need to roll our own caching and figure out how to convince ZLS to pick up our dependencies.

    It's therefore easier, at least for now, to generate a build.zig in the project root and add it
    to the .gitignore. This means ZLS works as expected, we can leverage zig build caching, and the user
    can inspect the generated file to assist with debugging.
    """
    conf = config.load()

    with open(build_zig_file, "w+") as f:
        b = Writer(f)

        b.writeln('const std = @import("std");')
        b.writeln()

        with b.block("pub fn build(b: *std.Build) void"):
            b.write(
                """
                const target = b.standardTargetOptions(.{});
                const optimize = b.standardOptimizeOption(.{});

                const test_step = b.step("test", "Run library tests");
                """
            )

            for ext_module in conf.ext_modules:
                # TODO(ngates): fix the out filename for non-limited modules
                assert ext_module.limited_api, "Only limited_api is supported for now"

                # For each module, we generate some options, a library, as well as a test runner.
                with b.block():
                    b.write(
                        f"""
                        const pyconf = b.addOptions();
                        pyconf.addOption([:0]const u8, "module_name", "{ext_module.libname}");
                        pyconf.addOption(bool, "limited_api", {str(ext_module.limited_api).lower()});
                        pyconf.addOption([:0]const u8, "hexversion", "{PYVER_HEX}");

                        const lib{ext_module.libname} = b.addSharedLibrary(.{{
                            .name = "{ext_module.libname}",
                            .root_source_file = .{{ .path = "{ext_module.root}" }},
                            .main_pkg_path = .{{ .path = "{conf.root}" }},
                            .target = target,
                            .optimize = optimize,
                        }});
                        configurePythonInclude(lib{ext_module.libname}, pyconf);
                        b.installArtifact(lib{ext_module.libname});

                        const test{ext_module.libname} = b.addTest(.{{
                            .root_source_file = .{{ .path = "{ext_module.root}" }},
                            .main_pkg_path = .{{ .path = "{conf.root}" }},
                            .target = target,
                            .optimize = optimize,
                        }});
                        configurePythonRuntime(test{ext_module.libname}, pyconf);

                        const run_test{ext_module.libname} = b.addRunArtifact(test{ext_module.libname});
                        test_step.dependOn(&run_test{ext_module.libname}.step);
                        """
                    )

            b.write(
                f"""
                // Option for emitting test binary based on the given root source. This can be helpful for debugging.
                const debugRoot = b.option([]const u8, "debug-root", "The root path of a file emitted as a binary for use with the debugger");
                if (debugRoot) |root| {{
                    const pyconf = b.addOptions();
                    pyconf.addOption([:0]const u8, "module_name", "debug");
                    pyconf.addOption(bool, "limited_api", false);
                    pyconf.addOption([:0]const u8, "hexversion", "{PYVER_HEX}");

                    const testdebug = b.addTest(.{{
                        .root_source_file = .{{ .path = root }},
                        .main_pkg_path = .{{ .path = "{conf.root}" }},
                        .target = target,
                        .optimize = optimize,
                    }});
                    configurePythonRuntime(testdebug, pyconf);

                    const debugBin = b.addInstallBinFile(testdebug.getEmittedBin(), "debug.bin");
                    b.getInstallStep().dependOn(&debugBin.step);
                }}
                """
            )

        b.write(
            f"""
            fn configurePythonInclude(compile: *std.Build.CompileStep, pyconf: *std.Build.Step.Options) void {{
                compile.addAnonymousModule("pydust", .{{
                    .source_file = .{{ .path = "{PYDUST_ROOT}" }},
                    .dependencies = &.{{.{{ .name = "pyconf", .module = pyconf.createModule() }}}},
                }});
                compile.addIncludePath(.{{ .path = "{PYINC}" }});
                compile.linker_allow_shlib_undefined = true;
            }}

            fn configurePythonRuntime(compile: *std.Build.CompileStep, pyconf: *std.Build.Step.Options) void {{
                configurePythonInclude(compile, pyconf);
                compile.linkLibC();
                compile.linkSystemLibrary("python{PYVER_MINOR}");
                compile.addLibraryPath(.{{ .path =  "{PYLIB}" }});
            }}
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
