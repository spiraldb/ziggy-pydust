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

/// Wrapper for Python PyCode.
/// See: https://docs.python.org/3/c-api/code.html
pub const PyCode = extern struct {
    obj: py.PyObject,

    pub inline fn firstLineNumber(self: *const PyCode) !u32 {
        const lineNo = try self.obj.getAs(py.PyLong, "co_firstlineno");
        defer lineNo.decref();
        return lineNo.as(u32);
    }

    pub inline fn fileName(self: *const PyCode) !py.PyString {
        return self.obj.getAs(py.PyString, "co_filename");
    }

    pub inline fn name(self: *const PyCode) !py.PyString {
        return self.obj.getAs(py.PyString, "co_name");
    }
};

test "PyCode" {
    py.initialize();
    defer py.finalize();

    const pf = py.PyFrame.get();
    try std.testing.expectEqual(@as(?py.PyFrame, null), pf);
}
