const std = @import("std");
const mem = @import("mem.zig");
const modules = @import("modules.zig");
const types = @import("types.zig");
const pytypes = @import("pytypes.zig");
const funcs = @import("functions.zig");
const tramp = @import("trampoline.zig");
const PyError = @import("errors.zig").PyError;

// Export some useful things for users
pub usingnamespace types;
pub const ffi = @import("ffi.zig");
pub const allocator: std.mem.Allocator = mem.PyMemAllocator.allocator();

const Self = @This();

pub const ModuleDef = struct {
    name: [:0]const u8,
    fullname: [:0]const u8,
    definition: type,
};

pub const ClassDef = struct {
    name: [:0]const u8,
    definition: type,
    bases: []const type,
};

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

pub fn initialize() void {
    ffi.Py_Initialize();
}

pub fn finalize() void {
    ffi.Py_Finalize();
}

/// Register a struct as a Python module definition.
pub fn module(comptime name: [:0]const u8, comptime definition: type) @TypeOf(definition) {
    var shortname = name;
    if (std.mem.lastIndexOf(u8, name, ".")) |idx| {
        shortname = name[idx + 1 ..];
    }

    const moddef: ModuleDef = .{
        .name = shortname,
        .fullname = name,
        .definition = definition,
    };
    State.addModule(moddef);
    evaluateDeclarations(definition);
    return definition;
}

/// Register a struct as a Python class definition.
pub fn class(comptime name: [:0]const u8, comptime definition: type) @TypeOf(definition) {
    const classdef: ClassDef = .{
        .name = name,
        .definition = definition,
        .bases = &.{},
    };
    State.addClass(classdef);
    evaluateDeclarations(definition);
    return definition;
}

pub fn subclass(comptime name: [:0]const u8, comptime bases: []const type, comptime definition: type) @TypeOf(definition) {
    const classdef: ClassDef = .{
        .name = name,
        .definition = definition,
        .bases = bases,
    };
    State.addClass(classdef);
    evaluateDeclarations(definition);
    return definition;
}

/// Instantiate class register view class/subclass
pub fn init(comptime Cls: type, args: ?InitArgs(Cls)) !types.PyObject {
    const moduleName = findContainingModule(Cls);
    const imported = try types.PyModule.import(moduleName);
    const pytype = try imported.obj.getAttr(getClassName(Cls));
    if (args) |arg| {
        if (@hasDecl(Cls, "__init__")) {
            const pyTup = try tramp.buildArgTuple(InitArgs(Cls), arg);
            return try pytype.callObj(pyTup.obj);
        } else {
            var pyObj = try pytype.call0();
            var zigObj: *pytypes.State(Cls) = @ptrCast(pyObj.py);
            zigObj.state = arg;
            return pyObj;
        }
    } else {
        return try pytype.call0();
    }
}

fn InitArgs(comptime Cls: type) type {
    if (!@hasDecl(Cls, "__init__")) {
        return Cls;
    }

    const func = @field(Cls, "__init__");
    const typeInfo = @typeInfo(@TypeOf(func));
    const sig = funcs.parseSignature("__init__", typeInfo.Fn, &.{ types.PyObject, *Cls, *const Cls });
    return @typeInfo(sig.argsParam.?.type.?).Pointer.child;
}

/// Find the name of the module that contains the given definition.
pub fn getClassName(comptime definition: type) [:0]const u8 {
    inline for (State.classes()) |classDef| {
        if (classDef.definition == definition) {
            return classDef.name;
        }
    }
    @compileError("Unknown class definition");
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

/// Export PyInit_<modname> C functions into the output object file.
pub fn exportInitFunctions() void {
    inline for (State.modules()) |moddef| {
        const wrapped = modules.define(moddef);
        @export(wrapped.init, .{ .name = "PyInit_" ++ moddef.name, .linkage = .Strong });
    }
}
