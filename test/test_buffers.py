from example import modules
from array import array  # implements buffer protocol


def test_sum():
    arr = array("L", [1, 2, 3, 4, 5])  # uint64
    assert modules.sum(arr) == 15


def test_reverse():
    arr = array("L", [1, 2, 3, 4, 5])  # uint64
    assert arr == modules.reverse(arr)
