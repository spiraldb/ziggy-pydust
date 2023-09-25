# Python Classes

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
that takes a CallArgs struct and returns a new instance of `Self`.

=== "Zig"

    ```zig
    --8<-- "example/classes.zig:constructor"
    ```

=== "Python"

    ```python
    --8<-- "test/test_classes.py:constructor"
    ```

## Inheritance

Inheritance allows you to define a subclass of another Zig Pydust class.

!!! note

    It is currently not possible to create a subclass of a Python class.

Subclasses are defined by including the parent class struct as a field of the subclass struct.
They can then be instantiated from Zig using `py.init`, or from Python
if a `__new__` function is defined.

=== "Zig"

    ```zig
    --8<-- "example/classes.zig:subclass"
    ```

=== "Python"

    ```python
    --8<-- "test/test_classes.py:subclass"
    ```

### Super

The `py.super(Type, self)` function returns a proxy `py.PyObject` that can be used to invoke methods on the super class. This behaves the same as the Python builtin [super](https://docs.python.org/3/library/functions.html#super).

## Properties

Properties behave the same as the Python `@property` decorator. They allow you to define
getter and setter functions for an attribute of the class.

Pydust properties are again defined as structs with optional `get` and `set` methods. If you
do not define a `set` method for example, then the property is read-only. And vice versa.

In this example we define an `email` property that performs a naive validity check. It makes
use of Zig's `@fieldParentPointer` builtin to get a handle on the class instance struct.

=== "Zig"

    ```zig
    --8<-- "example/classes.zig:properties"
    ```

=== "Python"

    ```python
    --8<-- "test/test_classes.py:properties"
    ```

In the second example, the `greeting` property takes `*const Self` as a first parameter providing it direct
access to the outer struct. This is a convenience when implementing typically getter-only properties.

## Instance Attributes

Attributes are similar to properties, except they do not allow for custom getters and setters.
Due to how they are implemented, attributes wrap the type in a struct definition:

```zig
struct { value: T }
```

This means you must access the attribute in Zig using `.value`.

=== "Zig"

    ```zig
    --8<-- "example/classes.zig:attributes"
    ```

=== "Python"

    ```python
    --8<-- "test/test_classes.py:attributes"
    ```

!!! note

    Attributes are currently read-only. Please file an issue if you have a use-case for writable
    attributes.

### Class Attributes

Class attributes are not currently supported by Pydust.

## Static Methods

Static methods are similar to class methods but do not have access to the class itself. You can define static methods by simply not taking a `self` argument.

```zig
--8<-- "example/classes.zig:staticmethods"
```

## Dunder Methods

Dunder methods, or "double underscore" methods, provide a mechanism for overriding builtin
Python operators.

- `object` refers to either a pointer to a Pydust type, a `py.PyObject`,
  or any other Pydust Python type, e.g. `py.PyString`.
- `CallArgs` refers to a Zig struct that is interpreted as `args` and `kwargs`
  where fields are marked as keyword arguments if they have a default value.

Also note the shorthand signatures:

```zig
const binaryfunc = fn(self: *Self, other: object) !object;
```

### Type Methods

| Method     | Signature                         |
| :--------- | :-------------------------------- |
| `__new__`  | `#!zig fn(CallArgs) !Self`        |
| `__init__` | `#!zig fn(*Self, CallArgs) !void` |
| `__del__`  | `#!zig fn(*Self) void`            |
| `__repr__` | `#!zig fn(*Self) !py.PyString`    |
| `__str__`  | `#!zig fn(*Self) !py.PyString`    |
| `__iter__` | `#!zig fn(*Self) !object`         |
| `__next__` | `#!zig fn(*Self) !?object`        |

### Sequence Methods

| Method    | Signature                |
| :-------- | :----------------------- |
| `__len__` | `#!zig fn(*Self) !usize` |

The remaining sequence methods are yet to be implemented.

### Mapping Methods

| Method        | Signature    |
| :------------ | :----------- |
| `__getitem__` | `binaryfunc` |

The remaining mapping methods are yet to be implemented.

### Number Methods

You can override numerical methods. If you want to support mixing types declare second argument as `py.PyObject` and perform the type checks inside the function

=== "Zig"

    ```zig
    --8<-- "example/operators.zig:ops"
    ```

=== "Python"

    ```python
    --8<-- "test/test_operators.py:test_ops"
    ```

| Method          | Signature    |
| :-------------- | :----------- |
| `__add__`       | `binaryfunc` |
| `__iadd__`      | `binaryfunc` |
| `__sub__`       | `binaryfunc` |
| `__isub__`      | `binaryfunc` |
| `__mul__`       | `binaryfunc` |
| `__imul__`      | `binaryfunc` |
| `__mod__`       | `binaryfunc` |
| `__imod__`      | `binaryfunc` |
| `__divmod__`    | `binaryfunc` |
| `__pow__`       | `binaryfunc` |
| `__ipow__`      | `binaryfunc` |
| `__lshift__`    | `binaryfunc` |
| `__ilshift__`   | `binaryfunc` |
| `__rshift__`    | `binaryfunc` |
| `__irshift__`   | `binaryfunc` |
| `__and__`       | `binaryfunc` |
| `__iand__`      | `binaryfunc` |
| `__or__`        | `binaryfunc` |
| `__ior__`       | `binaryfunc` |
| `__xor__`       | `binaryfunc` |
| `__ixor__`      | `binaryfunc` |
| `__truediv__`   | `binaryfunc` |
| `__itruediv__`  | `binaryfunc` |
| `__floordiv__`  | `binaryfunc` |
| `__ifloordiv__` | `binaryfunc` |
| `__matmul__`    | `binaryfunc` |
| `__imatmul__`   | `binaryfunc` |

??? "Example usage of all numeric functions"

    ```zig
    --8<-- "example/operators.zig:all"
    ```

### Buffer Methods

| Method               | Signature                                      |
| :------------------- | :--------------------------------------------- |
| `__buffer__`         | `#!zig fn (*Self, *py.PyBuffer, flags: c_int)` |
| `__release_buffer__` | `#!zig fn (*Self, *py.PyBuffer)`               |
