# Python Modules

Python modules represent the entrypoint into your Zig code. You can create a new 
module by adding an entry into your `pyproject.toml`:

```toml title="pyproject.toml"
[[tool.pydust.ext_module]]
name = "example.modules"   # A fully-qualified python module name
root = "src/modules.zig"   # Path to a Zig file that exports this module.
```

!!! note

    Poetry doesn't support building exclusively native modules without a containing
    python package. In this example, you would need to create an empty `example/__init__.py`.

In Pydust, all Python declarations start life as a struct. When a struct is registered with 
Pydust as a module, a `#!c PyObject *PyInit_<modulename>(void)` function is created automatically
and exported from the compiled shared library. This allows the module to be imported by Python.

## Example Module

Please refer to the annotations in this example module for an explanation of the Pydust features.

```zig title="src/modules.zig"
--8<-- "example/modules.zig:ex"
```

1. In Zig, every file is itself a struct. So assigning `Self = @This();` allows you to get a reference to your own type.

2. Unlike regular Python modules, native Python modules are able to carry private internal state.

3. Any fields that cannot be defaulted at comptime (i.e. if they require calling into Python) 
   must be initialized in the module's `__new__` function.

4. Module functions taking a `*Self` or `*const Self` argument are passed a pointer 
   to their internal state.

5. Arguments in Pydust are accepted as a pointer to a const struct. This allows Pydust to generate
   function docstrings using the struct field names.

6. All modules must be registered with Pydust such that a `PyInit_<modulename>` function is 
   generated and exported from the object file.