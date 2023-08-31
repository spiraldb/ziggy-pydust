import subprocess

from pydust import config, zigexe


def build():
    """The main entry point from Poetry's build script."""
    pydust_conf = config.load()

    for ext_module in pydust_conf.ext_modules:
        with zigexe.build_argv("build-lib", ext_module) as argv:
            retcode = subprocess.call(argv)
            if retcode != 0:
                raise ValueError(f"Failed to compile Zig with args {argv}")
