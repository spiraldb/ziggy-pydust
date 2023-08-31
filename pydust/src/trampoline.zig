/// Utilities for bouncing CPython calls into Zig functions and back again.
const std = @import("std");
const Type = std.builtin.Type;
const ffi = @import("ffi.zig");
const py = @import("types.zig");
const PyError = @import("errors.zig").PyError;

pub fn errObj(obj: anyerror!py.PyObject) ?*ffi.PyObject {
    return if (obj) |o| o.py else |err| setErrObj(err);
}

pub fn errStr(str: anyerror!py.PyString) ?*ffi.PyObject {
    return if (str) |s| s.obj.py else |err| setErrObj(err);
}

pub fn errVoid(result: anyerror!void) c_int {
    return if (result) 0 else |err| setErrInt(err);
}

pub fn setErrInt(err: anyerror) c_int {
    setErr(err);
    return -1;
}

pub fn setErrObj(err: anyerror) ?*ffi.PyObject {
    setErr(err);
    return null;
}

pub fn setErr(err: anyerror) void {
    return switch (err) {
        error.Propagate => {},
        else => py.PyErr.setRuntimeError("An error occurrred"),
    };
}

pub fn toPyObject(comptime funcName: [:0]const u8, comptime objType: type) type {
    return struct {
        pub inline fn unwrap(obj: objType) ?*ffi.PyObject {
            // Handle the error case explicitly, then we can unwrap the error case entirely.
            const typeInfo = @typeInfo(objType);
            if (typeInfo == .ErrorUnion) {
                _ = obj catch |err| {
                    return setErrObj(err);
                };
            }

            const result = if (typeInfo == .ErrorUnion) obj catch @panic("Error already handled above") else obj;
            const resultType = if (typeInfo == .ErrorUnion) typeInfo.ErrorUnion.payload else objType;

            switch (@typeInfo(resultType)) {
                .Bool => return if (result) ffi.Py_True else ffi.Py_False,
                .ErrorUnion => @compileError("ErrorUnion already handled"),
                .Float => return (py.PyFloat.from(resultType, result) catch |e| return setErrObj(e)).obj.py,
                .Int => return (py.PyLong.from(resultType, result) catch |e| return setErrObj(e)).obj.py,
                .Struct => switch (resultType) {
                    py.PyString => return result.obj.py,
                    py.PyFloat => return result.obj.py,
                    py.PyObject => return result.py,
                    else => {},
                },
                .Void => return ffi.Py_None,
                else => {},
            }

            @compileError("Unsupported return type " ++ @typeName(objType) ++ " from Pydust function " ++ funcName);
        }
    };
}

pub fn buildArgTuple(comptime argType: type, arg: argType) !py.PyTuple {
    const argFields = @typeInfo(argType).Struct.fields;
    const pyTup = try py.PyTuple.new(argFields.len);
    inline for (argFields, 0..) |field, idx| {
        const value = @field(arg, field.name);
        switch (field.type) {
            inline [:0]const u8 => |_| try pyTup.setItem(idx, ffi.Py_BuildValue("s", value)),
            inline py.PyString => |_| try pyTup.setItem(idx, value.obj),
            else => @panic("unhandled type"),
        }
    }

    return pyTup;
}
