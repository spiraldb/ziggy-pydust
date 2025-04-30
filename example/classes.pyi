class Animal:
    def species(self, /): ...

class Callable:
    def __init__(self, /) -> None: ...
    def __call__(self, /, *args, **kwargs):
        """
        Call self as a function.
        """

class ConstructableClass:
    def __init__(self, count, /) -> None: ...

class Counter:
    def __init__(self, /) -> None: ...
    def increment(self, /): ...
    count: ...

class GetAttr:
    def __init__(self, /) -> None: ...
    def __getattribute__(self, name, /):
        """
        Return getattr(self, name).
        """

class Hash:
    def __init__(self, x, /) -> None: ...
    def __hash__(self, /) -> int:
        """
        Return hash(self).
        """

class Math:
    def add(x, y, /): ...

class SomeClass:
    """
    Some class defined in Zig accessible from Python
    """

class User:
    def __init__(self, name, /) -> None: ...
    @property
    def email(self, /): ...
    @property
    def greeting(self, /): ...

class ZigOnlyMethod:
    def __init__(self, x, /) -> None: ...
    def reexposed(self, /): ...

class Dog(Animal):
    def __init__(self, breed, /) -> None: ...
    def breed(self, /): ...
