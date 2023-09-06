const std = @import("std");
const py = @import("pydust");

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
            return py.BufferError.raise("request for writable buffer is rejected");
        }
        view.initFromSlice(i64, self.values, self.shape, self);
    }

    pub fn __release_buffer__(self: *const Self, view: *py.PyBuffer) void {
        _ = self;
        // FIXME(ngates): ref count the buffer
        // py.allocator.free(self.values);
        // It might be necessary to clear the view here in case the __bufferr__ method allocates view properties.
        _ = view;
    }
});

// A function that accepts an object implementing the buffer protocol.
pub fn sum(args: struct { buf: py.PyObject }) !i64 {
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
