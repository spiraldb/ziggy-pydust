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

const builtin = @import("builtin");
const std = @import("std");
const ffi = @import("ffi");
const py = @import("../pydust.zig");
const PyError = @import("../errors.zig").PyError;
const State = @import("../discovery.zig").State;

pub fn ArithmeticError(comptime root: type) type {
    return PyExc(root, "ArithmeticError");
}
pub fn AssertionError(comptime root: type) type {
    return PyExc(root, "AssertionError");
}
pub fn AttributeError(comptime root: type) type {
    return PyExc(root, "AttributeError");
}
pub fn BaseException(comptime root: type) type {
    return PyExc(root, "BaseException");
}
pub fn BaseExceptionGroup(comptime root: type) type {
    return PyExc(root, "BaseExceptionGroup");
}
pub fn BlockingIOError(comptime root: type) type {
    return PyExc(root, "BlockingIOError");
}
pub fn BrokenPipeError(comptime root: type) type {
    return PyExc(root, "BrokenPipeError");
}
pub fn BufferError(comptime root: type) type {
    return PyExc(root, "BufferError");
}
pub fn BytesWarning(comptime root: type) type {
    return PyExc(root, "BytesWarning");
}
pub fn ChildProcessError(comptime root: type) type {
    return PyExc(root, "ChildProcessError");
}
pub fn ConnectionAbortedError(comptime root: type) type {
    return PyExc(root, "ConnectionAbortedError");
}
pub fn ConnectionError(comptime root: type) type {
    return PyExc(root, "ConnectionError");
}
pub fn ConnectionRefusedError(comptime root: type) type {
    return PyExc(root, "ConnectionRefusedError");
}
pub fn ConnectionResetError(comptime root: type) type {
    return PyExc(root, "ConnectionResetError");
}
pub fn DeprecationWarning(comptime root: type) type {
    return PyExc(root, "DeprecationWarning");
}
pub fn EOFError(comptime root: type) type {
    return PyExc(root, "EOFError");
}
pub fn EncodingWarning(comptime root: type) type {
    return PyExc(root, "EncodingWarning");
}
pub fn EnvironmentError(comptime root: type) type {
    return PyExc(root, "EnvironmentError");
}
pub fn Exception(comptime root: type) type {
    return PyExc(root, "Exception");
}
pub fn FileExistsError(comptime root: type) type {
    return PyExc(root, "FileExistsError");
}
pub fn FileNotFoundError(comptime root: type) type {
    return PyExc(root, "FileNotFoundError");
}
pub fn FloatingPointError(comptime root: type) type {
    return PyExc(root, "FloatingPointError");
}
pub fn FutureWarning(comptime root: type) type {
    return PyExc(root, "FutureWarning");
}
pub fn GeneratorExit(comptime root: type) type {
    return PyExc(root, "GeneratorExit");
}
pub fn IOError(comptime root: type) type {
    return PyExc(root, "IOError");
}
pub fn ImportError(comptime root: type) type {
    return PyExc(root, "ImportError");
}
pub fn ImportWarning(comptime root: type) type {
    return PyExc(root, "ImportWarning");
}
pub fn IndentationError(comptime root: type) type {
    return PyExc(root, "IndentationError");
}
pub fn IndexError(comptime root: type) type {
    return PyExc(root, "IndexError");
}
pub fn InterruptedError(comptime root: type) type {
    return PyExc(root, "InterruptedError");
}
pub fn IsADirectoryError(comptime root: type) type {
    return PyExc(root, "IsADirectoryError");
}
pub fn KeyError(comptime root: type) type {
    return PyExc(root, "KeyError");
}
pub fn KeyboardInterrupt(comptime root: type) type {
    return PyExc(root, "KeyboardInterrupt");
}
pub fn LookupError(comptime root: type) type {
    return PyExc(root, "LookupError");
}
pub fn MemoryError(comptime root: type) type {
    return PyExc(root, "MemoryError");
}
pub fn ModuleNotFoundError(comptime root: type) type {
    return PyExc(root, "ModuleNotFoundError");
}
pub fn NameError(comptime root: type) type {
    return PyExc(root, "NameError");
}
pub fn NotADirectoryError(comptime root: type) type {
    return PyExc(root, "NotADirectoryError");
}
pub fn NotImplementedError(comptime root: type) type {
    return PyExc(root, "NotImplementedError");
}
pub fn OSError(comptime root: type) type {
    return PyExc(root, "OSError");
}
pub fn OverflowError(comptime root: type) type {
    return PyExc(root, "OverflowError");
}
pub fn PendingDeprecationWarning(comptime root: type) type {
    return PyExc(root, "PendingDeprecationWarning");
}
pub fn PermissionError(comptime root: type) type {
    return PyExc(root, "PermissionError");
}
pub fn ProcessLookupError(comptime root: type) type {
    return PyExc(root, "ProcessLookupError");
}
pub fn RecursionError(comptime root: type) type {
    return PyExc(root, "RecursionError");
}
pub fn ReferenceError(comptime root: type) type {
    return PyExc(root, "ReferenceError");
}
pub fn ResourceWarning(comptime root: type) type {
    return PyExc(root, "ResourceWarning");
}
pub fn RuntimeError(comptime root: type) type {
    return PyExc(root, "RuntimeError");
}
pub fn RuntimeWarning(comptime root: type) type {
    return PyExc(root, "RuntimeWarning");
}
pub fn StopAsyncIteration(comptime root: type) type {
    return PyExc(root, "StopAsyncIteration");
}
pub fn StopIteration(comptime root: type) type {
    return PyExc(root, "StopIteration");
}
pub fn SyntaxError(comptime root: type) type {
    return PyExc(root, "SyntaxError");
}
pub fn SyntaxWarning(comptime root: type) type {
    return PyExc(root, "SyntaxWarning");
}
pub fn SystemError(comptime root: type) type {
    return PyExc(root, "SystemError");
}
pub fn SystemExit(comptime root: type) type {
    return PyExc(root, "SystemExit");
}
pub fn TabError(comptime root: type) type {
    return PyExc(root, "TabError");
}
pub fn TimeoutError(comptime root: type) type {
    return PyExc(root, "TimeoutError");
}
pub fn TypeError(comptime root: type) type {
    return PyExc(root, "TypeError");
}
pub fn UnboundLocalError(comptime root: type) type {
    return PyExc(root, "UnboundLocalError");
}
pub fn UnicodeDecodeError(comptime root: type) type {
    return PyExc(root, "UnicodeDecodeError");
}
pub fn UnicodeEncodeError(comptime root: type) type {
    return PyExc(root, "UnicodeEncodeError");
}
pub fn UnicodeError(comptime root: type) type {
    return PyExc(root, "UnicodeError");
}
pub fn UnicodeTranslateError(comptime root: type) type {
    return PyExc(root, "UnicodeTranslateError");
}
pub fn UnicodeWarning(comptime root: type) type {
    return PyExc(root, "UnicodeWarning");
}
pub fn UserWarning(comptime root: type) type {
    return PyExc(root, "UserWarning");
}
pub fn ValueError(comptime root: type) type {
    return PyExc(root, "ValueError");
}
pub fn Warning(comptime root: type) type {
    return PyExc(root, "Warning");
}
pub fn WindowsError(comptime root: type) type {
    return PyExc(root, "WindowsError");
}
pub fn ZeroDivisionError(comptime root: type) type {
    return PyExc(root, "ZeroDivisionError");
}

/// Struct providing comptime logic for raising Python exceptions.
fn PyExc(comptime root: type, comptime name: [:0]const u8) type {
    return struct {
        const Self = @This();

        pub fn raise(message: [:0]const u8) PyError {
            ffi.PyErr_SetString(asPyObject().py, message.ptr);
            try augmentTraceback();
            return PyError.PyRaised;
        }

        pub fn raiseFmt(comptime fmt: [:0]const u8, args: anytype) PyError {
            const message = try std.fmt.allocPrintZ(py.allocator, fmt, args);
            defer py.allocator.free(message);
            return raise(message);
        }

        pub fn raiseComptimeFmt(comptime fmt: [:0]const u8, comptime args: anytype) PyError {
            const message = std.fmt.comptimePrint(fmt, args);
            return raise(message);
        }

        inline fn asPyObject() py.PyObject(root) {
            return .{ .py = @field(ffi, "PyExc_" ++ name) };
        }

        /// In debug mode, augment the Python traceback to include Zig stack frames.
        /// Warning: hackery ahead!
        fn augmentTraceback() PyError!void {
            if (builtin.mode == .Debug) {
                // Capture at most 32 stack frames above us.
                var addresses: [32]usize = undefined;
                var st: std.builtin.StackTrace = .{
                    .index = 0,
                    .instruction_addresses = &addresses,
                };
                std.debug.captureStackTrace(@returnAddress(), &st);

                const debugInfo = std.debug.getSelfDebugInfo() catch return;
                const stderr = std.io.getStdErr();

                // Skip the first frame (this function) and the last frame (the trampoline entrypoint)
                for (0..st.index) |idx| {
                    // std.debug.writeStackTrace subtracts 1 from the address - not sure why, but it gives accurate frames.
                    if (st.instruction_addresses[idx] == 0) {
                        continue; // Skip empty addresses
                    }
                    const address = st.instruction_addresses[idx] - 1;

                    // If we can't find info for the stack frame, then we skip this frame..
                    const module = debugInfo.getModuleForAddress(address) catch continue;
                    const symbol_info: std.debug.Symbol = module.getSymbolAtAddress(debugInfo.allocator, address) catch continue;
                    const line_info = symbol_info.source_location orelse continue;

                    // We also want to skip any Pydust internal frames, e.g. the function trampoline and also this current function!
                    if (std.mem.indexOf(u8, line_info.file_name, "/pydust/src/")) |_| {
                        continue;
                    }

                    // Print the source location of the frame.
                    std.debug.printSourceAtAddress(debugInfo, stderr.writer(), address, std.io.tty.detectConfig(stderr)) catch unreachable;
                }
            }
        }
    };
}
