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
const PyLong = @import("long.zig").PyLong;
const PyFloat = @import("float.zig").PyFloat;
const PyObject = @import("obj.zig").PyObject;
const PyError = @import("../errors.zig").PyError;
const seq = @import("./sequence.zig");
const State = @import("../discovery.zig").State;

pub fn PyTuple(comptime root: type) type {
    return extern struct {
        obj: PyObject(root),

        const Self = @This();
        pub usingnamespace PyObjectMixin(root, "tuple", "PyTuple", Self);
        pub usingnamespace seq.SequenceMixin(root, Self);

        /// Construct a PyTuple from the given Zig tuple.
        pub fn create(values: anytype) !Self {
            const s = @typeInfo(@TypeOf(values)).@"struct";
            if (!s.is_tuple and s.fields.len > 0) {
                @compileError("Expected a struct tuple " ++ @typeName(@TypeOf(values)));
            }

            const tuple = try new(s.fields.len);
            inline for (s.fields, 0..) |field, i| {
                // Recursively unwrap the field value
                try tuple.setOwnedItem(@intCast(i), try py.create(root, @field(values, field.name)));
            }
            return tuple;
        }

        /// Convert this tuple into the given Zig tuple struct.
        pub fn as(self: Self, comptime T: type) !T {
            const s = @typeInfo(T).@"struct";
            const result: T = undefined;
            for (s.fields, 0..) |field, i| {
                const value = try self.getItem(field.type, i);
                if (value) |val| {
                    @field(result, field.name) = val;
                } else if (field.defaultValue()) |default| {
                    @field(result, field.name) = default;
                } else {
                    return py.TypeError.raise("tuple missing field " ++ field.name ++ ": " ++ @typeName(field.type));
                }
            }
            return result;
        }

        pub fn new(size: usize) !Self {
            const tuple = ffi.PyTuple_New(@intCast(size)) orelse return PyError.PyRaised;
            return .{ .obj = .{ .py = tuple } };
        }

        pub fn length(self: *const Self) usize {
            return @intCast(ffi.PyTuple_Size(self.obj.py));
        }

        pub fn getItem(self: *const Self, comptime T: type, idx: usize) !T {
            return self.getItemZ(T, @intCast(idx));
        }

        pub fn getItemZ(self: *const Self, comptime T: type, idx: isize) !T {
            if (ffi.PyTuple_GetItem(self.obj.py, idx)) |item| {
                return py.as(root, T, PyObject(root){ .py = item });
            } else {
                return PyError.PyRaised;
            }
        }

        /// Insert a reference to object o at position pos of the tuple.
        ///
        /// Warning: steals a reference to value.
        pub fn setOwnedItem(self: *const Self, pos: usize, value: anytype) !void {
            if (ffi.PyTuple_SetItem(self.obj.py, @intCast(pos), py.object(root, value).py) < 0) {
                return PyError.PyRaised;
            }
        }

        /// Insert a reference to object o at position pos of the tuple. Does not steal a reference to value.
        pub fn setItem(self: *const Self, pos: usize, value: anytype) !void {
            if (ffi.PyTuple_SetItem(self.obj.py, @intCast(pos), value.py) < 0) {
                return PyError.PyRaised;
            }
            // PyTuple_SetItem steals a reference to value. We want the default behaviour not to do that.
            // See setOwnedItem for an implementation that does steal.
            value.incref();
        }
    };
}

test "PyTuple" {
    py.initialize();
    defer py.finalize();

    const root = @This();
    const first = try PyLong(root).create(1);
    defer first.decref();
    const second = try PyFloat(root).create(1.0);
    defer second.decref();

    var tuple = try PyTuple(root).create(.{ first.obj, second.obj });
    defer tuple.decref();

    try std.testing.expectEqual(@as(usize, 2), tuple.length());

    try std.testing.expectEqual(@as(usize, 0), try tuple.index(second));

    try std.testing.expectEqual(@as(c_long, 1), try tuple.getItem(c_long, 0));
    try tuple.setItem(0, second.obj);
    try std.testing.expectEqual(@as(f64, 1.0), try tuple.getItem(f64, 0));
}

test "PyTuple setOwnedItem" {
    py.initialize();
    defer py.finalize();

    const root = @This();
    var tuple = try PyTuple(root).new(2);
    defer tuple.decref();
    const py1 = try py.create(root, 1);
    defer py1.decref();
    try tuple.setOwnedItem(0, py1);
    const py2 = try py.create(root, 2);
    defer py2.decref();
    try tuple.setOwnedItem(1, py2);

    try std.testing.expectEqual(@as(u8, 1), try tuple.getItem(u8, 0));
    try std.testing.expectEqual(@as(u8, 2), try tuple.getItem(u8, 1));
}
