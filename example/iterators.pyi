from __future__ import annotations

class Range:
    def __init__(lower, upper, step, /):
        pass
    def __iter__(self, /):
        """
        Implement iter(self).
        """
        ...

class RangeIterator:
    """
    Range iterator
    """

    def __next__(self, /):
        """
        Implement next(self).
        """
        ...
