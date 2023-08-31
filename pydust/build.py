import shlex
import subprocess

from pydust import config, zigexe


def build():
    """The main entry point from Poetry's build script."""
    pydust_conf = config.load()

    for ext_module in pydust_conf.ext_modules:
        # TODO(ngates): figure out if we're running as part of a dev install, or an sdist install?
        with zigexe.build_argv("build-lib", ext_module, optimize="ReleaseSafe") as argv:
            retcode = subprocess.call(argv)
            if retcode != 0:
                raise ValueError(f"Failed to compile Zig: {' '.join(shlex.quote(arg) for arg in argv)}")
