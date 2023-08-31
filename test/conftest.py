import pytest

from pydust import build


def pytest_collection(session):
    """We use the same pydust build system for our example modules, but we trigger it from a pytest hook."""
    build.build()


def pytest_collection_modifyitems(session, config, items):
    """The Pydust Pytest plugin runs Zig tests from within the examples project.

    To ensure our plugin captures the failures, we have made one of those tests fail.
    Therefore we mark it here is "xfail" to test that it actually does so.
    """
    for item in items:
        if item.nodeid == "example/pytest.zig::pydust-expected-failure":
            item.add_marker(pytest.mark.xfail(strict=True))
