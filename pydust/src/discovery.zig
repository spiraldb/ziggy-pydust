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

/// Every Pydust definition registers itself in the discovery state against its parent.
const Definition = struct {
    type: DefinitionType,
    // Name starts optional, and is updated later when the surrounding object performs discovery.
    name: ?[:0]const u8,
    definition: type,
    parent: type,

    pub fn getName(self: Definition) [:0]const u8 {
        return self.name orelse @compileError("Name not set for " ++ @typeName(self.definition));
    }
};

const DefinitionType = enum { module, class };

const State = blk: {
    comptime var stack: [50]Definition = undefined;
    comptime var stackSize = 0;

    comptime var definitions: [1000]Definition = undefined;
    comptime var definitionsSize = 0;

    break :blk struct {
        fn push(
            comptime deftype: DefinitionType,
            comptime definition: type,
            comptime permittedParents: []const DefinitionType,
        ) void {
            _ = permittedParents;
            const parent = if (stackSize == 0) definition else stack[stackSize].definition;

            // Ensure the definition is within a valid parent type.
            // e.g. cannot define a module inside a class
            // if (parentDefinition) |p| {
            //     var matched: bool = false;
            //     for (permittedParents) |pt| {
            //         if (p.type == pt) {
            //             matched = true;
            //             break;
            //         }
            //     }
            //     if (!matched) {
            //         @compileError("Cannot define a " ++ @tagName(deftype) ++ " inside a " ++ @tagName(p.type));
            //     }
            // }

            const def = .{
                .type = deftype,
                .name = null,
                .definition = definition,
                .parent = parent,
            };

            stack[stackSize] = def;
            stackSize += 1;

            definitions[definitionsSize] = def;
            definitionsSize += 1;
        }

        fn pop() void {
            stackSize -= 1;
        }

        fn peek() ?Definition {
            if (stackSize == 0) {
                return null;
            }
            return stack[stackSize - 1];
        }

        fn isempty() bool {
            return stackSize == 0;
        }

        fn setName(comptime definition: type, comptime name: [:0]const u8) void {
            for (0..definitionsSize) |i| {
                if (definitions[i].definition == definition) {
                    definitions[i].name = name;
                }
            }
        }

        fn getDefinitions() []Definition {
            return definitions[0..definitionsSize];
        }
    };
};

/// Register the root Pydust module
pub fn rootmodule(comptime definition: type) void {
    comptime {
        if (!State.isempty()) {
            @compileError("Root module can only be registered in a root-level comptime block");
        }

        const pyconf = @import("pyconf");
        const name = pyconf.module_name;

        State.push(.module, definition, &.{.module});
        State.setName(definition, name);
        State.pop();

        const moddef = Module(name, definition);

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
}

/// Register a Pydust module as a submodule to an existing module.
pub fn module(comptime definition: type) @TypeOf(definition) {
    State.push(.module, definition, &.{.module});
    defer State.pop();
    evaluateDeclarations(definition);
    return definition;
}

/// Register a struct as a Python class definition.
pub fn class(comptime definition: type) @TypeOf(definition) {
    State.push(.class, definition, &.{ .module, .class });
    defer State.pop();
    evaluateDeclarations(definition);
    return definition;
}

pub fn getDefinitions() []const Definition {
    return State.getDefinitions();
}

pub fn getDefinition(comptime definition: type) Definition {
    return findDefinition(definition) orelse @compileError("Unable to find definition " ++ @typeName(definition));
}

pub fn findDefinition(comptime definition: type) ?Definition {
    for (State.getDefinitions()) |def| {
        if (def.definition == definition) {
            return def;
        }
    }
    return null;
}

pub fn getContaining(comptime definition: type, comptime deftype: DefinitionType) Definition {
    return findContaining(definition, deftype) orelse @compileError("Cannot find containing object");
}

/// Find the nearest containing definition with the given deftype.
pub fn findContaining(comptime definition: type, comptime deftype: DefinitionType) ?Definition {
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
            return def;
        }
    }
    return null;
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
