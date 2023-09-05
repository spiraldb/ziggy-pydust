const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;

/// Wrapper for Python PyLong.
/// See: https://docs.python.org/3/c-api/long.html#c.PyLongObject
pub const PyLong = extern struct {
    obj: py.PyObject,

    pub fn of(obj: py.PyObject) PyLong {
        return .{ .obj = obj };
    }

    /// Construct a PyLong from a comptime-known integer type.
    pub fn from(comptime int_type: type, value: int_type) !PyLong {
        const typeInfo = @typeInfo(int_type).Int;
        return switch (typeInfo.signedness) {
            // We +1 each switch case to each of the bit sizes. This prevents compilation errors on platforms
            // where c_long == c_longlong, while avoiding a Zig compiler error for the lower bound being gt the upper bound.
            .signed => switch (typeInfo.bits) {
                0...@bitSizeOf(c_long) => fromLong(@intCast(value)),
                else => @compileError("Unsupported long type" ++ @typeName(int_type)),
            },
            .unsigned => switch (typeInfo.bits) {
                0...@bitSizeOf(c_ulong) => fromULong(@intCast(value)),
                else => @compileError("Unsupported long type" ++ @typeName(int_type)),
            },
        };
    }

    pub fn as(self: PyLong, comptime int_type: type) !int_type {
        const typeInfo = @typeInfo(int_type).Int;
        return switch (typeInfo.signedness) {
            .signed => {
                if (typeInfo.bits <= @bitSizeOf(c_long)) {
                    return @intCast(try self.asLong());
                } else if (typeInfo.bits <= @bitSizeOf(c_longlong)) {
                    return @intCast(try self.asLongLong());
                } else {
                    @compileError("Unsupported long type" ++ @typeName(int_type));
                }
            },
            .unsigned => {
                if (typeInfo.bits <= @bitSizeOf(c_ulong)) {
                    return @intCast(try self.asULong());
                } else if (typeInfo.bits <= @bitSizeOf(c_ulonglong)) {
                    return @intCast(try self.asULongLong());
                } else {
                    @compileError("Unsupported long type" ++ @typeName(int_type));
                }
            },
        };
    }

    pub fn incref(self: PyLong) void {
        self.obj.incref();
    }

    pub fn decref(self: PyLong) void {
        self.obj.decref();
    }

    fn fromLong(value: c_long) !PyLong {
        return .{ .obj = .{ .py = ffi.PyLong_FromLong(value) orelse return PyError.Propagate } };
    }

    fn fromULong(value: c_ulong) !PyLong {
        return .{ .obj = .{ .py = ffi.PyLong_FromUnsignedLong(value) orelse return PyError.Propagate } };
    }

    fn asLong(self: PyLong) !c_long {
        var pl = ffi.PyLong_AsLong(self.obj.py);
        return if (ffi.PyErr_Occurred() != null) PyError.Propagate else pl;
    }

    fn asLongLong(self: PyLong) !c_longlong {
        var pl = ffi.PyLong_AsLongLong(self.obj.py);
        return if (ffi.PyErr_Occurred() != null) PyError.Propagate else pl;
    }

    fn asULong(self: PyLong) !c_ulong {
        var pl = ffi.PyLong_AsUnsignedLong(self.obj.py);
        return if (ffi.PyErr_Occurred() != null) PyError.Propagate else pl;
    }

    fn asULongLong(self: PyLong) !c_ulonglong {
        var pl = ffi.PyLong_AsUnsignedLongLong(self.obj.py);
        return if (ffi.PyErr_Occurred() != null) PyError.Propagate else pl;
    }
};

test "PyLong" {
    py.initialize();
    defer py.finalize();

    const pl = try PyLong.from(c_long, 100);
    defer pl.decref();

    try std.testing.expectEqual(@as(c_long, 100), try pl.as(c_long));
    try std.testing.expectEqual(@as(c_ulong, 100), try pl.as(c_ulong));

    const neg_pl = try PyLong.from(c_long, -100);
    defer neg_pl.decref();

    try std.testing.expectError(
        PyError.Propagate,
        neg_pl.as(c_ulong),
    );
}
