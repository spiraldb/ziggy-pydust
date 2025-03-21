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
const PyError = @import("../errors.zig").PyError;
const State = @import("../discovery.zig").State;

pub fn ArithmeticError(comptime state: State) type {
    return PyExc(state, "ArithmeticError");
}
pub fn AssertionError(comptime state: State) type {
    return PyExc(state, "AssertionError");
}
pub fn AttributeError(comptime state: State) type {
    return PyExc(state, "AttributeError");
}
pub fn BaseException(comptime state: State) type {
    return PyExc(state, "BaseException");
}
pub fn BaseExceptionGroup(comptime state: State) type {
    return PyExc(state, "BaseExceptionGroup");
}
pub fn BlockingIOError(comptime state: State) type {
    return PyExc(state, "BlockingIOError");
}
pub fn BrokenPipeError(comptime state: State) type {
    return PyExc(state, "BrokenPipeError");
}
pub fn BufferError(comptime state: State) type {
    return PyExc(state, "BufferError");
}
pub fn BytesWarning(comptime state: State) type {
    return PyExc(state, "BytesWarning");
}
pub fn ChildProcessError(comptime state: State) type {
    return PyExc(state, "ChildProcessError");
}
pub fn ConnectionAbortedError(comptime state: State) type {
    return PyExc(state, "ConnectionAbortedError");
}
pub fn ConnectionError(comptime state: State) type {
    return PyExc(state, "ConnectionError");
}
pub fn ConnectionRefusedError(comptime state: State) type {
    return PyExc(state, "ConnectionRefusedError");
}
pub fn ConnectionResetError(comptime state: State) type {
    return PyExc(state, "ConnectionResetError");
}
pub fn DeprecationWarning(comptime state: State) type {
    return PyExc(state, "DeprecationWarning");
}
pub fn EOFError(comptime state: State) type {
    return PyExc(state, "EOFError");
}
pub fn EncodingWarning(comptime state: State) type {
    return PyExc(state, "EncodingWarning");
}
pub fn EnvironmentError(comptime state: State) type {
    return PyExc(state, "EnvironmentError");
}
pub fn Exception(comptime state: State) type {
    return PyExc(state, "Exception");
}
pub fn FileExistsError(comptime state: State) type {
    return PyExc(state, "FileExistsError");
}
pub fn FileNotFoundError(comptime state: State) type {
    return PyExc(state, "FileNotFoundError");
}
pub fn FloatingPointError(comptime state: State) type {
    return PyExc(state, "FloatingPointError");
}
pub fn FutureWarning(comptime state: State) type {
    return PyExc(state, "FutureWarning");
}
pub fn GeneratorExit(comptime state: State) type {
    return PyExc(state, "GeneratorExit");
}
pub fn IOError(comptime state: State) type {
    return PyExc(state, "IOError");
}
pub fn ImportError(comptime state: State) type {
    return PyExc(state, "ImportError");
}
pub fn ImportWarning(comptime state: State) type {
    return PyExc(state, "ImportWarning");
}
pub fn IndentationError(comptime state: State) type {
    return PyExc(state, "IndentationError");
}
pub fn IndexError(comptime state: State) type {
    return PyExc(state, "IndexError");
}
pub fn InterruptedError(comptime state: State) type {
    return PyExc(state, "InterruptedError");
}
pub fn IsADirectoryError(comptime state: State) type {
    return PyExc(state, "IsADirectoryError");
}
pub fn KeyError(comptime state: State) type {
    return PyExc(state, "KeyError");
}
pub fn KeyboardInterrupt(comptime state: State) type {
    return PyExc(state, "KeyboardInterrupt");
}
pub fn LookupError(comptime state: State) type {
    return PyExc(state, "LookupError");
}
pub fn MemoryError(comptime state: State) type {
    return PyExc(state, "MemoryError");
}
pub fn ModuleNotFoundError(comptime state: State) type {
    return PyExc(state, "ModuleNotFoundError");
}
pub fn NameError(comptime state: State) type {
    return PyExc(state, "NameError");
}
pub fn NotADirectoryError(comptime state: State) type {
    return PyExc(state, "NotADirectoryError");
}
pub fn NotImplementedError(comptime state: State) type {
    return PyExc(state, "NotImplementedError");
}
pub fn OSError(comptime state: State) type {
    return PyExc(state, "OSError");
}
pub fn OverflowError(comptime state: State) type {
    return PyExc(state, "OverflowError");
}
pub fn PendingDeprecationWarning(comptime state: State) type {
    return PyExc(state, "PendingDeprecationWarning");
}
pub fn PermissionError(comptime state: State) type {
    return PyExc(state, "PermissionError");
}
pub fn ProcessLookupError(comptime state: State) type {
    return PyExc(state, "ProcessLookupError");
}
pub fn RecursionError(comptime state: State) type {
    return PyExc(state, "RecursionError");
}
pub fn ReferenceError(comptime state: State) type {
    return PyExc(state, "ReferenceError");
}
pub fn ResourceWarning(comptime state: State) type {
    return PyExc(state, "ResourceWarning");
}
pub fn RuntimeError(comptime state: State) type {
    return PyExc(state, "RuntimeError");
}
pub fn RuntimeWarning(comptime state: State) type {
    return PyExc(state, "RuntimeWarning");
}
pub fn StopAsyncIteration(comptime state: State) type {
    return PyExc(state, "StopAsyncIteration");
}
pub fn StopIteration(comptime state: State) type {
    return PyExc(state, "StopIteration");
}
pub fn SyntaxError(comptime state: State) type {
    return PyExc(state, "SyntaxError");
}
pub fn SyntaxWarning(comptime state: State) type {
    return PyExc(state, "SyntaxWarning");
}
pub fn SystemError(comptime state: State) type {
    return PyExc(state, "SystemError");
}
pub fn SystemExit(comptime state: State) type {
    return PyExc(state, "SystemExit");
}
pub fn TabError(comptime state: State) type {
    return PyExc(state, "TabError");
}
pub fn TimeoutError(comptime state: State) type {
    return PyExc(state, "TimeoutError");
}
pub fn TypeError(comptime state: State) type {
    return PyExc(state, "TypeError");
}
pub fn UnboundLocalError(comptime state: State) type {
    return PyExc(state, "UnboundLocalError");
}
pub fn UnicodeDecodeError(comptime state: State) type {
    return PyExc(state, "UnicodeDecodeError");
}
pub fn UnicodeEncodeError(comptime state: State) type {
    return PyExc(state, "UnicodeEncodeError");
}
pub fn UnicodeError(comptime state: State) type {
    return PyExc(state, "UnicodeError");
}
pub fn UnicodeTranslateError(comptime state: State) type {
    return PyExc(state, "UnicodeTranslateError");
}
pub fn UnicodeWarning(comptime state: State) type {
    return PyExc(state, "UnicodeWarning");
}
pub fn UserWarning(comptime state: State) type {
    return PyExc(state, "UserWarning");
}
pub fn ValueError(comptime state: State) type {
    return PyExc(state, "ValueError");
}
pub fn Warning(comptime state: State) type {
    return PyExc(state, "Warning");
}
pub fn WindowsError(comptime state: State) type {
    return PyExc(state, "WindowsError");
}
pub fn ZeroDivisionError(comptime state: State) type {
    return PyExc(state, "ZeroDivisionError");
}

/// Struct providing comptime logic for raising Python exceptions.
fn PyExc(comptime state: State, comptime name: [:0]const u8) type {
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

        inline fn asPyObject() py.PyObject(state) {
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

                // Skip the first frame (this function) and the last frame (the trampoline entrypoint)
                for (0..st.index) |idx| {
                    // std.debug.writeStackTrace subtracts 1 from the address - not sure why, but it gives accurate frames.
                    const address = st.instruction_addresses[idx] - 1;

                    // If we can't find info for the stack frame, then we skip this frame..
                    const module = debugInfo.getModuleForAddress(address) catch continue;
                    const symbol_info: std.debug.SymbolInfo = module.getSymbolAtAddress(debugInfo.allocator, address) catch continue;
                    defer symbol_info.deinit(debugInfo.allocator);
                    const line_info = symbol_info.line_info orelse continue;

                    // We also want to skip any Pydust internal frames, e.g. the function trampoline and also this current function!
                    if (std.mem.indexOf(u8, line_info.file_name, "/pydust/src/")) |_| {
                        continue;
                    }

                    // Allocate a string of newlines.
                    // Since we wrap the error in a function, we have an addition "def foo()" line.
                    // In addition to lineno being zero-based, we have to subtract 2.
                    // This means that exceptions on line 1 will be off... but that's quite rare.
                    const nnewlines = if (line_info.line < 2) 0 else line_info.line - 2;
                    const newlines = try py.allocator.alloc(u8, nnewlines);
                    defer py.allocator.free(newlines);
                    @memset(newlines, '\n');

                    // Setup a function we know will fail (with DivideByZero error)
                    const code = try std.fmt.allocPrintZ(
                        py.allocator,
                        "{s}def {s}():\n    1/0\n",
                        .{ newlines, symbol_info.symbol_name },
                    );
                    defer py.allocator.free(code);

                    // Import the compiled code as a module and invoke the failing function
                    const fake_module = try py.PyModule(state).fromCode(code, line_info.file_name, symbol_info.compile_unit_name);
                    defer fake_module.decref();

                    _ = fake_module.obj.call(void, symbol_info.symbol_name, .{}, .{}) catch null;

                    // Grab our forced exception info.
                    // We can ignore qtype and qvalue, we just want to get the traceback object.
                    var qtype: ?*ffi.PyObject = undefined;
                    var qvalue: ?*ffi.PyObject = undefined;
                    var qtraceback: ?*ffi.PyObject = undefined;
                    ffi.PyErr_Fetch(&qtype, &qvalue, &qtraceback);
                    if (qtype) |q| py.decref(state, q);
                    if (qvalue) |q| py.decref(state, q);
                    std.debug.assert(qtraceback != null);

                    // Extract the traceback frame by calling into Python (Pytraceback isn't part of the Stable API)
                    const pytb = py.PyObject(state){ .py = qtraceback.? };
                    const frame = (try pytb.get("tb_frame")).py;

                    // Restore the original exception, augment it with the new frame, then fetch the new exception.
                    ffi.PyErr_Restore(ptype, pvalue, ptraceback);
                    _ = ffi.PyTraceBack_Here(@alignCast(@ptrCast(frame)));
                    ffi.PyErr_Fetch(&ptype, &pvalue, &ptraceback);
                }

                // Restore the latest the exception info
                ffi.PyErr_Restore(ptype, pvalue, ptraceback);
            }
        }
    };
}
