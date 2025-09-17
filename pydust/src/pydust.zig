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
const builtins = @import("builtins.zig");
pub const CompareOp = builtins.CompareOp;
pub const NotImplemented = builtins.NotImplemented;
pub const None = builtins.None;
pub const False = builtins.False;
pub const True = builtins.True;
pub const decref = builtins.decref;
pub const incref = builtins.incref;
pub const callable = builtins.callable;
pub const call0 = builtins.call0;
pub const call = builtins.call;
pub const dict = builtins.dict;
pub const gil = builtins.gil;
pub const PyNoGIL = builtins.PyNoGIL;
pub const nogil = builtins.nogil;
pub const is_none = builtins.is_none;
pub const import = builtins.import;
pub const alloc = builtins.alloc;
pub const init = builtins.init;
pub const isinstance = builtins.isinstance;
pub const iter = builtins.iter;
pub const len = builtins.len;
pub const moduleState = builtins.moduleState;
pub const next = builtins.next;
pub const not_ = builtins.not_;
pub const refcnt = builtins.refcnt;
pub const str = builtins.str;
pub const repr = builtins.repr;
pub const self = builtins.self;
pub const super = builtins.super;
pub const tuple = builtins.tuple;
pub const type_ = builtins.type_;
pub const eq = builtins.eq;
pub const ne = builtins.ne;
pub const lt = builtins.lt;
pub const le = builtins.le;
pub const gt = builtins.gt;
pub const ge = builtins.ge;
const conversions = @import("conversions.zig");
pub const object = conversions.object;
pub const createOwned = conversions.createOwned;
pub const create = conversions.create;
pub const as = conversions.as;
pub const unchecked = conversions.unchecked;
pub const PyBool = types.PyBool;
pub const PyBuffer = types.PyBuffer;
pub const PyBytes = types.PyBytes;
pub const PyCode = types.PyCode;
pub const PyDict = types.PyDict;
pub const PyFloat = types.PyFloat;
pub const PyFrame = types.PyFrame;
pub const PyGIL = types.PyGIL;
pub const PyIter = types.PyIter;
pub const PyList = types.PyList;
pub const PyLong = types.PyLong;
pub const PyMemoryView = types.PyMemoryView;
pub const PyModule = types.PyModule;
pub const PyObject = types.PyObject;
pub const PySlice = types.PySlice;
pub const PyString = types.PyString;
pub const PyTuple = types.PyTuple;
pub const PyType = types.PyType;
const err = @import("types/error.zig");
pub const ArithmeticError = err.ArithmeticError;
pub const AssertionError = err.AssertionError;
pub const AttributeError = err.AttributeError;
pub const BaseException = err.BaseException;
pub const BaseExceptionGroup = err.BaseExceptionGroup;
pub const BlockingIOError = err.BlockingIOError;
pub const BrokenPipeError = err.BrokenPipeError;
pub const BufferError = err.BufferError;
pub const BytesWarning = err.BytesWarning;
pub const ChildProcessError = err.ChildProcessError;
pub const ConnectionAbortedError = err.ConnectionAbortedError;
pub const ConnectionError = err.ConnectionError;
pub const ConnectionRefusedError = err.ConnectionRefusedError;
pub const ConnectionResetError = err.ConnectionResetError;
pub const DeprecationWarning = err.DeprecationWarning;
pub const EOFError = err.EOFError;
pub const EncodingWarning = err.EncodingWarning;
pub const EnvironmentError = err.EnvironmentError;
pub const Exception = err.Exception;
pub const FileExistsError = err.FileExistsError;
pub const FileNotFoundError = err.FileNotFoundError;
pub const FloatingPointError = err.FloatingPointError;
pub const FutureWarning = err.FutureWarning;
pub const GeneratorExit = err.GeneratorExit;
pub const IOError = err.IOError;
pub const ImportError = err.ImportError;
pub const ImportWarning = err.ImportWarning;
pub const IndentationError = err.IndentationError;
pub const IndexError = err.IndexError;
pub const InterruptedError = err.InterruptedError;
pub const IsADirectoryError = err.IsADirectoryError;
pub const KeyError = err.KeyError;
pub const KeyboardInterrupt = err.KeyboardInterrupt;
pub const LookupError = err.LookupError;
pub const MemoryError = err.MemoryError;
pub const ModuleNotFoundError = err.ModuleNotFoundError;
pub const NameError = err.NameError;
pub const NotADirectoryError = err.NotADirectoryError;
pub const NotImplementedError = err.NotImplementedError;
pub const OSError = err.OSError;
pub const OverflowError = err.OverflowError;
pub const PendingDeprecationWarning = err.PendingDeprecationWarning;
pub const PermissionError = err.PermissionError;
pub const ProcessLookupError = err.ProcessLookupError;
pub const RecursionError = err.RecursionError;
pub const ReferenceError = err.ReferenceError;
pub const ResourceWarning = err.ResourceWarning;
pub const RuntimeError = err.RuntimeError;
pub const RuntimeWarning = err.RuntimeWarning;
pub const StopAsyncIteration = err.StopAsyncIteration;
pub const StopIteration = err.StopIteration;
pub const SyntaxError = err.SyntaxError;
pub const SyntaxWarning = err.SyntaxWarning;
pub const SystemError = err.SystemError;
pub const SystemExit = err.SystemExit;
pub const TabError = err.TabError;
pub const TimeoutError = err.TimeoutError;
pub const TypeError = err.TypeError;
pub const UnboundLocalError = err.UnboundLocalError;
pub const UnicodeDecodeError = err.UnicodeDecodeError;
pub const UnicodeEncodeError = err.UnicodeEncodeError;
pub const UnicodeError = err.UnicodeError;
pub const UnicodeTranslateError = err.UnicodeTranslateError;
pub const UnicodeWarning = err.UnicodeWarning;
pub const UserWarning = err.UserWarning;
pub const ValueError = err.ValueError;
pub const Warning = err.Warning;
pub const WindowsError = err.WindowsError;
pub const ZeroDivisionError = err.ZeroDivisionError;
pub const ffi = @import("ffi");
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
        pub fn init() callconv(.c) ?*ffi.PyObject {
            const obj = @call(.always_inline, moddef.init, .{}) catch return null;
            return obj.py;
        }
    };

    const short_name = if (std.mem.lastIndexOfScalar(u8, name, '.')) |idx| name[idx + 1 ..] else name;
    @export(&Closure.init, .{ .name = "PyInit_" ++ short_name, .linkage = .strong });
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
//     for (@typeInfo(definition).@"struct".decls) |decl| {
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
pub fn Args() type {
    return []types.PyObject;
}

/// Zig type representing variadic keyword arguments to a Python function.
pub fn Kwargs() type {
    return std.StringHashMap(types.PyObject);
}

/// Zig type representing `(*args, **kwargs)`
pub fn CallArgs() type {
    return struct { args: Args, kwargs: Kwargs };
}

test {
    // See https://ziggit.dev/t/how-do-i-get-zig-build-to-run-all-the-tests/4434/2
    std.testing.refAllDecls(@This());
}
