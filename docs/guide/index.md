# User Guide

The user guide details every single feature Pydust offers. All code snippets are taken
from our `example/` directory and are tested during CI.

If you do struggle or find any issues with the examples, please do [let us know!](https://github.com/fulcrum-so/ziggy-pydust/issues)

## Conventions

Pydust maintains a consistent set of conventions around structs, function naming, and memory
management to assist with development.

### Conversion Functions

When converting from Python to Zig types:

* `.as(T, anytype)` - return a view of the object *as* the given type. This will leave the `refcnt` of the original object untouched.

When creating Python types from Zig types:

* `.create(anytype)` - create a new Python object from a Zig type. Zig slices are copied.
* `PyFoo.checked(py.PyObject)` - checks a `PyObject` is indeed a `PyFoo` before wrapping it up as one.
* `PyFoo.unchecked(py.PyObject)` - wraps a `PyObject` as a `PyFoo` without checking the type.

## Type Conversions

At comptime, Pydust wraps your function definitions such that native Zig types can be accepted
or returned from functions and automatically converted into Python objects.

### Zig Primitives

| Zig Type              | Python Type  |
|:----------------------| :----------- |
| `void`                | `None`       |
| `bool`                | `bool`       |
| `i32`, `i64`          | `int`        |
| `u32`, `u64`          | `int`        |
| `f16`, `f32`, `f64`   | `float`      |
| `struct`              | `dict`       |
| `tuple struct`        | `tuple`      |
| `[]const u8`          | `str`        |
| `*[_]u8`              | `str`        |

!!! tip ""

    Slices (e.g. `[]const u8` strings) cannot be returned from Pydust functions since Pydust has
    no way to deallocate them after they're copied into Python.

    Slices _can_ be taken as arguments to a function, but the bytes underlying that slice are only
    guaranteed to live for the duration of the function call. They should be copied if you wish to extend
    the lifetime.

### Pydust Objects

Pointers to any Pydust Zig structs will convert to their corresponding Python instance.

For example, given the class `Foo` below,
if the class is initialized with `const foo: *Foo = py.init(Foo, .{})`,
then a result of `foo` will be wrapped into the corresponding Python instance of
`Foo`.

```zig title="foo.zig"
const Foo = py.class(struct { a: u32 = 0 });

pub fn create_foo() *const Foo {
    return py.init(Foo, .{});
}
```

### Pydust Type Wrappers

The Pydust Python type wrappers convert as expected.

| Zig Type      | Python Type  |
| :------------ | :----------- |
| `py.PyObject` | `object`     |
| `py.PyBool`   | `bool`       |
| `py.PyBytes`  | `bytes`      |
| `py.PyLong`   | `int`        |
| `py.PyFloat`  | `float`      |
| `py.PyTuple`  | `tuple`      |
| `py.PyDict`   | `dict`       |
| `py.PyString` | `str`        |
