const py = @import("./pydust.zig");
const ffi = @import("./ffi.zig");
const PyError = @import("./errors.zig").PyError;

/// Returns a new reference to Py_None.
pub inline fn None() py.PyObject {
    // It's important that we incref the Py_None singleton
    const none = py.PyObject{ .py = ffi.Py_None };
    none.incref();
    return none;
}

/// Checks whether a given object is None. Avoids incref'ing None to do the check.
pub inline fn is_none(object: anytype) bool {
    const obj = try py.object(object);
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

/// Get the length of the given object. Equivalent to len(obj) in Python.
pub fn len(object: anytype) !usize {
    const obj = try py.object(object);
    const length = ffi.PyObject_Length(obj.py);
    if (length < 0) return PyError.Propagate;
    return @intCast(length);
}

/// Import a module by fully-qualified name returning a PyObject.
pub fn import(module_name: [:0]const u8) !py.PyObject {
    return (try py.PyModule.import(module_name)).obj;
}

/// The equivalent of Python's super() builtin. Returns a PyObject.
pub fn super(comptime Super: type, selfInstance: anytype) !py.PyObject {
    const imported = try import(py.findContainingModule(Super));
    const superPyType = try imported.get(py.getClassName(Super));
    const pyObj = try py.object(selfInstance);

    const superBuiltin = py.PyObject{ .py = @alignCast(@ptrCast(&ffi.PySuper_Type)) };
    return superBuiltin.call(py.PyObject, .{ superPyType, pyObj }, .{});
}
