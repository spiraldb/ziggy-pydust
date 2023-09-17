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
const State = @import("discovery.zig").State;
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

/// Initialize Python interpreter state
pub fn initialize() void {
    ffi.Py_Initialize();
}

/// Tear down Python interpreter state
pub fn finalize() void {
    ffi.Py_Finalize();
}

/// Instantiate a class defined in Pydust.
pub fn init(comptime Cls: type, args: NewArgs(Cls)) !*Cls {
    const module = State.getContaining(Cls, .module);
    const imported = try types.PyModule.import(State.getIdentifier(module).name);
    const pytype = try imported.obj.get(State.getIdentifier(Cls).name);

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
