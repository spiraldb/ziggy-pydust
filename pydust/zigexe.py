import contextlib
import os
import sys
import sysconfig
import tempfile
from typing import Literal

import pydust
from pydust import config

# We ship the PyDust Zig library inside our Python package to make it easier
# for us to auto-configure user projects.
PYDUST_ROOT = os.path.join(os.path.dirname(pydust.__file__), "src", "pydust.zig")
PYVER_MINOR = ".".join(str(v) for v in sys.version_info[:2])

Command = Literal["build-lib"] | Literal["test"]


@contextlib.contextmanager
def build_argv(command: Command, ext_module: config.ExtModule, optimize: str = "Debug"):
    """The main entry point from Poetry's build script."""
    argv = [sys.executable, "-m", "ziglang", command, "-O", optimize]
    if command == "build-lib":
        argv += ["-dynamic"]
        # TODO(ngates): create the correct .so filename based on arch
        os.makedirs(ext_module.install_prefix, exist_ok=True)
        argv += [f"-femit-bin={os.path.join(ext_module.install_prefix, ext_module.libname + '.abi3.so')}"]

    if command == "test":
        # Generate the test binary without running it.
        # For testing, we need to link libpython too.
        os.makedirs("zig-out/", exist_ok=True)
        argv += [
            f"-femit-bin={ext_module.test_bin}",
            "--test-no-exec",
            "-L",
            sysconfig.get_config_var("LIBDIR"),
            f"-lpython{PYVER_MINOR}",
        ]

    argv += ["--name", ext_module.libname, ext_module.root]

    # Configure root package
    argv += ["--main-pkg-path", config.load().root]

    # Add Python include directory
    argv += [
        "-I",
        sysconfig.get_path("include"),
        # And allow Python symbols to be unresolved
        "-fallow-shlib-undefined",
    ]

    # Link libC
    argv += ["-lc"]

    with pyconf(ext_module) as pyconf_file:
        # Setup a pyconf module
        argv += ["--mod", f"pyconf::{pyconf_file}"]
        # Setup pydust as a dependency, and allow it to read from pyconf
        os.path.dirname(__file__)
        argv += ["--mod", f"pydust:pyconf:{PYDUST_ROOT}"]
        # Add all our deps
        argv += ["--deps", "pydust,pyconf"]

        yield argv


@contextlib.contextmanager
def pyconf(ext_module: config.ExtModule):
    """Render a config file to pass information into the build."""
    with tempfile.NamedTemporaryFile(prefix="pyconf_", suffix=".zig", mode="w") as pyconf_file:
        pyconf_file.write(f'pub const module_name: [:0]const u8 = "{ext_module.name}";\n')
        pyconf_file.write(f"pub const limited_api: bool = {str(ext_module.limited_api).lower()};\n")

        hexversion = f"{sys.hexversion:#010x}"
        pyconf_file.write(f'pub const hexversion: [:0]const u8 = "{hexversion}";\n')

        pyconf_file.flush()
        yield pyconf_file.name
