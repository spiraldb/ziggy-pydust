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
    def __init__(next, stop, step, /):
        pass
    def __next__(self, /):
        """
        Implement next(self).
        """
        ...
