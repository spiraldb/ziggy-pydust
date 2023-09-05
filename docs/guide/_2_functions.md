# Python Functions

Python functions can be declared as usual zig functions at top level of the module

```zig
--8<-- "example/functions.zig:function"
```

Functions come with \_\_text_signature\_\_ support out of the box. Function `double`
will have signature `(x, /)`.

Functions also accept keyword arguments as regular python function. Argument is deemed
to be a kwarg argument if it has a default value associated with it for a function:

```zig
--8<-- "example/functions.zig:kwargs"
```

The generated signature will be `(x, /, *, y=42.0)`

## Exceptions

Pydust wraps all CPython exception types for convenience and lets users
define functions that return zig error types. Exception method will set appropriate
python exception to the interpreter and propagate a null return value.

```zig
--8<-- "example/functions.zig:exceptions"
```

All available apis are explaine in [Exceptions](exceptions.md).
