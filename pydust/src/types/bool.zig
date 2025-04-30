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

/// Wrapper for Python PyBool.
///
/// See: https://docs.python.org/3/c-api/bool.html
///
/// Note: refcounting semantics apply, even for bools!
pub const PyBool = extern struct {
    obj: py.PyObject,

    pub usingnamespace PyObjectMixin("bool", "PyBool", @This());

    pub fn create(value: bool) !PyBool {
        return if (value) true_() else false_();
    }

    pub fn asbool(self: PyBool) bool {
        return ffi.Py_IsTrue(self.obj.py) == 1;
    }

    pub fn intobool(self: PyBool) bool {
        self.decref();
        return self.asbool();
    }

    pub fn true_() PyBool {
        return .{ .obj = .{ .py = ffi.PyBool_FromLong(1) } };
    }

    pub fn false_() PyBool {
        return .{ .obj = .{ .py = ffi.PyBool_FromLong(0) } };
    }
};

test "PyBool" {
    py.initialize();
    defer py.finalize();

    const pytrue = PyBool.true_();
    defer pytrue.decref();

    const pyfalse = PyBool.false_();
    defer pyfalse.decref();

    try std.testing.expect(pytrue.asbool());
    try std.testing.expect(!pyfalse.asbool());
}
