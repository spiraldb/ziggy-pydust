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
const ffi = @import("ffi.zig");
const py = @import("pydust.zig");
const pytypes = @import("pytypes.zig");
const funcs = @import("functions.zig");
const PyMemAllocator = @import("mem.zig").PyMemAllocator;

pub fn define(comptime mod: py.ModuleDef) type {
    return struct {
        const definition = mod.definition;

        const doc: ?[:0]const u8 = if (@hasDecl(definition, "__doc__")) @field(definition, "__doc__") else null;

        const slots = Slots(mod);
        const methods = funcs.Methods(mod.definition);

        /// The PyInit_<modname> function to be exported in the output object file.
        pub fn init() callconv(.C) ?*ffi.PyObject {
            var pyModuleDef = py.allocator.create(ffi.PyModuleDef) catch @panic("OOM");
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
                .m_name = mod.name.ptr,
                .m_doc = if (doc) |d| d.ptr else null,
                .m_size = @sizeOf(definition),
                .m_methods = @constCast(&methods.pydefs),
                .m_slots = @constCast(slots.slots.ptr),
                .m_traverse = null,
                .m_clear = null,
                .m_free = null,
            };
            return ffi.PyModuleDef_Init(pyModuleDef);
        }
    };
}

fn Slots(comptime mod: py.ModuleDef) type {
    const empty = ffi.PyModuleDef_Slot{ .slot = 0, .value = null };
    const definition = mod.definition;
    const classDefs = py.findClasses(mod);

    return struct {
        const Self = @This();

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
            mod_exec_internal(.{ .obj = .{ .py = pymodule } }) catch return -1;
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

            // Add class definitions to the module
            inline for (classDefs) |classDef| {
                const classType = pytypes.define(classDef);
                const pytype: py.PyType = try classType.init(module);
                try module.addObjectRef(classType.name, pytype.obj);
            }
        }
    };
}
