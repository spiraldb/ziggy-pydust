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
const builtins = @import("builtins.zig");
const conversions = @import("conversions.zig");
const mem = @import("mem.zig");
const modules = @import("modules.zig");
const ModuleDef = @import("modules.zig").ModuleDef;
const types = @import("types.zig");
const pytypes = @import("pytypes.zig");
const ClassDef = pytypes.ClassDef;
const funcs = @import("functions.zig");
const tramp = @import("trampoline.zig");

// Export some useful things for users
pub usingnamespace builtins;
pub usingnamespace conversions;
pub usingnamespace types;
pub const ffi = @import("ffi.zig");
pub const PyError = @import("errors.zig").PyError;
pub const allocator: std.mem.Allocator = mem.PyMemAllocator.allocator();

// FIXME(ngates): export the registry functions only
pub usingnamespace @import("discovery.zig");

const Self = @This();

const State = blk: {
    comptime var modList: [20]ModuleDef = undefined;
    comptime var modulesOffset: u8 = 0;
    comptime var classList: [100]ClassDef = undefined;
    comptime var classesOffset: u8 = 0;

    break :blk struct {
        pub fn addModule(comptime def: ModuleDef) void {
            modList[modulesOffset] = def;
            modulesOffset += 1;
        }

        pub fn addClass(comptime def: ClassDef) void {
            classList[classesOffset] = def;
            classesOffset += 1;
        }

        pub fn modules() []const ModuleDef {
            return modList[0..modulesOffset];
        }

        pub fn classes() []const ClassDef {
            return classList[0..classesOffset];
        }
    };
};

/// Initialize Python interpreter state
pub fn initialize() void {
    ffi.Py_Initialize();
}

/// Tear down Python interpreter state
pub fn finalize() void {
    ffi.Py_Finalize();
}

pub fn subclass(comptime name: [:0]const u8, comptime bases: []const type, comptime definition: type) @TypeOf(definition) {
    // TODO(ngates): infer bases by looking at struct fields.
    const classdef: ClassDef = .{
        .name = name,
        .definition = definition,
        .bases = bases,
    };
    State.addClass(classdef);
    evaluateDeclarations(definition);
    return definition;
}

/// Instantiate a class defined in Pydust.
pub fn init(comptime Cls: type, args: NewArgs(Cls)) !*Cls {
    const moduleName = findContainingModule(Cls);
    const imported = try types.PyModule.import(moduleName);
    const pytype = try imported.obj.get(getClassName(Cls));

    // Alloc the class
    // NOTE(ngates): we currently don't allow users to override tp_alloc, therefore we can shortcut
    // using ffi.PyType_GetSlot(tp_alloc) since we know it will always return ffi.PyType_GenericAlloc
    const pyobj: *pytypes.State(Cls) = @alignCast(@ptrCast(ffi.PyType_GenericAlloc(@ptrCast(pytype.py), 0) orelse return PyError.Propagate));

    if (@hasDecl(Cls, "__new__")) {
        pyobj.state = try Cls.__new__(args);
    } else if (@typeInfo(Cls).Struct.fields.len > 0) {
        pyobj.state = args;
    }

    return &pyobj.state;
}

pub fn decref(value: anytype) void {
    conversions.object(value).decref();
}

pub fn incref(value: anytype) void {
    conversions.object(value).incref();
}

/// Find the type of the positional args for a class
inline fn NewArgs(comptime Cls: type) type {
    if (!@hasDecl(Cls, "__new__")) {
        // Default construct args are the struct fields themselves.
        return Cls;
    }

    const func = @field(Cls, "__new__");
    const typeInfo = @typeInfo(@TypeOf(func));
    const sig = funcs.parseSignature("__new__", typeInfo.Fn, &.{});
    return sig.argsParam orelse struct {};
}

pub fn getClassName(comptime definition: type) [:0]const u8 {
    return findClassName(definition) orelse @compileError("Unrecognized class definition");
}

/// Find the class name of the given state definition.
pub inline fn findClassName(comptime definition: type) ?[:0]const u8 {
    inline for (State.classes()) |classDef| {
        if (classDef.definition == definition) {
            return classDef.name;
        }
    }
    return null;
}

/// Get the module name of the given state definition.
pub fn getModuleName(comptime definition: type) ?[:0]const u8 {
    return findModuleName(definition) orelse @compileError("Unrecognized module definition");
}

/// Find the module name of the given state definition.
pub inline fn findModuleName(comptime definition: type) ?[:0]const u8 {
    inline for (State.modules()) |modDef| {
        if (modDef.definition == definition) {
            return modDef.name;
        }
    }
    return null;
}

/// Find the name of the module that contains the given definition.
pub fn findContainingModule(comptime definition: type) [:0]const u8 {
    inline for (State.modules()) |mod| {
        inline for (@typeInfo(mod.definition).Struct.decls) |decl| {
            const value = @field(mod.definition, decl.name);
            if (@TypeOf(value) != @TypeOf(definition)) {
                continue;
            }
            if (value == definition) {
                return mod.fullname;
            }
        }
    }
    @compileError("Class has no associated module");
}

/// Find the class definitions belonging to this module.
pub fn findClasses(comptime mod: ModuleDef) []const ClassDef {
    var moduleClasses: []const ClassDef = &.{};
    inline for (State.classes()) |classDef| {
        inline for (@typeInfo(mod.definition).Struct.decls) |decl| {
            const value = @field(mod.definition, decl.name);
            if (@typeInfo(@TypeOf(value)) != .Type) {
                continue;
            }
            if (value == classDef.definition) {
                moduleClasses = moduleClasses ++ .{classDef};
            }
        }
    }
    return moduleClasses;
}

/// Force the eager evaluation of the public declarations of the module
fn evaluateDeclarations(comptime definition: type) void {
    for (@typeInfo(definition).Struct.decls) |decl| {
        _ = @field(definition, decl.name);
    }
}
