# Python Functions

TODO:
* CallArgs struct (parsed into args/kwargs)


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
