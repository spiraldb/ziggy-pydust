const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;

/// Wrapper for Python Py_buffer.
/// See: https://docs.python.org/3/c-api/buffer.html
pub const PyBuffer = extern struct {
    const Self = @This();

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

    buf: ?[*]u8,

    // Use pyObj to get the PyObject.
    // This must be an optional pointer so we can set null value.
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
    format: [*:0]const u8,

    shape: ?[*]isize = null,
    // If strides is NULL, the array is interpreted as a standard n-dimensional C-array.
    // Otherwise, the consumer must access an n-dimensional array as follows:
    // ptr = (char *)buf + indices[0] * strides[0] + ... + indices[n-1] * strides[n-1];
    strides: ?[*]isize = null,
    // If all suboffsets are negative (i.e. no de-referencing is needed),
    // then this field must be NULL (the default value).
    suboffsets: ?[*]isize = null,
    internal: ?*anyopaque = null,

    pub fn release(self: *Self) void {
        ffi.PyBuffer_Release(@ptrCast(self));
    }

    pub fn pyObj(self: *Self) py.PyObject {
        return .{ .py = self.obj orelse unreachable };
    }

    // Flag is a combination of ffi.PyBUF_* flags.
    // See: https://docs.python.org/3/c-api/buffer.html#buffer-request-types
    pub fn of(obj: py.PyObject, flag: c_int) !PyBuffer {
        if (ffi.PyObject_CheckBuffer(obj.py) != 1) {
            return py.BufferError.raise("object does not support buffer interface");
        }

        var out: Self = undefined;
        if (ffi.PyObject_GetBuffer(obj.py, @ptrCast(&out), flag) != 0) {
            // Error is already raised.
            return PyError.Propagate;
        }
        return out;
    }

    pub fn initFromSlice(self: *Self, comptime value_type: type, values: []value_type, shape: []isize, obj: py.PyObject) void {
        self.* = .{
            .buf = std.mem.sliceAsBytes(values).ptr,
            .obj = obj.py,
            .len = @intCast(values.len * @sizeOf(value_type)),
            .itemsize = @sizeOf(value_type),
            .readonly = 1,
            .ndim = 1,
            .format = getFormat(value_type).ptr,
            .shape = shape.ptr,
        };
    }

    // asSlice returns buf property as Zig slice. The view must have been created with ND flag.
    pub fn asSlice(self: *const Self, comptime value_type: type) []value_type {
        return @alignCast(std.mem.bytesAsSlice(value_type, self.buf.?[0..@intCast(self.len)]));
    }

    fn getFormat(comptime value_type: type) [:0]const u8 {
        switch (@typeInfo(value_type)) {
            .Int => |i| {
                switch (i.signedness) {
                    .unsigned => switch (i.bits) {
                        8 => return "B",
                        16 => return "H",
                        32 => return "I",
                        64 => return "L",
                        else => {
                            @compileError("Unsupported buffer value type" ++ @typeName(value_type));
                        },
                    },
                    .signed => switch (i.bits) {
                        8 => return "b",
                        16 => return "h",
                        32 => return "i",
                        64 => return "l",
                        else => {
                            @compileError("Unsupported buffer value type" ++ @typeName(value_type));
                        },
                    },
                }
            },
            .Float => |f| {
                switch (f.bits) {
                    32 => return "f",
                    64 => return "d",
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
