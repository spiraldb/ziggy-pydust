const py = @import("./pydust.zig");
const ffi = @import("./ffi.zig");
const PyError = @import("./errors.zig").PyError;

/// Get the length of the given object. Equivalent to len(obj) in Python.
pub fn len(object: anytype) !usize {
    const obj = try py.PyObject.from(object);
    const length = ffi.PyObject_Length(obj.py);
    if (length < 0) return PyError.Propagate;
    return length;
}

/// Import a module by fully-qualified name returning a PyObject.
pub fn import(module_name: [:0]const u8) !py.PyObject {
    return (try py.PyModule.import(module_name)).obj;
}
