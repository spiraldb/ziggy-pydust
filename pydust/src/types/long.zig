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

/// Wrapper for Python PyLong.
/// See: https://docs.python.org/3/c-api/long.html#c.PyLongObject
pub fn PyLong(comptime root: type) type {
    return extern struct {
        obj: py.PyObject(root),

        const Self = @This();
        pub usingnamespace PyObjectMixin(root, "int", "PyLong", Self);

        pub fn create(value: anytype) !Self {
            if (@TypeOf(value) == comptime_int) {
                return create(@as(i64, @intCast(value)));
            }

            const typeInfo = @typeInfo(@TypeOf(value)).Int;

            const pylong = switch (typeInfo.signedness) {
                .signed => ffi.PyLong_FromLongLong(@intCast(value)),
                .unsigned => ffi.PyLong_FromUnsignedLongLong(@intCast(value)),
            } orelse return PyError.PyRaised;

            return .{ .obj = .{ .py = pylong } };
        }

        pub fn as(self: Self, comptime T: type) !T {
            // TODO(ngates): support non-int conversions
            const typeInfo = @typeInfo(T).Int;
            return switch (typeInfo.signedness) {
                .signed => {
                    const ll = ffi.PyLong_AsLongLong(self.obj.py);
                    if (ffi.PyErr_Occurred() != null) return PyError.PyRaised;
                    return @intCast(ll);
                },
                .unsigned => {
                    const ull = ffi.PyLong_AsUnsignedLongLong(self.obj.py);
                    if (ffi.PyErr_Occurred() != null) return PyError.PyRaised;
                    return @intCast(ull);
                },
            };
        }
    };
}

test "PyLong" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    const pl = try PyLong(root).create(100);
    defer pl.decref();

    try std.testing.expectEqual(@as(c_long, 100), try pl.as(c_long));
    try std.testing.expectEqual(@as(c_ulong, 100), try pl.as(c_ulong));

    const neg_pl = try PyLong(root).create(@as(c_long, -100));
    defer neg_pl.decref();

    try std.testing.expectError(
        PyError.PyRaised,
        neg_pl.as(c_ulong),
    );
}
