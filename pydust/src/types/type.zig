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

/// Wrapper for Python PyType.
/// Since PyTypeObject is opaque in the Python API, we cannot use the PyObject mixin.
/// Instead, we re-implement the mixin functions and insert @ptrCast where necessary.
pub fn PyType(comptime root: type) type {
    return extern struct {
        obj: py.PyObject(root),

        const Self = @This();
        pub usingnamespace PyObjectMixin(root, "type", "PyType", Self);

        pub fn name(self: Self) !py.PyString(root) {
            return py.PyString(root).unchecked(.{
                .py = ffi.PyType_GetName(typePtr(self)) orelse return PyError.PyRaised,
            });
        }

        pub fn qualifiedName(self: Self) !py.PyString(root) {
            return py.PyString(root).unchecked(.{
                .py = ffi.PyType_GetQualName(typePtr(self)) orelse return PyError.PyRaised,
            });
        }

        pub fn getSlot(self: Self, slot: c_int) ?*anyopaque {
            return ffi.PyType_GetSlot(typePtr(self), slot);
        }

        pub fn hasFeature(self: Self, feature: u64) bool {
            return ffi.PyType_GetFlags(typePtr(self)) & feature != 0;
        }

        inline fn typePtr(self: Self) *ffi.PyTypeObject {
            return @alignCast(@ptrCast(self.obj.py));
        }

        inline fn objPtr(obj: *ffi.PyTypeObject) *ffi.PyObject {
            return @alignCast(@ptrCast(obj));
        }
    };
}

test "PyType" {
    py.initialize();
    defer py.finalize();

    const root = @This();
    const io = try py.import(root, "io");
    defer io.decref();

    const StringIO = try io.getAs(py.PyType(root), "StringIO");
    try std.testing.expectEqualSlices(u8, "StringIO", try (try StringIO.name()).asSlice());

    const sio = try py.call0(root, py.PyObject(root), StringIO);
    defer sio.decref();
    const sioType = py.type_(root, sio);
    try std.testing.expectEqualSlices(u8, "StringIO", try (try sioType.name()).asSlice());
}
