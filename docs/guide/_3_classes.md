# Python Classes

Classes are defined using `py.class` method.

```zig
--8<-- "example/classes.zig:class"
```

The returned type of `py.class` is the same struct that has been used to define the class.

You can refer to your own state by taking pointer to self `self: *@This()`. Classes' internal
state is only accessible from the extension code. Currently pydust doesn't support declaring
Python class attributes.

## Instantiation and constructors

Pydust provides convenience function `py.init` that creates an instance of pydust defined class. This
will still create a PyObject internally and return the internal state tied to that object. You can
then call methods on that object as usual which will avoid dispatching the method through Python.

If your class defines a `pub fn __new__(args: struct{}) !Self` function, then it is possible to instantiate
it from Python. Otherwise, it is only possible to instantiate the class from Zig using `py.init`.

```zig
--8<-- "example/classes.zig:init"
```


## Subclasses

Creating subclasses is similar to classes, with the exception of needing to provide references
to your base classes.

```zig
--8<-- "example/classes.zig:subclass"
```

Subclasses can then use builtins like [super](https://docs.python.org/3/library/functions.html#super)
to invoke methods on their parent types. Bear in mind that Python superclasses aren't actually fields
on the subtype. Thus it is only possible to refer to supertype methods from that supertype.

## Binary Operators

Pydust supports classes implementing binary operators (e.g. `__add__` or bitwise operators).

```zig
--8<-- "example/classes.zig:operator"
```

The self parameter must be a pointer to the class type. The other parameter can be of any Pydust supported type.

Supported binary operators are: `__add__`, `__sub__`, `__mul__`, `__mod__`, `__divmod__`, `__pow__`,
`__lshift__`, `__rshift__`, `__and__`, `__xor__`, `__or__`, `__truediv__`, `__floordiv__`,
`__matmul__`, `__getitem__`.
