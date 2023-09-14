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

/// Wrapper for Python PyMemoryView.
/// See: https://docs.python.org/3/c-api/memoryview.html
pub const PyMemoryView = extern struct {
    obj: py.PyObject,

    pub usingnamespace PyObjectMixin("memoryview", "PyMemoryView", @This());

    pub fn create(value: anytype) !PyMemoryView {
        // TODO(ngates): discuss constructors, see https://github.com/fulcrum-so/ziggy-pydust/issues/94

        // Extract a simple buffer from the object
        const obj = py.object(value);
        return .{ .obj = .{ .py = ffi.PyMemoryView_FromObject(obj.py) orelse return PyError.Propagate } };
    }

    /// Create a memory view from a Zig slice. The allocator will be used to free the slice when the memory view is destroyed.
    pub fn fromSlice(comptime T: type, values: []const T, allocator: std.mem.Allocator) void {
        _ = allocator;
        _ = values;

        ffi.PyMemoryView_FromBuffer(info: [*c]const Py_buffer)
    }
};

test "PyMemoryView" {
    py.initialize();
    defer py.finalize();

    const pl = try PyLong.create(100);
    defer pl.decref();

    try std.testing.expectEqual(@as(c_long, 100), try pl.as(c_long));
    try std.testing.expectEqual(@as(c_ulong, 100), try pl.as(c_ulong));

    const neg_pl = try PyLong.create(@as(c_long, -100));
    defer neg_pl.decref();

    try std.testing.expectError(
        PyError.Propagate,
        neg_pl.as(c_ulong),
    );
}
