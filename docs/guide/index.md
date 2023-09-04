# User Guide

The user guide details every single feature Pydust offers. All code snippets are taken
from our `example/` directory and are tested during CI. 

If you do struggle or find any issues with the examples, please do [let us know!](https://github.com/fulcrum-so/ziggy-pydust/issues)

## Conventions

Pydust maintains a consistent set of conventions around structs, function naming, and memory 
management to assist with development. 

### PyObject

A Pydust `py.PyObject` is an extern struct containing _only_ a pointer to an `ffi.PyObject`. In other words,
wherever a `*ffi.PyObject` appears in CPython docs, it can be replaced with a `py.PyObject` (notice not a 
pointer).

``` zig title="PyObject.zig"
const PyObject = extern struct {
    py: *ffi.PyObject,
};
```

### Python Type Wrappers

Pydust ships with type wrappers for CPython built-ins, such as PyFloat, PyTuple, etc. These type wrappers
are extern structs containing a single `#!c py.PyObject` field. This again enables them to be used in place
of `#!c *ffi.PyObject`.

## Type Conversions

At comptime, Pydust wraps your function definitions such that native Zig types can be returned
from functions and automatically converted into Python objects.

!!! note

    Currently only return types are wrapped into Python objects. Argument types must be specified
    as `py.PyObject` or any of the other Pydust `py.Py<Name>` native Python object types.

### Result Types

Currently, only function return types are automatically wrapped into Python objects. As expected, 
any of the Pydust native types (such as `py.PyString`) convert to their respective Python type.

For native Zig types however, the following conversions apply:

| Zig Type      | Python Type  |
| :------------ | :----------- |
| `void`        | `None`       |
| `bool`        | `bool`       |
| `i32`, `i64`  | `int`        |
| `u32`, `u64`  | `int`        |
| `f32`, `f64`  | `float`      |
| `struct`      | `dict`       |
| `tuple struct`| `tuple`      |
