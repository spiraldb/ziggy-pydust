/// Utilities for bouncing CPython calls into Zig functions and back again.
const std = @import("std");
const Type = std.builtin.Type;
const ffi = @import("ffi.zig");
const py = @import("pydust.zig");
const funcs = @import("functions.zig");
const pytypes = @import("pytypes.zig");
const PyError = @import("errors.zig").PyError;

/// Generate functions to convert comptime-known Zig types to/from py.PyObject.
pub fn Trampoline(comptime T: type) type {
    // Catch and handle comptime literals
    if (T == comptime_int) {
        return Trampoline(i64);
    }
    if (T == comptime_float) {
        return Trampoline(f64);
    }

    return struct {
        /// Wraps an object that already represents an existing Python object.
        /// In other words, Zig primitive types are not supported.
        pub inline fn asObject(obj: T) py.PyObject {
            switch (@typeInfo(T)) {
                .Pointer => |p| {
                    // The object is an ffi.PyObject
                    if (p.child == ffi.PyObject) {
                        return .{ .py = obj };
                    }

                    // If the pointer is for a Pydust class
                    if (py.findClassName(p.child)) |_| {
                        const PyType = pytypes.State(p.child);
                        const ffiObject: *ffi.PyObject = @constCast(@ptrCast(@fieldParentPtr(PyType, "state", obj)));
                        return .{ .py = ffiObject };
                    }

                    // If the pointer is for a Pydust module
                    if (py.findModuleName(p.child)) |_| {
                        @compileError("Cannot currently return modules");
                    }
                },
                .Struct => {
                    // Support all extensions of py.PyObject, e.g. py.PyString, py.PyFloat
                    if (@hasField(T, "obj") and @hasField(std.meta.fieldInfo(T, .obj).type, "py")) {
                        return obj.obj;
                    }

                    if (T == py.PyObject) {
                        return obj;
                    }
                },
                inline else => {},
            }
            @compileError("Cannot convert into PyObject: " ++ @typeName(T));
        }

        inline fn isObjectLike() bool {
            switch (@typeInfo(T)) {
                .Pointer => |p| {
                    // The object is an ffi.PyObject
                    if (p.child == ffi.PyObject) {
                        return true;
                    }

                    // If the pointer is for a Pydust class
                    if (py.findClassName(p.child)) |_| {
                        return true;
                    }

                    // If the pointer is for a Pydust module
                    if (py.findModuleName(p.child)) |_| {
                        // FIXME(ngates): support modules
                        return false;
                    }
                },
                .Struct => {
                    // Support all extensions of py.PyObject, e.g. py.PyString, py.PyFloat
                    if (@hasField(T, "obj") and @hasField(std.meta.fieldInfo(T, .obj).type, "py")) {
                        return true;
                    }

                    // Support py.PyObject
                    if (T == py.PyObject) {
                        return true;
                    }
                },
                inline else => {},
            }
            return false;
        }

        /// Wraps a Zig object into a new Python object.
        /// Always creates a new strong reference.
        pub inline fn create(obj: T) !py.PyObject {
            const typeInfo = @typeInfo(T);

            // Early return to handle errors
            if (typeInfo == .ErrorUnion) {
                const value = obj catch |err| return err;
                return Trampoline(typeInfo.ErrorUnion.payload).create(value);
            }

            // Early return to handle optionals
            if (typeInfo == .Optional) {
                const value = obj orelse return py.None();
                return Trampoline(typeInfo.Optional.child).create(value);
            }

            // Shortcut for object types
            if (isObjectLike()) {
                const pyobj = asObject(obj);
                pyobj.incref();
                return pyobj;
            }

            switch (@typeInfo(T)) {
                .Bool => return if (obj) py.True().obj else py.False().obj,
                .ErrorUnion => @compileError("ErrorUnion already handled"),
                .Float => return (try py.PyFloat.create(obj)).obj,
                .Int => return (try py.PyLong.create(obj)).obj,
                .Pointer => |p| {
                    // We make the assumption that []const u8 is converted to a PyUnicode.
                    if (p.child == u8 and p.size == .Slice and p.is_const) {
                        return (try py.PyString.create(obj)).obj;
                    }

                    // Also pointers to u8 arrays *[_]u8
                    const childInfo = @typeInfo(p.child);
                    if (childInfo == .Array and childInfo.Array.child == u8) {
                        return (try py.PyString.create(obj)).obj;
                    }
                },
                .Struct => |s| {
                    // If the struct is a tuple, return a Python tuple
                    if (s.is_tuple) {
                        return (try py.PyTuple.create(obj)).obj;
                    }
                    // Check the user is not accidentally returning a Pydust class or Module without a pointer
                    if (py.findClassName(T) != null or py.findModuleName(T) != null) {
                        @compileError("Pydust objects can only be returned as pointers");
                    }
                    // Otherwise, return a Python dictionary
                    return (try py.PyDict.create(obj)).obj;
                },
                .Void => return py.None(),
                else => {},
            }

            @compileError("Unsupported return type " ++ @typeName(T));
        }

        /// Unwrap a Python object into a Zig object. DOES steal a reference.
        pub inline fn unwrapInto(object: ?py.PyObject) !T {
            if (!isObjectLike()) {
                // If we're unwrapping into another Python object, then we don't want to decref.
                // If we're unwrapping into a Zig, then we do want to decref.
                if (object) |o| {
                    defer o.decref();
                }
            }
            return unwrap(object);
        }

        /// Unwrap a Python object into a Zig object. Does not steal a reference.
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
                .Bool => return if ((try py.PyBool.checked(obj)).asbool()) true else false,
                .ErrorUnion => @compileError("ErrorUnion already handled"),
                .Float => return try (try py.PyFloat.checked(obj)).as(T),
                .Int => return try (try py.PyLong.checked(obj)).as(T),
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
                        const mod = try py.PyModule.checked(obj);
                        return try mod.getState(p.child);
                    }

                    // We make the assumption that []const u8 is converted from a PyString
                    if (p.child == u8 and p.size == .Slice and p.is_const) {
                        // FIXME(ngates): we can't do this since we need to copy the slice out of the string.
                    }

                    @compileLog("Unsupported pointer type " ++ @typeName(p.child));
                },
                .Struct => |s| {
                    // Support all extensions of py.PyObject, e.g. py.PyString, py.PyFloat
                    if (@hasField(R, "obj") and @hasField(std.meta.fieldInfo(R, .obj).type, "py")) {
                        return try @field(R, "checked")(obj);
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
                            @field(result, field.name) = try tuple.getItem(field.type.?, i);
                        }
                        return result;
                    }
                    // Otherwise, extract from a Python dictionary
                    const dict = try py.PyDict.of(obj);
                    var result: R = undefined;
                    inline for (s.fields) |field| {
                        // Recursively unwrap the field value
                        const fieldValue = try dict.getItem(field.name ++ "") orelse {
                            return py.TypeError.raise("dict missing field " ++ field.name ++ ": " ++ @typeName(field.type));
                        };
                        @field(result, field.name) = try Trampoline(field.type).unwrap(fieldValue);
                    }
                    return result;
                },
                .Void => if (py.is_none(obj)) return else return py.TypeError.raise("expected None"),
                else => {},
            }

            @compileError("Unsupported argument type " ++ @typeName(T));
        }

        pub const CallArgs = struct {
            args: ?py.PyTuple,
            kwargs: ?py.PyDict,

            pub fn nargs(self: CallArgs) usize {
                return if (self.args) |args| args.length() else 0;
            }

            pub fn nkwargs(self: CallArgs) usize {
                return if (self.kwargs) |kwargs| kwargs.length() else 0;
            }

            pub fn getArg(self: CallArgs, comptime R: type, idx: usize) !R {
                const args = self.args orelse return py.TypeError.raise("missing args");
                return try args.getItem(R, idx);
            }

            pub fn getKwarg(self: CallArgs, comptime R: type, name: []const u8) !?R {
                const kwargs = self.kwargs orelse return null;
                return kwargs.getItem(R, name);
            }

            pub fn decref(self: CallArgs) void {
                if (self.args) |args| args.decref();
                if (self.kwargs) |kwargs| kwargs.decref();
            }
        };

        /// Wrap a Zig Pydust argument struct into Python CallArgs.
        /// The caller is responsible for decref'ing the returned args and kwargs.
        pub inline fn wrapCallArgs(obj: T) !CallArgs {
            const args = try py.PyTuple.new(funcs.argCount(T));
            const kwargs = try py.PyDict.new();

            inline for (@typeInfo(T).Struct.fields, 0..) |field, i| {
                const arg = try Trampoline(field.type).create(@field(obj, field.name));
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

        pub inline fn unwrapCallArgs(callArgs: CallArgs) !T {
            if (funcs.argCount(T) != callArgs.nargs()) {
                return py.TypeError.raiseComptimeFmt(
                    "expected {d} argument{s}",
                    .{ funcs.argCount(T), if (funcs.argCount(T) > 1) "s" else "" },
                );
            }

            var args: T = undefined;
            inline for (@typeInfo(T).Struct.fields, 0..) |field, i| {
                if (field.default_value == null) {
                    // We're an arg
                    @field(args, field.name) = try callArgs.getArg(field.type, i);
                } else {
                    // We're a kwarg
                    if (try callArgs.getKwarg(field.type, field.name)) |kwarg| {
                        @field(args, field.name) = kwarg;
                    } else {
                        @field(args, field.name) = @as(*field.type, @ptrCast(field.default_value)).*;
                    }
                }
            }

            // Sanity check that we didn't recieve any kwargs that we weren't expecting
            const fieldNames = std.meta.fieldNames(T);
            if (callArgs.kwargs) |kwargs| {
                var iter = kwargs.itemsIterator();
                while (iter.next()) |item| {
                    const itemName = try (try item.key(py.PyString)).asSlice();

                    var exists = false;
                    for (fieldNames) |name| {
                        if (std.mem.eql(u8, name, itemName)) {
                            exists = true;
                            break;
                        }
                    }

                    if (!exists) {
                        return py.TypeError.raiseFmt("unexpected kwarg '{s}'", .{itemName});
                    }
                }
            }

            return args;
        }
    };
}
