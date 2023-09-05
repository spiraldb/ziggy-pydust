const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;

/// Wrapper for Python Py_buffer.
/// See: https://docs.python.org/3/c-api/buffer.html
pub const PyBuffer = extern struct {
    const Self = @This();

    buf: ?[*]u8,

    // TODO(marko): We can make this PyObject but have to make ffi reference optional.
    obj: ?*ffi.PyObject,

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

    pub fn incref(self: *Self) void {
        self.obj.incref();
    }

    pub fn decref(self: *Self) void {
        // decrefs the underlying object
        ffi.PyBuffer_Release(@ptrCast(self));
    }

    // Flag is a combination of ffi.PyBUF_* flags.
    // See: https://docs.python.org/3/c-api/buffer.html#buffer-request-types
    pub fn of(obj: py.PyObject, flag: c_int) PyBuffer {
        if (ffi.PyObject_CheckBuffer(obj.py) != 1) {
            // TODO(marko): This should raise BufferError.
            @panic("not a buffer");
        }

        var out: Self = undefined;
        if (ffi.PyObject_GetBuffer(obj.py, @ptrCast(&out), flag) != 0) {
            // TODO(marko): This should raise BufferError.
            @panic("unable to get buffer");
        }
        return out;
    }

    // A helper function for converting Zig types to buffer format string.
    pub fn allocFormat(comptime value_type: type, allocator: std.mem.Allocator) ![*:0]u8 {
        const fmt = PyBuffer.getFormat(value_type);
        var fmt_c = try allocator.allocSentinel(u8, fmt.len, 0);
        @memcpy(fmt_c, fmt);
        return fmt_c;
    }

    fn getFormat(comptime value_type: type) []const u8 {
        switch (@typeInfo(value_type)) {
            .Int => |i| {
                switch (i.signedness) {
                    .unsigned => switch (i.bits) {
                        8 => return &.{'B'},
                        16 => return &.{'H'},
                        32 => return &.{'I'},
                        64 => return &.{'L'},
                        else => {
                            @compileError("Unsupported buffer value type" ++ @typeName(value_type));
                        },
                    },
                    .signed => switch (i.bits) {
                        8 => return &.{'b'},
                        16 => return &.{'h'},
                        32 => return &.{'i'},
                        64 => return &.{'l'},
                        else => {
                            @compileError("Unsupported buffer value type" ++ @typeName(value_type));
                        },
                    },
                }
            },
            .Float => |f| {
                switch (f.bits) {
                    32 => return &.{'f'},
                    64 => return &.{'d'},
                    else => {
                        @compileError("Unsupported buffer value type" ++ @typeName(value_type));
                    },
                }
            },
            else => {
                @compileError("Unsupported buffer value type" ++ @typeName(value_type));
            },
        }
    }
};
