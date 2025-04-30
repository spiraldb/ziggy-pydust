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
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;
const State = @import("../discovery.zig").State;

/// Wrapper for Python Py_buffer.
/// See: https://docs.python.org/3/c-api/buffer.html
pub fn PyBuffer(comptime root: type) type {
    return extern struct {
        const Self = @This();

        pub const Flags = struct {
            pub const SIMPLE: c_int = 0;
            pub const WRITABLE: c_int = 0x0001;
            pub const FORMAT: c_int = 0x0004;
            pub const ND: c_int = 0x0008;
            pub const STRIDES: c_int = 0x0010 | ND;
            pub const C_CONTIGUOUS: c_int = 0x0020 | STRIDES;
            pub const F_CONTIGUOUS: c_int = 0x0040 | STRIDES;
            pub const ANY_CONTIGUOUS: c_int = 0x0080 | STRIDES;
            pub const INDIRECT: c_int = 0x0100 | STRIDES;
            pub const CONTIG: c_int = STRIDES | WRITABLE;
            pub const CONTIG_RO: c_int = ND;
            pub const STRIDED: c_int = STRIDES | WRITABLE;
            pub const STRIDED_RO: c_int = STRIDES;
            pub const RECORDS: c_int = STRIDES | FORMAT | WRITABLE;
            pub const RECORDS_RO: c_int = STRIDES | FORMAT;
            pub const FULL: c_int = STRIDES | FORMAT | WRITABLE | ND;
            pub const FULL_RO: c_int = STRIDES | FORMAT | ND;
        };

        buf: [*]u8,

        // Use pyObj to get the PyObject.
        // This must be an optional pointer so we can set null value.
        obj: ?*ffi.PyObject,

        // product(shape) * itemsize.
        // For contiguous arrays, this is the length of the underlying memory block.
        // For non-contiguous arrays, it is the length that the logical structure would
        // have if it were copied to a contiguous representation.
        len: isize,
        itemsize: isize,
        readonly: bool,

        // If ndim == 0, the memory location pointed to by buf is interpreted as a scalar of size itemsize.
        // In that case, both shape and strides are NULL.
        ndim: c_int,
        // A NULL terminated string in struct module style syntax describing the contents of a single item.
        // If this is NULL, "B" (unsigned bytes) is assumed.
        format: ?[*:0]const u8,

        shape: ?[*]const isize = null,
        // If strides is NULL, the array is interpreted as a standard n-dimensional C-array.
        // Otherwise, the consumer must access an n-dimensional array as follows:
        // ptr = (char *)buf + indices[0] * strides[0] + ... + indices[n-1] * strides[n-1];
        strides: ?[*]isize = null,
        // If all suboffsets are negative (i.e. no de-referencing is needed),
        // then this field must be NULL (the default value).
        suboffsets: ?[*]isize = null,
        internal: ?*anyopaque = null,

        pub fn release(self: *const Self) void {
            ffi.PyBuffer_Release(@constCast(@ptrCast(self)));
        }

        /// Returns whether the buffer is contiguous in either C or Fortran order.
        pub fn isContiguous(self: *const Self) bool {
            return ffi.PyBuffer_IsContiguous(&self, 'A') == 1;
        }

        pub fn initFromSlice(self: *Self, comptime T: type, values: []T, shape: []const isize, owner: anytype) void {
            // We need to incref the owner object because it's being used by the view.
            const ownerObj = py.object(root, owner);
            ownerObj.incref();

            self.* = .{
                .buf = std.mem.sliceAsBytes(values).ptr,
                .obj = ownerObj.py,
                .len = @intCast(values.len * @sizeOf(T)),
                .itemsize = @sizeOf(T),
                .readonly = true,
                .ndim = @intCast(shape.len),
                .format = getFormat(T).ptr,
                .shape = shape.ptr,
            };
        }

        // asSlice returns buf property as Zig slice. The view must have been created with ND flag.
        pub fn asSlice(self: Self, comptime value_type: type) []value_type {
            return @alignCast(std.mem.bytesAsSlice(value_type, self.buf[0..@intCast(self.len)]));
        }

        pub fn getFormat(comptime value_type: type) [:0]const u8 {
            // TODO(ngates): support more complex composite types.
            switch (@typeInfo(value_type)) {
                .int => |i| {
                    switch (i.signedness) {
                        .unsigned => switch (i.bits) {
                            8 => return "B",
                            16 => return "H",
                            32 => return "I",
                            64 => return "L",
                            else => {},
                        },
                        .signed => switch (i.bits) {
                            8 => return "b",
                            16 => return "h",
                            32 => return "i",
                            64 => return "l",
                            else => {},
                        },
                    }
                },
                .float => |f| {
                    switch (f.bits) {
                        16 => return "e",
                        32 => return "f",
                        64 => return "d",
                        else => {},
                    }
                },
                else => {},
            }

            @compileError("Unsupported buffer value type " ++ @typeName(value_type));
        }
    };
}
