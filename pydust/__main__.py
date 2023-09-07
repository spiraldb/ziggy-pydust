"""
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements.  See the NOTICE file
distributed with this work for additional information
regarding copyright ownership.  The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License.  You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied.  See the License for the
specific language governing permissions and limitations
under the License.
"""

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
