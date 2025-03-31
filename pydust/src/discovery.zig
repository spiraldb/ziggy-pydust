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
    if (Definition == @TypeOf(definition))
        return 1 + countDefinitions(definition.definition);
    comptime var count = 0;
    switch (@typeInfo(definition)) {
        .Struct => |info| {
            for (info.fields) |f| {
                count += countDefinitions(f.type);
            }
            for (info.decls) |d| {
                const field = @field(definition, d.name);
                if (@TypeOf(field) == type)
                    count += countDefinitions(field);
            }
        },
        else => {},
    }
    return count;
}

fn getDefinitions(comptime definition: type) [countDefinitions(definition)]Definition {
    if (Definition == @TypeOf(definition))
        return .{definition} ++ getDefinitions(definition.definition);
    comptime var definitions: [countDefinitions(definition)]Definition = undefined;
    comptime var count = 0;
    switch (@typeInfo(definition)) {
        .Struct => |info| {
            for (info.fields) |f| {
                for (getDefinitions(f.type)) |subDef| {
                    // Append the sub-definition to the list.
                    definitions[count] = subDef;
                    count += 1;
                }
            }
            for (info.decls) |d| {
                const field = @field(definition, d.name);
                if (@TypeOf(field) == type) {
                    for (getDefinitions(@field(definition, d.name))) |subDef| {
                        // Append the sub-definition to the list.
                        definitions[count] = subDef;
                        count += 1;
                    }
                }
            }
        },
        else => {},
    }
    return definitions;
}

fn getIdentifiers(
    comptime definition: type,
    comptime qualifiedName: [:0]const u8,
    comptime parent: type,
) [countDefinitions(definition)]Identifier {
    if (Definition == @TypeOf(definition))
        return .{.{
            .name = qualifiedName[qualifiedName.len - 1],
            .qualifiedName = qualifiedName,
            .definition = definition,
            .parent = parent,
        }} ++ getIdentifiers(definition.definition);
    comptime var identifiers: [countDefinitions(definition)]Definition = undefined;
    comptime var count = 0;
    for (std.meta.fields(definition)) |f| {
        for (getIdentifiers(@field(definition, f.name), qualifiedName ++ .{f.name}, definition)) |identifier| {
            // Append the sub-definition to the list.
            identifiers[count] = identifier;
            count += 1;
        }
    }
    for (std.meta.declarations(definition)) |d| {
        for (getIdentifiers(@field(definition, d.name), qualifiedName ++ .{d.name}, definition)) |identifier| {
            // Append the sub-definition to the list.
            identifiers[count] = identifier;
            count += 1;
        }
    }
    return count;
}

pub const State = struct {
    pub fn countDeclsWithType(
        comptime root: type,
        comptime definition: type,
        deftype: DefinitionType,
    ) usize {
        var cnt = 0;
        for (@typeInfo(definition).Struct.decls) |decl| {
            const declType = @TypeOf(@field(definition, decl.name));
            if (hasType(root, declType, deftype)) {
                cnt += 1;
            }
        }
        return cnt;
    }

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
        if (@typeInfo(@TypeOf(definition)) != .Type) {
            return null;
        }
        if (@typeInfo(definition) != .Struct) {
            return null;
        }
        for ([_]Definition{.{ .definition = root, .type = .module }} ++ getDefinitions(root)) |def| {
            if (def.definition == definition) {
                return def;
            }
        }
        return null;
    }

    pub fn getIdentifier(
        comptime root: type,
        comptime definition: type,
    ) Identifier {
        return findIdentifier(root, definition) orelse @compileError("Definition not yet identified " ++ @typeName(definition));
    }

    pub inline fn findIdentifier(
        comptime root: type,
        comptime definition: type,
    ) ?Identifier {
        if (@typeInfo(definition) != .Struct) {
            return null;
        }
        for (getIdentifiers(root)) |idef| {
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
    pub fn findContaining(
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
