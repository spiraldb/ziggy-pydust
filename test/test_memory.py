import pytest

from example import memory


@pytest.mark.skip
def test_append():
    s = "hello "
    memory.appendFoo(s)
    assert s == "hello foo"
