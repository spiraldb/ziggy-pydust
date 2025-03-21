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
const State = discovery.State;
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
pub fn rootmodule(comptime definition: type) State {
    comptime var state = State{};

    if (!state.isEmpty()) {
        @compileError("Root module can only be registered in a root-level comptime block");
    }

    const pyconf = @import("pyconf");
    const name = pyconf.module_name;

    state.register(module(definition));
    state.identify(definition, name, definition);
    eagerEval(&state, definition);

    const moddef = Module(state, name, definition);

    // For root modules, we export a PyInit__name function per CPython API.
    const Closure = struct {
        pub fn init() callconv(.C) ?*ffi.PyObject {
            const obj = @call(.always_inline, moddef.init, .{}) catch return null;
            return obj.py;
        }
    };

    const short_name = if (std.mem.lastIndexOfScalar(u8, name, '.')) |idx| name[idx + 1 ..] else name;
    @export(Closure.init, .{ .name = "PyInit_" ++ short_name, .linkage = .strong });
    return state;
}

/// Register a Pydust module as a submodule to an existing module.
pub fn module(comptime definition: type) Definition {
    return .{ .definition = definition, .type = .module };
}

/// Register a struct as a Python class definition.
pub fn class(comptime definition: type) Definition {
    return .{ .definition = definition, .type = .class };
}

pub fn zig(comptime definition: type) [std.meta.declarations(definition).len]*const anyopaque {
    const decls = std.meta.declarations(definition);
    var methods: [decls.len]*const anyopaque = undefined;
    for (decls, 0..) |decl, i|
        methods[i] = @constCast(@ptrCast(&@field(definition, decl.name)));
    return methods;
}

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
pub const Args = []types.PyObject;

/// Zig type representing variadic keyword arguments to a Python function.
pub const Kwargs = std.StringHashMap(types.PyObject);

/// Zig type representing `(*args, **kwargs)`
pub const CallArgs = struct { args: Args, kwargs: Kwargs };

/// Force the evaluation of Pydust registration methods.
/// Using this enables us to breadth-first traverse the object graph, ensuring
/// objects are registered before they're referenced elsewhere.
fn eagerEval(comptime state: *State, comptime definition: type) void {
    for (std.meta.fields(definition)) |f| {
        _ = f.type;
    }
    for (std.meta.declarations(definition)) |d| {
        const value = @field(definition, d.name);
        @setEvalBranchQuota(10000);
        switch (@TypeOf(value)) {
            Definition => |def| {
                // If it's a Pydust definition, then we identify it.
                state.register(def);
                state.identify(value, d.name ++ "", def.definition);
                eagerEval(state, def.definition);
            },
            *const anyopaque => |ptr| {
                // If it's a function pointer, then we register it.
                state.privateMethod(ptr);
                state.identify(value, d.name ++ "", ptr);
            },
            else => {},
        }
    }
}
