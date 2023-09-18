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

// https://docs.python.org/3/extending/newtypes_tutorial.html

const std = @import("std");
const ffi = @import("ffi.zig");
const py = @import("pydust.zig");
const discovery = @import("discovery.zig");
const Attributes = @import("attributes.zig").Attributes;
const State = @import("discovery.zig").State;
const funcs = @import("functions.zig");
const PyError = @import("errors.zig").PyError;
const PyMemAllocator = @import("mem.zig").PyMemAllocator;
const tramp = @import("trampoline.zig");
const Type = std.builtin.Type;

/// For a given Pydust class definition, return the encapsulating PyType struct.
pub fn PyTypeStruct(comptime definition: type) type {
    // I think we might need to dynamically generate this struct to include PyMemberDef fields?
    // This is how we can add nested classes and other attributes.
    return struct {
        obj: ffi.PyObject,
        state: definition,
    };
}

/// Discover a Pydust class definition.
pub fn PyType(comptime name: [:0]const u8, comptime definition: type) type {
    return struct {
        const qualifiedName: [:0]const u8 = blk: {
            const moduleName = State.getIdentifier(State.getContaining(definition, .module)).name;
            break :blk moduleName ++ "." ++ name;
        };

        const bases = Bases(definition);
        const attrs = Attributes(definition);
        const slots = Slots(definition);

        pub fn init(module: py.PyModule) !py.PyObject {
            var basesPtr: ?*ffi.PyObject = null;
            if (bases.bases.len > 0) {
                const basesTuple = try py.PyTuple.new(bases.bases.len);
                inline for (bases.bases, 0..) |base, i| {
                    const baseType = try module.obj.get(State.getIdentifier(base).name);
                    try basesTuple.setItem(i, baseType);
                }
                basesPtr = basesTuple.obj.py;
            }

            const spec = ffi.PyType_Spec{
                // TODO(ngates): according to the docs, since we're a heap allocated type I think we
                // should be manually setting a __module__ attribute and not using a qualified name here?
                .name = qualifiedName.ptr,
                .basicsize = @sizeOf(PyTypeStruct(definition)),
                .itemsize = 0,
                .flags = ffi.Py_TPFLAGS_DEFAULT | ffi.Py_TPFLAGS_BASETYPE,
                .slots = @constCast(slots.slots.ptr),
            };

            const pytype = ffi.PyType_FromModuleAndSpec(
                module.obj.py,
                @constCast(&spec),
                basesPtr,
            ) orelse return PyError.Propagate;

            return .{ .py = pytype };
        }
    };
}

/// Discover the base classes of the pytype definition.
/// We look for any struct field that is itself a Pydust class.
fn Bases(comptime definition: type) type {
    const typeInfo = @typeInfo(definition).Struct;
    return struct {
        const bases: []const type = blk: {
            var bases_: []const type = &.{};
            for (typeInfo.fields) |field| {
                if (State.findDefinition(field.type)) |def| {
                    if (def.type == .class) {
                        bases_ = bases_ ++ .{field.type};
                    }
                }
            }
            break :blk bases_;
        };
    };
}

fn Slots(comptime definition: type) type {
    return struct {
        const empty = ffi.PyType_Slot{ .slot = 0, .pfunc = null };

        const attrs = Attributes(definition);
        const methods = funcs.Methods(definition);
        const members = Members(definition);
        const properties = Properties(definition);

        /// Slots populated in the PyType
        pub const slots: [:empty]const ffi.PyType_Slot = blk: {
            var slots_: [:empty]const ffi.PyType_Slot = &.{};

            if (@hasDecl(definition, "__doc__")) {
                const doc: [:0]const u8 = @field(definition, "__doc__");
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_doc,
                    .pfunc = @ptrCast(@constCast(doc.ptr)),
                }};
            }

            if (@hasDecl(definition, "__new__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_new,
                    .pfunc = @ptrCast(@constCast(&tp_new)),
                }};
            } else {
                // Otherwise, we set tp_new to a default that throws a type error.
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_new,
                    .pfunc = @ptrCast(@constCast(&tp_new_default)),
                }};
            }

            if (@hasDecl(definition, "__del__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_finalize,
                    .pfunc = @ptrCast(@constCast(&tp_finalize)),
                }};
            }

            if (@hasDecl(definition, "__buffer__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_bf_getbuffer,
                    .pfunc = @ptrCast(@constCast(&bf_getbuffer)),
                }};
            }

            if (@hasDecl(definition, "__release_buffer__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_bf_releasebuffer,
                    .pfunc = @ptrCast(@constCast(&bf_releasebuffer)),
                }};
            }

            if (@hasDecl(definition, "__len__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_sq_length,
                    .pfunc = @ptrCast(@constCast(&sq_length)),
                }};
            }

            if (@hasDecl(definition, "__iter__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_iter,
                    .pfunc = @ptrCast(@constCast(&tp_iter)),
                }};
            }

            if (@hasDecl(definition, "__next__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_iternext,
                    .pfunc = @ptrCast(@constCast(&tp_iternext)),
                }};
            }

            if (@hasDecl(definition, "__str__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_str,
                    .pfunc = @ptrCast(@constCast(&tp_str)),
                }};
            }

            if (@hasDecl(definition, "__repr__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_repr,
                    .pfunc = @ptrCast(@constCast(&tp_repr)),
                }};
            }

            for (funcs.BinaryOperators.kvs) |kv| {
                if (@hasDecl(definition, kv.key)) {
                    const op = BinaryOperator(definition, kv.key);
                    slots_ = slots_ ++ .{ffi.PyType_Slot{
                        .slot = kv.value,
                        .pfunc = @ptrCast(@constCast(&op.call)),
                    }};
                }
            }

            slots_ = slots_ ++ .{ffi.PyType_Slot{
                .slot = ffi.Py_tp_methods,
                .pfunc = @ptrCast(@constCast(&methods.pydefs)),
            }};

            slots_ = slots_ ++ .{ffi.PyType_Slot{
                .slot = ffi.Py_tp_members,
                .pfunc = @ptrCast(@constCast(&members.memberdefs)),
            }};

            slots_ = slots_ ++ .{ffi.PyType_Slot{
                .slot = ffi.Py_tp_getset,
                .pfunc = @ptrCast(@constCast(&properties.getsetdefs)),
            }};

            slots_ = slots_ ++ .{empty};

            break :blk slots_;
        };

        fn tp_new(subtype: *ffi.PyTypeObject, pyargs: [*c]ffi.PyObject, pykwargs: [*c]ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const pyself: *ffi.PyObject = ffi.PyType_GenericAlloc(subtype, 0) orelse return null;
            // Cast it into a supertype instance. Note: we check at comptime that subclasses of this class
            // include our own state object as the first field in their struct.
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);

            // Allow the definition to initialize the state field.
            self.state = tp_new_internal(
                if (pyargs) |pa| py.PyTuple.unchecked(.{ .py = pa }) else null,
                if (pykwargs) |pk| py.PyDict.unchecked(.{ .py = pk }) else null,
            ) catch return null;

            return pyself;
        }

        fn tp_new_internal(pyargs: ?py.PyTuple, pykwargs: ?py.PyDict) !definition {
            const sig = funcs.parseSignature("__new__", @typeInfo(@TypeOf(definition.__new__)).Fn, &.{});
            if (sig.selfParam) |_| @compileError("__new__ must not take a self parameter");

            if (sig.argsParam) |Args| {
                const args = try tramp.Trampoline(Args).unwrapCallArgs(.{ .args = pyargs, .kwargs = pykwargs });
                return try definition.__new__(args);
            } else {
                return try definition.__new__();
            }
        }

        fn tp_new_default(subtype: *ffi.PyTypeObject, pyargs: [*c]ffi.PyObject, pykwargs: [*c]ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            _ = pykwargs;
            _ = pyargs;
            _ = subtype;
            py.TypeError.raise("Native type cannot be instantiated from Python") catch return null;
            return null;
        }

        /// Wrapper for the user's __del__ function.
        /// Note: tp_del is deprecated in favour of tp_finalize.
        ///
        /// See https://docs.python.org/3/c-api/typeobj.html#c.PyTypeObject.tp_finalize.
        fn tp_finalize(pyself: *ffi.PyObject) void {
            // The finalize slot shouldn't alter any exception that is currently set.
            // So it's recommended we save the existing one (if any) and restore it afterwards.
            // NOTE(ngates): we may want to move this logic to PyErr if it happens more?
            var error_type: ?*ffi.PyObject = undefined;
            var error_value: ?*ffi.PyObject = undefined;
            var error_tb: ?*ffi.PyObject = undefined;
            ffi.PyErr_Fetch(&error_type, &error_value, &error_tb);

            const instance: *PyTypeStruct(definition) = @ptrCast(pyself);
            definition.__del__(&instance.state);

            ffi.PyErr_Restore(error_type, error_value, error_tb);
        }

        fn bf_getbuffer(pyself: *ffi.PyObject, view: *ffi.Py_buffer, flags: c_int) callconv(.C) c_int {
            // In case of any error, the view.obj field must be set to NULL.
            view.obj = null;

            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            definition.__buffer__(&self.state, @ptrCast(view), flags) catch return -1;
            return 0;
        }

        fn bf_releasebuffer(pyself: *ffi.PyObject, view: *ffi.Py_buffer) callconv(.C) void {
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            return definition.__release_buffer__(&self.state, @ptrCast(view));
        }

        fn sq_length(pyself: *ffi.PyObject) callconv(.C) isize {
            const self: *const PyTypeStruct(definition) = @ptrCast(pyself);
            const result = definition.__len__(&self.state) catch return -1;
            return @as(isize, @intCast(result));
        }

        fn tp_iter(pyself: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const iterator = definition.__iter__(&self.state) catch return null;
            return (py.createOwned(iterator) catch return null).py;
        }

        fn tp_iternext(pyself: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const optionalNext = definition.__next__(&self.state) catch return null;
            if (optionalNext) |next| {
                return (py.createOwned(next) catch return null).py;
            }
            return null;
        }

        fn tp_str(pyself: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const result = definition.__str__(&self.state) catch return null;
            return (py.createOwned(result) catch return null).py;
        }

        fn tp_repr(pyself: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const result = definition.__repr__(&self.state) catch return null;
            return (py.createOwned(result) catch return null).py;
        }
    };
}

fn Members(comptime definition: type) type {
    return struct {
        const count = State.countFieldsWithType(definition, .attribute);

        const memberdefs: [count + 1]ffi.PyMemberDef = blk: {
            var defs: [count + 1]ffi.PyMemberDef = undefined;
            var idx = 0;
            for (@typeInfo(definition).Struct.fields) |field| {
                if (!State.hasType(field.type, .attribute)) {
                    continue;
                }

                // We compute the offset of the attribute within the type, and then the value field within the attribute.
                // Although the value within the attribute should always be 0 since it's the only field.
                var offset = @offsetOf(PyTypeStruct(definition), "state") + @offsetOf(definition, field.name) + @offsetOf(field.type, "value");

                const T = @typeInfo(field.type).Struct.fields[0].type;

                defs[idx] = ffi.PyMemberDef{
                    .name = field.name ++ "",
                    .type = getMemberType(T),
                    .offset = @intCast(offset),
                    .flags = ffi.READONLY,
                    .doc = null,
                };
                idx += 1;
            }

            // Add null terminator
            defs[count] = .{ .name = null, .type = 0, .offset = 0, .flags = 0, .doc = null };

            break :blk defs;
        };

        // We extract the equivalent C type by looking at signedness and bits.
        // This allows us to support native Zig types like u32 and not require the user
        // to specify c_int.
        fn getMemberType(comptime T: type) c_int {
            if (T == py.PyObject) {
                return ffi.T_OBJECT_EX;
            }

            if (T == [*:0]const u8) {
                return ffi.T_STRING;
            }

            switch (@typeInfo(T)) {
                .Int => |i| switch (i.signedness) {
                    .signed => switch (i.bits) {
                        @bitSizeOf(i8) => return ffi.T_BYTE,
                        @bitSizeOf(c_short) => return ffi.T_SHORT,
                        @bitSizeOf(c_int) => return ffi.T_INT,
                        @bitSizeOf(c_long) => return ffi.T_LONG,
                        @bitSizeOf(isize) => return ffi.T_PYSSIZET,
                        else => {},
                    },
                    .unsigned => switch (i.bits) {
                        @bitSizeOf(u8) => return ffi.T_UBYTE,
                        @bitSizeOf(c_ushort) => return ffi.T_USHORT,
                        @bitSizeOf(c_uint) => return ffi.T_UINT,
                        @bitSizeOf(c_ulong) => return ffi.T_ULONG,
                        else => {},
                    },
                },
                else => {},
            }
            @compileError("Zig type " ++ @typeName(T) ++ " is not supported for Pydust attribute. Consider using a py.property instead.");
        }
    };
}

fn Properties(comptime definition: type) type {
    return struct {
        const count = State.countFieldsWithType(definition, .property);

        const getsetdefs: [count + 1]ffi.PyGetSetDef = blk: {
            var props: [count + 1]ffi.PyGetSetDef = undefined;
            var idx = 0;
            for (@typeInfo(definition).Struct.fields) |field| {
                if (State.hasType(field.type, .property)) {
                    var prop: ffi.PyGetSetDef = .{
                        .name = field.name ++ "",
                        .get = null,
                        .set = null,
                        .doc = null,
                        .closure = null,
                    };

                    if (@hasDecl(field.type, "get")) {
                        const Closure = struct {
                            pub fn get(pyself: [*c]ffi.PyObject, closure: ?*anyopaque) callconv(.C) ?*ffi.PyObject {
                                _ = closure;

                                const self: *PyTypeStruct(definition) = @ptrCast(pyself);
                                const propself = @constCast(&@field(self.state, field.name));

                                // TODO(ngates): trampoline self?
                                const result = field.type.get(propself) catch return null;
                                const resultObj = tramp.Trampoline(@TypeOf(result)).wrap(result) catch return null;
                                return resultObj.py;
                            }
                        };
                        prop.get = &Closure.get;
                    }

                    if (@hasDecl(field.type, "set")) {
                        const Closure = struct {
                            pub fn set(pyself: [*c]ffi.PyObject, pyvalue: [*c]ffi.PyObject, closure: ?*anyopaque) callconv(.C) c_int {
                                _ = closure;
                                const self: *PyTypeStruct(definition) = @ptrCast(pyself);
                                const propself = &@field(self.state, field.name);

                                const ValueArg = @typeInfo(@TypeOf(field.type.set)).Fn.params[1].type.?;
                                const value = tramp.Trampoline(ValueArg).unwrap(.{ .py = pyvalue }) catch return -1;

                                // TODO(ngates): trampoline self?
                                field.type.set(propself, value) catch return -1;
                                return 0;
                            }
                        };
                        prop.set = &Closure.set;
                    }

                    props[idx] = prop;
                    idx += 1;
                }
            }

            // Null terminator
            props[count] = .{ .name = null, .get = null, .set = null, .doc = null, .closure = null };

            break :blk props;
        };
    };
}

fn BinaryOperator(
    comptime definition: type,
    comptime op: []const u8,
) type {
    return struct {
        fn call(pyself: *ffi.PyObject, pyother: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const func = @field(definition, op);
            const typeInfo = @typeInfo(@TypeOf(func));
            const sig = funcs.parseSignature(op, typeInfo.Fn, &.{});

            if (sig.selfParam == null) @compileError(op ++ " must take a self parameter");
            if (sig.nargs != 1) @compileError(op ++ " must take exactly one parameter after self parameter");

            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const other = tramp.Trampoline(
                sig.argsParam orelse unreachable,
            ).unwrap(.{ .py = pyother }) catch return null;

            const result = func(&self.state, other) catch return null;
            return (py.createOwned(result) catch return null).py;
        }
    };
}
