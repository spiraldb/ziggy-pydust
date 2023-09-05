/// Utilities for bouncing CPython calls into Zig functions and back again.
const std = @import("std");
const Type = std.builtin.Type;
const ffi = @import("ffi.zig");
const py = @import("pydust.zig");
const PyError = @import("errors.zig").PyError;

pub fn errObj(obj: PyError!py.PyObject) ?*ffi.PyObject {
    return if (obj) |o| o.py else |err| setErrObj(err);
}

pub fn errStr(str: PyError!py.PyString) ?*ffi.PyObject {
    return if (str) |s| s.obj.py else |err| setErrObj(err);
}

pub fn errVoid(result: PyError!void) c_int {
    return if (result) 0 else |err| setErrInt(err);
}

pub fn setErrInt(err: PyError) c_int {
    setErr(err);
    return -1;
}

pub fn setErrObj(err: PyError) ?*ffi.PyObject {
    setErr(err);
    return null;
}

pub fn setErr(err: PyError) void {
    return switch (err) {
        error.Propagate => {},
        error.Raised => {},
        error.OutOfMemory => py.MemoryError.raise("OOM") catch return,
    };
}

/// Generate a function to convert a comptime-known Zig type into a py.PyObject.
pub fn toPyObject(comptime objType: type) type {
    return struct {
        pub inline fn unwrapPy(obj: objType) !*ffi.PyObject {
            return (try unwrap(obj)).py;
        }

        pub inline fn unwrap(obj: objType) !py.PyObject {
            // Handle the error case explicitly, then we can unwrap the error case entirely.
            const typeInfo = @typeInfo(objType);
            if (typeInfo == .ErrorUnion) {
                _ = obj catch |err| {
                    return err;
                };
            }

            const result = if (typeInfo == .ErrorUnion) obj catch @panic("Error already handled above") else obj;
            const resultType = if (typeInfo == .ErrorUnion) typeInfo.ErrorUnion.payload else objType;

            switch (@typeInfo(resultType)) {
                .Bool => return if (result) py.True().obj else py.False().obj,
                .ErrorUnion => @compileError("ErrorUnion already handled"),
                .Float => return (try py.PyFloat.from(resultType, result)).obj,
                .Int => return (try py.PyLong.from(resultType, result)).obj,
                .Struct => |s| {
                    // Support all extensions of py.PyObject, e.g. py.PyString, py.PyFloat
                    if (@hasField(resultType, "obj") and @hasField(@TypeOf(result.obj), "py")) {
                        return result.obj;
                    }
                    // Support py.PyObject
                    if (resultType == py.PyObject) {
                        return result;
                    }
                    // If the struct is a tuple, return a Python tuple
                    if (s.is_tuple) {
                        const tuple = try py.PyTuple.new(s.fields.len);
                        inline for (s.fields, 0..) |field, i| {
                            // Recursively unwrap the field value
                            const fieldValue = try toPyObject(field.type).unwrap(@field(result, field.name));
                            try tuple.setItem(@intCast(i), fieldValue);
                        }
                        return tuple.obj;
                    }
                    // Otherwise, return a Python dictionary
                    const dict = try py.PyDict.new();
                    inline for (s.fields) |field| {
                        // Recursively unwrap the field value
                        const fieldValue = try toPyObject(field.type).unwrap(@field(result, field.name));
                        try dict.setItemStr(field.name ++ "\x00", fieldValue);
                    }
                    return dict.obj;
                },
                .Void => return py.None(),
                else => {},
            }

            @compileError("Unsupported return type " ++ @typeName(objType) ++ " from Pydust function");
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
