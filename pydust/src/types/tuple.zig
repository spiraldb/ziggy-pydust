const std = @import("std");
const py = @import("../pydust.zig");
const PyObjectMixin = @import("./obj.zig").PyObjectMixin;
const ffi = py.ffi;
const PyLong = @import("long.zig").PyLong;
const PyFloat = @import("float.zig").PyFloat;
const PyObject = @import("obj.zig").PyObject;
const PyError = @import("../errors.zig").PyError;
const seq = @import("./sequence.zig");

pub const PyTuple = extern struct {
    obj: PyObject,

    pub usingnamespace PyObjectMixin("tuple", "PyTuple", @This());
    pub usingnamespace seq.SequenceMixin(@This());

    /// Construct a PyTuple from the given Zig tuple.
    pub fn create(values: anytype) !PyTuple {
        const s = @typeInfo(@TypeOf(values)).Struct;
        if (!s.is_tuple and s.fields.len > 0) {
            @compileError("Expected a struct tuple " ++ @typeName(@TypeOf(values)));
        }

        const tuple = try new(s.fields.len);
        inline for (s.fields, 0..) |field, i| {
            // Recursively unwrap the field value
            try tuple.setItem(@intCast(i), try py.create(@field(values, field.name)));
        }
        return tuple;
    }

    /// Convert this tuple into the given Zig tuple struct.
    pub fn as(self: PyTuple, comptime T: type) !T {
        const s = @typeInfo(T).Struct;
        const result: T = undefined;
        for (s.fields, 0..) |field, i| {
            const value = try self.getItem(field.type, i);
            if (value) |val| {
                @field(result, field.name) = val;
            } else if (field.default_value) |default| {
                @field(result, field.name) = @as(*const field.type, @alignCast(@ptrCast(default))).*;
            } else {
                return py.TypeError.raise("tuple missing field " ++ field.name ++ ": " ++ @typeName(field.type));
            }
        }
        return result;
    }

    pub fn new(size: usize) !PyTuple {
        const tuple = ffi.PyTuple_New(@intCast(size)) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = tuple } };
    }

    pub fn length(self: *const PyTuple) usize {
        return @intCast(ffi.PyTuple_Size(self.obj.py));
    }

    pub fn getItem(self: *const PyTuple, comptime T: type, idx: usize) !T {
        return self.getItemZ(T, @intCast(idx));
    }

    pub fn getItemZ(self: *const PyTuple, comptime T: type, idx: isize) !T {
        if (ffi.PyTuple_GetItem(self.obj.py, idx)) |item| {
            return py.as(T, py.PyObject{ .py = item });
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
};

test "PyTuple" {
    py.initialize();
    defer py.finalize();

    const first = try PyLong.create(1);
    defer first.decref();
    const second = try PyFloat.create(1.0);
    defer second.decref();

    var tuple = try PyTuple.create(.{ first.obj, second.obj });
    defer tuple.decref();

    try std.testing.expectEqual(@as(usize, 2), tuple.length());

    try std.testing.expectEqual(@as(usize, 0), try tuple.index(second));

    try std.testing.expectEqual(@as(c_long, 1), try tuple.getItem(c_long, 0));
    try tuple.setItem(0, second.obj);
    try std.testing.expectEqual(@as(f64, 1.0), try tuple.getItem(f64, 0));
}
