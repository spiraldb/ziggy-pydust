const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;

/// Wrapper for Python PyBool.
///
/// See: https://docs.python.org/3/c-api/bool.html
///
/// Note: refcounting semantics apply, even for bools!
pub const PyBool = extern struct {
    obj: py.PyObject,

    pub fn incref(self: PyBool) void {
        self.obj.incref();
    }

    pub fn decref(self: PyBool) void {
        self.obj.decref();
    }

    pub inline fn true_() PyBool {
        return .{ .obj = .{ .py = ffi.PyBool_FromLong(1) } };
    }

    pub inline fn false_() PyBool {
        return .{ .obj = .{ .py = ffi.PyBool_FromLong(0) } };
    }

    pub fn asbool(self: PyBool) bool {
        return ffi.Py_IsTrue(self.obj.py) == 1;
    }
};

test "PyBool" {
    py.initialize();
    defer py.finalize();

    const pytrue = PyBool.true_();
    defer pytrue.decref();

    const pyfalse = PyBool.false_();
    defer pyfalse.decref();

    try std.testing.expect(pytrue.asbool());
    try std.testing.expect(!pyfalse.asbool());
}
