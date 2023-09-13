# Python Exceptions

Pydust provides utilities for raising builtin exception types as provided by the
[Stable API](https://docs.python.org/3/c-api/stable.html) under `PyExc_<name>`.

``` zig
--8<-- "example/exceptions.zig:valueerror"
```

Exceptions can be raise with any of the following:

* `#!zig .raise(message: [:0]const u8)`
* `#!zig .raiseFmt(comptime fmt: [:0]const u8, args: anytype)`
* `#!zig .raiseComptimeFmt(comptime fmt: [:0]const u8, comptime args: anytype)`