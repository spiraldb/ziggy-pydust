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
pub fn Type(comptime name: [:0]const u8, comptime definition: type) type {
    return struct {
        const qualifiedName: [:0]const u8 = blk: {
            const moduleName = State.getIdentifier(State.getContaining(definition, .module)).name;
            break :blk moduleName ++ "." ++ name;
        };

        const bases = Bases(definition);
        const slots = Slots(definition, name);

        const flags = blk: {
            var flags_: usize = ffi.Py_TPFLAGS_DEFAULT | ffi.Py_TPFLAGS_BASETYPE;
            if (slots.gc.needsGc) {
                flags_ |= ffi.Py_TPFLAGS_HAVE_GC;
            }

            break :blk flags_;
        };

        pub fn init(module: py.PyModule) PyError!py.PyObject {
            var basesPtr: ?*ffi.PyObject = null;
            if (bases.bases.len > 0) {
                const basesTuple = try py.PyTuple.new(bases.bases.len);
                inline for (bases.bases, 0..) |base, i| {
                    try basesTuple.setOwnedItem(i, try py.self(base));
                }
                basesPtr = basesTuple.obj.py;
            }

            const spec = ffi.PyType_Spec{
                // TODO(ngates): according to the docs, since we're a heap allocated type I think we
                // should be manually setting a __module__ attribute and not using a qualified name here?
                .name = qualifiedName.ptr,
                .basicsize = @sizeOf(PyTypeStruct(definition)),
                .itemsize = 0,
                .flags = flags,
                .slots = @constCast(slots.slots.ptr),
            };

            const pytype = ffi.PyType_FromModuleAndSpec(
                module.obj.py,
                @constCast(&spec),
                basesPtr,
            ) orelse return PyError.PyRaised;

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

fn Slots(comptime definition: type, comptime name: [:0]const u8) type {
    return struct {
        const empty = ffi.PyType_Slot{ .slot = 0, .pfunc = null };

        const attrs = Attributes(definition);
        const methods = funcs.Methods(definition);
        const members = Members(definition);
        const properties = Properties(definition);
        const doc = Doc(definition, name);
        const richcmp = RichCompare(definition);
        const gc = GC(definition);

        /// Slots populated in the PyType
        pub const slots: [:empty]const ffi.PyType_Slot = blk: {
            var slots_: [:empty]const ffi.PyType_Slot = &.{};

            if (gc.needsGc) {
                slots_ = slots_ ++ .{ ffi.PyType_Slot{
                    .slot = ffi.Py_tp_clear,
                    .pfunc = @constCast(&gc.tp_clear),
                }, ffi.PyType_Slot{
                    .slot = ffi.Py_tp_traverse,
                    .pfunc = @constCast(&gc.tp_traverse),
                } };
            }

            if (doc.docLen != 0) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_doc,
                    .pfunc = @ptrCast(@constCast(&doc.doc)),
                }};
            }

            if (@hasDecl(definition, "__new__")) {
                @compileLog("The behaviour of __new__ is replaced by __init__(*Self). See ", State.getIdentifier(definition).qualifiedName);
            }

            if (@hasDecl(definition, "__init__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_init,
                    .pfunc = @ptrCast(@constCast(&tp_init)),
                }};

                // Add a default tp_new implementation so that we override any tp_new_not_instatiatable
                // calls that supertypes may have configured.
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_new,
                    .pfunc = @constCast(&ffi.PyType_GenericNew),
                }};
            } else {
                // Otherwise, we set tp_new to a default that throws to ensure the class
                // cannot be constructed from Python.
                // NOTE(ngates): we use tp_new because it allows us to fail as early as possible.
                // This means that Python will not attempt to call the finalizer (__del__) on an
                // uninitialized class.
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_new,
                    .pfunc = @ptrCast(@constCast(&tp_new_not_instantiable)),
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

            if (@hasDecl(definition, "__hash__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_hash,
                    .pfunc = @ptrCast(@constCast(&tp_hash)),
                }};
            }

            if (@hasDecl(definition, "__call__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_call,
                    .pfunc = @ptrCast(@constCast(&tp_call)),
                }};
            }

            if (@hasDecl(definition, "__bool__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_nb_bool,
                    .pfunc = @ptrCast(@constCast(&nb_bool)),
                }};
            }

            if (richcmp.hasCompare) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_richcompare,
                    .pfunc = @ptrCast(@constCast(&richcmp.compare)),
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

            for (funcs.UnaryOperators.kvs) |kv| {
                if (@hasDecl(definition, kv.key)) {
                    const op = UnaryOperator(definition, kv.key);
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

        fn tp_new_not_instantiable(pycls: *ffi.PyTypeObject, pyargs: [*c]ffi.PyObject, pykwargs: [*c]ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            _ = pycls;
            _ = pykwargs;
            _ = pyargs;
            py.TypeError.raise("Native type cannot be instantiated from Python") catch return null;
        }

        fn tp_init(pyself: *ffi.PyObject, pyargs: [*c]ffi.PyObject, pykwargs: [*c]ffi.PyObject) callconv(.C) c_int {
            const sig = funcs.parseSignature("__init__", @typeInfo(@TypeOf(definition.__init__)).Fn, &.{ *definition, *const definition, py.PyObject });

            if (sig.selfParam == null and @typeInfo(definition).fields.len > 0) {
                @compileError("__init__ must take both a self argument");
            }
            const self = tramp.Trampoline(sig.selfParam.?).unwrap(py.PyObject{ .py = pyself }) catch return -1;

            if (sig.argsParam) |Args| {
                const args = if (pyargs) |pa| py.PyTuple.unchecked(.{ .py = pa }) else null;
                const kwargs = if (pykwargs) |pk| py.PyDict.unchecked(.{ .py = pk }) else null;

                const init_args = tramp.Trampoline(Args).unwrapCallArgs(args, kwargs) catch return -1;
                defer init_args.deinit();

                tramp.coerceError(definition.__init__(self, init_args.argsStruct)) catch return -1;
            } else if (sig.selfParam) |_| {
                tramp.coerceError(definition.__init__(self)) catch return -1;
            } else {
                // The function is just a marker to say that the type can be instantiated from Python
            }

            return 0;
        }

        /// Wrapper for the user's __del__ function.
        /// Note: tp_del is deprecated in favour of tp_finalize.
        ///
        /// See https://docs.python.org/3/c-api/typeobj.html#c.PyTypeObject.tp_finalize.
        fn tp_finalize(pyself: *ffi.PyObject) callconv(.C) void {
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
            tramp.coerceError(definition.__buffer__(&self.state, @ptrCast(view), flags)) catch return -1;
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
            const iterator = tramp.coerceError(definition.__iter__(&self.state)) catch return null;
            return (py.createOwned(iterator) catch return null).py;
        }

        fn tp_iternext(pyself: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const optionalNext = tramp.coerceError(definition.__next__(&self.state)) catch return null;
            if (optionalNext) |next| {
                return (py.createOwned(next) catch return null).py;
            }
            return null;
        }

        fn tp_str(pyself: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const result = tramp.coerceError(definition.__str__(&self.state)) catch return null;
            return (py.createOwned(result) catch return null).py;
        }

        fn tp_repr(pyself: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const result = tramp.coerceError(definition.__repr__(&self.state)) catch return null;
            return (py.createOwned(result) catch return null).py;
        }

        fn tp_hash(pyself: *ffi.PyObject) callconv(.C) ffi.Py_hash_t {
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const result = tramp.coerceError(definition.__hash__(&self.state)) catch return -1;
            return @as(isize, @bitCast(result));
        }

        fn tp_call(pyself: *ffi.PyObject, pyargs: [*c]ffi.PyObject, pykwargs: [*c]ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const sig = funcs.parseSignature("__call__", @typeInfo(@TypeOf(definition.__call__)).Fn, &.{ *definition, *const definition, py.PyObject });

            const args = if (pyargs) |pa| py.PyTuple.unchecked(.{ .py = pa }) else null;
            const kwargs = if (pykwargs) |pk| py.PyDict.unchecked(.{ .py = pk }) else null;

            const self = tramp.Trampoline(sig.selfParam.?).unwrap(py.PyObject{ .py = pyself }) catch return null;
            const call_args = tramp.Trampoline(sig.argsParam.?).unwrapCallArgs(args, kwargs) catch return null;
            defer call_args.deinit();

            const result = tramp.coerceError(definition.__call__(self, call_args.argsStruct)) catch return null;
            return (py.createOwned(result) catch return null).py;
        }

        fn nb_bool(pyself: *ffi.PyObject) callconv(.C) c_int {
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const result = tramp.coerceError(definition.__bool__(&self.state)) catch return -1;
            return @intCast(@intFromBool(result));
        }
    };
}

fn Doc(comptime definition: type, comptime name: [:0]const u8) type {
    return struct {
        const docLen = blk: {
            var size: usize = 0;
            var maybeSig: ?funcs.Signature = null;
            if (@hasDecl(definition, "__init__")) {
                maybeSig = funcs.parseSignature("__init__", @typeInfo(@TypeOf(definition.__init__)).Fn, &.{ py.PyObject, *definition, *const definition });
            }

            if (maybeSig) |sig| {
                const classSig: funcs.Signature = .{
                    .name = name,
                    .selfParam = sig.selfParam,
                    .argsParam = sig.argsParam,
                    .returnType = sig.returnType,
                    .nargs = sig.nargs,
                    .nkwargs = sig.nkwargs,
                };
                size += funcs.textSignature(classSig).len;
            }

            if (@hasDecl(definition, "__doc__")) {
                size += definition.__doc__.len;
            }
            break :blk size;
        };

        const doc: [docLen:0]u8 = blk: {
            var userDoc: [docLen:0]u8 = undefined;
            var docOffset = 0;
            var maybeSig: ?funcs.Signature = null;
            if (@hasDecl(definition, "__init__")) {
                maybeSig = funcs.parseSignature("__init__", @typeInfo(@TypeOf(definition.__init__)).Fn, &.{ py.PyObject, *definition, *const definition });
            }

            if (maybeSig) |sig| {
                const classSig: funcs.Signature = .{
                    .name = name,
                    .selfParam = sig.selfParam,
                    .argsParam = sig.argsParam,
                    .returnType = sig.returnType,
                    .nargs = sig.nargs,
                    .nkwargs = sig.nkwargs,
                };
                const sigText = funcs.textSignature(classSig);
                @memcpy(userDoc[0..sigText.len], &sigText);
                docOffset += sigText.len;
            }
            if (@hasDecl(definition, "__doc__")) {
                @memcpy(userDoc[docOffset..], definition.__doc__);
            }

            // Add null terminator
            userDoc[userDoc.len] = 0;

            break :blk userDoc;
        };
    };
}

fn GC(comptime definition: type) type {
    const VisitProc = *const fn (*ffi.PyObject, *anyopaque) callconv(.C) c_int;

    return struct {
        const needsGc = classNeedsGc(definition);

        fn classNeedsGc(comptime CT: type) bool {
            inline for (@typeInfo(CT).Struct.fields) |field| {
                if (typeNeedsGc(field.type)) {
                    return true;
                }
            }
            return false;
        }

        fn typeNeedsGc(comptime FT: type) bool {
            return switch (@typeInfo(FT)) {
                .Pointer => |p| @typeInfo(p.child) == .Struct and (p.child == ffi.PyObject or typeNeedsGc(p.child)),
                .Struct => blk: {
                    if (State.findDefinition(FT)) |def| {
                        break :blk switch (def.type) {
                            .attribute => typeNeedsGc(@typeInfo(FT).Struct.fields[0].type),
                            .property => classNeedsGc(FT),
                            .class, .module => false,
                        };
                    } else {
                        break :blk @hasField(FT, "obj") and @hasField(std.meta.fieldInfo(FT, .obj).type, "py") or FT == py.PyObject;
                    }
                },
                .Optional => |o| (@typeInfo(o.child) == .Struct or @typeInfo(o.child) == .Pointer) and typeNeedsGc(o.child),
                else => return false,
            };
        }

        fn tp_clear(pyself: *ffi.PyObject) callconv(.C) c_int {
            var self: *PyTypeStruct(definition) = @ptrCast(pyself);
            clearFields(self.state);
            return 0;
        }

        fn clearFields(class: anytype) void {
            inline for (@typeInfo(@TypeOf(class)).Struct.fields) |field| {
                clear(@field(class, field.name));
            }
        }

        fn clear(obj: anytype) void {
            const fieldType = @TypeOf(obj);
            switch (@typeInfo(fieldType)) {
                .Pointer => |p| if (@typeInfo(p.child) == .Struct) {
                    if (p.child == ffi.PyObject) {
                        pyClear(obj);
                    }
                    if (State.findDefinition(fieldType)) |def| {
                        if (def.type == .class) {
                            pyClear(py.object(obj).py);
                        }
                    }
                },
                .Struct => {
                    if (State.findDefinition(fieldType)) |def| {
                        switch (def.type) {
                            .attribute => clear(@field(obj, @typeInfo(fieldType).Struct.fields[0].name)),
                            .property => clearFields(obj),
                            .class, .module => {},
                        }
                    } else {
                        if (@hasField(fieldType, "obj") and @hasField(std.meta.fieldInfo(fieldType, .obj).type, "py")) {
                            pyClear(obj.obj.py);
                        }

                        if (fieldType == py.PyObject) {
                            pyClear(obj.py);
                        }
                    }
                },
                .Optional => |o| if (@typeInfo(o.child) == .Struct or @typeInfo(o.child) == .Pointer) {
                    if (obj == null) {
                        return;
                    }

                    clear(obj.?);
                },
                else => {},
            }
        }

        inline fn pyClear(obj: *ffi.PyObject) void {
            var objRef = @constCast(&obj);
            const objOld = objRef.*;
            objRef.* = undefined;
            py.decref(objOld);
        }

        /// Visit all members of pyself. We visit all PyObjects that this object references
        fn tp_traverse(pyself: *ffi.PyObject, visit: VisitProc, arg: *anyopaque) callconv(.C) c_int {
            if (pyVisit(py.type_(pyself).obj.py, visit, arg)) |ret| {
                return ret;
            }

            const self: *const PyTypeStruct(definition) = @ptrCast(pyself);
            if (traverseFields(self.state, visit, arg)) |ret| {
                return ret;
            }
            return 0;
        }

        fn traverseFields(class: anytype, visit: VisitProc, arg: *anyopaque) ?c_int {
            inline for (@typeInfo(@TypeOf(class)).Struct.fields) |field| {
                if (traverse(@field(class, field.name), visit, arg)) |ret| {
                    return ret;
                }
            }
            return null;
        }

        fn traverse(obj: anytype, visit: VisitProc, arg: *anyopaque) ?c_int {
            const fieldType = @TypeOf(obj);
            switch (@typeInfo(@TypeOf(obj))) {
                .Pointer => |p| if (@typeInfo(p.child) == .Struct) {
                    if (p.child == ffi.PyObject) {
                        if (pyVisit(obj, visit, arg)) |ret| {
                            return ret;
                        }
                    }
                    if (State.findDefinition(fieldType)) |def| {
                        if (def.type == .class) {
                            if (pyVisit(py.object(obj).py, visit, arg)) |ret| {
                                return ret;
                            }
                        }
                    }
                },
                .Struct => if (State.findDefinition(fieldType)) |def| {
                    switch (def.type) {
                        .attribute => if (traverse(@field(obj, @typeInfo(@TypeOf(obj)).Struct.fields[0].name), visit, arg)) |ret| {
                            return ret;
                        },
                        .property => if (traverseFields(obj, visit, arg)) |ret| {
                            return ret;
                        },
                        .class, .module => {},
                    }
                } else {
                    if (@hasField(fieldType, "obj") and @hasField(std.meta.fieldInfo(fieldType, .obj).type, "py")) {
                        if (pyVisit(obj.obj.py, visit, arg)) |ret| {
                            return ret;
                        }
                    }

                    if (fieldType == py.PyObject) {
                        if (pyVisit(obj.py, visit, arg)) |ret| {
                            return ret;
                        }
                    }
                },
                .Optional => |o| if (@typeInfo(o.child) == .Struct or @typeInfo(o.child) == .Pointer) {
                    if (obj == null) {
                        return null;
                    }

                    if (traverse(obj.?, visit, arg)) |ret| {
                        return ret;
                    }
                },
                else => return null,
            }
            return null;
        }

        inline fn pyVisit(obj: *ffi.PyObject, visit: VisitProc, arg: *anyopaque) ?c_int {
            const ret = visit(obj, arg);
            return if (ret != 0) ret else null;
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

                                const self: *const PyTypeStruct(definition) = @ptrCast(pyself);

                                const SelfParam = @typeInfo(@TypeOf(field.type.get)).Fn.params[0].type.?;
                                const propself = switch (SelfParam) {
                                    *const definition => &self.state,
                                    *const field.type => @constCast(&@field(self.state, field.name)),
                                    else => @compileError("Unsupported self parameter " ++ @typeName(SelfParam) ++ ". Expected " ++ @typeName(*const definition) ++ " or " ++ @typeName(*const field.type)),
                                };

                                const result = tramp.coerceError(field.type.get(propself)) catch return null;
                                const resultObj = py.createOwned(result) catch return null;
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

                                tramp.coerceError(field.type.set(propself, value)) catch return -1;
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
            const typeInfo = @typeInfo(@TypeOf(func)).Fn;

            if (typeInfo.params.len != 2) @compileError(op ++ " must take exactly two parameters");

            // TODO(ngates): do we want to trampoline the self argument?
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const other = tramp.Trampoline(typeInfo.params[1].type.?).unwrap(.{ .py = pyother }) catch return null;

            const result = tramp.coerceError(func(&self.state, other)) catch return null;
            return (py.createOwned(result) catch return null).py;
        }
    };
}

fn UnaryOperator(
    comptime definition: type,
    comptime op: []const u8,
) type {
    return struct {
        fn call(pyself: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const func = @field(definition, op);
            const typeInfo = @typeInfo(@TypeOf(func)).Fn;

            if (typeInfo.params.len != 1) @compileError(op ++ " must take exactly one parameter");

            // TODO(ngates): do we want to trampoline the self argument?
            const self: *PyTypeStruct(definition) = @ptrCast(pyself);

            const result = tramp.coerceError(func(&self.state)) catch return null;
            return (py.createOwned(result) catch return null).py;
        }
    };
}

fn EqualsOperator(
    comptime definition: type,
    comptime op: []const u8,
) type {
    return struct {
        const equals = std.mem.eql(u8, op, "__eq__");
        fn call(pyself: *ffi.PyObject, pyother: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const func = @field(definition, op);
            const typeInfo = @typeInfo(@TypeOf(func)).Fn;

            if (typeInfo.params.len != 2) @compileError(op ++ " must take exactly two parameters");
            const Other = typeInfo.params[1].type.?;

            // If Other arg type is the same as Self, and Other is not a subclass of Self,
            // then we can short-cut and return not-equal.
            if (Other == *const definition) {
                // TODO(ngates): #193
                const selfType = py.self(definition) catch return null;
                defer selfType.decref();

                const isSubclass = py.isinstance(pyother, selfType) catch return null;
                if (!isSubclass) {
                    return if (equals) py.False().obj.py else py.True().obj.py;
                }
            }

            const self: *PyTypeStruct(definition) = @ptrCast(pyself);
            const other = tramp.Trampoline(Other).unwrap(.{ .py = pyother }) catch return null;

            const result = tramp.coerceError(func(&self.state, other)) catch return null;
            return (py.createOwned(result) catch return null).py;
        }
    };
}

fn RichCompare(comptime definition: type) type {
    const BinaryFunc = *const fn (*ffi.PyObject, *ffi.PyObject) callconv(.C) ?*ffi.PyObject;
    const errorMsg =
        \\Class cannot define both __richcompare__ and
        \\ any of __lt__, __le__, __eq__, __ne__, __gt__, __ge__."
    ;
    const richCmpName = "__richcompare__";
    return struct {
        const hasCompare = blk: {
            var result = false;
            if (@hasDecl(definition, richCmpName)) {
                result = true;
            }

            for (funcs.compareFuncs) |fnName| {
                if (@hasDecl(definition, fnName)) {
                    if (result) {
                        @compileError(errorMsg);
                    }
                    break :blk true;
                }
            }
            break :blk result;
        };

        const compare = if (@hasDecl(definition, richCmpName)) richCompare else builtCompare;

        fn richCompare(pyself: *ffi.PyObject, pyother: *ffi.PyObject, op: c_int) callconv(.C) ?*ffi.PyObject {
            const func = definition.__richcompare__;
            const typeInfo = @typeInfo(@TypeOf(func)).Fn;

            if (typeInfo.params.len != 3) @compileError("__richcompare__ must take exactly three parameters: Self, Other, CompareOp");

            const Self = typeInfo.params[0].type.?;
            const Other = typeInfo.params[1].type.?;
            const CompareOpArg = typeInfo.params[2].type.?;
            if (CompareOpArg != py.CompareOp) @compileError("Third parameter of __richcompare__ must be a py.CompareOp");

            const self = py.unchecked(Self, .{ .py = pyself });
            const otherArg = tramp.Trampoline(Other).unwrap(.{ .py = pyother }) catch return null;
            const opEnum: py.CompareOp = @enumFromInt(op);

            const result = tramp.coerceError(func(self, otherArg, opEnum)) catch return null;
            return (py.createOwned(result) catch return null).py;
        }

        fn builtCompare(pyself: *ffi.PyObject, pyother: *ffi.PyObject, op: c_int) callconv(.C) ?*ffi.PyObject {
            const compFunc = compareFuncs[@intCast(op)];
            if (compFunc) |func| {
                return func(pyself, pyother);
            } else if (op == @intFromEnum(py.CompareOp.NE)) {
                // Use the negation of __eq__ if it is implemented and __ne__ is not.
                if (compareFuncs[@intFromEnum(py.CompareOp.EQ)]) |eq_func| {
                    const is_eq = eq_func(pyself, pyother) orelse return null;
                    defer py.decref(is_eq);

                    if (py.not_(is_eq) catch return null) {
                        return py.True().obj.py;
                    } else {
                        return py.False().obj.py;
                    }
                }
            }
            return py.NotImplemented().py;
        }

        const compareFuncs = blk: {
            var funcs_: [6]?BinaryFunc = .{ null, null, null, null, null, null };
            for (&funcs_, funcs.compareFuncs) |*func, funcName| {
                if (@hasDecl(definition, funcName)) {
                    if (std.mem.eql(u8, funcName, "__eq__") or std.mem.eql(u8, funcName, "__ne__")) {
                        func.* = &EqualsOperator(definition, funcName).call;
                    } else {
                        func.* = &BinaryOperator(definition, funcName).call;
                    }
                }
            }
            break :blk funcs_;
        };
    };
}
