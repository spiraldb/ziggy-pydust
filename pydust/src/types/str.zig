const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyObject = @import("obj.zig").PyObject;
const PyError = @import("../errors.zig").PyError;

pub const PyString = extern struct {
    obj: PyObject,

    pub fn of(obj: py.PyObject) PyString {
        return .{ .obj = obj };
    }

    pub fn fromSlice(str: []const u8) !PyString {
        const unicode = ffi.PyUnicode_FromStringAndSize(str.ptr, @intCast(str.len)) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = unicode } };
    }

    pub fn fromPtr(str: [*]const u8) !PyString {
        const unicode = ffi.PyUnicode_FromString(str) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = unicode } };
    }

    pub inline fn append(self: PyString, other: PyString) !PyString {
        return self.appendObj(other.obj);
    }

    pub fn appendObj(self: PyString, other: PyObject) !PyString {
        var self_ptr: ?*ffi.PyObject = self.obj.py;
        ffi.PyUnicode_Append(@ptrCast(&self_ptr), other.py);
        if (self_ptr) |ptr| {
            return .{ .obj = .{ .py = ptr } };
        } else {
            return PyError.Propagate;
        }
    }

    pub fn appendSlice(self: PyString, str: [:0]const u8) !PyString {
        const other = try fromSlice(str);
        defer other.decref();
        return self.appendObj(other.obj);
    }

    pub fn asSlice(self: PyString) ![:0]const u8 {
        var size: i64 = 0;
        const buffer: [*]const u8 = ffi.PyUnicode_AsUTF8AndSize(self.obj.py, &size) orelse return PyError.Propagate;
        return @ptrCast(buffer[0..@intCast(size + 1)]);
    }

    pub fn incref(self: PyString) void {
        self.obj.incref();
    }

    pub fn decref(self: PyString) void {
        self.obj.decref();
    }
};

test "PyString" {
    py.initialize();
    defer py.finalize();

    var ps = try PyString.fromSlice("Hello");
    defer ps.decref();

    ps = try ps.appendSlice(", world!");
    var ps_slice = try ps.asSlice();
    try std.testing.expectEqualStrings("Hello, world!", ps_slice[0 .. ps_slice.len - 1]);
}
