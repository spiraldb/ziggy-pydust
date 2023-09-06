const std = @import("std");
const ffi = @import("../ffi.zig");
const str = @import("str.zig");
const py = @import("../pydust.zig");
const tramp = @import("../trampoline.zig");
const PyError = @import("../errors.zig").PyError;

/// PyTypeObject exists in Limited API only as an opaque pointer.
pub const PyType = extern struct {
    obj: PyObject,

    pub fn getQualifiedName(self: PyType) !py.PyString {
        return py.PyString.of(ffi.PyType_GetQualName(self.obj.py) orelse return PyError.Propagate);
    }
};

pub const PyObject = extern struct {
    pub const HEAD = ffi.PyObject{
        .ob_refcnt = 1,
        .ob_type = null,
    };

    py: *ffi.PyObject,

    pub fn incref(self: PyObject) void {
        ffi.Py_INCREF(self.py);
    }

    pub fn decref(self: PyObject) void {
        ffi.Py_DECREF(self.py);
    }

    pub fn from(value: anytype) !PyObject {
        return try tramp.Trampoline(@TypeOf(value)).wrap(value);
    }

    /// Call this object without any arguments.
    pub fn call0(self: PyObject) !PyObject {
        return .{ .py = ffi.PyObject_CallNoArgs(self.py) orelse return PyError.Propagate };
    }

    /// Call this object with the given args and kwargs.
    pub fn call(self: PyObject, comptime R: type, args: anytype, kwargs: anytype) !R {
        const argsObj = try tramp.Trampoline(@TypeOf(args)).wrap(args);
        defer argsObj.decref();
        const argsPy = if (try py.len(argsObj) == 0) null else (try py.PyTuple.of(argsObj)).obj.py;

        const kwargsObj = try tramp.Trampoline(@TypeOf(kwargs)).wrap(kwargs);
        defer kwargsObj.decref();
        const kwargsPy = if (try py.len(kwargsObj) == 0) null else (try py.PyDict.of(kwargsObj)).obj.py;

        const result = ffi.PyObject_Call(self.py, argsPy, kwargsPy) orelse return PyError.Propagate;
        return tramp.Trampoline(R).unwrap(.{ .py = result });
    }

    pub fn get(self: PyObject, attr: [:0]const u8) !PyObject {
        return .{ .py = ffi.PyObject_GetAttrString(self.py, attr) orelse return PyError.Propagate };
    }

    // See: https://docs.python.org/3/c-api/buffer.html#buffer-request-types
    pub fn getBuffer(self: py.PyObject, out: *py.PyBuffer, flags: c_int) !void {
        if (ffi.PyObject_CheckBuffer(self.py) != 1) {
            return py.BufferError.raise("object does not support buffer interface");
        }
        if (ffi.PyObject_GetBuffer(self.py, @ptrCast(out), flags) != 0) {
            // Error is already raised.
            return PyError.Propagate;
        }
    }

    pub fn set(self: PyObject, attr: [:0]const u8, value: PyObject) !PyObject {
        if (ffi.PyObject_SetAttrString(self.py, attr, value.py) < 0) {
            return PyError.Propagate;
        }
        return self;
    }

    pub fn del(self: PyObject, attr: [:0]const u8) !PyObject {
        if (ffi.PyObject_DelAttrString(self.py, attr) < 0) {
            return PyError.Propagate;
        }
        return self;
    }

    pub fn repr(self: PyObject) !PyObject {
        return .{ .py = ffi.PyObject_Repr(@ptrCast(self)) orelse return PyError.Propagate };
    }
};

test "call" {
    py.initialize();
    defer py.finalize();

    const math = try py.import("math");
    defer math.decref();

    const pow = try math.get("pow");
    const result = try pow.call(f32, .{ @as(i32, 2), @as(i32, 3) }, .{});

    try std.testing.expectEqual(@as(f32, 8.0), result);
}
