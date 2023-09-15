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
const ffi = @import("../ffi.zig");
const py = @import("../pydust.zig");
const pyconf = @import("pyconf");
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
        try augmentTraceback();
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

    /// Try to augment the Python traceback with Zig stack frames.
    /// This will only work if we're in debug mode.
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

            // Let's assume the error was raised within user code, we truncate the traceback at the first
            // frame that lives in a different file, e.g. when we move from user code to libpython.
            var modName: ?[]const u8 = null;
            var frameIdx: usize = 0;
            for (st.instruction_addresses, 0..) |addr, idx| {
                if (debugInfo.getModuleNameForAddress(addr)) |addrModName| {
                    if (modName == null) {
                        modName = addrModName;
                    } else if (!std.mem.eql(u8, modName.?, addrModName)) {
                        frameIdx = idx;
                        break;
                    }
                }
            }

            // Strip off the top frame (augmentTraceback())
            // And strip off the bottom frame since it's the trampoline "fastcall" method.
            //st.instruction_addresses = st.instruction_addresses[1..frameIdx];
            //st.index = frameIdx - 2;

            // We could now dump the Zig stack trace to stderr
            // std.debug.dumpStackTrace(st);

            // Or... we can walk it, compile it into Python code we know to fail
            // Grab the Python frame objects this produces, and tack them onto our traceback!
            for (st.instruction_addresses[1 .. st.index - 1]) |addr| {
                // TODO(ngates): handle breaking out of this loop with failure
                const module = debugInfo.getModuleForAddress(addr) catch break;
                const symbol_info: std.debug.SymbolInfo = module.getSymbolAtAddress(debugInfo.allocator, addr) catch break;
                const line_info = symbol_info.line_info orelse break;

                // Grab the current Python exception
                var ptype: ?*ffi.PyObject = undefined;
                var pvalue: ?*ffi.PyObject = undefined;
                var ptraceback: ?*ffi.PyObject = undefined;
                ffi.PyErr_Fetch(&ptype, &pvalue, &ptraceback);

                // We allocate a string that looks roughly like:
                //  <N blank lines to create correct lineno>
                //  def <func name>():
                //      1/0
                // So lineno + len("def ") + len(symbol_name) + "():\n    " + "1/0\n"
                // So... lineno + len(symbol_name) + 4 + 8 + 4
                const newlines = try py.allocator.alloc(u8, line_info.line);
                @memset(newlines, '\n');

                const code = try std.fmt.allocPrintZ(
                    py.allocator,
                    "{s}def {s}():\n    1/0\n\n{s}()\n",
                    .{ newlines, symbol_info.symbol_name, symbol_info.symbol_name },
                );
                //std.debug.print("CODE ${s}$\n", .{code});

                // Compilation should succeed, but execution should fail.
                // TODO(ngates): can we do something with strings so we can include the actual line of Zig code in the frame?
                const filename = try py.allocator.dupeZ(u8, line_info.file_name);
                const compiled = ffi.Py_CompileString(code.ptr, filename.ptr, ffi.Py_file_input) orelse @panic("Failed to compile");

                // Execute the failing code and grab its traceback
                const globals = ffi.PyEval_GetGlobals();
                const result = ffi.PyEval_EvalCode(compiled, globals, null);
                std.debug.assert(result == 0); // It should fail with DivideByZero error.

                // We can ignore qtype and qvalue, we just want to get the traceback object.
                var qtype: ?*ffi.PyObject = undefined;
                var qvalue: ?*ffi.PyObject = undefined;
                var qtraceback: ?*ffi.PyObject = undefined;
                ffi.PyErr_Fetch(&qtype, &qvalue, &qtraceback);
                if (qtype) |q| py.decref(q);
                if (qvalue) |q| py.decref(q);
                std.debug.assert(qtraceback != null);

                // Append the traceback frame
                const pytb = py.PyObject{ .py = qtraceback.? };
                // tb_frame is not part of the stable C API
                const frame = (try pytb.get("tb_frame")).py;

                // Restore the original exception just before augmenting it with a new frame.
                ffi.PyErr_Restore(ptype, pvalue, ptraceback);
                if (ffi.PyTraceBack_Here(@alignCast(@ptrCast(frame))) == -1) {
                    break;
                }
            }

            // Reset the exception info
            //ffi.PyErr_Restore(ptype, pvalue, ptraceback);

            // if (ptraceback != null) {
            //     if (ffi.PyException_SetTraceback(pvalue, ptraceback) == -1) {
            //         return PyError.Propagate;
            //     }
            // }

            // Reset the exception info
        }
    }
};

const PyTraceback = extern struct {
    ob_base: ffi.PyVarObject,
    tb_next: ?*anyopaque,
    tb_frame: ?*ffi.PyFrameObject,
    tb_lasti: c_int,
    tb_lineno: c_int,
};
