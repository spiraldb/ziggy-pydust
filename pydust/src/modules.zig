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

const std = @import("std");
const State = @import("discovery.zig").State;
const ffi = @import("ffi.zig");
const py = @import("pydust.zig");
const PyError = py.PyError;
const Attributes = @import("attributes.zig").Attributes;
const pytypes = @import("pytypes.zig");
const funcs = @import("functions.zig");
const tramp = @import("trampoline.zig");
const PyMemAllocator = @import("mem.zig").PyMemAllocator;
const CPyObject = @import("types/obj.zig").CPyObject;

pub const ModuleDef = struct {
    name: [:0]const u8,
    fullname: [:0]const u8,
    definition: type,
};

/// Discover a Pydust module.
pub fn Module(comptime root: type, comptime name: [:0]const u8, comptime definition: type) type {
    return struct {
        const slots = Slots(root, definition);
        const methods = funcs.Methods(root, definition);

        const doc: ?[:0]const u8 = blk: {
            if (@hasDecl(definition, "__doc__")) {
                break :blk definition.__doc__;
            }
            break :blk null;
        };

        const Fns = struct {
            pub fn free(module: ?*anyopaque) callconv(.C) void {
                const mod: py.PyModule(root) = .{ .obj = .{ .py = @alignCast(@ptrCast(module)) } };
                const state = mod.getState(definition) catch return;
                state.__del__();
            }
        };

        /// A function to initialize the Python module from its definition.
        pub fn init() !py.PyObject(root) {
            const pyModuleDef = try py.allocator.create(ffi.PyModuleDef);
            pyModuleDef.* = ffi.PyModuleDef{
                .m_base = std.mem.zeroes(ffi.PyModuleDef_Base),
                .m_name = name.ptr,
                .m_doc = if (doc) |d| d.ptr else null,
                .m_size = @sizeOf(definition),
                .m_methods = @constCast(&methods.pydefs),
                .m_slots = @constCast(slots.slots.ptr),
                .m_traverse = null,
                .m_clear = null,
                .m_free = if (@hasDecl(definition, "__del__")) &Fns.free else null,
            };

            // Set reference count to 1 so that it is not freed.
            const local_obj: *CPyObject = @ptrCast(&pyModuleDef.m_base.ob_base);
            local_obj.ob_refcnt = 1;

            return .{ .py = ffi.PyModuleDef_Init(pyModuleDef) orelse return PyError.PyRaised };
        }
    };
}

fn Slots(comptime root: type, comptime definition: type) type {
    return struct {
        const Self = @This();

        const empty = ffi.PyModuleDef_Slot{ .slot = 0, .value = null };
        const attrs = Attributes(root, definition);
        const submodules = Submodules(root, definition);

        pub const slots: []const ffi.PyModuleDef_Slot = blk: {
            var slots_: []const ffi.PyModuleDef_Slot = &.{};

            slots_ = slots_ ++ .{ffi.PyModuleDef_Slot{
                .slot = ffi.Py_mod_exec,
                .value = @ptrCast(@constCast(&Self.mod_exec)),
            }};

            // Allow the user to add extra module initialization logic
            if (@hasDecl(definition, "__exec__")) {
                slots_ = slots_ ++ .{ffi.PyModuleDef_Slot{
                    .slot = ffi.Py_mod_exec,
                    .value = @ptrCast(@constCast(&custom_mod_exec)),
                }};
            }

            slots_ = slots_ ++ .{empty};

            break :blk slots_;
        };

        fn custom_mod_exec(pymodule: *ffi.PyObject) callconv(.C) c_int {
            const mod: py.PyModule = .{ .obj = .{ .py = pymodule } };
            tramp.coerceError(root, definition.__exec__(mod)) catch return -1;
            return 0;
        }

        fn mod_exec(pymodule: *ffi.PyObject) callconv(.C) c_int {
            tramp.coerceError(root, mod_exec_internal(.{ .obj = .{ .py = pymodule } })) catch return -1;
            return 0;
        }

        inline fn mod_exec_internal(module: py.PyModule(root)) !void {
            // First, initialize the module state using an __init__ function
            if (@typeInfo(definition).@"struct".fields.len > 0) {
                if (!@hasDecl(definition, "__init__")) {
                    @compileError("Non-empty module must define `fn __init__(*Self) !void` method to initialize its state: " ++ @typeName(definition));
                }
                const state = try module.getState(definition);
                if (@typeInfo(@typeInfo(@TypeOf(definition.__init__)).@"fn".return_type.?) == .error_union) {
                    try state.__init__();
                } else {
                    state.__init__();
                }
            }

            // Add attributes (including class definitions) to the module
            inline for (attrs.attributes) |attr| {
                const obj = try attr.ctor(module);
                try module.addObjectRef(attr.name, obj);
            }

            // Add submodules to the module
            inline for (submodules.submodules) |submodule| {
                // We use PEP489 multi-phase initialization. For this, we create a ModuleSpec
                // which is a dumb object containing only a name.
                // See https://github.com/python/cpython/blob/042f31da552c19054acd3ef7bb6cfd857bce172b/Python/import.c#L2527-L2539

                const name = State.getIdentifier(root, submodule).name;
                const submodDef = Module(root, name, submodule);
                const pySubmodDef: *ffi.PyModuleDef = @ptrCast((try submodDef.init()).py);

                // Create a dumb ModuleSpec with a name attribute using types.SimpleNamespace
                const types = try py.import(root, "types");
                defer types.decref();
                const pyname = try py.PyString(root).create(name);
                defer pyname.decref();
                const spec = try types.call(py.PyObject(root), "SimpleNamespace", .{}, .{ .name = pyname });
                defer spec.decref();

                const submod: py.PyObject(root) = .{ .py = ffi.PyModule_FromDefAndSpec(pySubmodDef, spec.py) orelse return PyError.PyRaised };

                if (ffi.PyModule_ExecDef(submod.py, pySubmodDef) < 0) {
                    return PyError.PyRaised;
                }

                try module.addObjectRef(name, submod);
            }
        }
    };
}

fn Submodules(comptime root: type, comptime definition: type) type {
    const typeInfo = @typeInfo(definition).@"struct";
    return struct {
        const submodules: []const type = blk: {
            var mods: []const type = &.{};
            for (typeInfo.decls) |decl| {
                if (State.findDefinition(root, @field(definition, decl.name))) |def| {
                    if (def.type == .module) {
                        mods = mods ++ .{def.definition};
                    }
                }
            }
            break :blk mods;
        };
    };
}
