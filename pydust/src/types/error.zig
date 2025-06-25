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

pub const ArithmeticError = PyExc("ArithmeticError");
pub const AssertionError = PyExc("AssertionError");
pub const AttributeError = PyExc("AttributeError");
pub const BaseException = PyExc("BaseException");
pub const BaseExceptionGroup = PyExc("BaseExceptionGroup");
pub const BlockingIOError = PyExc("BlockingIOError");
pub const BrokenPipeError = PyExc("BrokenPipeError");
pub const BufferError = PyExc("BufferError");
pub const BytesWarning = PyExc("BytesWarning");
pub const ChildProcessError = PyExc("ChildProcessError");
pub const ConnectionAbortedError = PyExc("ConnectionAbortedError");
pub const ConnectionError = PyExc("ConnectionError");
pub const ConnectionRefusedError = PyExc("ConnectionRefusedError");
pub const ConnectionResetError = PyExc("ConnectionResetError");
pub const DeprecationWarning = PyExc("DeprecationWarning");
pub const EOFError = PyExc("EOFError");
pub const EncodingWarning = PyExc("EncodingWarning");
pub const EnvironmentError = PyExc("EnvironmentError");
pub const Exception = PyExc("Exception");
pub const FileExistsError = PyExc("FileExistsError");
pub const FileNotFoundError = PyExc("FileNotFoundError");
pub const FloatingPointError = PyExc("FloatingPointError");
pub const FutureWarning = PyExc("FutureWarning");
pub const GeneratorExit = PyExc("GeneratorExit");
pub const IOError = PyExc("IOError");
pub const ImportError = PyExc("ImportError");
pub const ImportWarning = PyExc("ImportWarning");
pub const IndentationError = PyExc("IndentationError");
pub const IndexError = PyExc("IndexError");
pub const InterruptedError = PyExc("InterruptedError");
pub const IsADirectoryError = PyExc("IsADirectoryError");
pub const KeyError = PyExc("KeyError");
pub const KeyboardInterrupt = PyExc("KeyboardInterrupt");
pub const LookupError = PyExc("LookupError");
pub const MemoryError = PyExc("MemoryError");
pub const ModuleNotFoundError = PyExc("ModuleNotFoundError");
pub const NameError = PyExc("NameError");
pub const NotADirectoryError = PyExc("NotADirectoryError");
pub const NotImplementedError = PyExc("NotImplementedError");
pub const OSError = PyExc("OSError");
pub const OverflowError = PyExc("OverflowError");
pub const PendingDeprecationWarning = PyExc("PendingDeprecationWarning");
pub const PermissionError = PyExc("PermissionError");
pub const ProcessLookupError = PyExc("ProcessLookupError");
pub const RecursionError = PyExc("RecursionError");
pub const ReferenceError = PyExc("ReferenceError");
pub const ResourceWarning = PyExc("ResourceWarning");
pub const RuntimeError = PyExc("RuntimeError");
pub const RuntimeWarning = PyExc("RuntimeWarning");
pub const StopAsyncIteration = PyExc("StopAsyncIteration");
pub const StopIteration = PyExc("StopIteration");
pub const SyntaxError = PyExc("SyntaxError");
pub const SyntaxWarning = PyExc("SyntaxWarning");
pub const SystemError = PyExc("SystemError");
pub const SystemExit = PyExc("SystemExit");
pub const TabError = PyExc("TabError");
pub const TimeoutError = PyExc("TimeoutError");
pub const TypeError = PyExc("TypeError");
pub const UnboundLocalError = PyExc("UnboundLocalError");
pub const UnicodeDecodeError = PyExc("UnicodeDecodeError");
pub const UnicodeEncodeError = PyExc("UnicodeEncodeError");
pub const UnicodeError = PyExc("UnicodeError");
pub const UnicodeTranslateError = PyExc("UnicodeTranslateError");
pub const UnicodeWarning = PyExc("UnicodeWarning");
pub const UserWarning = PyExc("UserWarning");
pub const ValueError = PyExc("ValueError");
pub const Warning = PyExc("Warning");
pub const WindowsError = PyExc("WindowsError");
pub const ZeroDivisionError = PyExc("ZeroDivisionError");

/// Struct providing comptime logic for raising Python exceptions.
fn PyExc(comptime name: [:0]const u8) type {
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

        inline fn asPyObject() py.PyObject {
            return .{ .py = @field(ffi, "PyExc_" ++ name) };
        }

        /// In debug mode, augment the Python traceback to include Zig stack frames.
        /// Warning: hackery ahead!
        fn augmentTraceback() PyError!void {
            if (builtin.mode == .Debug) {
                // First of all, grab the current Python exception
                var ptype: ?*ffi.PyObject = undefined;
                var pvalue: ?*ffi.PyObject = undefined;
                var ptraceback: ?*ffi.PyObject = undefined;
                ffi.PyErr_Fetch(&ptype, &pvalue, &ptraceback);

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
                    std.debug.printSourceAtAddress(debugInfo, stderr.writer(), address, std.io.tty.detectConfig(stderr)) catch return;
                }

                // Restore the latest the exception info
                ffi.PyErr_Restore(ptype, pvalue, ptraceback);
            }
        }
    };
}
