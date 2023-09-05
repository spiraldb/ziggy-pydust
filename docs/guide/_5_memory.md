# Memory Management

Pydust, like Zig, doesn't perform any implicit memory management. Pydust is designed to be a relatively
thin layer around the CPython API, and therefore the same semantics apply.

All Pydust Python types (such as `py.PyObject` and `py.Py<Name>`) have `incref()` and `decref()` member
functions. These correspond to `Py_INCREF` and `Py_DECREF` respectively.

To create a contrived example, here we take a string `left` as an argument passed in from Python and we 
append a Zig slice `right` to it. Since we create a new `py.PyString` containing `right`, it is our 
responsibility to ensure `decref()` is called on it.

The reason we call `incref()` on `left` is more subtle. When being called from Python, we are essentially
_borrowing_ references to each of the arguments. The `PyString.append` function actually _steals_ 
a reference to itself (for performance improvements and ergonomics when chaining multiple `append` calls).
Since we had only borrowed a reference to `left`, we must call `.incref()` in order to allow `left.append()`
to steal the new reference back again.

``` zig
--8<-- "example/memory.zig:append"
```

Of course, this could be implemeneted much more simply using `PyString.concatSlice` (which returns a new reference
without stealing one) and also internally creates and decref's `right`.

``` zig
--8<-- "example/memory.zig:concat"
```

In general, Pydust functions to not steal references. They should be loudly documented in the rare cases that 
they do, and typically will have the naming convention `fromOwned` meaning they take ownership (steal a reference)
to the argument being passed in.

The `PyString.append` function can however be useful. For example, when chaining several appends together.

``` zig 
var s = py.PyString.fromSlice("Hello ");
s = s.appendSlice("1, ");
s = s.appendSlice("2, ");
s = s.appendSlice("3");
return s;
```

!!! tip "Upcoming Feature!"

    Work is underway to provide a test harness that uses Zig's `GeneralPurposeAllocator` to 
    catch memory leaks within your Pydust extension code and surface them to pytest.