const std = @import("std");
const py = @import("pydust");

pub const ConstantBuffer = py.class("ConstantBuffer", struct {
    pub const __doc__ = "A class implementing a buffer protocol";
    const Self = @This();

    values: []i64,
    shape: []isize,
    format: [:0]const u8,

    pub fn __init__(self: *Self, args: *const extern struct { elem: py.PyLong, size: py.PyLong }) !void {
        const elem = try args.elem.as(i64);
        const size = try args.size.as(u64);

        self.format = "l"; // i64
        self.values = try py.allocator.alloc(i64, size);
        @memset(self.values, elem);
        self.shape = try py.allocator.alloc(isize, 1);
        self.shape[0] = @intCast(size);
    }

    pub fn __buffer__(self: *const Self, view: *py.PyBuffer, flags: c_int) !void {
        // For more details on request types, see https://docs.python.org/3/c-api/buffer.html#buffer-request-types
        if (flags & py.PyBuffer.WRITABLE != 0) {
            return py.BufferError.raise("buffer is not writable");
        }

        const pyObj = try py.self(@constCast(self));
        view.initFromSlice(i64, self.values, self.shape, pyObj);

        // We need to incref the self object because it's being used by the view.
        pyObj.incref();
    }

    pub fn __release_buffer__(self: *const Self, view: *py.PyBuffer) void {
        py.allocator.free(self.values);
        py.allocator.free(self.shape);
        // It might be necessary to clean up the view here. Depends on the implementation.
        _ = view;
    }
});

// A function that accepts an object implementing the buffer protocol.
pub fn sum(args: *const extern struct { buf: py.PyObject }) !i64 {
    // ND is required by asSlice.
    var view = try py.PyBuffer.of(args.buf, py.PyBuffer.ND);
    defer view.release();

    var bufferSum: i64 = 0;
    for (view.asSlice(i64)) |value| bufferSum += value;
    return bufferSum;
}

comptime {
    py.module(@This());
}
