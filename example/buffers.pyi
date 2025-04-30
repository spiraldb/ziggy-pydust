from __future__ import annotations

def sum(buf, /): ...

class ConstantBuffer:
    """
    A class implementing a buffer protocol
    """

    def __init__(self, elem, length, /):
        pass
    def __buffer__(self, flags, /):
        """
        Return a buffer object that exposes the underlying memory of the object.
        """
        ...
