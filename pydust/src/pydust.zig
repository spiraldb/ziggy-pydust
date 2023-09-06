const std = @import("std");
const builtins = @import("builtins.zig");
const mem = @import("mem.zig");
const modules = @import("modules.zig");
const types = @import("types.zig");
const pytypes = @import("pytypes.zig");
const funcs = @import("functions.zig");
const tramp = @import("trampoline.zig");
const PyError = @import("errors.zig").PyError;

// Export some useful things for users
pub usingnamespace builtins;
pub usingnamespace types;
pub const ffi = @import("ffi.zig");
pub const allocator: std.mem.Allocator = mem.PyMemAllocator.allocator();

pub usingnamespace tramp;

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

/// Initialize Python interpreter state
pub fn initialize() void {
    ffi.Py_Initialize();
}

/// Tear down Python interpreter state
pub fn finalize() void {
    ffi.Py_Finalize();
}

/// Register a struct as a Python module definition.
pub fn module(comptime definition: type) void {
    const pyconf = @import("pyconf");
    const name = pyconf.module_name;

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

    const wrapped = modules.define(moddef);
    @export(wrapped.init, .{ .name = "PyInit_" ++ moddef.name, .linkage = .Strong });
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

    // TODO(ngates): we could avoid going through Python for this if we can get hold of
    // a static PyType definition? That would make the behaviour quite different from heap-allocated
    // PyTypes though, so possibly not worth it.

    const callArgs = try tramp.Trampoline(NewArgs(Cls)).wrapCallArgs(args);
    defer callArgs.decref();

    return pytype.call(*Cls, callArgs.args, callArgs.kwargs);
}

/// Find the type of the positional args for a class
inline fn NewArgs(comptime Cls: type) type {
    if (!@hasDecl(Cls, "__new__")) {
        return struct {};
    }

    const func = @field(Cls, "__new__");
    const typeInfo = @typeInfo(@TypeOf(func));
    const sig = funcs.parseSignature("__new__", typeInfo.Fn, &.{});
    return sig.argsParam orelse struct {};
}

/// Convert an instance of a Pydust class struct into PyObject instance
pub fn object(selfInstance: anytype) !types.PyObject {
    const selfState = @fieldParentPtr(pytypes.State(@typeInfo(@TypeOf(selfInstance)).Pointer.child), "state", selfInstance);
    return .{ .py = &selfState.obj };
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
