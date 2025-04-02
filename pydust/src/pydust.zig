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
const mem = @import("mem.zig");
const discovery = @import("discovery.zig");
const Definition = discovery.Definition;
const Module = @import("modules.zig").Module;
const types = @import("types.zig");
const pytypes = @import("pytypes.zig");
const funcs = @import("functions.zig");
const tramp = @import("trampoline.zig");

// Export some useful things for users
pub usingnamespace @import("builtins.zig");
pub usingnamespace @import("conversions.zig");
pub usingnamespace types;
pub const ffi = @import("ffi.zig");
pub const PyError = @import("errors.zig").PyError;
pub const allocator: std.mem.Allocator = mem.PyMemAllocator.allocator();

const Self = @This();

/// Initialize Python interpreter state
pub fn initialize() void {
    ffi.Py_Initialize();
}

/// Tear down Python interpreter state
pub fn finalize() void {
    ffi.Py_Finalize();
}

/// Register the root Pydust module
pub fn rootmodule(comptime definition: type) void {
    const name = @import("pyconf").module_name;

    const moddef = Module(definition, name, definition);

    // For root modules, we export a PyInit__name function per CPython API.
    const Closure = struct {
        pub fn init() callconv(.C) ?*ffi.PyObject {
            const obj = @call(.always_inline, moddef.init, .{}) catch return null;
            return obj.py;
        }
    };

    const short_name = if (std.mem.lastIndexOfScalar(u8, name, '.')) |idx| name[idx + 1 ..] else name;
    @export(Closure.init, .{ .name = "PyInit_" ++ short_name, .linkage = .strong });
}

/// Register a Pydust module as a submodule to an existing module.
pub fn module(comptime definition: type) Definition {
    return .{ .definition = definition, .type = .module };
}

/// Register a struct as a Python class definition.
pub fn class(comptime definition: type) Definition {
    return .{ .definition = definition, .type = .class };
}

// pub fn zig(comptime definition: type) @TypeOf(definition) {
//     for (@typeInfo(definition).Struct.decls) |decl| {
//         State.privateMethod(&@field(definition, decl.name));
//     }
//     return definition;
// }

/// Register a struct field as a Python read-only attribute.
pub fn attribute(comptime T: type) Definition {
    return .{ .definition = Attribute(T), .type = .attribute };
}

fn Attribute(comptime T: type) type {
    return struct { value: T };
}

/// Register a property as a field on a Pydust class.
pub fn property(comptime definition: type) Definition {
    return .{ .definition = definition, .type = .property };
}

/// Zig type representing variadic arguments to a Python function.
pub fn Args(comptime root: type) type {
    return []types.PyObject(root);
}

/// Zig type representing variadic keyword arguments to a Python function.
pub fn Kwargs(comptime root: type) type {
    return std.StringHashMap(types.PyObject(root));
}

/// Zig type representing `(*args, **kwargs)`
pub fn CallArgs(comptime root: type) type {
    return struct { args: Args(root), kwargs: Kwargs(root) };
}
