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

    pub fn get(obj: py.PyObject) !Self {
        return getWithFlag(obj, ffi.PyBUF_FULL);
    }

    pub fn getro(obj: py.PyObject) !Self {
        return getWithFlag(obj, ffi.PyBUF_FULL_RO);
    }

    pub fn getWithFlag(obj: py.PyObject, flag: c_int) !Self {
        if (ffi.PyObject_CheckBuffer(obj.py) != 1) {
            // TODO(marko): This should be an error once we figure out how to do it
            @panic("not a buffer");
        }
        var out: Self = undefined;
        if (ffi.PyObject_GetBuffer(obj.py, @ptrCast(&out), flag) != 0) {
            // TODO(marko): This should be an error once we figure out how to do it
            @panic("unable to get buffer");
        }
        return out;
    }

    pub fn asSliceView(self: *const Self, comptime value_type: type) ![]value_type {
        if (ffi.PyBuffer_IsContiguous(@ptrCast(self), 'C') != 1) {
            // TODO(marko): This should be an error once we figure out how to do it
            @panic("only continuous buffers are supported for view - use getPtr instead");
        }
        return @alignCast(std.mem.bytesAsSlice(value_type, self.buf.?[0..@intCast(self.len)]));
    }

    pub fn fromOwnedSlice(allocator: std.mem.Allocator, fake: py.PyObject, comptime value_type: type, values: []value_type) !*Self {
        var shape = try allocator.alloc(isize, 1);
        shape[0] = @intCast(values.len);
        const fmt = formatStr(value_type);
        var fmt_c = try allocator.allocSentinel(u8, fmt.len, 0);
        @memcpy(fmt_c, fmt[0..1]);

        var result = try allocator.create(Self);
        result.* = .{
            .buf = @alignCast(std.mem.sliceAsBytes(values).ptr),
            // TODO(marko): We need to create an object using PyType_FromSpec and register buffer release
            .obj = fake,
            .len = @intCast(@sizeOf(value_type) * values.len),
            .itemsize = @intCast(@sizeOf(value_type)),
            // TODO(marko): Not sure
            .readonly = 0,
            .ndim = 1,
            .format_str = fmt_c.ptr,
            .shape = @ptrCast(shape),
            .strides = null,
            .suboffsets = null,
            .internal = null,
        };
        return result;
    }

    fn formatStr(comptime value_type: type) *const [1:0]u8 {
        switch (@typeInfo(value_type)) {
            .Int => |i| {
                switch (i.signedness) {
                    .unsigned => switch (i.bits) {
                        8 => return "B",
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

    pub fn getPtr(self: *const Self, comptime value_type: type, item: [*]const isize) !*value_type {
        var ptr: *anyopaque = ffi.PyBuffer_GetPointer(@ptrCast(self), item) orelse return PyError.Propagate;
        return @ptrCast(@alignCast(ptr));
    }

    pub fn incref(self: *Self) void {
        self.obj.incref();
    }

    pub fn decref(self: *Self) void {
        // decrefs the underlying object
        std.debug.print("RELEASING BUFFER {any}", .{self});
        ffi.PyBuffer_Release(@ptrCast(self));
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
