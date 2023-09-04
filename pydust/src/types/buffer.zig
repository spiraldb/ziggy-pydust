const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;

/// Wrapper for Python Py_buffer.
/// See: https://docs.python.org/3/c-api/buffer.html
pub fn PyBuffer(comptime T: type) type {
    return extern struct {
        const Self = @This();

        buf: ?[*]u8,
        obj: py.PyObject,

        // product(shape) * itemsize.
        // For contiguous arrays, this is the length of the underlying memory block.
        // For non-contiguous arrays, it is the length that the logical structure would
        // have if it were copied to a contiguous representation.
        len: isize,
        itemsize: isize,
        readonly: c_int,

        // If ndim == 0, the memory location pointed to by buf is interpreted as a scalar of size itemsize.
        // In that case, both shape and strides are NULL.
        ndim: c_int,
        format_str: [*:0]u8,

        shape: ?[*]isize,
        // If strides is NULL, the array is interpreted as a standard n-dimensional C-array.
        // Otherwise, the consumer must access an n-dimensional array as follows:
        // ptr = (char *)buf + indices[0] * strides[0] + ... + indices[n-1] * strides[n-1];
        strides: ?[*]isize,
        // If all suboffsets are negative (i.e. no de-referencing is needed),
        // then this field must be NULL (the default value).
        suboffsets: ?[*]isize,

        internal: ?*T,

        pub fn allocFormat(comptime value_type: type, allocator: std.mem.Allocator) [*:0]u8 {
            const fmt = switch (@typeInfo(value_type)) {
                .Int => |i| {
                    switch (i.signedness) {
                        .unsigned => switch (i.bits) {
                            8 => "B",
                            16 => "H",
                            32 => "I",
                            64 => "L",
                            else => {
                                @compileError("Unsupported buffer type" ++ @typeName(value_type));
                            },
                        },
                        .signed => switch (i.bits) {
                            8 => "b",
                            16 => "h",
                            32 => "i",
                            64 => "l",
                            else => {
                                @compileError("Unsupported buffer type" ++ @typeName(value_type));
                            },
                        },
                    }
                },
                .Float => |f| {
                    switch (f.bits) {
                        32 => "f",
                        64 => "d",
                        else => {
                            @compileError("Unsupported buffer type" ++ @typeName(value_type));
                        },
                    }
                },
                else => {
                    @compileError("Unsupported buffer type" ++ @typeName(value_type));
                },
            };

            var fmt_c = try allocator.allocSentinel(u8, fmt.len, 0);
            @memcpy(fmt_c, fmt[0..1]);
            return fmt_c;
        }

        pub fn format(value: *const Self, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
            _ = options;
            _ = fmt;
            try writer.print("\nPyBuffer({s})[", .{value.format_str});
            if (value.shape) |shape| {
                for (0..@intCast(value.ndim - 1)) |i| {
                    try writer.print("{d},", .{shape[i]});
                }
                try writer.print("{d}]\n", .{shape[@intCast(value.ndim - 1)]});
            }
            if (value.strides) |strides| {
                for (0..@intCast(value.ndim)) |i| {
                    try writer.print("stride[{d}]={d}\n", .{ i, strides[i] });
                }
            }
            if (value.suboffsets) |suboffsets| {
                for (0..@intCast(value.ndim)) |i| {
                    try writer.print("stride[{d}]={d}\n", .{ i, suboffsets[i] });
                }
            }
        }
    };
}
