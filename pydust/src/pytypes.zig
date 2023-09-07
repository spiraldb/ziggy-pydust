// https://docs.python.org/3/extending/newtypes_tutorial.html

const std = @import("std");
const ffi = @import("ffi.zig");
const py = @import("pydust.zig");
const funcs = @import("functions.zig");
const PyError = @import("errors.zig").PyError;
const PyMemAllocator = @import("mem.zig").PyMemAllocator;
const tramp = @import("trampoline.zig");
const Type = std.builtin.Type;

pub fn State(comptime definition: type) type {
    return struct {
        obj: ffi.PyObject,
        state: definition,
    };
}

/// Wrap a user-defined class struct into a unique struct that itself wraps the trampolined functions.
pub fn define(comptime class: py.ClassDef) type {
    return struct {
        const Self = @This();
        pub const name: [:0]const u8 = class.name;

        pub const pyName: [:0]const u8 = blk: {
            const moduleName = py.findContainingModule(class.definition);
            break :blk moduleName[0..moduleName.len] ++ "." ++ name;
        };

        // Declare a struct representing an instance of the object.
        const Instance = State(class.definition);

        const slots = Slots(class.definition, Instance);

        const spec = ffi.PyType_Spec{
            .name = pyName.ptr,
            .basicsize = @sizeOf(Instance),
            .itemsize = 0,
            .flags = ffi.Py_TPFLAGS_DEFAULT | ffi.Py_TPFLAGS_BASETYPE,
            .slots = @constCast(slots.slots.ptr),
        };

        pub fn init(module: py.PyModule) !py.PyType {
            var basesPtr: ?*ffi.PyObject = null;
            if (class.bases.len > 0) {
                const basesTuple = try py.PyTuple.new(class.bases.len);
                inline for (class.bases, 0..) |base, i| {
                    const baseType = try module.obj.get(py.getClassName(base));
                    try basesTuple.setItem(i, baseType);
                }
                basesPtr = basesTuple.obj.py;
            }

            var pytype = ffi.PyType_FromModuleAndSpec(module.obj.py, @constCast(&spec), basesPtr) orelse return PyError.Propagate;
            return .{ .obj = .{ .py = pytype } };
        }
    };
}

fn Slots(comptime definition: type, comptime Instance: type) type {
    const empty = ffi.PyType_Slot{ .slot = 0, .pfunc = null };

    return struct {
        const methods = Methods(definition, Instance);

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
                    .slot = ffi.Py_mp_length,
                    .pfunc = @ptrCast(@constCast(&mp_length)),
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

            slots_ = slots_ ++ .{ffi.PyType_Slot{
                .slot = ffi.Py_tp_methods,
                .pfunc = @ptrCast(@constCast(&methods.pydefs)),
            }};

            slots_ = slots_ ++ .{empty};

            break :blk slots_;
        };

        fn tp_new(subtype: *ffi.PyTypeObject, pyargs: [*c]ffi.PyObject, pykwargs: [*c]ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const pyself: *ffi.PyObject = ffi.PyType_GenericAlloc(subtype, 0) orelse return null;
            // Cast it into a supertype instance. Note: we check at comptime that subclasses of this class
            // include our own state object as the first field in their struct.
            const self: *Instance = @ptrCast(pyself);

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

            const Args = sig.argsParam orelse @compileError("__new__ must take an args struct");
            const args = try tramp.Trampoline(Args).unwrapCallArgs(.{ .args = pyargs, .kwargs = pykwargs });

            return try definition.__new__(args);
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

            const instance: *Instance = @ptrCast(pyself);
            definition.__del__(&instance.state);

            ffi.PyErr_Restore(error_type, error_value, error_tb);
        }

        fn bf_getbuffer(pyself: *ffi.PyObject, view: *ffi.Py_buffer, flags: c_int) callconv(.C) c_int {
            // In case of any error, the view.obj field must be set to NULL.
            view.obj = null;

            const self: *Instance = @ptrCast(pyself);
            definition.__buffer__(&self.state, @ptrCast(view), flags) catch return -1;
            return 0;
        }

        fn bf_releasebuffer(pyself: *ffi.PyObject, view: *ffi.Py_buffer) callconv(.C) void {
            const self: *Instance = @ptrCast(pyself);
            return definition.__release_buffer__(&self.state, @ptrCast(view));
        }

        fn mp_length(pyself: *ffi.PyObject) callconv(.C) isize {
            const lenFunc = definition.__len__;
            const self: *const Instance = @ptrCast(pyself);
            const result = @as(isize, @intCast(lenFunc(&self.state)));
            if (@typeInfo(@typeInfo(@TypeOf(lenFunc)).Fn.return_type.?) == .ErrorUnion) {
                return result catch return -1;
            }
            return result;
        }

        fn tp_iter(pyself: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const iterFunc = definition.__iter__;
            const trampoline = tramp.Trampoline(@typeInfo(@TypeOf(iterFunc)).Fn.return_type.?);
            const self: *const Instance = @ptrCast(pyself);
            const result = iterFunc(&self.state) catch return null;
            const obj = trampoline.wrap(result) catch return null;
            return obj.py;
        }

        fn tp_iternext(pyself: *ffi.PyObject) callconv(.C) ?*ffi.PyObject {
            const iterFunc = definition.__next__;
            const trampoline = tramp.Trampoline(@typeInfo(@TypeOf(iterFunc)).Fn.return_type.?);
            const self: *Instance = @constCast(@ptrCast(pyself));
            const result = iterFunc(&self.state) catch return null;
            const obj = trampoline.wrap(result orelse return null) catch return null;
            return obj.py;
        }
    };
}

fn Methods(comptime definition: type, comptime Instance: type) type {
    _ = Instance;
    const empty = ffi.PyMethodDef{ .ml_name = null, .ml_meth = null, .ml_flags = 0, .ml_doc = null };

    return struct {
        const defs: []const type = blk: {
            var defs_: []const type = &.{};

            for (@typeInfo(definition).Struct.decls) |decl| {
                const value = @field(definition, decl.name);
                const typeInfo = @typeInfo(@TypeOf(value));

                // For now, we skip non-function declarations.
                if (typeInfo != .Fn or funcs.isReserved(decl.name)) {
                    continue;
                }

                // The valid types for a "self" parameter are either the module state struct (definition), or a py.PyModule.
                const sig = funcs.parseSignature(decl.name, typeInfo.Fn, &.{ py.PyObject, *definition, *const definition });
                const def = funcs.wrap(value, sig, 0);
                defs_ = defs_ ++ .{def};
            }

            break :blk defs_;
        };

        pub const pydefs: [defs.len:empty]ffi.PyMethodDef = blk: {
            var pydefs_: [defs.len:empty]ffi.PyMethodDef = undefined;
            for (0..defs.len) |i| {
                pydefs_[i] = defs[i].aspy();
            }
            break :blk pydefs_;
        };
    };
}
