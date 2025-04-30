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

/// Wrapper for Python PySlice.
pub fn PySlice(comptime root: type) type {
    return extern struct {
        obj: py.PyObject(root),

        const Self = @This();
        pub usingnamespace PyObjectMixin(root, "slice", "PySlice", Self);

        pub fn create(start: anytype, stop: anytype, step: anytype) !Self {
            // TODO(ngates): think about how to improve comptime optional handling?
            const pystart = if (@typeInfo(@TypeOf(start)) == .Null) null else (try py.create(root, start)).py;
            defer if (@typeInfo(@TypeOf(start)) != .Null) py.decref(root, pystart);
            const pystop = if (@typeInfo(@TypeOf(stop)) == .Null) null else (try py.create(root, stop)).py;
            defer if (@typeInfo(@TypeOf(stop)) != .Null) py.decref(root, pystop);
            const pystep = if (@typeInfo(@TypeOf(step)) == .Null) null else (try py.create(root, step)).py;
            defer if (@typeInfo(@TypeOf(step)) != .Null) py.decref(root, pystep);

            const pyslice = ffi.PySlice_New(pystart, pystop, pystep) orelse return PyError.PyRaised;
            return .{ .obj = .{ .py = pyslice } };
        }

        pub fn getStart(self: Self, comptime T: type) !T {
            return try self.obj.getAs(T, "start");
        }

        pub fn getStop(self: Self, comptime T: type) !T {
            return try self.obj.getAs(T, "stop");
        }

        pub fn getStep(self: Self, comptime T: type) !T {
            return try self.obj.getAs(T, "step");
        }
    };
}

test "PySlice" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    const range = try PySlice(root).create(0, 100, null);
    defer range.decref();

    try std.testing.expectEqual(@as(u64, 0), try range.getStart(u64));
    try std.testing.expectEqual(@as(u64, 100), try range.getStop(u64));
    try std.testing.expectEqual(@as(?u64, null), try range.getStep(?u64));
}
