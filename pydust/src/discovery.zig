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

const Module = @import("./modules.zig").Module;

/// Every Pydust definition registers itself in the discovery state against its parent.
const Definition = struct {
    type: DefinitionType,
    // Name starts optional, and is updated later when the surrounding object performs discovery.
    name: ?[:0]const u8,
    definition: type,
    parent: type,
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
            comptime parentTypes: []const DefinitionType,
        ) void {
            const parentDefinition: ?Definition = if (stackSize == 0) null else stack[stackSize - 1];

            _ = parentTypes;
            // Ensure the definition is within a valid parent type.
            // e.g. cannot define a module inside a class
            // if (parentDefinition) |p| {
            //     var matched: bool = false;
            //     for (parentTypes) |pt| {
            //         if (p.type == pt) {
            //             matched = true;
            //             break;
            //         }
            //     }
            //     if (!matched) {
            //         @compileError("Cannot define a " ++ @tagName(deftype) ++ " inside a " ++ @tagName(p.type));
            //     }
            // }

            const def: Definition = .{
                .type = deftype,
                .name = null,
                .definition = definition,
                // Use @This() as a placeholder for the root parent. Means we don't have to check optional everywhere.
                .parent = if (parentDefinition) |p| p.definition else @This(),
            };

            definitions[definitionsSize] = def;
            definitionsSize += 1;

            stack[stackSize] = def;
            stackSize += 1;
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
    if (!State.isempty()) {
        @compileError("Root module can only be registered in a root-level comptime block");
    }

    const pyconf = @import("pyconf");
    const name = pyconf.module_name;

    State.push(.module, definition, &.{});
    State.setName(definition, name);
    defer State.pop();

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

pub fn setName(comptime definition: type, comptime name: [:0]const u8) void {
    State.setName(definition, name);
}

pub fn getDefinitions() []const Definition {
    return State.getDefinitions();
}

pub fn getDefinition(comptime definition: type) ?Definition {
    for (State.getDefinitions()) |def| {
        if (def.definition == definition) {
            return def;
        }
    }
    return null;
}

/// Find the nearest containing definition with the given deftype.
pub fn findContaining(comptime definition: type, comptime deftype: DefinitionType) ?Definition {
    const defs = State.getDefinitions();
    var idx = defs.len;
    var foundOriginal = false;
    while (idx > 0) : (idx -= 1) {
        const def = defs[idx - 1];

        @compileLog("Checking", def, definition);

        if (def.definition == definition) {
            // Only once we found the original definition, should we check for deftype.
            foundOriginal = true;
            @compileLog("Found");
            continue;
        }

        if (def.type == deftype) {
            @compileLog("Found parent", def);
            return def;
        }
    }
    return null;
}

/// Force the eager evaluation of the public declarations of the module
/// From here, we can also update the definition names.
fn evaluateDeclarations(comptime definition: type) void {
    for (@typeInfo(definition).Struct.decls) |decl| {
        const def = @field(definition, decl.name);
        if (@typeInfo(@TypeOf(def)) == .Type) {
            setName(def, decl.name ++ "");
        }
    }
}
