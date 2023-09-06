/// Utilities for bouncing CPython calls into Zig functions and back again.
const std = @import("std");
const Type = std.builtin.Type;
const ffi = @import("ffi.zig");
const py = @import("pydust.zig");
const funcs = @import("functions.zig");
const pytypes = @import("pytypes.zig");
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

/// Generate functions to convert comptime-known Zig types to/from py.PyObject.
pub fn Trampoline(comptime T: type) type {
    return struct {
        pub inline fn wrapRaw(obj: T) ?*ffi.PyObject {
            const pyobj = wrap(obj) catch |err| switch (err) {
                // On error, we assume an exception has been set and return a NULL pointer to Python.
                // Maybe we should std.debug.assert that we have in fact done so?
                error.Propagate => return null,
                error.Raised => return null,
                error.OutOfMemory => py.MemoryError.raise("OOM") catch return null,
            };

            if (@as(?*ffi.PyObject, @ptrCast(pyobj.py)) == null) {
                @panic("NULL POINTER");
            }

            return pyobj.py;
        }

        /// Wrap a Zig object into a PyObject.
        pub inline fn wrap(obj: T) !py.PyObject {
            const typeInfo = @typeInfo(T);

            // Early return to handle errors
            if (typeInfo == .ErrorUnion) {
                const value = obj catch |err| return err;
                return Trampoline(typeInfo.ErrorUnion.payload).wrap(value);
            }

            // Early return to handle optionals
            if (typeInfo == .Optional) {
                const value = obj orelse return py.None();
                return Trampoline(typeInfo.Optional.child).wrap(value);
            }

            switch (@typeInfo(T)) {
                .Bool => return if (obj) py.True().obj else py.False().obj,
                .ErrorUnion => @compileError("ErrorUnion already handled"),
                .Float => return (try py.PyFloat.from(T, obj)).obj,
                .Int => return (try py.PyLong.from(T, obj)).obj,
                .Pointer => |p| {
                    // If the pointer is for ffi.PyObject, just wrap it up
                    if (p.child == ffi.PyObject) {
                        return .{ .py = obj };
                    }

                    // If the pointer is for a Pydust class
                    if (py.findClassName(p.child)) |_| {
                        // TODO(ngates): check the PyType?
                        const PyType = pytypes.State(p.child);
                        const pyobject: *ffi.PyObject = @constCast(@ptrCast(@fieldParentPtr(PyType, "state", obj)));
                        return .{ .py = pyobject };
                    }

                    // If the pointer is for a Pydust module
                    if (py.findModuleName(p.child)) |_| {
                        @compileError("Cannot currently return modules");
                    }

                    @compileLog("Unsupported pointer type " ++ @typeName(p.child), py.State.classes(), py.State.modules());
                },
                .Struct => |s| {
                    // Support all extensions of py.PyObject, e.g. py.PyString, py.PyFloat
                    // TODO(ngates): do this on the type info, not runtime value
                    if (@hasField(T, "obj") and @hasField(@TypeOf(obj.obj), "py")) {
                        return obj.obj;
                    }
                    // Support py.PyObject
                    if (T == py.PyObject) {
                        return obj;
                    }
                    // If the struct is a tuple, return a Python tuple
                    if (s.is_tuple) {
                        const tuple = try py.PyTuple.new(s.fields.len);
                        inline for (s.fields, 0..) |field, i| {
                            // Recursively unwrap the field value
                            const fieldValue = try Trampoline(field.type).wrap(@field(obj, field.name));
                            try tuple.setItem(@intCast(i), fieldValue);
                        }
                        return tuple.obj;
                    }
                    // Check the user is not accidentally returning a Pydust class or Module without a pointer
                    if (py.findClassName(T) != null or py.findModuleName(T) != null) {
                        @compileError("Pydust objects can only be returned as pointers");
                    }
                    // Otherwise, return a Python dictionary
                    const dict = try py.PyDict.new();
                    inline for (s.fields) |field| {
                        // Recursively unwrap the field value
                        const fieldValue = try Trampoline(field.type).wrap(@field(obj, field.name));
                        try dict.setItemStr(field.name, fieldValue);
                    }
                    return dict.obj;
                },
                .Void => return py.None(),
                else => {},
            }

            @compileError("Unsupported return type " ++ @typeName(T) ++ " from Pydust function");
        }

        /// Unwrap a Python object into a Zig object.
        pub inline fn unwrap(object: ?py.PyObject) !T {
            // Handle the error case explicitly, then we can unwrap the error case entirely.
            const typeInfo = @typeInfo(T);
            comptime var R = T;

            // Early return to handle errors
            if (typeInfo == .ErrorUnion) {
                const value = object catch |err| return err;
                return Trampoline(typeInfo.ErrorUnion.payload).unwrap(value);
            }

            // Early return to handle optionals
            if (typeInfo == .Optional) {
                const value = object orelse return null;
                return Trampoline(typeInfo.Optional.child).unwrap(value);
            }

            // Otherwise we can unwrap the object.
            var obj = object orelse @panic("Unexpected null");

            switch (@typeInfo(R)) {
                .Bool => return if ((try py.PyBool.of(obj)).asbool()) true else false,
                .ErrorUnion => @compileError("ErrorUnion already handled"),
                .Float => return try (try py.PyFloat.of(obj)).as(T),
                .Int => return try (try py.PyLong.of(obj)).as(T),
                .Optional => @compileError("Optional already handled"),
                .Pointer => |p| {
                    // If the pointer is for a Pydust class
                    if (py.findClassName(p.child)) |_| {
                        // TODO(ngates): check the PyType?
                        const PyType = pytypes.State(p.child);
                        const pyobject = @as(*PyType, @ptrCast(obj.py));
                        return @constCast(&pyobject.state);
                    }

                    // If the pointer is for a Pydust module
                    if (py.findModuleName(p.child)) |_| {
                        const mod = try py.PyModule.of(obj);
                        return try mod.getState(p.child);
                    }

                    @compileLog("Unsupported pointer type " ++ @typeName(p.child), py.State.classes(), py.State.modules());
                },
                .Struct => |s| {
                    // Support all extensions of py.PyObject, e.g. py.PyString, py.PyFloat
                    // TODO(ngates): extract this into a TraitFn
                    if (@hasField(R, "obj") and @hasField(std.meta.fieldInfo(R, .obj).type, "py")) {
                        return try @field(R, "of")(obj);
                    }
                    // Support py.PyObject
                    if (R == py.PyObject) {
                        return obj;
                    }
                    // If the struct is a tuple, extract from the PyTuple
                    if (s.is_tuple) {
                        const tuple = try py.PyTuple.of(obj);
                        var result: R = undefined;
                        for (s.fields, 0..) |field, i| {
                            // Recursively unwrap the field value
                            const fieldValue = try tuple.getItem(i);
                            @field(result, field.name) = try Trampoline(field.type.?).unwrap(fieldValue);
                        }
                        return result;
                    }
                    // Otherwise, extract from a Python dictionary
                    const dict = try py.PyDict.of(obj);
                    var result: R = undefined;
                    inline for (s.fields) |field| {
                        // Recursively unwrap the field value
                        const fieldValue = try dict.getItemStr(field.name ++ "") orelse {
                            return py.TypeError.raise("dict missing field " ++ field.name ++ ": " ++ @typeName(field.type));
                        };
                        @field(result, field.name) = try Trampoline(field.type).unwrap(fieldValue);
                    }
                    return result;
                },
                .Void => if (py.is_none(obj)) return else return py.TypeError.raise("expected None"),
                else => {},
            }

            @compileError("Unsupported argument type " ++ @typeName(T) ++ " for Pydust function");
        }

        pub const CallArgs = struct {
            args: py.PyTuple,
            kwargs: py.PyDict,

            pub fn decref(self: CallArgs) void {
                self.args.decref();
                self.kwargs.decref();
            }
        };

        /// Wrap a Zig Pydust argument struct into Python CallArgs.
        /// The caller is responsible for decref'ing the returned args and kwargs.
        pub inline fn wrapCallArgs(obj: T) !CallArgs {
            const args = try py.PyTuple.new(funcs.argCount(T));
            const kwargs = try py.PyDict.new();

            inline for (@typeInfo(T).Struct.fields, 0..) |field, i| {
                const arg = try Trampoline(field.type).wrap(@field(obj, field.name));
                if (field.default_value == null) {
                    // It's an arg
                    try args.setOwnedItem(i, arg);
                } else {
                    // It's a kwarg
                    try kwargs.setOwnedItemStr(field.name, arg);
                }
            }

            return .{ .args = args, .kwargs = kwargs };
        }
    };
}
