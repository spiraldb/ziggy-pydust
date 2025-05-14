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

/// Utilities for bouncing CPython calls into Zig functions and back again.
const std = @import("std");
const Type = std.builtin.Type;
const ffi = @import("ffi.zig");
const py = @import("pydust.zig");
const State = @import("discovery.zig").State;
const funcs = @import("functions.zig");
const pytypes = @import("pytypes.zig");
const PyError = @import("errors.zig").PyError;

/// Generate functions to convert comptime-known Zig types to/from py.PyObject.
pub fn Trampoline(comptime root: type, comptime T: type) type {
    // Catch and handle comptime literals
    if (T == comptime_int) {
        return Trampoline(root, i64);
    }
    if (T == comptime_float) {
        return Trampoline(root, f64);
    }

    return struct {
        /// Recursively decref any PyObjects found in a native Zig type.
        pub inline fn decref_objectlike(obj: T) void {
            if (isObjectLike()) {
                asObject(obj).decref();
                return;
            }
            switch (@typeInfo(T)) {
                .error_union => |e| {
                    Trampoline(root, e.payload).decref_objectlike(obj catch return);
                },
                .optional => |o| {
                    if (obj) |object| Trampoline(root, o.child).decref_objectlike(object);
                },
                .@"struct" => |s| {
                    inline for (s.fields) |f| {
                        Trampoline(root, f.type).decref_objectlike(@field(obj, f.name));
                    }
                },
                // Explicit compile-error for other "container" types just to force us to handle them in the future.
                .pointer, .array, .@"union" => {
                    @compileError("Object decref not supported for type: " ++ @typeName(T));
                },
                else => {},
            }
        }

        /// Wraps an object that already represents an existing Python object.
        /// In other words, Zig primitive types are not supported.
        pub inline fn asObject(obj: T) py.PyObject(root) {
            switch (@typeInfo(T)) {
                .pointer => |p| {
                    // The object is an ffi.PyObject
                    if (p.child == ffi.PyObject) {
                        return .{ .py = obj };
                    }

                    if (comptime State.findDefinition(root, p.child)) |def| {
                        // If the pointer is for a Pydust class
                        if (def.type == .class) {
                            const PyType = pytypes.PyTypeStruct(p.child);
                            const ffiObject: *ffi.PyObject = @constCast(@ptrCast(@as(*const PyType, @alignCast(@fieldParentPtr("state", obj)))));
                            return .{ .py = ffiObject };
                        }

                        // If the pointer is for a Pydust module
                        if (def.type == .module) {
                            @compileError("Cannot currently return modules");
                        }
                    }
                },
                .@"struct" => {
                    // Support all extensions of py.PyObject, e.g. py.PyString, py.PyFloat
                    if (@hasField(T, "obj") and @hasField(std.meta.fieldInfo(T, .obj).type, "py")) {
                        return obj.obj;
                    }
                    if (T == py.PyObject(root)) {
                        return obj;
                    }
                },
                .optional => |o| return if (obj) |objP| Trampoline(o.child).asObject(objP) else std.debug.panic("Can't convert null to an object", .{}),
                inline else => {},
            }
            @compileError("Cannot convert into PyObject: " ++ @typeName(T));
        }

        inline fn isObjectLike() bool {
            switch (@typeInfo(T)) {
                .pointer => |p| {
                    // The object is an ffi.PyObject
                    if (p.child == ffi.PyObject) {
                        return true;
                    }

                    if (comptime State.findDefinition(root, p.child)) |_| {
                        return true;
                    }
                },
                .@"struct" => {
                    // Support all extensions of py.PyObject, e.g. py.PyString, py.PyFloat
                    if (@hasField(T, "obj") and @hasField(std.meta.fieldInfo(T, .obj).type, "py")) {
                        return true;
                    }

                    // Support py.PyObject
                    if (T == py.PyObject(root)) {
                        return true;
                    }
                },
                inline else => {},
            }
            return false;
        }

        /// Wraps a Zig object into a new Python object.
        /// The result should be treated like a new reference.
        pub inline fn wrap(obj: T) PyError!py.PyObject(root) {
            // Check the user is not accidentally returning a Pydust class or Module without a pointer
            if (comptime State.findDefinition(root, T) != null) {
                @compileError("Pydust objects can only be returned as pointers");
            }

            const typeInfo = @typeInfo(T);

            // Early return to handle errors
            if (typeInfo == .error_union) {
                const value = coerceError(root, obj) catch |err| return err;
                return Trampoline(root, typeInfo.error_union.payload).wrap(value);
            }

            // Early return to handle optionals
            if (typeInfo == .optional) {
                const value = obj orelse return py.None(root);
                return Trampoline(root, typeInfo.optional.child).wrap(value);
            }

            // Shortcut for object types
            if (isObjectLike()) {
                const pyobj = asObject(obj);
                pyobj.incref();
                return pyobj;
            }

            switch (@typeInfo(T)) {
                .bool => return if (obj) py.True(root).obj else py.False(root).obj,
                .error_union => @compileError("ErrorUnion already handled"),
                .float => return (try py.PyFloat(root).create(obj)).obj,
                .int => return (try py.PyLong(root).create(obj)).obj,
                .pointer => |p| {
                    // We make the assumption that []const u8 is converted to a PyUnicode.
                    if (p.child == u8 and p.size == .slice and p.is_const) {
                        return (try py.PyString(root).create(obj)).obj;
                    }

                    // Also pointers to u8 arrays *[_]u8
                    const childInfo = @typeInfo(p.child);
                    if (childInfo == .array and childInfo.array.child == u8) {
                        return (try py.PyString(root).create(obj)).obj;
                    }
                },
                .@"struct" => |s| {
                    // If the struct is a tuple, convert into a Python tuple
                    if (s.is_tuple) {
                        return (try py.PyTuple(root).create(obj)).obj;
                    }

                    // Otherwise, return a Python dictionary
                    return (try py.PyDict(root).create(obj)).obj;
                },
                .void => return py.None(root),
                else => {},
            }

            @compileError("Unsupported return type " ++ @typeName(T));
        }

        /// Unwrap a Python object into a Zig object. Does not steal a reference.
        /// The Python object must be the correct corresponding type (vs a cast which coerces values).
        pub inline fn unwrap(object: ?py.PyObject(root)) PyError!T {
            // Handle the error case explicitly, then we can unwrap the error case entirely.
            const typeInfo = @typeInfo(T);

            // Early return to handle errors
            if (typeInfo == .error_union) {
                const value = coerceError(root, object) catch |err| return err;
                return @as(T, Trampoline(root, typeInfo.error_union.payload).unwrap(value));
            }

            // Early return to handle optionals
            if (typeInfo == .optional) {
                const value = object orelse return null;
                if (py.is_none(root, value)) return null;
                return @as(T, try Trampoline(root, typeInfo.optional.child).unwrap(value));
            }

            // Otherwise we can unwrap the object.
            var obj = object orelse @panic("Unexpected null");

            switch (@typeInfo(T)) {
                .bool => return (try py.PyBool(root).checked(obj)).asbool(),
                .error_union => @compileError("ErrorUnion already handled"),
                .float => return try (try py.PyFloat(root).checked(obj)).as(T),
                .int => return try (try py.PyLong(root).checked(obj)).as(T),
                .optional => @compileError("Optional already handled"),
                .pointer => |p| {
                    if (comptime State.findDefinition(root, p.child)) |def| {
                        // If the pointer is for a Pydust module
                        if (def.type == .module) {
                            const mod = try py.PyModule(root).checked(obj);
                            return try mod.getState(p.child);
                        }

                        // If the pointer is for a Pydust class
                        if (def.type == .class) {
                            // TODO(ngates): #193
                            const Cls = try py.self(root, p.child);
                            defer Cls.decref();

                            if (!try py.isinstance(root, obj, Cls)) {
                                const clsName = State.getIdentifier(root, p.child).name;
                                const mod = State.getContaining(root, p.child, .module);
                                const modName = State.getIdentifier(root, mod).name;
                                return py.TypeError(root).raiseFmt(
                                    "Expected {s}.{s} but found {s}",
                                    .{ modName, clsName, try obj.getTypeName() },
                                );
                            }

                            const PyType = pytypes.PyTypeStruct(p.child);
                            const pyobject = @as(*PyType, @ptrCast(obj.py));
                            return @constCast(&pyobject.state);
                        }
                    }

                    // We make the assumption that []const u8 is converted from a PyString
                    if (p.child == u8 and p.size == .slice and p.is_const) {
                        return (try py.PyString(root).checked(obj)).asSlice();
                    }

                    @compileError("Unsupported pointer type " ++ @typeName(p.child));
                },
                .@"struct" => |s| {
                    // Support all extensions of py.PyObject, e.g. py.PyString, py.PyFloat
                    if (@hasField(T, "obj") and @hasField(std.meta.fieldInfo(T, .obj).type, "py")) {
                        return try @field(T, "checked")(obj);
                    }
                    // Support py.PyObject
                    if (T == py.PyObject(root) and @TypeOf(obj) == py.PyObject(root)) {
                        return obj;
                    }
                    // If the struct is a tuple, extract from the PyTuple
                    if (s.is_tuple) {
                        return (try py.PyTuple(root).checked(obj)).as(T);
                    }
                    // Otherwise, extract from a Python dictionary
                    return (try py.PyDict(root).checked(obj)).as(T);
                },
                .void => if (py.is_none(root, obj)) return else return py.TypeError(root).raise("expected None"),
                else => {},
            }

            @compileError("Unsupported argument type " ++ @typeName(T));
        }

        // Unwrap the call args into a Pydust argument struct, borrowing references to the Python objects
        // but instantiating the args slice and kwargs map containers.
        // The caller is responsible for invoking deinit on the returned struct.
        pub inline fn unwrapCallArgs(pyargs: ?py.PyTuple(root), pykwargs: ?py.PyDict(root)) PyError!ZigCallArgs {
            return ZigCallArgs.unwrap(pyargs, pykwargs);
        }

        const ZigCallArgs = struct {
            argsStruct: T,
            allPosArgs: []py.PyObject(root),

            pub fn unwrap(pyargs: ?py.PyTuple(root), pykwargs: ?py.PyDict(root)) PyError!@This() {
                var kwargs = py.Kwargs(root).init(py.allocator);
                if (pykwargs) |kw| {
                    var iter = kw.itemsIterator();
                    while (iter.next()) |item| {
                        const key: []const u8 = try (try py.PyString(root).checked(item.k)).asSlice();
                        try kwargs.put(key, item.v);
                    }
                }

                const args = try py.allocator.alloc(py.PyObject(root), if (pyargs) |a| a.length() else 0);
                if (pyargs) |a| {
                    for (0..a.length()) |i| {
                        args[i] = try a.getItem(py.PyObject(root), i);
                    }
                }

                return .{ .argsStruct = try funcs.unwrapArgs(root, T, args, kwargs), .allPosArgs = args };
            }

            pub fn deinit(self: @This()) void {
                if (comptime funcs.varArgsIdx(root, T)) |idx| {
                    py.allocator.free(self.allPosArgs[0..idx]);
                } else {
                    py.allocator.free(self.allPosArgs);
                }

                inline for (@typeInfo(T).@"struct".fields) |field| {
                    if (field.type == py.Args(root)) {
                        py.allocator.free(@field(self.argsStruct, field.name));
                    }
                    if (field.type == py.Kwargs(root)) {
                        var kwargs: py.Kwargs(root) = @field(self.argsStruct, field.name);
                        kwargs.deinit();
                    }
                }
            }
        };
    };
}

/// Takes a value that optionally errors and coerces it always into a PyError.
pub fn coerceError(comptime root: type, result: anytype) coerceErrorType(@TypeOf(result)) {
    const typeInfo = @typeInfo(@TypeOf(result));
    if (typeInfo == .error_union) {
        return result catch |err| {
            if (err == PyError.PyRaised) return PyError.PyRaised;
            if (err == PyError.OutOfMemory) return PyError.OutOfMemory;
            return py.RuntimeError(root).raise(@errorName(err));
        };
    } else {
        return result;
    }
}

fn coerceErrorType(comptime Result: type) type {
    const typeInfo = @typeInfo(Result);
    if (typeInfo == .error_union) {
        // Unwrap the error to ensure it's a PyError
        return PyError!typeInfo.error_union.payload;
    } else {
        // Always return a PyError union so the caller can always "try".
        return PyError!Result;
    }
}
