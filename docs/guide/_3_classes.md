# Python Classes

Classes are defined using `py.class` method.

```zig
--8<-- "example/classes.zig:class"
```

The returned type of `py.class` will be struct that has be used to define the class.

You can refer to your own state by taking pointer to self `self: *@This()`. Classes internal
state is only accessible from the extension code. Currently pydust doesn't support declaring
Python class attributes.

## Subclasses

Creating subclasses is similar to classes, with exception of needing to provide references
to your base classes.

```zig
--8<-- "example/classes.zig:subclass"
```

Subclasses can then user builtins like [super](https://docs.python.org/3/library/functions.html#super)
to invoke methods on their parent types. Bear in mind that Python superclasses aren't actually fields
on subtype and you can only refer to methods from your super type.

## Instantiation

Pydust provides convenience function `py.init` that creates an instance of pydust defined class. This
will still create a PyObject internally and return the internal state tied to that object. You can
then call methods on that object as usual which will avoid dispatching the method through Python.

```zig
--8<-- "example/classes.zig:init"
```
