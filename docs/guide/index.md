# User Guide

The user guide details every single feature Pydust offers. All code snippets are taken
from our `example/` directory and are tested during CI. 

If you do struggle or find any issues with the examples, please do [let us know!](https://github.com/fulcrum-so/ziggy-pydust/issues)

## Conventions

Pydust maintains a consistent set of conventions around structs, function naming, and memory 
management to assist with development. 

### Conversion Functions

When converting from Python to Zig types:

* `.as(T)` - return a view of the object *as* the given type. This will leave the `refcnt` of the original object untouched.
* `.into(T)` - convert the object *into* the given type. This will decref the Python object when converting into Zig primitive
types. This is also known as "stealing the reference", or "moving the reference". After calling `into` on an object, you 
should consider the original object to be invalid.

## Type Conversions

At comptime, Pydust wraps your function definitions such that native Zig types can be accepted
or returned from functions and automatically converted into Python objects.

### Zig Primitives

| Zig Type       | Python Type  |
|:---------------| :----------- |
| `void`         | `None`       |
| `bool`         | `bool`       |
| `i32`, `i64`   | `int`        |
| `u32`, `u64`   | `int`        |
| `f32`, `f64`   | `float`      |
| `struct`       | `dict`       |
| `tuple struct` | `tuple`      |
| `[]const u8`   | `str`        |
| `*[_]u8`       | `str`        |

!!! Note

    We have found that generally we use a `[]const u8` to mean a string, and therefore
    our default conversion logic is to a Python unicode str object.

    If you wish to return a Python bytes object, you must explicitly wrap your slice
    with `py.PyBytes`.

### Pydust Objects

Pointers to any Pydust Zig structs will convert to their corresponding Python instance. 

For example, given the class `Foo` below,
if the class is initialized with `const foo: *Foo = py.init(Foo, .{})`,
then a result of `foo` will be wrapped into the corresponding Python instance of
`Foo`. 

```zig title="foo.zig"
const Foo = py.class("Foo", struct { a: u32 = 0 });

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
| `py.PyLong`   | `int`        |
| `py.PyFloat`  | `float`      |
| `py.PyTuple`  | `tuple`      |
| `py.PyDict`   | `dict`       |
| `py.PyString` | `str`        |
