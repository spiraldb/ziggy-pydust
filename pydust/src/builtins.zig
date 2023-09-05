const py = @import("./pydust.zig");
const ffi = @import("./ffi.zig");

/// Returns a new reference to Py_None.
pub inline fn None() py.PyObject {
    // It's important that we incref the Py_None singleton
    const none = py.PyObject{ .py = ffi.Py_None };
    none.incref();
    return none;
}

/// Checks whether a given object is None. Avoids incref'ing None to do the check.
pub inline fn isNone(object: anytype) bool {
    const obj = try py.PyObject.from(object);
    return ffi.Py_IsNone(obj.py) == 1;
}

/// Returns a new reference to Py_False.
pub inline fn False() py.PyBool {
    return py.PyBool.false_();
}

/// Returns a new reference to Py_True.
pub inline fn True() py.PyBool {
    return py.PyBool.true_();
}

/// Import a module by fully-qualified name returning a PyObject.
pub fn import(module_name: [:0]const u8) !py.PyObject {
    return (try py.PyModule.import(module_name)).obj;
}
