const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyLong = @import("long.zig").PyLong;
const PyFloat = @import("float.zig").PyFloat;
const PyObject = @import("obj.zig").PyObject;
const PyError = @import("../errors.zig").PyError;

pub const PyTuple = extern struct {
    obj: PyObject,

    pub fn of(obj: py.PyObject) PyTuple {
        return .{ .obj = obj };
    }

    pub fn new(size: isize) !PyTuple {
        const tuple = ffi.PyTuple_New(@intCast(size)) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = tuple } };
    }

    pub fn fromValues(values: []const PyObject) !PyTuple {
        const tuple = ffi.PyTuple_New(@intCast(values.len)) orelse return PyError.Propagate;

        for (values, 0..) |value, i| {
            if (ffi.PyTuple_SetItem(tuple, @intCast(i), value.py) < 0) {
                return PyError.Propagate;
            }
        }

        return .{ .obj = .{ .py = tuple } };
    }

    pub fn getSize(self: *const PyTuple) !isize {
        return ffi.PyTuple_Size(self.obj.py);
    }

    pub fn getItem(self: *const PyTuple, idx: isize) !PyObject {
        if (ffi.PyTuple_GetItem(self.obj.py, @intCast(idx))) |item| {
            return .{ .py = item };
        } else {
            return PyError.Propagate;
        }
    }

    pub fn getRawItem(self: *const PyTuple, idx: isize) !*ffi.PyObject {
        if (ffi.PyTuple_GetItem(self.obj.py, @intCast(idx))) |item| {
            return item;
        } else {
            return PyError.Propagate;
        }
    }

    pub fn setItem(self: *const PyTuple, item: isize, value: PyObject) !void {
        if (ffi.PyTuple_SetItem(self.obj.py, @intCast(item), value.py) < 0) {
            return PyError.Propagate;
        }
    }

    pub fn incref(self: PyTuple) void {
        self.obj.incref();
    }

    pub fn decref(self: PyTuple) void {
        self.obj.decref();
    }
};

test "PyTuple" {
    py.initialize();
    defer py.finalize();

    const first = try PyLong.from(c_long, 1);
    defer first.decref();
    const second = try PyFloat.from(f64, 1.0);
    defer second.decref();

    var tuple = try PyTuple.fromValues(&.{ first.obj, second.obj });
    defer tuple.decref();

    try std.testing.expectEqual(@as(isize, 2), try tuple.getSize());

    try std.testing.expectEqual(@as(c_long, 1), try PyLong.of(try tuple.getItem(0)).as(c_long));
    try tuple.setItem(0, second.obj);
    try std.testing.expectEqual(@as(f64, 1.0), try PyFloat.of(try tuple.getItem(0)).as(f64));
}
