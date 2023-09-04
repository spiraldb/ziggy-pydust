const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;

/// Wrapper for Python Py_buffer.
/// See: https://docs.python.org/3/c-api/buffer.html
pub const PyBuffer = extern struct {
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

    internal: ?*anyopaque,

    pub fn allocFormat(comptime value_type: type, allocator: std.mem.Allocator) ![*:0]u8 {
        const fmt = PyBuffer.getFormat(value_type);
        var fmt_c = try allocator.allocSentinel(u8, fmt.len, 0);
        @memcpy(fmt_c, fmt[0..1]);
        return fmt_c;
    }

    fn getFormat(comptime value_type: type) []const u8 {
        switch (@typeInfo(value_type)) {
            .Int => |i| {
                switch (i.signedness) {
                    .unsigned => switch (i.bits) {
                        8 => return &.{'B'},
                        16 => return "H",
                        32 => return "I",
                        64 => return "L",
                        else => {
                            @compileError("Unsupported buffer type" ++ @typeName(value_type));
                        },
                    },
                    .signed => switch (i.bits) {
                        8 => return "b",
                        16 => return "h",
                        32 => return "i",
                        64 => return "l",
                        else => {
                            @compileError("Unsupported buffer type" ++ @typeName(value_type));
                        },
                    },
                }
            },
            .Float => |f| {
                switch (f.bits) {
                    32 => return "f",
                    64 => return "d",
                    else => {
                        @compileError("Unsupported buffer type" ++ @typeName(value_type));
                    },
                }
            },
            else => {
                @compileError("Unsupported buffer type" ++ @typeName(value_type));
            },
        }
    }
};
