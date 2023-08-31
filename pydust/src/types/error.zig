const ffi = @import("../ffi.zig");
const py = @import("../pydust.zig");
const PyError = @import("../errors.zig").PyError;

pub const PyExc = struct {
    obj: py.PyObject,

    pub fn raise(self: PyExc, message: [:0]const u8) void {
        PyErr.setString(self, message);
    }

    pub const BaseException: PyExc = .{ .obj = .{ .py = ffi.PyExc_BaseException } };
    pub const TypeError: PyExc = .{ .obj = .{ .py = ffi.PyExc_TypeError } };
    pub const ValueError: PyExc = .{ .obj = .{ .py = ffi.PyExc_ValueError } };
};

pub const PyErr = struct {
    pub fn pass() PyErr {}

    pub fn setString(exc_type: PyExc, message: [:0]const u8) void {
        ffi.PyErr_SetString(exc_type.obj.py, message.ptr);
    }

    pub fn setRuntimeError(message: [:0]const u8) void {
        ffi.PyErr_SetString(ffi.PyExc_RuntimeError, message.ptr);
    }
};
