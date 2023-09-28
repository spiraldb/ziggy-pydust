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

/// Wrapper for Python PySlice.
pub const PySlice = extern struct {
    obj: py.PyObject,

    pub usingnamespace PyObjectMixin("slice", "PySlice", @This());

    pub fn create(start: anytype, stop: anytype, step: anytype) PySlice {
        const pystart = py.create(start);
        defer pystart.decref();
        const pystop = py.create(stop);
        defer pystop.decref();
        const pystep = py.create(step);
        defer pystep.decref();

        const pyslice = ffi.PySlice_New(
            pystart.obj.py,
            pystop.obj.py,
            pystep.obj.py,
        ) orelse return PyError.PyRaised();
        return .{ .obj = .{ .py = pyslice } };
    }

    pub fn getStart(self: PySlice, comptime T: type) !T {
        return try py.as(T, try self.obj.get("start"));
    }

    pub fn getStop(self: PySlice, comptime T: type) !T {
        return try py.as(T, try self.obj.get("stop"));
    }

    pub fn getStep(self: PySlice, comptime T: type) !T {
        return try py.as(T, try self.obj.get("step"));
    }
};

test "PySlice" {
    py.initialize();
    defer py.finalize();

    const range = PySlice.create(0, 100, null);
    defer range.decref();

    try std.testing.expectEqual(@as(u64, 100), range.getStart(u64));
}
