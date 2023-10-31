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

    /// Call a method on this object with no arguments.
    pub fn call0(self: PyObject, comptime T: type, method: []const u8) !T {
        const meth = try self.get(method);
        defer meth.decref();
        return py.call0(T, meth);
    }

    /// Call a method on this object with the given args and kwargs.
    pub fn call(self: PyObject, comptime T: type, method: []const u8, args: anytype, kwargs: anytype) !T {
        const meth = try self.get(method);
        defer meth.decref();
        return py.call(T, meth, args, kwargs);
    }

    /// Returns a new reference to the attribute of the object.
    pub fn get(self: PyObject, attrName: []const u8) !py.PyObject {
        const attrStr = try py.PyString.create(attrName);
        defer attrStr.decref();

        return .{ .py = ffi.PyObject_GetAttr(self.py, attrStr.obj.py) orelse return PyError.PyRaised };
    }

    /// Returns a new reference to the attribute of the object using default lookup semantics.
    pub fn getAttribute(self: PyObject, attrName: []const u8) !py.PyObject {
        const attrStr = try py.PyString.create(attrName);
        defer attrStr.decref();

        return .{ .py = ffi.PyObject_GenericGetAttr(self.py, attrStr.obj.py) orelse return PyError.PyRaised };
    }

    /// Returns a new reference to the attribute of the object.
    pub fn getAs(self: PyObject, comptime T: type, attrName: []const u8) !T {
        return try py.as(T, try self.get(attrName));
    }

    /// Checks whether object has given attribute
    pub fn has(self: PyObject, attrName: []const u8) !bool {
        const attrStr = try py.PyString.create(attrName);
        defer attrStr.decref();
        return ffi.PyObject_HasAttr(self.py, attrStr.obj.py) == 1;
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

    pub fn set(self: PyObject, attr: []const u8, value: PyObject) !PyObject {
        const attrStr = try py.PyString.create(attr);
        defer attrStr.decref();

        if (ffi.PyObject_SetAttr(self.py, attrStr.obj.py, value.py) < 0) {
            return PyError.PyRaised;
        }
        return self;
    }

    pub fn del(self: PyObject, attr: []const u8) !PyObject {
        const attrStr = try py.PyString.create(attr);
        defer attrStr.decref();

        if (ffi.PyObject_DelAttr(self.py, attrStr.obj.py) < 0) {
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
                const typeName = try py.str(py.type_(obj));
                defer typeName.decref();
                return py.TypeError.raiseFmt("expected {s}, found {s}", .{ name, try typeName.asSlice() });
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

    const math = try py.import("math");
    defer math.decref();

    const result = try math.call(f32, "pow", .{ 2, 3 }, .{});
    try std.testing.expectEqual(@as(f32, 8.0), result);
}

test "has" {
    py.initialize();
    defer py.finalize();

    const math = try py.import("math");
    defer math.decref();

    try std.testing.expect(try math.has("pow"));
}
