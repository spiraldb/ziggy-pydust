from example import memory


def test_memory_append():
    assert memory.append("hello ") == "hello right"


def test_memory_concat():
    assert memory.concat("hello ") == "hello right"
