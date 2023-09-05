from array import array

from example import buffers


def test_view():
    buffer = buffers.ConstantBuffer(1, 10)
    view = memoryview(buffer)
    for i in range(10):
        assert view[i] == 1
    view.release()


def test_sum():
    # array implements a buffer protocol
    arr = array("l", [1, 2, 3, 4, 5])
    assert buffers.sum(arr) == 15
