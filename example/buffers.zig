const std = @import("std");
const py = @import("pydust");

const PrivateData = struct {};

pub const Buffer = py.class("Buffer", struct {
    pub const __doc__ = "A class implementing a buffer protocol";
    const Self = @This();

    pub fn __init__(self: *Self, args: *const extern struct {}) !void {
        _ = args;
        _ = self;
        std.debug.print("__INIT__", .{});
    }

    pub fn __buffer__(self: *const Self, out: *py.PyBuffer(PrivateData), flags: c_int) c_int {
        _ = flags;
        _ = out;
        _ = self;
        std.debug.print("__BUFFER__", .{});
        return 0;
    }

    pub fn __release_buffer__(self: *const Self, view: *py.PyBuffer(PrivateData)) void {
        _ = view;
        _ = self;
        std.debug.print("__RELEASE_BUFFER__", .{});
    }
});

comptime {
    py.module(@This());
}
