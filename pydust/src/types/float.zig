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

/// Wrapper for Python PyFloat.
/// See: https://docs.python.org/3/c-api/float.html
pub fn PyFloat(comptime root: type) type {
    return extern struct {
        obj: py.PyObject(root),

        const Self = @This();
        pub usingnamespace PyObjectMixin(root, "float", "PyFloat", Self);

        pub fn create(value: anytype) !Self {
            const pyfloat = ffi.PyFloat_FromDouble(@floatCast(value)) orelse return PyError.PyRaised;
            return .{ .obj = .{ .py = pyfloat } };
        }

        pub fn as(self: Self, comptime T: type) !T {
            return switch (T) {
                f16, f32, f64 => {
                    const double = ffi.PyFloat_AsDouble(self.obj.py);
                    if (ffi.PyErr_Occurred() != null) return PyError.PyRaised;
                    return @floatCast(double);
                },
                else => @compileError("Unsupported float type " ++ @typeName(T)),
            };
        }
    };
}

test "PyFloat" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    const pf = try PyFloat(root).create(1.0);
    defer pf.decref();

    try std.testing.expectEqual(@as(f32, 1.0), try pf.as(f32));
}
