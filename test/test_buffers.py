from array import array  # implements buffer protocol

from example import buffers


def test_view():
    _ = memoryview(buffers.Buffer())
    _ = array(buffers.Buffer())
