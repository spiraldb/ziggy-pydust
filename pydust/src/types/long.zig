const std = @import("std");
const py = @import("../pydust.zig");
const PyObjectMixin = @import("./obj.zig").PyObjectMixin;
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;

/// Wrapper for Python PyLong.
/// See: https://docs.python.org/3/c-api/long.html#c.PyLongObject
pub const PyLong = extern struct {
    obj: py.PyObject,

    pub usingnamespace PyObjectMixin("int", "PyLong", @This());

    pub fn create(value: anytype) !PyLong {
        if (@TypeOf(value) == comptime_int) {
            return create(@as(i64, @intCast(value)));
        }

        const typeInfo = @typeInfo(@TypeOf(value)).Int;

        const pylong = switch (typeInfo.signedness) {
            .signed => ffi.PyLong_FromLongLong(@intCast(value)),
            .unsigned => ffi.PyLong_FromUnsignedLongLong(@intCast(value)),
        } orelse return PyError.Propagate;

        return .{ .obj = .{ .py = pylong } };
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

    const pl = try PyLong.create(100);
    defer pl.decref();

    try std.testing.expectEqual(@as(c_long, 100), try pl.as(c_long));
    try std.testing.expectEqual(@as(c_ulong, 100), try pl.as(c_ulong));

    const neg_pl = try PyLong.create(@as(c_long, -100));
    defer neg_pl.decref();

    try std.testing.expectError(
        PyError.Propagate,
        neg_pl.as(c_ulong),
    );
}
