// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

const std = @import("std");
const py = @import("../pydust.zig");
const PyObjectMixin = @import("./obj.zig").PyObjectMixin;
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;
const State = @import("../discovery.zig").State;

/// See: https://docs.python.org/3/c-api/dict.html
pub fn PyDict(comptime root: type) type {
    return extern struct {
        obj: py.PyObject(root),

        const Self = @This();
        pub usingnamespace PyObjectMixin(root, "dict", "PyDict", Self);

        /// Create a dictionary from a Zig object
        pub fn create(value: anytype) !Self {
            const s = @typeInfo(@TypeOf(value)).Struct;

            const dict = try new();
            inline for (s.fields) |field| {
                // Recursively create the field values
                try dict.setOwnedItem(field.name, try py.create(root, @field(value, field.name)));
            }
            return dict;
        }

        /// Convert this dictionary into the provided Zig struct.
        /// If the dictionary has extra fields not present in the struct, no error is raised.
        pub fn as(self: Self, comptime T: type) !T {
            const s = @typeInfo(T).Struct;
            var result: T = undefined;
            inline for (s.fields) |field| {
                const value = try self.getItem(field.type, field.name ++ "");
                if (value) |val| {
                    @field(result, field.name) = val;
                } else if (field.default_value) |default| {
                    @field(result, field.name) = @as(*const field.type, @alignCast(@ptrCast(default))).*;
                } else {
                    return py.TypeError.raise("dict missing field " ++ field.name ++ ": " ++ @typeName(field.type));
                }
            }
            return result;
        }

        /// Return a new empty dictionary.
        pub fn new() !Self {
            const dict = ffi.PyDict_New() orelse return PyError.PyRaised;
            return Self.unchecked(.{ .py = dict });
        }

        /// Return a new dictionary that contains the same key-value pairs as p.
        pub fn copy(self: Self) !Self {
            const dict = ffi.PyDict_Copy(self.obj.py) orelse return PyError.PyRaised;
            return Self.unchecked(.{ .py = dict });
        }

        /// Empty an existing dictionary of all key-value pairs.
        pub fn clear(self: Self) void {
            ffi.PyDict_Clear(self.obj.py);
        }

        /// Return the number of items in the dictionary. This is equivalent to len(p) on a dictionary.
        pub fn length(self: Self) usize {
            return @intCast(ffi.PyDict_Size(self.obj.py));
        }

        /// Determine if dictionary p contains key.
        /// This is equivalent to the Python expression `key in p`.
        pub fn contains(self: Self, key: anytype) !bool {
            const keyObj = try py.create(root, key);
            defer keyObj.decref();

            const result = ffi.PyDict_Contains(self.obj.py, keyObj.py);
            if (result < 0) return PyError.PyRaised;
            return result == 1;
        }

        /// Insert val into the dictionary p with a key of key.
        pub fn setItem(self: Self, key: anytype, value: anytype) !void {
            // toObject creates a new reference to the value object, so we delegate to setOwnedItem.
            const valueObj = try py.create(root, value);
            return self.setOwnedItem(key, valueObj);
        }

        /// Insert object-like value into the dictionary p with a key of key.
        /// The dictionary takes ownership of the value.
        pub fn setOwnedItem(self: Self, key: anytype, value: anytype) !void {
            const keyObj = try py.create(root, key);
            defer keyObj.decref();

            // Since PyDict_setItem creates a new strong reference, we decref this reference
            // such that we give the effect of setOwnedItem stealing the reference.
            const valueObj = py.object(root, value);
            defer valueObj.decref();

            const result = ffi.PyDict_SetItem(self.obj.py, keyObj.py, valueObj.py);
            if (result < 0) return PyError.PyRaised;
        }

        /// Remove the entry in dictionary p with key key.
        pub fn delItem(self: Self, key: anytype) !void {
            const keyObj = try py.create(root, key);
            defer keyObj.decref();

            if (ffi.PyDict_DelItem(self.obj.py, keyObj.py) < 0) {
                return PyError.PyRaised;
            }
        }

        /// Return the object from dictionary p which has a key key.
        /// Returned value is a borrowed reference.
        pub fn getItem(self: Self, comptime T: type, key: anytype) !?T {
            const keyObj = try py.create(root, key);
            defer keyObj.decref();

            if (ffi.PyDict_GetItemWithError(self.obj.py, keyObj.py)) |item| {
                return try py.as(root, T, py.PyObject(root){ .py = item });
            }

            // If no exception, then the item is missing.
            if (ffi.PyErr_Occurred() == null) {
                return null;
            }

            return PyError.PyRaised;
        }

        pub fn itemsIterator(self: Self) ItemIterator {
            return .{
                .pydict = self,
                .position = 0,
                .nextKey = null,
                .nextValue = null,
            };
        }

        pub const Item = struct {
            k: py.PyObject(root),
            v: py.PyObject(root),

            pub fn key(self: Item, comptime K: type) !K {
                return py.as(root, K, self.k);
            }

            pub fn value(self: Item, comptime V: type) !V {
                return py.as(root, V, self.v);
            }
        };

        pub const ItemIterator = struct {
            pydict: Self,
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
}

const testing = std.testing;

test "PyDict set and get" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    const pd = try PyDict(root).new();
    defer pd.decref();

    const bar = try py.PyString(root).create("bar");
    defer bar.decref();
    try pd.setItem("foo", bar);

    try testing.expect(try pd.contains("foo"));
    try testing.expectEqual(@as(usize, 1), pd.length());

    try testing.expectEqual(bar, (try pd.getItem(py.PyString(root), "foo")).?);

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

    const root = @This();

    const pd = try PyDict(root).create(.{ .foo = 123, .bar = false });
    defer pd.decref();

    try testing.expectEqual(@as(u32, 123), (try pd.getItem(u32, "foo")).?);
}

test "PyDict iterator" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    const pd = try PyDict(root).new();
    defer pd.decref();

    const foo = try py.PyString(root).create("foo");
    defer foo.decref();

    try pd.setItem("bar", foo);
    try pd.setItem("baz", foo);

    var iter = pd.itemsIterator();
    const first = iter.next().?;
    try testing.expectEqualStrings("bar", try (try first.key(py.PyString(root))).asSlice());
    try testing.expectEqual(foo, try first.value(py.PyString(root)));

    const second = iter.next().?;
    try testing.expectEqualStrings("baz", try (try second.key(py.PyString(root))).asSlice());
    try testing.expectEqual(foo, try second.value(py.PyString(root)));

    try testing.expectEqual(@as(?PyDict(root).Item, null), iter.next());
}
