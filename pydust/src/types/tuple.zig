const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyLong = @import("long.zig").PyLong;
const PyFloat = @import("float.zig").PyFloat;
const PyObject = @import("obj.zig").PyObject;
const PyError = @import("../errors.zig").PyError;

pub const PyTuple = extern struct {
    obj: PyObject,

    pub fn of(obj: py.PyObject) !PyTuple {
        if (ffi.PyTuple_Check(obj.py) == 0) {
            return py.TypeError.raise("Expected tuple");
        }
        return .{ .obj = obj };
    }

    pub fn new(size: isize) !PyTuple {
        const tuple = ffi.PyTuple_New(@intCast(size)) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = tuple } };
    }

    /// Construct a PyTuple from the given Zig tuple.
    pub fn from(values: anytype) !PyTuple {
        if (!@typeInfo(@TypeOf(values)).Struct.is_tuple) {
            @compileError("Must pass a Zig tuple into PyTuple.from");
        }
        return of(try py.PyObject.from(values));
    }

    pub fn getSize(self: *const PyTuple) !isize {
        return ffi.PyTuple_Size(self.obj.py);
    }

    pub fn getItem(self: *const PyTuple, idx: usize) !PyObject {
        if (ffi.PyTuple_GetItem(self.obj.py, @intCast(idx))) |item| {
            return .{ .py = item };
        } else {
            return PyError.Propagate;
        }
    }

    /// Insert a reference to object o at position pos of the tuple.
    ///
    /// Warning: steals a reference to value.
    pub fn setOwnedItem(self: *const PyTuple, pos: isize, value: PyObject) !void {
        if (ffi.PyTuple_SetItem(self.obj.py, @intCast(pos), value.py) < 0) {
            return PyError.Propagate;
        }
    }

    /// Insert a reference to object o at position pos of the tuple. Does not steal a reference to value.
    pub fn setItem(self: *const PyTuple, pos: isize, value: PyObject) !void {
        if (ffi.PyTuple_SetItem(self.obj.py, @intCast(pos), value.py) < 0) {
            return PyError.Propagate;
        }
        // PyTuple_SetItem steals a reference to value. We want the default behaviour not to do that.
        // See setOwnedItem for an implementation that does steal.
        value.incref();
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

    var tuple = try PyTuple.from(.{ first.obj, second.obj });
    defer tuple.decref();

    try std.testing.expectEqual(@as(isize, 2), try tuple.getSize());

    try std.testing.expectEqual(@as(c_long, 1), try (try PyLong.of(try tuple.getItem(0))).as(c_long));
    try tuple.setItem(0, second.obj);
    try std.testing.expectEqual(@as(f64, 1.0), try (try PyFloat.of(try tuple.getItem(0))).as(f64));
}
