from pydust import buildzig


def pytest_collection(session):
    """We use the same pydust build system for our example modules, but we trigger it from a pytest hook."""
    buildzig.zig_build(["install"], use_temp=True)
