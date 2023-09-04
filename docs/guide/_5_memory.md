# Memory Management

Pydust, like Zig, doesn't perform any implicit memory management. Pydust is designed to be a relatively
thin layer around the CPython API, and therefore the same semantics apply.

All Pydust Python types (such as `py.PyObject` and `py.Py<Name>`) have `incref()` and `decref()` member
functions. These correspond to `ffi.Py_INCREF` and `ffi.Py_DECREF` respectively.

For example, if we take a Zig string `right` and wish to append it to a Python string, we first need
to convert it to a `py.PyString`. We will no longer need this new string at the end of the function,
so we should defer a call to `decref()`.

``` zig
--8<-- "example/memory.zig:append"
```

The left-hand-side does not need be decref'd because `PyString.append` _steals_ a reference to itself.
This is rare in the CPython API, but exists to create more performant and ergonomic code around
string building. For example, chained appends don't need to decref all the intermediate strings.

``` zig 
const s = py.PyString.fromSlice("Hello ");
s = s.appendSlice("1, ");
s = s.appendSlice("2, ");
s = s.appendSlice("3");
return s;
```

!!! tip "Upcoming Feature!"

    Work is underway to provide a test harness that uses Zig's `GeneralPurposeAllocator` to 
    catch memory leaks within your Pydust extension code and surface them to pytest.