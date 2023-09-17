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
const py = @import("pydust.zig");
const ffi = py.ffi;

const PyType = @import("./pytypes.zig").PyType;
const Module = @import("./modules.zig").Module;

const Definition = struct {
    definition: type,
    type: DefinitionType,
};

const DefinitionType = enum { module, class };

const Identifier = struct {
    name: [:0]const u8,
    definition: type,
    parent: type,
};

pub const State = blk: {
    comptime var definitions: [1000]Definition = undefined;
    comptime var definitionsSize: usize = 0;

    comptime var identifiers: [1000]Identifier = undefined;
    comptime var identifiersSize: usize = 0;

    break :blk struct {
        pub fn register(
            comptime definition: type,
            comptime deftype: DefinitionType,
        ) void {
            definitions[definitionsSize] = .{ .definition = definition, .type = deftype };
            definitionsSize += 1;
        }

        pub fn identify(
            comptime definition: type,
            comptime name: [:0]const u8,
            comptime parent: type,
        ) void {
            identifiers[identifiersSize] = .{ .name = name, .definition = definition, .parent = parent };
            identifiersSize += 1;
        }

        pub fn isEmpty() bool {
            return definitionsSize == 0;
        }

        pub fn getDefinitions() []Definition {
            return definitions[0..definitionsSize];
        }

        pub fn getDefinition(comptime definition: type) Definition {
            return findDefinition(definition) orelse @compileError("Unable to find definition " ++ @typeName(definition));
        }

        pub inline fn findDefinition(comptime definition: type) ?Definition {
            if (@typeInfo(definition) != .Struct) {
                return null;
            }
            for (0..definitionsSize) |i| {
                if (definitions[i].definition == definition) {
                    return definitions[i];
                }
            }
            return null;
        }

        pub fn getIdentifier(comptime definition: type) Identifier {
            return findIdentifier(definition) orelse @compileError("Definition not yet identifier " ++ @typeName(definition));
        }

        pub inline fn findIdentifier(comptime definition: type) ?Identifier {
            if (@typeInfo(definition) != .Struct) {
                return null;
            }
            for (0..identifiersSize) |i| {
                if (identifiers[i].definition == definition) {
                    return identifiers[i];
                }
            }
            return null;
        }

        pub fn getContaining(comptime definition: type, comptime deftype: DefinitionType) type {
            return findContaining(definition, deftype) orelse @compileError("Cannot find containing object");
        }

        /// Find the nearest containing definition with the given deftype.
        pub fn findContaining(comptime definition: type, comptime deftype: DefinitionType) ?type {
            const defs = State.getDefinitions();
            var idx = defs.len;
            var foundOriginal = false;
            while (idx > 0) : (idx -= 1) {
                const def = defs[idx - 1];

                if (def.definition == definition) {
                    // Only once we found the original definition, should we check for deftype.
                    foundOriginal = true;
                    continue;
                }

                if (def.type == deftype) {
                    return def.definition;
                }
            }
            return null;
        }
    };
};

/// Register the root Pydust module
pub fn rootmodule(comptime definition: type) void {
    if (!State.isEmpty()) {
        @compileError("Root module can only be registered in a root-level comptime block");
    }

    const pyconf = @import("pyconf");
    const name = pyconf.module_name;

    const moddef = Module(name, definition);
    State.register(definition, .module);
    State.identify(definition, name, definition);

    // For root modules, we export a PyInit__name function per CPython API.
    const Closure = struct {
        pub fn init() callconv(.C) ?*ffi.PyObject {
            const obj = @call(.always_inline, moddef.init, .{}) catch return null;
            return obj.py;
        }
    };

    const short_name = if (std.mem.lastIndexOfScalar(u8, name, '.')) |idx| name[idx + 1 ..] else name;
    @export(Closure.init, .{ .name = "PyInit_" ++ short_name, .linkage = .Strong });
}

/// Register a Pydust module as a submodule to an existing module.
pub fn module(comptime definition: type) @TypeOf(definition) {
    State.register(definition, .module);
    //evaluateDeclarations(definition);
    return definition;
}

/// Register a struct as a Python class definition.
pub fn class(comptime definition: type) @TypeOf(definition) {
    State.register(definition, .class);
    //evaluateDeclarations(definition);
    return definition;
}

/// Force the eager evaluation of the public declarations of the module
/// From here, we can also update the definition names.
fn evaluateDeclarations(comptime definition: type) void {
    for (@typeInfo(definition).Struct.decls) |decl| {
        _ = @field(definition, decl.name);
        // if (@typeInfo(@TypeOf(def)) == .Type) {
        //     State.setName(def, decl.name ++ "");
        // }
    }
}
