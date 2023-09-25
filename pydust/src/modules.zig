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

pub const ModuleDef = struct {
    name: [:0]const u8,
    fullname: [:0]const u8,
    definition: type,
};

/// Discover a Pydust module.
pub fn Module(comptime name: [:0]const u8, comptime definition: type) type {
    return struct {
        const slots = Slots(definition);
        const methods = funcs.Methods(definition);

        const doc: ?[:0]const u8 = blk: {
            if (@hasDecl(definition, "__doc__")) {
                break :blk definition.__doc__;
            }
            break :blk null;
        };

        /// A function to initialize the Python module from its definition.
        pub fn init() !py.PyObject {
            var pyModuleDef = try py.allocator.create(ffi.PyModuleDef);
            pyModuleDef.* = ffi.PyModuleDef{
                .m_base = ffi.PyModuleDef_Base{
                    .ob_base = ffi.PyObject{
                        .ob_refcnt = 1,
                        .ob_type = null,
                    },
                    .m_init = null,
                    .m_index = 0,
                    .m_copy = null,
                },
                .m_name = name.ptr,
                .m_doc = if (doc) |d| d.ptr else null,
                .m_size = @sizeOf(definition),
                .m_methods = @constCast(&methods.pydefs),
                .m_slots = @constCast(slots.slots.ptr),
                .m_traverse = null,
                .m_clear = null,
                .m_free = null,
            };
            return .{ .py = ffi.PyModuleDef_Init(pyModuleDef) orelse return PyError.PyRaised };
        }
    };
}

fn Slots(comptime definition: type) type {
    return struct {
        const Self = @This();

        const empty = ffi.PyModuleDef_Slot{ .slot = 0, .value = null };
        const attrs = Attributes(definition);
        const submodules = Submodules(definition);

        pub const slots: [:empty]const ffi.PyModuleDef_Slot = blk: {
            var slots_: [:empty]const ffi.PyModuleDef_Slot = &.{};
            slots_ = slots_ ++ .{ffi.PyModuleDef_Slot{
                .slot = ffi.Py_mod_exec,
                .value = @ptrCast(@constCast(&Self.mod_exec)),
            }};

            // Then we check to see if the user has created a manual exec method.
            // This isn't really a Python dunder method, but it'll do for our API.
            if (@hasDecl(definition, "__exec__")) {
                // TODO(ngates): trampoline this.
                const initFn = @field(definition, "__exec__");

                slots_ = slots_ ++ .{ffi.PyModuleDef_Slot{
                    .slot = ffi.Py_mod_exec,
                    .value = @ptrCast(@constCast(&initFn)),
                }};
            }

            slots_ = slots_ ++ .{empty};

            break :blk slots_;
        };

        fn mod_exec(pymodule: *ffi.PyObject) callconv(.C) c_int {
            tramp.coerceError(mod_exec_internal(.{ .obj = .{ .py = pymodule } })) catch return -1;
            return 0;
        }

        inline fn mod_exec_internal(module: py.PyModule) !void {
            // Initialize the state struct to default values
            const state = try module.getState(definition);
            if (@hasDecl(definition, "__new__")) {
                const newFunc = @field(definition, "__new__");
                state.* = try newFunc();
            } else {
                state.* = definition{};
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

                const name = State.getIdentifier(submodule).name;
                const submodDef = Module(name, submodule);
                const pySubmodDef: *ffi.PyModuleDef = @ptrCast((try submodDef.init()).py);

                // Create a dumb ModuleSpec with a name attribute using types.SimpleNamespace
                const SimpleNamespace = try py.importFrom("types", "SimpleNamespace");

                const pyname = try py.PyString.create(name);
                defer pyname.decref();
                const spec = try SimpleNamespace.call(.{}, .{ .name = pyname });
                defer spec.decref();

                const submod: py.PyObject = .{ .py = ffi.PyModule_FromDefAndSpec(pySubmodDef, spec.py) orelse return PyError.PyRaised };
                try module.addObjectRef(name, submod);
            }
        }
    };
}

fn Submodules(comptime definition: type) type {
    const typeInfo = @typeInfo(definition).Struct;
    return struct {
        const submodules: []const type = blk: {
            var mods: []const type = &.{};
            for (typeInfo.decls) |decl| {
                if (State.findDefinition(@field(definition, decl.name))) |def| {
                    if (def.type == .module) {
                        mods = mods ++ .{def.definition};
                    }
                }
            }
            break :blk mods;
        };
    };
}
