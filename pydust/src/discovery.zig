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
const Definition = struct {
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

const _State = struct {
    const Self = @This();

    comptime privateMethods: [1000]*anyopaque = undefined,
    comptime privateMethodsSize: usize = 0,

    comptime definitions: [1000]Definition = undefined,
    comptime definitionsSize: usize = 0,

    comptime identifiers: [1000]Identifier = undefined,
    comptime identifiersSize: usize = 0,

    pub fn register(
        self: *Self,
        comptime definition: type,
        comptime deftype: DefinitionType,
    ) void {
        self.definitions[self.definitionsSize] = .{ .definition = definition, .type = deftype };
        self.definitionsSize += 1;
    }

    pub fn privateMethod(self: *Self, comptime fnPtr: anytype) void {
        const castPtr: *anyopaque = @constCast(@ptrCast(fnPtr));
        self.privateMethods[self.privateMethodsSize] = castPtr;
        self.privateMethodsSize += 1;
    }

    pub fn identify(
        self: *Self,
        comptime definition: type,
        comptime name: [:0]const u8,
        comptime parent: type,
    ) void {
        self.identifiers[self.identifiersSize] = .{
            .name = name,
            .qualifiedName = if (parent == definition) &.{name} else getIdentifier(parent).qualifiedName ++ .{name},
            .definition = definition,
            .parent = parent,
        };
        self.identifiersSize += 1;
    }

    pub fn isEmpty(self: Self) bool {
        return self.definitionsSize == 0;
    }

    pub fn getDefinitions(self: Self) []Definition {
        return self.definitions[0..self.definitionsSize];
    }

    pub fn countDeclsWithType(self: Self, comptime definition: type, deftype: DefinitionType) usize {
        var cnt = 0;
        for (@typeInfo(definition).Struct.decls) |decl| {
            const declType = @TypeOf(@field(definition, decl.name));
            if (self.hasType(declType, deftype)) {
                cnt += 1;
            }
        }
        return cnt;
    }

    pub fn countFieldsWithType(comptime self: Self, comptime definition: type, deftype: DefinitionType) usize {
        var cnt = 0;
        for (@typeInfo(definition).Struct.fields) |field| {
            if (self.hasType(field.type, deftype)) {
                cnt += 1;
            }
        }
        return cnt;
    }

    pub fn hasType(self: Self, comptime definition: type, deftype: DefinitionType) bool {
        if (self.findDefinition(definition)) |def| {
            return def.type == deftype;
        }
        return false;
    }

    pub fn isPrivate(self: Self, fnPtr: anytype) bool {
        const castPtr: *anyopaque = @constCast(@ptrCast(fnPtr));
        for (self.privateMethods[0..self.privateMethodsSize]) |methPtr| {
            if (castPtr == methPtr) {
                return true;
            }
        }
        return false;
    }

    pub fn getDefinition(self: Self, comptime definition: type) Definition {
        return self.findDefinition(definition) orelse @compileError("Unable to find definition " ++ @typeName(definition));
    }

    pub inline fn findDefinition(self: Self, comptime definition: anytype) ?Definition {
        if (@typeInfo(@TypeOf(definition)) != .Type) {
            return null;
        }
        if (@typeInfo(definition) != .Struct) {
            return null;
        }
        for (self.definitions[0..self.definitionsSize]) |def| {
            if (def.definition == definition) {
                return def;
            }
        }
        return null;
    }

    pub fn getIdentifier(comptime definition: type) Identifier {
        return findIdentifier(definition) orelse @compileError("Definition not yet identified " ++ @typeName(definition));
    }

    pub inline fn findIdentifier(self: Self, comptime definition: type) ?Identifier {
        if (@typeInfo(definition) != .Struct) {
            return null;
        }
        for (self.identifiers[0..self.identifiersSize]) |idef| {
            if (idef.definition == definition) {
                return idef;
            }
        }
        return null;
    }

    pub fn getContaining(comptime definition: type, comptime deftype: DefinitionType) type {
        return findContaining(definition, deftype) orelse @compileError("Cannot find containing object");
    }

    /// Find the nearest containing definition with the given deftype.
    pub fn findContaining(self: Self, comptime definition: type, comptime deftype: DefinitionType) ?type {
        const defs = self.definitions[0..self.definitionsSize];
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

pub const State = _State{};
