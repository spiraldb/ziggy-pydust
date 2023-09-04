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

    pub fn __buffer__(self: *const Self, view: *py.PyBuffer, flags: c_int) !void {
        if (flags & py.ffi.PyBUF_WRITABLE != 0) {
            // TODO(marko): This must raise BufferError
            @panic("Must not request writable");
        }

        const shape = try py.allocator.alloc(isize, 1);
        shape[0] = @intCast(self.values.len);

        view.* = .{
            .buf = std.mem.sliceAsBytes(self.values).ptr,
            // TODO(marko): THIS IS WRONG!!!
            .obj = view.obj,
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
        _ = view;
        std.debug.print("__release_buffer__ called", .{});
        py.allocator.free(self.values);
        // py.allocator.free(view.format_str);
        // py.allocator.free(view.shape);
    }
});

comptime {
    py.module(@This());
}
