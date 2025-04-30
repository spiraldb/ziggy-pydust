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

/// Wrapper for Python PyType.
/// Since PyTypeObject is opaque in the Python API, we cannot use the PyObject mixin.
/// Instead, we re-implement the mixin functions and insert @ptrCast where necessary.
pub const PyType = extern struct {
    obj: py.PyObject,

    pub usingnamespace PyObjectMixin("type", "PyType", @This());

    pub fn name(self: PyType) !py.PyString {
        return py.PyString.unchecked(.{
            .py = ffi.PyType_GetName(typePtr(self)) orelse return PyError.PyRaised,
        });
    }

    pub fn qualifiedName(self: PyType) !py.PyString {
        return py.PyString.unchecked(.{
            .py = ffi.PyType_GetQualName(typePtr(self)) orelse return PyError.PyRaised,
        });
    }

    pub fn getSlot(self: PyType, slot: c_int) ?*anyopaque {
        return ffi.PyType_GetSlot(typePtr(self), slot);
    }

    pub fn hasFeature(self: PyType, feature: u64) bool {
        return ffi.PyType_GetFlags(typePtr(self)) & feature != 0;
    }

    inline fn typePtr(self: PyType) *ffi.PyTypeObject {
        return @alignCast(@ptrCast(self.obj.py));
    }

    inline fn objPtr(obj: *ffi.PyTypeObject) *ffi.PyObject {
        return @alignCast(@ptrCast(obj));
    }
};

test "PyType" {
    py.initialize();
    defer py.finalize();

    const io = try py.import("io");
    defer io.decref();

    const StringIO = try io.getAs(py.PyType, "StringIO");
    try std.testing.expectEqualSlices(u8, "StringIO", try (try StringIO.name()).asSlice());

    const sio = try py.call0(py.PyObject, StringIO);
    defer sio.decref();
    const sioType = py.type_(sio);
    try std.testing.expectEqualSlices(u8, "StringIO", try (try sioType.name()).asSlice());
}
