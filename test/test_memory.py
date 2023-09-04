from example import memory


def test_memory_append():
    assert memory.appendFoo("hello ") == "hello foo"
