const std = @import("std");
const py = @import("../pydust.zig");
const PyObjectMixin = @import("./obj.zig").PyObjectMixin;

const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;

/// Wrapper for Python PyFloat.
/// See: https://docs.python.org/3/c-api/float.html
pub const PyFloat = extern struct {
    obj: py.PyObject,

    pub usingnamespace PyObjectMixin("float", "PyFloat", @This());

    pub fn create(value: anytype) !PyFloat {
        const pyfloat = ffi.PyFloat_FromDouble(@floatCast(value)) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = pyfloat } };
    }

    pub fn as(self: PyFloat, comptime float_type: type) !float_type {
        return switch (float_type) {
            f32 => @floatCast(try self.asDouble()),
            f64 => try self.asDouble(),
            else => @compileError("Unsupported float type " ++ @typeName(float_type)),
        };
    }

    fn asDouble(self: PyFloat) !f64 {
        var pd = ffi.PyFloat_AsDouble(self.obj.py);
        return if (ffi.PyErr_Occurred() != null) PyError.Propagate else pd;
    }
};

test "PyFloat" {
    py.initialize();
    defer py.finalize();

    const pf = try PyFloat.create(1.0);
    defer pf.decref();

    try std.testing.expectEqual(@as(f32, 1.0), try pf.as(f32));
}
