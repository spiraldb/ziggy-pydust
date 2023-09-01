from pydust import buildzig


def pytest_collection(session):
    """We use the same pydust build system for our example modules, but we trigger it from a pytest hook."""
    # We can't use a temp-file since zig build's caching depends on the file path.
    buildzig.zig_build(["install"], build_zig="pytest.build.zig")
