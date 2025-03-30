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
const PyObject = py.PyObject;
const PyLong = py.PyLong;
const PyError = @import("../errors.zig").PyError;
const State = @import("../discovery.zig").State;

/// Wrapper for Python PyList.
/// See: https://docs.python.org/3/c-api/list.html
pub fn PyList(comptime root: type) type {
    return extern struct {
        obj: py.PyObject(root),

        const Self = @This();
        pub usingnamespace PyObjectMixin(root, "list", "PyList", Self);

        pub fn new(size: usize) !Self {
            const list = ffi.PyList_New(@intCast(size)) orelse return PyError.PyRaised;
            return .{ .obj = .{ .py = list } };
        }

        pub fn length(self: Self) usize {
            return @intCast(ffi.PyList_Size(self.obj.py));
        }

        // Returns borrowed reference.
        pub fn getItem(self: Self, comptime T: type, idx: isize) !T {
            if (ffi.PyList_GetItem(self.obj.py, idx)) |item| {
                return py.as(root, T, py.PyObject(root){ .py = item });
            } else {
                return PyError.PyRaised;
            }
        }

        // Returns a slice of the list.
        pub fn getSlice(self: Self, low: isize, high: isize) !Self {
            if (ffi.PyList_GetSlice(self.obj.py, low, high)) |item| {
                return .{ .obj = .{ .py = item } };
            } else {
                return PyError.PyRaised;
            }
        }

        /// This function “steals” a reference to item and discards a reference to an item already in the list at the affected position.
        pub fn setOwnedItem(self: Self, pos: usize, value: anytype) !void {
            // Since this function steals the reference, it can only accept object-like values.
            if (ffi.PyList_SetItem(self.obj.py, @intCast(pos), py.object(root, value).py) < 0) {
                return PyError.PyRaised;
            }
        }

        /// Set the item at the given position.
        pub fn setItem(self: Self, pos: usize, value: anytype) !void {
            const valueObj = try py.create(root, value);
            return self.setOwnedItem(pos, valueObj);
        }

        // Insert the item item into list list in front of index idx.
        pub fn insert(self: Self, idx: isize, value: anytype) !void {
            const valueObj = try py.create(root, value);
            defer valueObj.decref();
            if (ffi.PyList_Insert(self.obj.py, idx, valueObj.py) < 0) {
                return PyError.PyRaised;
            }
        }

        // Append the object item at the end of list list.
        pub fn append(self: Self, value: anytype) !void {
            const valueObj = try py.create(root, value);
            defer valueObj.decref();

            if (ffi.PyList_Append(self.obj.py, valueObj.py) < 0) {
                return PyError.PyRaised;
            }
        }

        // Sort the items of list in place.
        pub fn sort(self: Self) !void {
            if (ffi.PyList_Sort(self.obj.py) < 0) {
                return PyError.PyRaised;
            }
        }

        // Reverse the items of list in place.
        pub fn reverse(self: Self) !void {
            if (ffi.PyList_Reverse(self.obj.py) < 0) {
                return PyError.PyRaised;
            }
        }

        pub fn toTuple(self: Self) !py.PyTuple(root) {
            const pytuple = ffi.PyList_AsTuple(self.obj.py) orelse return PyError.PyRaised;
            return py.PyTuple(root).unchecked(.{ .py = pytuple });
        }
    };
}

const testing = std.testing;

test "PyList" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    var list = try PyList(root).new(2);
    defer list.decref();
    try list.setItem(0, 1);
    try list.setItem(1, 2.0);

    try testing.expectEqual(@as(usize, 2), list.length());

    try testing.expectEqual(@as(i64, 1), try list.getItem(i64, 0));
    try testing.expectEqual(@as(f64, 2.0), try list.getItem(f64, 1));

    try list.append(3);
    try testing.expectEqual(@as(usize, 3), list.length());
    try testing.expectEqual(@as(i32, 3), try list.getItem(i32, 2));

    try list.insert(0, 1.23);
    try list.reverse();
    try testing.expectEqual(@as(f32, 1.23), try list.getItem(f32, 3));

    try list.sort();
    try testing.expectEqual(@as(i64, 1), try list.getItem(i64, 0));

    const tuple = try list.toTuple();
    defer tuple.decref();

    try std.testing.expectEqual(@as(usize, 4), tuple.length());
}

test "PyList setOwnedItem" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    var list = try PyList(root).new(2);
    defer list.decref();
    const py1 = try py.create(root, 1);
    defer py1.decref();
    try list.setOwnedItem(0, py1);
    const py2 = try py.create(root, 2);
    defer py2.decref();
    try list.setOwnedItem(1, py2);

    try std.testing.expectEqual(@as(u8, 1), try list.getItem(u8, 0));
    try std.testing.expectEqual(@as(u8, 2), try list.getItem(u8, 1));
}
