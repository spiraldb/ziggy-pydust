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

/// Captures the type of the Pydust object.
pub const Definition = struct {
    definition: type,
    type: DefinitionType,
};

const DefinitionType = enum { module, class, attribute, property };

/// Captures the name of and relationships between Pydust objects.
const Identifier = struct {
    name: [:0]const u8,
    qualifiedName: []const [:0]const u8,
    definition: type,
    parent: type,
};

pub const State = struct {
    privateMethods: [1000]*anyopaque = undefined,
    privateMethodsSize: usize = 0,

    definitions: [1000]Definition = undefined,
    definitionsSize: usize = 0,

    identifiers: [1000]Identifier = undefined,
    identifiersSize: usize = 0,

    pub fn register(
        comptime state: *State,
        comptime definition: Definition,
    ) void {
        state.definitions[state.definitionsSize] = definition;
        state.definitionsSize += 1;
    }

    pub fn privateMethod(
        comptime state: *State,
        comptime fnPtr: *const anyopaque,
    ) void {
        state.privateMethods[state.privateMethodsSize] = fnPtr;
        state.privateMethodsSize += 1;
    }

    pub fn identify(
        comptime state: *State,
        comptime definition: type,
        comptime name: [:0]const u8,
        comptime parent: type,
    ) void {
        state.identifiers[state.identifiersSize] = .{
            .name = name,
            .qualifiedName = if (parent == definition) &.{name} else getIdentifier(parent).qualifiedName ++ .{name},
            .definition = definition,
            .parent = parent,
        };
        state.identifiersSize += 1;
    }

    pub fn isEmpty(comptime state: State) bool {
        return state.definitionsSize == 0;
    }

    pub fn getDefinitions(comptime state: State) []Definition {
        return state.definitions[0..state.definitionsSize];
    }

    pub fn countDeclsWithType(
        comptime state: State,
        comptime definition: type,
        deftype: DefinitionType,
    ) usize {
        var cnt = 0;
        for (@typeInfo(definition).Struct.decls) |decl| {
            const declType = @TypeOf(@field(definition, decl.name));
            if (state.hasType(declType, deftype)) {
                cnt += 1;
            }
        }
        return cnt;
    }

    pub fn countFieldsWithType(
        comptime state: State,
        comptime definition: type,
        deftype: DefinitionType,
    ) usize {
        var cnt = 0;
        for (@typeInfo(definition).Struct.fields) |field| {
            if (state.hasType(field.type, deftype)) {
                cnt += 1;
            }
        }
        return cnt;
    }

    pub fn hasType(
        comptime state: State,
        comptime definition: type,
        deftype: DefinitionType,
    ) bool {
        if (state.findDefinition(definition)) |def| {
            return def.type == deftype;
        }
        return false;
    }

    pub fn isPrivate(comptime state: State, fnPtr: anytype) bool {
        const castPtr: *anyopaque = @constCast(@ptrCast(fnPtr));
        for (state.privateMethods[0..state.privateMethodsSize]) |methPtr| {
            if (castPtr == methPtr) {
                return true;
            }
        }
        return false;
    }

    pub fn getDefinition(
        comptime state: State,
        comptime definition: type,
    ) Definition {
        return state.findDefinition(definition) orelse @compileError("Unable to find definition " ++ @typeName(definition));
    }

    pub inline fn findDefinition(
        comptime state: State,
        comptime definition: anytype,
    ) ?Definition {
        if (@typeInfo(@TypeOf(definition)) != .Type) {
            return null;
        }
        if (@typeInfo(definition) != .Struct) {
            return null;
        }
        for (state.definitions[0..state.definitionsSize]) |def| {
            if (def.definition == definition) {
                return def;
            }
        }
        return null;
    }

    pub fn getIdentifier(
        comptime state: State,
        comptime definition: type,
    ) Identifier {
        return state.findIdentifier(definition) orelse @compileError("Definition not yet identified " ++ @typeName(definition));
    }

    pub inline fn findIdentifier(
        comptime state: State,
        comptime definition: type,
    ) ?Identifier {
        if (@typeInfo(definition) != .Struct) {
            return null;
        }
        for (state.identifiers[0..state.identifiersSize]) |idef| {
            if (idef.definition == definition) {
                return idef;
            }
        }
        return null;
    }

    pub fn getContaining(
        comptime state: State,
        comptime definition: type,
        comptime deftype: DefinitionType,
    ) type {
        return state.findContaining(definition, deftype) orelse @compileError("Cannot find containing object");
    }

    /// Find the nearest containing definition with the given deftype.
    pub fn findContaining(
        comptime state: State,
        comptime definition: type,
        comptime deftype: DefinitionType,
    ) ?type {
        const defs = state.definitions[0..state.definitionsSize];
        var idx = defs.len;
        var foundOriginal = false;
        while (idx > 0) : (idx -= 1) {
            const def = defs[idx - 1];

            if (def.definition == definition) {
                // Only once we found the original definition, should we check for deftype.
                foundOriginal = true;
                continue;
            }

            if (foundOriginal and def.type == deftype) {
                return def.definition;
            }
        }
        return null;
    }
};
