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
const ffi = @import("../ffi.zig");
const str = @import("str.zig");
const py = @import("../pydust.zig");
const PyError = @import("../errors.zig").PyError;

pub const PyObject = extern struct {
    py: *ffi.PyObject,

    pub fn incref(self: PyObject) void {
        ffi.Py_INCREF(self.py);
    }

    pub fn decref(self: PyObject) void {
        ffi.Py_DECREF(self.py);
    }

    pub fn getTypeName(self: PyObject) ![:0]const u8 {
        const pytype: *ffi.PyObject = ffi.PyObject_Type(self.py) orelse return PyError.PyRaised;
        const name = py.PyString.unchecked(.{ .py = ffi.PyType_GetName(@ptrCast(pytype)) orelse return PyError.PyRaised });
        return name.asSlice();
    }

    /// Call this object without any arguments.
    pub fn call0(self: PyObject) !PyObject {
        return .{ .py = ffi.PyObject_CallNoArgs(self.py) orelse return PyError.PyRaised };
    }

    /// Call this object with the given args and kwargs.
    pub fn call(self: PyObject, args: anytype, kwargs: anytype) !PyObject {
        var argsPy: py.PyTuple = undefined;
        if (@typeInfo(@TypeOf(args)) == .Optional and args == null) {
            argsPy = try py.PyTuple.new(0);
        } else {
            argsPy = try py.PyTuple.checked(try py.create(args));
        }
        defer argsPy.decref();

        // FIXME(ngates): avoid creating empty dict for kwargs
        var kwargsPy: py.PyDict = undefined;
        if (@typeInfo(@TypeOf(kwargs)) == .Optional and kwargs == null) {
            kwargsPy = try py.PyDict.new();
        } else {
            const kwobj = try py.create(kwargs);
            if (try py.len(kwobj) == 0) {
                kwobj.decref();
                kwargsPy = try py.PyDict.new();
            } else {
                kwargsPy = try py.PyDict.checked(kwobj);
            }
        }
        defer kwargsPy.decref();

        // We _must_ return a PyObject to the user to let them handle the lifetime of the object.
        const result = ffi.PyObject_Call(self.py, argsPy.obj.py, kwargsPy.obj.py) orelse return PyError.PyRaised;
        return PyObject{ .py = result };
    }

    pub fn get(self: PyObject, attr: [:0]const u8) !PyObject {
        return .{ .py = ffi.PyObject_GetAttrString(self.py, attr) orelse return PyError.PyRaised };
    }

    // See: https://docs.python.org/3/c-api/buffer.html#buffer-request-types
    pub fn getBuffer(self: py.PyObject, flags: c_int) !py.PyBuffer {
        if (ffi.PyObject_CheckBuffer(self.py) != 1) {
            return py.BufferError.raise("object does not support buffer interface");
        }
        var buffer: py.PyBuffer = undefined;
        if (ffi.PyObject_GetBuffer(self.py, @ptrCast(&buffer), flags) != 0) {
            // Error is already raised.
            return PyError.PyRaised;
        }
        return buffer;
    }

    pub fn set(self: PyObject, attr: [:0]const u8, value: PyObject) !PyObject {
        if (ffi.PyObject_SetAttrString(self.py, attr, value.py) < 0) {
            return PyError.PyRaised;
        }
        return self;
    }

    pub fn del(self: PyObject, attr: [:0]const u8) !PyObject {
        if (ffi.PyObject_DelAttrString(self.py, attr) < 0) {
            return PyError.PyRaised;
        }
        return self;
    }

    pub fn repr(self: PyObject) !PyObject {
        return .{ .py = ffi.PyObject_Repr(@ptrCast(self)) orelse return PyError.PyRaised };
    }
};

pub fn PyObjectMixin(comptime name: []const u8, comptime prefix: []const u8, comptime Self: type) type {
    const PyCheck = @field(ffi, prefix ++ "_Check");

    return struct {
        /// Check whether the given object is of this type.
        pub fn check(obj: py.PyObject) !bool {
            return PyCheck(obj.py) == 1;
        }

        /// Checked conversion from a PyObject.
        pub fn checked(obj: py.PyObject) !Self {
            if (PyCheck(obj.py) == 0) {
                return py.TypeError.raiseFmt("expected {s}, found {s}", .{ name, try (try py.str(try py.type_(obj))).asSlice() });
            }
            return .{ .obj = obj };
        }

        /// Optionally downcast the object if it is of this type.
        pub fn checkedCast(obj: py.PyObject) ?Self {
            if (PyCheck(obj.py) == 1) {
                return .{ .obj = obj };
            }
            return null;
        }

        /// Unchecked conversion from a PyObject.
        pub fn unchecked(obj: py.PyObject) Self {
            return .{ .obj = obj };
        }

        /// Increment the object's refcnt.
        pub fn incref(self: Self) void {
            self.obj.incref();
        }

        /// Decrement the object's refcnt.
        pub fn decref(self: Self) void {
            self.obj.decref();
        }
    };
}

test "call" {
    py.initialize();
    defer py.finalize();

    const pow = try py.importFrom("math", "pow");
    const result = try pow.call(.{ 2, 3 }, .{});

    if (py.PyFloat.checkedCast(result)) |f| {
        try std.testing.expectEqual(f.as(f32), 8.0);
    }

    try std.testing.expectEqual(@as(f32, 8.0), try py.as(f32, result));
}
