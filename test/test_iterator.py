import pytest

from example import iterators


def test_range_iterator():
    range_iterator = iter(iterators.Range(0, 10, 1))
    for i in range(10):
        assert next(range_iterator) == i
    with pytest.raises(StopIteration):
        next(range_iterator)
