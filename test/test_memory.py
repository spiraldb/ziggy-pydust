from example import memory


def test_append():
    assert memory.appendFoo("hello ") == "hello foo"
