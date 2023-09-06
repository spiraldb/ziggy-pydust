const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;

/// Wrapper for Python PyFloat.
/// See: https://docs.python.org/3/c-api/float.html
pub const PyFloat = extern struct {
    obj: py.PyObject,

    pub fn of(obj: py.PyObject) !PyFloat {
        if (ffi.PyFloat_Check(obj.py) == 0) {
            return py.TypeError.raise("expected float");
        }
        return .{ .obj = obj };
    }

    /// Construct a PyFloat from a comptime-known float type.
    pub fn from(comptime float_type: type, value: float_type) !PyFloat {
        const typeInfo = @typeInfo(float_type).Float;
        return switch (typeInfo.bits) {
            16 => fromDouble(@floatCast(value)),
            32 => fromDouble(@floatCast(value)),
            64 => fromDouble(value),
            else => @compileError("Unsupported float type" ++ @typeName(float_type)),
        };
    }

    pub fn as(self: PyFloat, comptime float_type: type) !float_type {
        return switch (float_type) {
            f32 => @floatCast(try self.asDouble()),
            f64 => try self.asDouble(),
            else => @compileError("Unsupported float type " ++ @typeName(float_type)),
        };
    }

    pub fn incref(self: PyFloat) void {
        self.obj.incref();
    }

    pub fn decref(self: PyFloat) void {
        self.obj.decref();
    }

    fn fromDouble(value: f64) !PyFloat {
        return .{ .obj = .{ .py = ffi.PyFloat_FromDouble(value) orelse return PyError.Propagate } };
    }

    fn asDouble(self: PyFloat) !f64 {
        var pd = ffi.PyFloat_AsDouble(self.obj.py);
        return if (ffi.PyErr_Occurred() != null) PyError.Propagate else pd;
    }
};

test "PyFloat" {
    py.initialize();
    defer py.finalize();

    const pf = try PyFloat.from(f32, 1.0);
    defer pf.decref();

    try std.testing.expectEqual(@as(f32, 1.0), try pf.as(f32));
}
