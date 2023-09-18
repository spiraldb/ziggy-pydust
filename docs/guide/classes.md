# Python Classes

TODO

* Defining a class
* Constructor
* Inheritance
* Instance Attributes (note no class attrs)
* Properties
* Instance methods
* Class methods
* Static methods
* Slots

This page describes how to define, instantiate and customize Python classes with Pydust.

Classes are defined by wrapping structs with the `py.class` function.

```zig
--8<-- "example/classes.zig:defining"
```

Struct fields are used to store per-instance state, and public struct functions are exported
as Python functions. See the [section on functions](./functions.md) for more details.

## Instantiation

By default, Pydust classes can _only_ be instantiated from Zig. While it is possible to
create Pydust structs with Zig syntax, this will only create a Zig struct and not the
corresponding Python object around it.

For example, the class above can be correctly constructed using the `py.init` function:

```zig
const some_class = try py.init(SomeClass, .{ .count = 1 });
```

### From Python

To enable instantiation from Python, you must define a `__new__` function
that takes a [CallArgs](./functions.md#call-args) struct and returns a new instance of `Self`.

```zig
--8<-- "example/classes.zig:constructor"
```

From Python, the class can then be instantiated as normal:

```python
--8<-- "test/test_classes_constructor.py:constructor"
```

## Inheritance

Inheritance allows you to define a subclass of another Zig Pydust class.

!!! note

    It is currently not possible to create a subclass of a Python class.

Subclasses are defined by including the parent class struct as a field of the subclass struct.

```zig
--8<-- "example/classes.zig:subclass"
```

They can then be instantiated from Zig using `py.init`, or from Python
if a `__new__` function is defined.

```python
--8<-- "test/test_classes.py:subclass"
```

### Super

The `py.super(Type, self)` function returns a proxy `py.PyObject` that can be used to invoke methods on the super class. This behaves the same as the Python builtin [super](https://docs.python.org/3/library/functions.html#super).

## Properties



## Instance Attributes

### Class Attributes

Class attributes are not currently supported by Pydust.

## Instance Methods

## Class Methods

## Static Methods

Static methods are similar to class methods but do not have access to the class itself. You can define static methods by simply not taking a `self` argument.

```zig
--8<-- "example/classes.zig:staticmethods"
```

## Dunder Methods

Dunder methods, or "double underscore" methods, provide a mechanism for overriding builtin
Python operators.

The currently supported methods are:



## Binary Operators

Pydust supports classes implementing binary operators (e.g. `__add__` or bitwise operators).

```zig
--8<-- "example/classes.zig:operator"
```

The self parameter must be a pointer to the class type. The other parameter can be of any Pydust supported type.

Supported binary operators are: `__add__`, `__sub__`, `__mul__`, `__mod__`, `__divmod__`, `__pow__`,
`__lshift__`, `__rshift__`, `__and__`, `__xor__`, `__or__`, `__truediv__`, `__floordiv__`,
`__matmul__`, `__getitem__`.
