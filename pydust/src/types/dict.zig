const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;
const tramp = @import("../trampoline.zig");

/// See: https://docs.python.org/3/c-api/dict.html
pub const PyDict = extern struct {
    obj: py.PyObject,

    pub fn of(obj: py.PyObject) !PyDict {
        // NOTE(ngates): should we be using CheckExact? Which of our functions break when passed a subclass of dict?
        if (ffi.PyDict_Check(obj.py) == 0) {
            return py.TypeError.raise("expected dict");
        }
        return .{ .obj = obj };
    }

    pub fn incref(self: PyDict) void {
        self.obj.incref();
    }

    pub fn decref(self: PyDict) void {
        self.obj.decref();
    }

    /// Create a PyDict from the given struct.
    pub fn from(comptime S: type, value: S) !PyDict {
        return switch (@typeInfo(S)) {
            .Struct => of(.{ .py = try tramp.Trampoline(S).wrap(value) }),
            else => @compileError("PyDict can only be created from struct types"),
        };
    }

    /// Return a new empty dictionary.
    pub fn new() !PyDict {
        const dict = ffi.PyDict_New() orelse return PyError.Propagate;
        return of(.{ .py = dict });
    }

    /// Return a new dictionary that contains the same key-value pairs as p.
    pub fn copy(self: PyDict) !PyDict {
        const dict = ffi.PyDict_Copy(self.obj.py) orelse return PyError.Propagate;
        return of(.{ .py = dict });
    }

    /// Empty an existing dictionary of all key-value pairs.
    pub fn clear(self: PyDict) void {
        ffi.PyDict_Clear(self.obj.py);
    }

    /// Return the number of items in the dictionary. This is equivalent to len(p) on a dictionary.
    pub fn length(self: PyDict) usize {
        return @intCast(ffi.PyDict_Size(self.obj.py));
    }

    /// Determine if dictionary p contains key.
    /// This is equivalent to the Python expression key in p.
    pub fn contains(self: PyDict, key: py.PyObject) !bool {
        const result = ffi.PyDict_Contains(self.obj.py, key.py);
        if (result < 0) return PyError.Propagate;
        return result == 1;
    }

    pub fn containsStr(self: PyDict, key: []const u8) !bool {
        const keyObj = try py.PyString.fromSlice(key);
        defer keyObj.decref();
        return self.contains(keyObj.obj);
    }

    /// Insert val into the dictionary p with a key of key.
    pub fn setItem(self: PyDict, key: py.PyObject, value: py.PyObject) !void {
        const result = ffi.PyDict_SetItem(self.obj.py, key.py, value.py);
        if (result < 0) return PyError.Propagate;
    }

    /// Insert val into the dictionary p with a key of key.
    /// The dictionary takes ownership of the value.
    pub fn setOwnedItem(self: PyDict, key: py.PyObject, value: py.PyObject) !void {
        defer value.decref();
        try self.setItem(key, value);
    }

    /// Insert val into the dictionary p with a key of key.
    pub fn setItemStr(self: PyDict, key: []const u8, value: anytype) !void {
        const keyObj = try py.PyString.fromSlice(key);
        defer keyObj.decref();
        return self.setItem(keyObj.obj, value);
    }

    /// Insert val into the dictionary p with a key of key.
    pub fn setOwnedItemStr(self: PyDict, key: []const u8, value: py.PyObject) !void {
        defer value.decref();
        try self.setItemStr(key, value);
    }

    /// Remove the entry in dictionary p with key key.
    pub fn delItem(self: PyDict, key: py.PyObject) !void {
        if (ffi.PyDict_DelItem(self.obj.py, key.py) < 0) {
            return PyError.Propagate;
        }
    }

    /// Remove the entry in dictionary p with key key.
    pub fn delItemStr(self: PyDict, key: []const u8) !void {
        const keyObj = try py.PyString.fromSlice(key);
        defer keyObj.decref();
        return self.delItem(keyObj.obj);
    }

    /// Return the object from dictionary p which has a key key.
    /// Return value is a borrowed reference.
    pub fn getItem(self: PyDict, key: py.PyObject) !?py.PyObject {
        if (ffi.PyDict_GetItemWithError(self.obj.py, key.py)) |item| {
            return .{ .py = item };
        }

        // If no exception, then the item is missing.
        if (ffi.PyErr_Occurred() == null) {
            return null;
        }
        return PyError.Propagate;
    }

    pub fn getItemStr(self: PyDict, key: []const u8) !?py.PyObject {
        const keyObj = try py.PyString.fromSlice(key);
        defer keyObj.decref();
        return self.getItem(keyObj.obj);
    }

    pub fn itemsIterator(self: PyDict) ItemIterator {
        return .{
            .pydict = self,
            .position = 0,
            .nextKey = null,
            .nextValue = null,
        };
    }

    pub const Item = struct {
        key: py.PyObject,
        value: py.PyObject,
    };

    pub const ItemIterator = struct {
        pydict: PyDict,
        position: isize,
        nextKey: ?*ffi.PyObject,
        nextValue: ?*ffi.PyObject,

        pub fn next(self: *@This()) ?Item {
            if (ffi.PyDict_Next(
                self.pydict.obj.py,
                &self.position,
                @ptrCast(&self.nextKey),
                @ptrCast(&self.nextValue),
            ) == 0) {
                // No more items
                return null;
            }

            return .{ .key = .{ .py = self.nextKey.? }, .value = .{ .py = self.nextValue.? } };
        }
    };
};

const testing = std.testing;

test "PyDict set and get" {
    py.initialize();
    defer py.finalize();

    const pd = try PyDict.new();
    defer pd.decref();

    const bar = try py.PyString.fromSlice("bar");
    defer bar.decref();
    try pd.setItemStr("foo", bar.obj);
    try testing.expect(try pd.containsStr("foo"));
    try testing.expectEqual(@as(usize, 1), pd.length());

    try testing.expectEqual(bar.obj, (try pd.getItemStr("foo")).?);

    try pd.delItemStr("foo");
    try testing.expect(!try pd.containsStr("foo"));
    try testing.expectEqual(@as(usize, 0), pd.length());

    try pd.setItemStr("foo", bar.obj);
    try testing.expectEqual(@as(usize, 1), pd.length());
    pd.clear();
    try testing.expectEqual(@as(usize, 0), pd.length());
}

test "PyDict iterator" {
    py.initialize();
    defer py.finalize();

    const pd = try PyDict.new();
    defer pd.decref();

    const foo = try py.PyString.fromSlice("foo");
    defer foo.decref();

    try pd.setItemStr("bar", foo.obj);
    try pd.setItemStr("baz", foo.obj);

    var iter = pd.itemsIterator();
    const first = iter.next().?;
    try testing.expectEqualStrings("bar", try (try py.PyString.of(first.key)).asSlice());
    try testing.expectEqual(foo.obj, first.value);

    const second = iter.next().?;
    try testing.expectEqualStrings("baz", try (try py.PyString.of(second.key)).asSlice());
    try testing.expectEqual(foo.obj, second.value);

    try testing.expectEqual(@as(?PyDict.Item, null), iter.next());
}
