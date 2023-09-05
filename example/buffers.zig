const std = @import("std");
const py = @import("pydust");

pub const ConstantBuffer = py.class("ConstantBuffer", struct {
    pub const __doc__ = "A class implementing a buffer protocol";
    const Self = @This();

    values: []i64,
    pylength: isize, // isize to be compatible with Python API
    format: [:0]const u8 = "l", // i64

    pub fn __init__(self: *Self, args: *const extern struct { elem: py.PyLong, size: py.PyLong }) !void {
        self.values = try py.allocator.alloc(i64, try args.size.as(u64));
        @memset(self.values, try args.elem.as(i64));
        self.pylength = @intCast(self.values.len);
    }

    pub fn __buffer__(self: *const Self, view: *py.PyBuffer, flags: c_int) !void {
        // For more details on request types, see https://docs.python.org/3/c-api/buffer.html#buffer-request-types
        if (flags & py.PyBuffer.Flags.WRITABLE != 0) {
            return py.BufferError.raise("request for writable buffer is rejected");
        }
        const pyObj = try py.self(@constCast(self));
        view.initFromSlice(i64, self.values, @ptrCast(&self.pylength), pyObj);
    }

    pub fn __release_buffer__(self: *const Self, view: *py.PyBuffer) void {
        py.allocator.free(self.values);
        // It might be necessary to clear the view here in case the __bufferr__ method allocates view properties.
        _ = view;
    }
});

// A function that accepts an object implementing the buffer protocol.
pub fn sum(args: *const extern struct { buf: py.PyObject }) !i64 {
    var view: py.PyBuffer = undefined;
    // ND is required by asSlice.
    try args.buf.getBuffer(&view, py.PyBuffer.Flags.ND);
    defer view.release();

    var bufferSum: i64 = 0;
    for (view.asSlice(i64)) |value| bufferSum += value;
    return bufferSum;
}

comptime {
    py.module(@This());
}
