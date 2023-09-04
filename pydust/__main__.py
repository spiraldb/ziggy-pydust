import argparse

from pydust import buildzig

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
    buildzig.zig_build(["install", f"-Ddebug-root={entrypoint}"])


if __name__ == "__main__":
    main()
