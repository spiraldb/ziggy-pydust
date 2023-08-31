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

Command = Literal["build-lib"] | Literal["test"]


@contextlib.contextmanager
def build_argv(command: Command, ext_module: config.ExtModule):
    """The main entry point from Poetry's build script."""
    pydust_conf = config.load()

    argv = [sys.executable, "-m", "ziglang", command]
    if command == "build-lib":
        argv += ["-dynamic"]

    # Setup pydust as a dependency
    os.path.dirname(__file__)
    argv += ["--mod", f"pydust::{PYDUST_ROOT}"]
    # Add Python include directory
    argv += [
        "-I",
        sysconfig.get_path("include"),
        # And allow Python symbols to be unresolved
        "-fallow-shlib-undefined",
    ]

    # Configure root package
    argv += ["--main-pkg-path", pydust_conf.root]

    # Setup a config package to pass information into the build
    with tempfile.NamedTemporaryFile(prefix="pyconf_", suffix=".zig", mode="w") as pyconf_file:
        argv += ["--mod", f"pyconf::{pyconf_file.name}"]
        pyconf_file.write('pub const foo = "bar";\n')
        pyconf_file.flush()

        # Add all our deps
        argv += ["--deps", "pydust,pyconf"]

        # For each module, run a zig build
        argv += ["--name", ext_module.libname, ext_module.root]

        if command == "test":
            # Generate the test binary without running it.
            # For testing, we need to link libpython too.
            os.makedirs("zig-out/", exist_ok=True)
            argv += [
                "-femit-bin=" + os.path.join("zig-out", ext_module.libname + ".test.bin"),
                "--test-no-exec",
                "-L",
                sysconfig.get_config_var("LIBDIR"),
                "-lpython3.11",  # FIXME,
            ]

        if command == "build-lib":
            # TODO(ngates): create the correct .so filename based on arch
            os.makedirs(ext_module.install_prefix, exist_ok=True)
            argv += [f"-femit-bin={os.path.join(ext_module.install_prefix, ext_module.libname + '.abi3.so')}"]

        # Calculate the Python hex versions
        if ext_module.limited_api:
            argv += ["-DPy_LIMITED_API=0x030B0000"]  # 3.11

        yield argv
