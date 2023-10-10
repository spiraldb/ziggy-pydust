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

pub const State = blk: {
    comptime var privateMethods: [1000]*anyopaque = undefined;
    comptime var privateMethodsSize: usize = 0;

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

        pub fn privateMethod(comptime fnPtr: anytype) void {
            const castPtr: *anyopaque = @constCast(@ptrCast(fnPtr));
            privateMethods[privateMethodsSize] = castPtr;
            privateMethodsSize += 1;
        }

        pub fn identify(
            comptime definition: type,
            comptime name: [:0]const u8,
            comptime parent: type,
        ) void {
            identifiers[identifiersSize] = .{
                .name = name,
                .qualifiedName = if (parent == definition) &.{name} else getIdentifier(parent).qualifiedName ++ .{name},
                .definition = definition,
                .parent = parent,
            };
            identifiersSize += 1;
        }

        pub fn isEmpty() bool {
            return definitionsSize == 0;
        }

        pub fn getDefinitions() []Definition {
            return definitions[0..definitionsSize];
        }

        pub fn countDeclsWithType(comptime definition: type, deftype: DefinitionType) usize {
            var cnt = 0;
            for (@typeInfo(definition).Struct.decls) |decl| {
                const declType = @TypeOf(@field(definition, decl.name));
                if (State.hasType(declType, deftype)) {
                    cnt += 1;
                }
            }
            return cnt;
        }

        pub fn countFieldsWithType(comptime definition: type, deftype: DefinitionType) usize {
            var cnt = 0;
            for (@typeInfo(definition).Struct.fields) |field| {
                if (State.hasType(field.type, deftype)) {
                    cnt += 1;
                }
            }
            return cnt;
        }

        pub fn hasType(comptime definition: type, deftype: DefinitionType) bool {
            if (findDefinition(definition)) |def| {
                return def.type == deftype;
            }
            return false;
        }

        pub fn isPrivate(fnPtr: anytype) bool {
            const castPtr: *anyopaque = @constCast(@ptrCast(fnPtr));
            for (privateMethods[0..privateMethodsSize]) |methPtr| {
                if (castPtr == methPtr) {
                    return true;
                }
            }
            return false;
        }

        pub fn getDefinition(comptime definition: type) Definition {
            return findDefinition(definition) orelse @compileError("Unable to find definition " ++ @typeName(definition));
        }

        pub inline fn findDefinition(comptime definition: anytype) ?Definition {
            if (@typeInfo(@TypeOf(definition)) != .Type) {
                return null;
            }
            if (@typeInfo(definition) != .Struct) {
                return null;
            }
            for (definitions[0..definitionsSize]) |def| {
                if (def.definition == definition) {
                    return def;
                }
            }
            return null;
        }

        pub fn getIdentifier(comptime definition: type) Identifier {
            return findIdentifier(definition) orelse @compileError("Definition not yet identified " ++ @typeName(definition));
        }

        pub inline fn findIdentifier(comptime definition: type) ?Identifier {
            if (@typeInfo(definition) != .Struct) {
                return null;
            }
            for (identifiers[0..identifiersSize]) |idef| {
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
        pub fn findContaining(comptime definition: type, comptime deftype: DefinitionType) ?type {
            const defs = definitions[0..definitionsSize];
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
};
