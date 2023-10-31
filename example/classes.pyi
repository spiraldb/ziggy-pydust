from __future__ import annotations

class Animal:
    def species(self, /): ...

class Callable:
    def __init__(self, /):
        pass
    def __call__(self, /, *args, **kwargs):
        """
        Call self as a function.
        """
        ...

class ConstructableClass:
    def __init__(self, count, /):
        pass

class Counter:
    def __init__(self, /):
        pass
    def increment(self, /): ...

    count: ...

class GetAttr:
    def __init__(self, /):
        pass
    def __getattribute__(self, name, /):
        """
        Return getattr(self, name).
        """
        ...

class Hash:
    def __init__(self, x, /):
        pass
    def __hash__(self, /):
        """
        Return hash(self).
        """
        ...

class Math:
    def add(x, y, /): ...

class SomeClass:
    """
    Some class defined in Zig accessible from Python
    """

class User:
    def __init__(self, name, /):
        pass
    @property
    def email(self): ...
    @property
    def greeting(self): ...

class ZigOnlyMethod:
    def __init__(self, x, /):
        pass
    def reexposed(self, /): ...

class Dog(Animal):
    def __init__(self, breed, /):
        pass
    def breed(self, /): ...
