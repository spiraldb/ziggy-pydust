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

    pub inline fn append(self: PyString, other: PyString) !void {
        try self.appendObj(other.obj);
    }

    pub fn appendObj(self: *PyString, other: PyObject) !void {
        // This function effectively decref's the left-hand side.
        // The semantics therefore sort of imply mutation, and so we expose the same in our API.
        var self_ptr: ?*ffi.PyObject = self.obj.py;
        ffi.PyUnicode_Append(&self_ptr, other.py);
        if (self_ptr) |ptr| {
            self.obj.py = ptr;
        } else {
            // If set to null, then it failed.
            return PyError.Propagate;
        }
    }

    pub fn appendSlice(self: *PyString, str: [:0]const u8) !void {
        const other = try fromSlice(str);
        defer other.decref();
        try self.appendObj(other.obj);
    }

    pub fn asSlice(self: PyString) ![:0]const u8 {
        var size: i64 = 0;
        const buffer: [*:0]const u8 = ffi.PyUnicode_AsUTF8AndSize(self.obj.py, &size) orelse return PyError.Propagate;
        return buffer[0..@as(usize, @intCast(size)) :0];
    }

    pub fn incref(self: PyString) void {
        self.obj.incref();
    }

    pub fn decref(self: PyString) void {
        self.obj.decref();
    }
};

const testing = std.testing;

test "PyString" {
    py.initialize();
    defer py.finalize();

    const a = "Hello";
    const b = ", world!";

    var ps = try PyString.fromSlice(a);
    defer ps.decref();

    try ps.appendSlice(b);

    var ps_slice = try ps.asSlice();

    // Null-terminated strings have len == non-null bytes, but are guaranteed to have a null byte
    // when indexed by their length.
    try testing.expectEqual(a.len + b.len, ps_slice.len);
    try testing.expectEqual(@as(u8, 0), ps_slice[ps_slice.len]);

    try testing.expectEqualStrings("Hello, world!", ps_slice);
}
