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

/// Wrapper for Python PyIter.
/// Constructed using py.iter(...)
pub fn PyIter(comptime root: type) type {
    return extern struct {
        obj: py.PyObject(root),

        const Self = @This();
        pub usingnamespace PyObjectMixin(root, "iterator", "PyIter", Self);

        pub fn next(self: Self, comptime T: type) !?T {
            if (ffi.PyIter_Next(self.obj.py)) |result| {
                return try py.as(root, T, result);
            }

            // If no exception, then the item is missing.
            if (ffi.PyErr_Occurred() == null) {
                return null;
            }

            return PyError.PyRaised;
        }

        // TODO(ngates): implement PyIter_Send when required
    };
}

test "PyIter" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    const tuple = try py.PyTuple(root).create(.{ 1, 2, 3 });
    defer tuple.decref();

    const iterator = try py.iter(root, tuple);
    var previous: u64 = 0;
    while (try iterator.next(u64)) |v| {
        try std.testing.expect(v > previous);
        previous = v;
    }
}
