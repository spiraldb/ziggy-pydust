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

        const slots = Slots(name, class.definition, Instance);

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
                    // TODO(ngates): find the correct parent module
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

fn Slots(comptime name: [:0]const u8, comptime definition: type, comptime Instance: type) type {
    const empty = ffi.PyType_Slot{ .slot = 0, .pfunc = null };

    return struct {
        const methods = Methods(definition, Instance);
        const init = Init(name, definition, Instance);

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

            if (@hasDecl(definition, "__init__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_init,
                    .pfunc = @ptrCast(@constCast(&init.init)),
                }};
            }

            if (@hasDecl(definition, "__del__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_tp_finalize,
                    .pfunc = @ptrCast(@constCast(&tp_finalize)),
                }};
            }

            if (@hasDecl(definition, "__len__")) {
                slots_ = slots_ ++ .{ffi.PyType_Slot{
                    .slot = ffi.Py_mp_length,
                    .pfunc = @ptrCast(@constCast(&mp_length)),
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

            slots_ = slots_ ++ .{ffi.PyType_Slot{
                .slot = ffi.Py_tp_methods,
                .pfunc = @ptrCast(@constCast(&methods.pydefs)),
            }};

            slots_ = slots_ ++ .{empty};

            break :blk slots_;
        };

        fn mp_length(pyself: *ffi.PyObject) callconv(.C) isize {
            const lenFunc = @field(definition, "__len__");
            const self: *const Instance = @ptrCast(pyself);
            const result = @as(isize, @intCast(lenFunc(&self.state)));
            if (@typeInfo(@typeInfo(@TypeOf(lenFunc)).Fn.return_type.?) == .ErrorUnion) {
                return result catch return -1;
            }
            return result;
        }

        /// Wrapper for the user's __del__ function.
        /// Note: tp_del is deprecated in favour of tp_finalize.
        ///
        /// See https://docs.python.org/3/c-api/typeobj.html#c.PyTypeObject.tp_finalize.
        fn tp_finalize(pyself: *ffi.PyObject) void {
            // The finalize slot shouldn't alter any exception that is currently set.
            // So it's recommended we save the existing one (if any) and restore it afterwards.
            // TODO(ngates): we may want to move this logic to PyErr if it happens more?
            var error_type: ?*ffi.PyObject = undefined;
            var error_value: ?*ffi.PyObject = undefined;
            var error_tb: ?*ffi.PyObject = undefined;
            ffi.PyErr_Fetch(&error_type, &error_value, &error_tb);

            const instance: *Instance = @ptrCast(pyself);
            definition.__del__(&instance.state);

            ffi.PyErr_Restore(error_type, error_value, error_tb);
        }

        fn bf_getbuffer(self: *ffi.PyObject, view: *ffi.Py_buffer, flags: c_int) callconv(.C) c_int {
            // In case of any error, the view.obj field must be set to NULL.
            view.obj = null;

            const instance: *Instance = @ptrCast(self);
            return tramp.errVoid(definition.__buffer__(&instance.state, @ptrCast(view), flags));
        }

        fn bf_releasebuffer(self: *ffi.PyObject, view: *ffi.Py_buffer) callconv(.C) void {
            const instance: *Instance = @ptrCast(self);
            return definition.__release_buffer__(&instance.state, @ptrCast(view));
        }
    };
}

fn Methods(comptime definition: type, comptime Instance: type) type {
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
                const def = funcs.wrap(value, sig, funcs.getSelfParamFn(definition, Instance, sig), 0);
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

fn Init(comptime name: [:0]const u8, comptime definition: type, comptime Instance: type) type {
    const initName = "__init__";

    return struct {
        const initSig = blk: {
            const func = @field(definition, initName);
            const typeInfo = @typeInfo(@TypeOf(func));
            break :blk funcs.parseSignature(initName, typeInfo.Fn, &.{ py.PyObject, *definition, *const definition });
        };

        const initFn = blk: {
            const func = @field(definition, initName);
            if (initSig.argsParam) |parg| {
                const initFunction = struct {
                    pub inline fn dispatch(self: *definition, args: []*ffi.PyObject) !void {
                        const castArgs: parg.type.? = @ptrCast(args);
                        try func(self, castArgs);
                    }
                };
                break :blk initFunction.dispatch;
            }

            const initFunction = struct {
                pub inline fn invoke(self: *definition) !void {
                    try func(self);
                }
            };
            break :blk initFunction.invoke;
        };

        pub fn init(self: *ffi.PyObject, args: [*c]ffi.PyObject, kwargs: [*c]ffi.PyObject) callconv(.C) c_int {
            if (kwargs != null and ffi.PyDict_Size(kwargs) > 0) {
                py.TypeError.raise(std.fmt.comptimePrint("Kwargs in __init__ functions are not supported for type: {s}", .{name})) catch return -1;
            }

            const instance: *Instance = @ptrCast(self);
            if (initSig.argsParam) |_| {
                const pyArgs: []*ffi.PyObject = unpackTuple(args) orelse return -1;
                defer py.allocator.free(pyArgs);
                return tramp.errVoid(initFn(&instance.state, pyArgs));
            }

            return tramp.errVoid(initFn(&instance.state));
        }

        fn unpackTuple(args: [*c]ffi.PyObject) ?[]*ffi.PyObject {
            if (args == null) {
                return null;
            }

            const tuple: py.PyTuple = .{ .obj = .{ .py = args } };
            const argsSize = tuple.getSize() catch return null;
            const argLen = @typeInfo(@typeInfo(initSig.argsParam.?.type.?).Pointer.child).Struct.fields.len;
            if (argsSize != argLen) {
                const argsNeedsS = if (argLen > 1) "s" else "";
                py.TypeError.raiseComptimeFmt("{s} takes {d} argument" ++ argsNeedsS, .{ name, argLen }) catch return null;
            }

            var pyArgs: []*ffi.PyObject = py.allocator.alloc(*ffi.PyObject, argLen) catch return null;
            for (0..argLen) |i| {
                const item = tuple.getItem(@intCast(i)) catch return null;
                pyArgs[i] = item.py;
            }

            return pyArgs;
        }
    };
}
