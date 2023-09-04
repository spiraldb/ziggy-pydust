const std = @import("std");
const ffi = @import("../ffi.zig");
const str = @import("str.zig");
const py = @import("../pydust.zig");
const tramp = @import("../trampoline.zig");
const PyError = @import("../errors.zig").PyError;

/// PyTypeObject exists in Limited API only as an opaque pointer.
pub const PyType = extern struct {
    obj: PyObject,
};

pub const PyObject = extern struct {
    pub const HEAD = ffi.PyObject{
        .ob_refcnt = 1,
        .ob_type = null,
    };

    py: *ffi.PyObject,

    pub fn incref(self: PyObject) void {
        ffi.Py_INCREF(self.py);
    }

    pub fn decref(self: PyObject) void {
        ffi.Py_DECREF(self.py);
    }

    pub fn get_refcnt(self: PyObject) usize {
        return @intCast(self.py.ob_refcnt);
    }

    pub fn from(value: anytype) !PyObject {
        const ptr = try tramp.toPyObject(@TypeOf(value)).unwrap(value);
        return .{ .py = ptr };
    }

    pub fn call0(self: PyObject) !PyObject {
        return .{ .py = ffi.PyObject_CallNoArgs(self.py) orelse return PyError.Propagate };
    }

    pub fn call(self: PyObject, args: anytype, kwargs: anytype) !PyObject {
        _ = kwargs;
        const argsTuple = try py.PyTuple.from(args);
        defer argsTuple.obj.decref();
        return .{ .py = ffi.PyObject_CallObject(self.py, argsTuple.obj.py) orelse return PyError.Propagate };
    }

    pub fn callObj(self: PyObject, args: PyObject) !PyObject {
        return .{ .py = ffi.PyObject_CallObject(self.py, args.py) orelse return PyError.Propagate };
    }

    pub fn get(self: PyObject, attr: [:0]const u8) !PyObject {
        return .{ .py = ffi.PyObject_GetAttrString(self.py, attr) orelse return PyError.Propagate };
    }

    pub fn set(self: PyObject, attr: [:0]const u8, value: PyObject) !PyObject {
        if (ffi.PyObject_SetAttrString(self.py, attr, value.py) < 0) {
            return PyError.Propagate;
        }
        return self;
    }

    pub fn del(self: PyObject, attr: [:0]const u8) !PyObject {
        if (ffi.PyObject_DelAttrString(self.py, attr) < 0) {
            return PyError.Propagate;
        }
        return self;
    }

    pub fn repr(self: PyObject) !PyObject {
        return .{ .py = ffi.PyObject_Repr(@ptrCast(self)) orelse return PyError.Propagate };
    }
};

test "call" {
    py.initialize();
    defer py.finalize();

    const math = try py.import("math");
    defer math.decref();

    const pow = try math.get("pow");
    const result = py.PyFloat.of(try pow.call(.{ @as(u32, 2), @as(u32, 3) }, .{}));

    try std.testing.expectEqual(@as(f32, 8.0), try result.as(f32));
}
