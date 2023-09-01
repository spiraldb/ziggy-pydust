import argparse
import os
import shutil
import subprocess

from pydust import config, zigexe

parser = argparse.ArgumentParser()
sub = parser.add_subparsers(dest="command", required=True)

debug = sub.add_parser("debug", help="Compile a Zig file with debug symbols. Useful for running from an IDE.")
debug.add_argument("entrypoint")


def main():
    args = parser.parse_args()

    if args.command == "debug":
        debug(args)


def debug(args):
    """Given an entrypoint file, compile it for test debugging. Placing it in a well-known location."""
    entrypoint = args.entrypoint

    filename = os.path.basename(entrypoint)
    name, _ext = os.path.splitext(filename)

    ext_module = config.ExtModule(
        name=name,
        root=entrypoint,
        # Not sure how else we could guess this?
        limited_api=False,
    )

    with zigexe.build_argv("test", ext_module, optimize="Debug") as argv:
        subprocess.run(argv, check=True)

    os.makedirs("zig-out/", exist_ok=True)
    shutil.move(ext_module.test_bin, "zig-out/debug.bin")


if __name__ == "__main__":
    main()
