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

fn countDefinitions(comptime definition: type) usize {
    @setEvalBranchQuota(10000);
    comptime var count = 0;
    switch (@typeInfo(definition)) {
        .@"struct" => |info| {
            inline for (info.fields) |f| {
                count += countDefinitions(f.type);
            }
            inline for (info.decls) |d| {
                const field = @field(definition, d.name);
                count += switch (@TypeOf(field)) {
                    Definition => 1 + countDefinitions(field.definition),
                    type => countDefinitions(field),
                    else => 0,
                };
            }
        },
        else => {},
    }
    return count;
}

fn getDefinitions(comptime definition: type) [countDefinitions(definition)]Definition {
    comptime var definitions: [countDefinitions(definition)]Definition = undefined;
    comptime var count = 0;
    switch (@typeInfo(definition)) {
        .@"struct" => |info| {
            for (info.fields) |f| {
                for (getDefinitions(f.type)) |subDef| {
                    // Append the sub-definition to the list.
                    definitions[count] = subDef;
                    count += 1;
                }
            }
            for (info.decls) |d| {
                const field = @field(definition, d.name);
                for (switch (@TypeOf(field)) {
                    Definition => .{field} ++ getDefinitions(field.definition),
                    type => getDefinitions(field), // Handle other types
                    else => .{},
                }) |subDef| {
                    // Append the sub-definition to the list.
                    definitions[count] = subDef;
                    count += 1;
                }
            }
        },
        else => {},
    }
    return definitions;
}

fn getIdentifiers(
    comptime definition: type,
    comptime qualifiedName: []const [:0]const u8,
    comptime parent: type,
) [countDefinitions(definition)]Identifier {
    comptime var identifiers: [countDefinitions(definition)]Identifier = undefined;
    comptime var count = 0;
    switch (@typeInfo(definition)) {
        .@"struct" => |info| {
            // Iterate over the fields of the struct
            for (info.fields) |f| {
                for (getIdentifiers(f.type, qualifiedName ++ .{f.name}, definition)) |identifier| {
                    // Append the sub-definition to the list.
                    identifiers[count] = identifier;
                    count += 1;
                }
            }
            for (info.decls) |d| {
                const field = @field(definition, d.name);
                const name = qualifiedName ++ .{d.name};
                // Handle the field based on its type
                for (switch (@TypeOf(field)) {
                    Definition => [_]Identifier{.{
                        .name = d.name,
                        .qualifiedName = name,
                        .definition = field.definition,
                        .parent = parent,
                    }} ++ getIdentifiers(field.definition, name, definition),
                    type => getIdentifiers(field, name, definition),
                    else => .{},
                }) |identifier| {
                    // Append the sub-definition to the list.
                    identifiers[count] = identifier;
                    count += 1;
                }
            }
        },
        else => {},
    }
    return identifiers;
}

pub const State = struct {
    pub fn countFieldsWithType(
        comptime root: type,
        comptime definition: type,
        deftype: DefinitionType,
    ) usize {
        var cnt = 0;
        for (std.meta.fields(definition)) |field| {
            if (hasType(root, field.type, deftype)) {
                cnt += 1;
            }
        }
        return cnt;
    }

    pub fn hasType(
        comptime root: type,
        comptime definition: type,
        deftype: DefinitionType,
    ) bool {
        if (findDefinition(root, definition)) |def| {
            return def.type == deftype;
        }
        return false;
    }

    pub fn getDefinition(
        comptime root: type,
        comptime definition: type,
    ) Definition {
        return findDefinition(root, definition) orelse @compileError("Unable to find definition " ++ @typeName(definition));
    }

    pub inline fn findDefinition(
        comptime root: type,
        comptime definition: anytype,
    ) ?Definition {
        return switch (@TypeOf(definition)) {
            Definition => definition,
            type => switch (@typeInfo(definition)) {
                .@"struct" => blk: {
                    for ([_]Definition{.{ .definition = root, .type = .module }} ++ getDefinitions(root)) |def| {
                        if (def.definition == definition)
                            break :blk def;
                    }
                    break :blk null;
                },
                else => null,
            },
            else => null,
        };
    }

    pub fn getIdentifier(
        comptime root: type,
        comptime definition: type,
    ) Identifier {
        return findIdentifier(root, definition) orelse @compileError("Definition not yet identified " ++ @typeName(definition));
    }

    inline fn findIdentifier(
        comptime root: type,
        comptime definition: type,
    ) ?Identifier {
        const qualifiedName = &.{@import("pyconf").module_name};
        if (@typeInfo(definition) != .@"struct") {
            return null;
        }
        for ([_]Identifier{.{
            .name = qualifiedName[0],
            .qualifiedName = qualifiedName,
            .definition = root,
            .parent = root,
        }} ++ getIdentifiers(root, qualifiedName, root)) |idef| {
            if (idef.definition == definition) {
                return idef;
            }
        }
        return null;
    }

    pub fn getContaining(
        comptime root: type,
        comptime definition: type,
        comptime deftype: DefinitionType,
    ) type {
        return findContaining(root, definition, deftype) orelse @compileError("Cannot find containing object");
    }

    /// Find the nearest containing definition with the given deftype.
    fn findContaining(
        comptime root: type,
        comptime definition: type,
        comptime deftype: DefinitionType,
    ) ?type {
        const defs = [_]Definition{.{ .definition = root, .type = .module }} ++ getDefinitions(root);
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
