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

import pytest

from pydust import buildzig


def pytest_collection(session):
    """We use the same pydust build system for our example modules, but we trigger it from a pytest hook."""
    # We can't use a temp-file since zig build's caching depends on the file path.
    buildzig.zig_build(["install"])


def pytest_collection_modifyitems(session, config, items):
    """The Pydust Pytest plugin runs Zig tests from within the examples project.

    To ensure our plugin captures the failures, we have made one of those tests fail.
    Therefore we mark it here is "xfail" to test that it actually does so.
    """
    for item in items:
        if item.nodeid == "example/pytest.zig::pydust-expected-failure":
            item.add_marker(pytest.mark.xfail(strict=True))
