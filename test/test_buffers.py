from example import buffers
from array import array  # implements buffer protocol


def test_sum():
    arr = array("L", [1, 2, 3, 4, 5])  # uint64
    assert buffers.sum(arr) == 15


def test_reverse():
    arr = array("L", [1, 2, 3, 4, 5])  # uint64
    assert array("L", [5, 4, 3, 2, 1]) == buffers.reverse(arr)
