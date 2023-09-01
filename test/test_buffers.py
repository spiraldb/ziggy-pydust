from array import array  # implements buffer protocol

from example import buffers


def test_sum():
    arr = array("L", [1, 2, 3, 4, 5])  # uint64
    assert buffers.sum(arr) == 15


def test_reverse():
    arr = array("L", [1, 2, 3, 4, 5])  # uint64
    buffers.reverse(arr)
    assert arr == array("L", [5, 4, 3, 2, 1])


def test_nd():
    import numpy as np

    arr = np.asarray([[1, 2, 3], [4, 5, 6]], dtype=np.uint64)
    buffers.testing(arr)
