const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyObject = py.PyObject;
const PyLong = py.PyLong;
const PyError = @import("../errors.zig").PyError;

/// Wrapper for Python PyList.
/// See: https://docs.python.org/3/c-api/list.html
pub const PyList = extern struct {
    obj: py.PyObject,

    pub fn of(obj: py.PyObject) PyList {
        return .{ .obj = obj };
    }

    pub fn new(size: usize) !PyList {
        const list = ffi.PyList_New(@intCast(size)) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = list } };
    }

    pub fn length(self: *const PyList) usize {
        return @intCast(ffi.PyList_Size(self.obj.py));
    }

    // Returns borrowed reference.
    pub fn getItem(self: *const PyList, idx: isize) !PyObject {
        if (ffi.PyList_GetItem(self.obj.py, idx)) |item| {
            return .{ .py = item };
        } else {
            return PyError.Propagate;
        }
    }

    // Returns new reference with borrowed items.
    pub fn getSlice(self: *const PyList, low: isize, high: isize) !PyList {
        if (ffi.PyList_GetSlice(self.obj.py, low, high)) |item| {
            return .{ .obj = .{ .py = item } };
        } else {
            return PyError.Propagate;
        }
    }

    /// This function “steals” a reference to item and discards a reference to an item already in the list at the affected position.
    pub fn setOwnedItem(self: *const PyList, pos: isize, value: PyObject) !void {
        if (ffi.PyList_SetItem(self.obj.py, pos, value.py) < 0) {
            return PyError.Propagate;
        }
    }

    /// Does not steal a reference to value.
    pub fn setItem(self: *const PyList, pos: isize, value: PyObject) !void {
        defer value.incref();
        return self.setOwnedItem(pos, value);
    }

    // Insert the item item into list list in front of index idx.
    pub fn insert(self: *const PyList, idx: isize, value: PyObject) !void {
        if (ffi.PyList_Insert(self.obj.py, idx, value.py) < 0) {
            return PyError.Propagate;
        }
    }

    // Append the object item at the end of list list.
    pub fn append(self: *const PyList, value: PyObject) !void {
        if (ffi.PyList_Append(self.obj.py, value.py) < 0) {
            return PyError.Propagate;
        }
    }

    // Sort the items of list in place.
    pub fn sort(self: *const PyList) !void {
        if (ffi.PyList_Sort(self.obj.py) < 0) {
            return PyError.Propagate;
        }
    }

    // Reverse the items of list in place.
    pub fn reverse(self: *const PyList) !void {
        if (ffi.PyList_Reverse(self.obj.py) < 0) {
            return PyError.Propagate;
        }
    }

    pub fn asTuple(self: *const PyList) !py.PyTuple {
        return try py.PyTuple.of(.{ .py = ffi.PyList_AsTuple(self.obj.py) orelse return PyError.Propagate });
    }

    pub fn incref(self: PyList) void {
        self.obj.incref();
    }

    pub fn decref(self: PyList) void {
        self.obj.decref();
    }
};

const testing = std.testing;

test "PyList" {
    py.initialize();
    defer py.finalize();

    var list = try PyList.new(2);
    defer list.decref();

    const first = try PyLong.from(i64, 1);
    defer first.decref();
    try testing.expectEqual(@as(usize, 2), list.length());
    try list.setItem(0, first.obj);
    try testing.expectEqual(@as(i64, 1), try py.as(i64, list.getItem(0)));

    const second = try PyLong.from(i64, 2);
    try list.setOwnedItem(1, second.obj); // owned by the list, don't decref

    const third = try PyLong.from(i64, 3);
    defer third.decref();
    try list.append(third.obj);
    try testing.expectEqual(@as(usize, 3), list.length());
    try testing.expectEqual(@as(i64, 3), try py.as(i64, list.getItem(2)));

    try list.reverse();
    try testing.expectEqual(@as(i64, 3), try py.as(i64, list.getItem(0)));
    try testing.expectEqual(@as(i64, 1), try py.as(i64, list.getItem(2)));
    try list.sort();
    try testing.expectEqual(@as(i64, 1), try py.as(i64, list.getItem(0)));
    try testing.expectEqual(@as(i64, 3), try py.as(i64, list.getItem(2)));

    const tuple = try list.asTuple();
    defer tuple.decref();
    try std.testing.expectEqual(@as(usize, 3), tuple.length());
}
