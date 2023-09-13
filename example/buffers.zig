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
const py = @import("pydust");

// --8<-- [start:protocol]
pub const ConstantBuffer = py.class("ConstantBuffer", struct {
    pub const __doc__ = "A class implementing a buffer protocol";
    const Self = @This();

    values: []i64,
    shape: []const isize, // isize to be compatible with Python API
    format: [:0]const u8 = "l", // i64

    pub fn __new__(args: struct { elem: i64, length: u32 }) !Self {
        const values = try py.allocator.alloc(i64, args.length);
        @memset(values, args.elem);

        const shape = try py.allocator.alloc(isize, 1);
        shape[0] = @intCast(args.length);

        return Self{
            .values = values,
            .shape = shape,
        };
    }

    pub fn __del__(self: *Self) void {
        py.allocator.free(self.values);
        py.allocator.free(self.shape);
    }

    pub fn __buffer__(self: *const Self, view: *py.PyBuffer, flags: c_int) !void {
        // For more details on request types, see https://docs.python.org/3/c-api/buffer.html#buffer-request-types
        if (flags & py.PyBuffer.Flags.WRITABLE != 0) {
            return py.BufferError.raise(@src(), "request for writable buffer is rejected");
        }
        view.initFromSlice(i64, self.values, self.shape, self);
    }
});
// --8<-- [end:protocol]

// --8<-- [start:sum]
pub fn sum(args: struct { buf: py.PyObject }) !i64 {
    var view: py.PyBuffer = undefined;
    try args.buf.getBuffer(&view, py.PyBuffer.Flags.ND);
    defer view.release();

    var bufferSum: i64 = 0;
    for (view.asSlice(i64)) |value| bufferSum += value;
    return bufferSum;
}

comptime {
    py.module(@This());
}
// --8<-- [end:sum]
