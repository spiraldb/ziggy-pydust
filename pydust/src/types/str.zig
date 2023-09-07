const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyObject = @import("obj.zig").PyObject;
const PyError = @import("../errors.zig").PyError;

pub const PyString = extern struct {
    obj: PyObject,

    pub fn of(obj: py.PyObject) !PyString {
        if (ffi.PyUnicode_Check(obj.py) == 0) {
            return py.TypeError.raise("expected str");
        }
        return .{ .obj = obj };
    }

    pub fn fromSlice(str: []const u8) !PyString {
        const unicode = ffi.PyUnicode_FromStringAndSize(str.ptr, @intCast(str.len)) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = unicode } };
    }

    /// Append other to self.
    ///
    /// Warning: a reference to self is stolen. Use concat, or self.incref(), if you don't own a reference to self.
    pub fn append(self: PyString, other: PyString) !PyString {
        return self.appendObj(other.obj);
    }

    /// Append the slice to self.
    ///
    /// Warning: a reference to self is stolen. Use concat, or self.incref(), if you don't own a reference to self.
    pub fn appendSlice(self: PyString, str: []const u8) !PyString {
        const other = try fromSlice(str);
        defer other.decref();
        return self.appendObj(other.obj);
    }

    fn appendObj(self: PyString, other: PyObject) !PyString {
        // This function effectively decref's the left-hand side.
        // The semantics therefore sort of imply mutation, and so we expose the same in our API.
        // FIXME(ngates): this comment
        var self_ptr: ?*ffi.PyObject = self.obj.py;
        ffi.PyUnicode_Append(&self_ptr, other.py);
        if (self_ptr) |ptr| {
            return of(.{ .py = ptr });
        } else {
            // If set to null, then it failed.
            return PyError.Propagate;
        }
    }

    /// Concat other to self. Returns a new reference.
    pub fn concat(self: PyString, other: PyString) !PyString {
        const result = ffi.PyUnicode_Concat(self.obj.py, other.obj.py) orelse return PyError.Propagate;
        return of(.{ .py = result });
    }

    /// Concat other to self. Returns a new reference.
    pub fn concatSlice(self: PyString, other: []const u8) !PyString {
        const otherString = try fromSlice(other);
        defer otherString.decref();

        return concat(self, otherString);
    }

    /// Return the length of the Unicode object, in code points.
    pub fn length(self: PyString) !usize {
        return @intCast(ffi.PyUnicode_GetLength(self.obj.py));
    }

    pub fn asOwnedSlice(self: PyString) ![:0]const u8 {
        defer self.decref();
        return try self.asSlice();
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
    // defer ps.decref();  <-- We don't need to decref here since append steals the reference to self.
    ps = try ps.appendSlice(b);
    defer ps.decref();

    var ps_slice = try ps.asSlice();

    // Null-terminated strings have len == non-null bytes, but are guaranteed to have a null byte
    // when indexed by their length.
    try testing.expectEqual(a.len + b.len, ps_slice.len);
    try testing.expectEqual(@as(u8, 0), ps_slice[ps_slice.len]);

    try testing.expectEqualStrings("Hello, world!", ps_slice);
}
