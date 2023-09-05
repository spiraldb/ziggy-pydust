const std = @import("std");
const py = @import("pydust");

pub const ConstantBuffer = py.class("ConstantBuffer", struct {
    pub const __doc__ = "A class implementing a buffer protocol";
    const Self = @This();

    values: []i64,

    pub fn __init__(self: *Self, args: *const extern struct { elem: py.PyLong, size: py.PyLong }) !void {
        const elem = try args.elem.as(i64);
        const size = try args.size.as(u64);

        self.values = try py.allocator.alloc(i64, size);
        @memset(self.values, elem);
    }

    // TODO(marko): Get obj from self.
    pub fn __buffer__(self: *const Self, obj: py.PyObject, view: *py.PyBuffer, flags: c_int) !void {
        if (flags & py.ffi.PyBUF_WRITABLE != 0) {
            return py.BufferError.raise("Must not request writable");
        }

        const shape = try py.allocator.alloc(isize, 1);
        shape[0] = @intCast(self.values.len);

        // Because we're using values, we need to incref it.
        obj.incref();

        view.* = .{
            .buf = std.mem.sliceAsBytes(self.values).ptr,
            .obj = obj.py,
            .len = @intCast(self.values.len * @sizeOf(i64)),
            .readonly = 1,
            .itemsize = @sizeOf(i64),
            .format_str = try py.PyBuffer.allocFormat(i64, py.allocator),
            .ndim = 1,
            .shape = shape.ptr,
            .strides = null,
            .suboffsets = null,
            .internal = null,
        };
    }

    pub fn __release_buffer__(self: *const Self, view: *py.PyBuffer) void {
        py.allocator.free(self.values);
        py.allocator.free(view.format_str[0..@intCast(std.mem.indexOfSentinel(u8, 0, view.format_str) + 1)]);
        if (view.shape) |shape| py.allocator.free(shape[0..@intCast(view.ndim)]);
        view.obj = null;
    }
});

// Accept a buffer protocol object.
pub fn sum(args: *const extern struct { buf: py.PyObject }) !py.PyLong {
    var view = try py.PyBuffer.of(args.buf, py.ffi.PyBUF_C_CONTIGUOUS);
    defer view.release();

    const sliceView: []i64 = @alignCast(std.mem.bytesAsSlice(i64, view.buf.?[0..@intCast(view.len)]));
    var bufferSum: i64 = 0;
    for (sliceView) |value| bufferSum += value;

    return try py.PyLong.from(i64, bufferSum);
}

comptime {
    py.module(@This());
}
