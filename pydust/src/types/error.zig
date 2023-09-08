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
const ffi = @import("../ffi.zig");
const py = @import("../pydust.zig");
const PyError = @import("../errors.zig").PyError;

pub const ArithmeticError = PyExc{ .name = "ArithmeticError" };
pub const AssertionError = PyExc{ .name = "AssertionError" };
pub const AttributeError = PyExc{ .name = "AttributeError" };
pub const BaseException = PyExc{ .name = "BaseException" };
pub const BaseExceptionGroup = PyExc{ .name = "BaseExceptionGroup" };
pub const BlockingIOError = PyExc{ .name = "BlockingIOError" };
pub const BrokenPipeError = PyExc{ .name = "BrokenPipeError" };
pub const BufferError = PyExc{ .name = "BufferError" };
pub const BytesWarning = PyExc{ .name = "BytesWarning" };
pub const ChildProcessError = PyExc{ .name = "ChildProcessError" };
pub const ConnectionAbortedError = PyExc{ .name = "ConnectionAbortedError" };
pub const ConnectionError = PyExc{ .name = "ConnectionError" };
pub const ConnectionRefusedError = PyExc{ .name = "ConnectionRefusedError" };
pub const ConnectionResetError = PyExc{ .name = "ConnectionResetError" };
pub const DeprecationWarning = PyExc{ .name = "DeprecationWarning" };
pub const EOFError = PyExc{ .name = "EOFError" };
pub const EncodingWarning = PyExc{ .name = "EncodingWarning" };
pub const EnvironmentError = PyExc{ .name = "EnvironmentError" };
pub const Exception = PyExc{ .name = "Exception" };
pub const FileExistsError = PyExc{ .name = "FileExistsError" };
pub const FileNotFoundError = PyExc{ .name = "FileNotFoundError" };
pub const FloatingPointError = PyExc{ .name = "FloatingPointError" };
pub const FutureWarning = PyExc{ .name = "FutureWarning" };
pub const GeneratorExit = PyExc{ .name = "GeneratorExit" };
pub const IOError = PyExc{ .name = "IOError" };
pub const ImportError = PyExc{ .name = "ImportError" };
pub const ImportWarning = PyExc{ .name = "ImportWarning" };
pub const IndentationError = PyExc{ .name = "IndentationError" };
pub const IndexError = PyExc{ .name = "IndexError" };
pub const InterruptedError = PyExc{ .name = "InterruptedError" };
pub const IsADirectoryError = PyExc{ .name = "IsADirectoryError" };
pub const KeyError = PyExc{ .name = "KeyError" };
pub const KeyboardInterrupt = PyExc{ .name = "KeyboardInterrupt" };
pub const LookupError = PyExc{ .name = "LookupError" };
pub const MemoryError = PyExc{ .name = "MemoryError" };
pub const ModuleNotFoundError = PyExc{ .name = "ModuleNotFoundError" };
pub const NameError = PyExc{ .name = "NameError" };
pub const NotADirectoryError = PyExc{ .name = "NotADirectoryError" };
pub const NotImplementedError = PyExc{ .name = "NotImplementedError" };
pub const OSError = PyExc{ .name = "OSError" };
pub const OverflowError = PyExc{ .name = "OverflowError" };
pub const PendingDeprecationWarning = PyExc{ .name = "PendingDeprecationWarning" };
pub const PermissionError = PyExc{ .name = "PermissionError" };
pub const ProcessLookupError = PyExc{ .name = "ProcessLookupError" };
pub const RecursionError = PyExc{ .name = "RecursionError" };
pub const ReferenceError = PyExc{ .name = "ReferenceError" };
pub const ResourceWarning = PyExc{ .name = "ResourceWarning" };
pub const RuntimeError = PyExc{ .name = "RuntimeError" };
pub const RuntimeWarning = PyExc{ .name = "RuntimeWarning" };
pub const StopAsyncIteration = PyExc{ .name = "StopAsyncIteration" };
pub const StopIteration = PyExc{ .name = "StopIteration" };
pub const SyntaxError = PyExc{ .name = "SyntaxError" };
pub const SyntaxWarning = PyExc{ .name = "SyntaxWarning" };
pub const SystemError = PyExc{ .name = "SystemError" };
pub const SystemExit = PyExc{ .name = "SystemExit" };
pub const TabError = PyExc{ .name = "TabError" };
pub const TimeoutError = PyExc{ .name = "TimeoutError" };
pub const TypeError = PyExc{ .name = "TypeError" };
pub const UnboundLocalError = PyExc{ .name = "UnboundLocalError" };
pub const UnicodeDecodeError = PyExc{ .name = "UnicodeDecodeError" };
pub const UnicodeEncodeError = PyExc{ .name = "UnicodeEncodeError" };
pub const UnicodeError = PyExc{ .name = "UnicodeError" };
pub const UnicodeTranslateError = PyExc{ .name = "UnicodeTranslateError" };
pub const UnicodeWarning = PyExc{ .name = "UnicodeWarning" };
pub const UserWarning = PyExc{ .name = "UserWarning" };
pub const ValueError = PyExc{ .name = "ValueError" };
pub const Warning = PyExc{ .name = "Warning" };
pub const WindowsError = PyExc{ .name = "WindowsError" };
pub const ZeroDivisionError = PyExc{ .name = "ZeroDivisionError" };

/// Struct providing comptime logic for raising Python exceptions.
const PyExc = struct {
    name: [:0]const u8,

    const Self = @This();

    pub fn raise(comptime self: Self, message: [:0]const u8) PyError {
        ffi.PyErr_SetString(self.asPyObject().py, message.ptr);
        return PyError.Raised;
    }

    pub fn raiseFmt(comptime self: Self, comptime fmt: [:0]const u8, args: anytype) PyError {
        const message = try std.fmt.allocPrintZ(py.allocator, fmt, args);
        return self.raise(message);
    }

    pub fn raiseComptimeFmt(comptime self: Self, comptime fmt: [:0]const u8, comptime args: anytype) PyError {
        const message = std.fmt.comptimePrint(fmt, args);
        return self.raise(message);
    }

    inline fn asPyObject(comptime self: Self) py.PyObject {
        return .{ .py = @field(ffi, "PyExc_" ++ self.name) };
    }
};
