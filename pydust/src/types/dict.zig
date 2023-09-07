const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;

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
    pub fn from(value: anytype) !PyDict {
        return switch (@typeInfo(@TypeOf(value))) {
            .Struct => of(try py.toObject(value)),
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
    /// This is equivalent to the Python expression `key in p`.
    pub fn contains(self: PyDict, key: anytype) !bool {
        const keyObj = try py.toObject(key);
        defer keyObj.decref();

        const result = ffi.PyDict_Contains(self.obj.py, keyObj.py);
        if (result < 0) return PyError.Propagate;
        return result == 1;
    }

    /// Insert val into the dictionary p with a key of key.
    pub fn setItem(self: PyDict, key: anytype, value: anytype) !void {
        // toObject creates a new reference to the value object, so we delegate to setOwnedItem.
        const valueObj = try py.toObject(value);
        return self.setOwnedItem(key, valueObj);
    }

    /// Insert object-like value into the dictionary p with a key of key.
    /// The dictionary takes ownership of the value.
    pub fn setOwnedItem(self: PyDict, key: anytype, value: anytype) !void {
        const keyObj = try py.toObject(key);
        defer keyObj.decref();

        const valueObj = py.PyObject.of(value);
        // Since PyDict_setItem creates a new strong reference, we decref this reference
        // such that we give the effect of setOwnedItem stealing the reference.
        defer valueObj.decref();

        const result = ffi.PyDict_SetItem(self.obj.py, keyObj.py, valueObj.py);
        if (result < 0) return PyError.Propagate;
    }

    /// Remove the entry in dictionary p with key key.
    pub fn delItem(self: PyDict, key: anytype) !void {
        const keyObj = try py.toObject(key);
        defer keyObj.decref();

        if (ffi.PyDict_DelItem(self.obj.py, keyObj.py) < 0) {
            return PyError.Propagate;
        }
    }

    /// Return the object from dictionary p which has a key key.
    /// Returned value is a borrowed reference.
    pub fn getItem(self: PyDict, comptime T: type, key: anytype) !?T {
        const keyObj = try py.toObject(key);
        defer keyObj.decref();

        if (ffi.PyDict_GetItemWithError(self.obj.py, keyObj.py)) |item| {
            return try py.as(T, .{ .py = item });
        }

        // If no exception, then the item is missing.
        if (ffi.PyErr_Occurred() == null) {
            return null;
        }

        return PyError.Propagate;
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
        k: py.PyObject,
        v: py.PyObject,

        pub fn key(self: Item, comptime K: type) !K {
            return py.as(K, self.k);
        }

        pub fn value(self: Item, comptime V: type) !V {
            return py.as(V, self.v);
        }
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

            return .{ .k = .{ .py = self.nextKey.? }, .v = .{ .py = self.nextValue.? } };
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
    try pd.setOwnedItem("foo", bar);

    try testing.expect(try pd.contains("foo"));
    try testing.expectEqual(@as(usize, 1), pd.length());

    try testing.expectEqual(bar, (try pd.getItem(py.PyString, "foo")).?);

    try pd.delItem("foo");
    try testing.expect(!try pd.contains("foo"));
    try testing.expectEqual(@as(usize, 0), pd.length());

    try pd.setItem("foo", bar);
    try testing.expectEqual(@as(usize, 1), pd.length());
    pd.clear();
    try testing.expectEqual(@as(usize, 0), pd.length());
}

test "PyDict from" {
    py.initialize();
    defer py.finalize();

    const pd = try PyDict.from(.{ .foo = 123, .bar = false });
    defer pd.decref();

    try testing.expectEqual(@as(u32, 123), (try pd.getItem(u32, "foo")).?);
}

test "PyDict iterator" {
    py.initialize();
    defer py.finalize();

    const pd = try PyDict.new();
    defer pd.decref();

    const foo = try py.PyString.fromSlice("foo");
    defer foo.decref();

    try pd.setItem("bar", foo);
    try pd.setItem("baz", foo);

    var iter = pd.itemsIterator();
    const first = iter.next().?;
    try testing.expectEqualStrings("bar", try (try first.key(py.PyString)).asSlice());
    try testing.expectEqual(foo, try first.value(py.PyString));

    const second = iter.next().?;
    try testing.expectEqualStrings("baz", try (try second.key(py.PyString)).asSlice());
    try testing.expectEqual(foo, try second.value(py.PyString));

    try testing.expectEqual(@as(?PyDict.Item, null), iter.next());
}
