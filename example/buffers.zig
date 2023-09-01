const std = @import("std");
const py = @import("pydust");

const Self = @This();

pub const __doc__ =
    \\Using buffer protocol to accept arrays, e.g. numpy.
;

pub fn testing(args: *const struct { arr: py.PyObject }) !u64 {
    var out: py.PyBuffer = try py.PyBuffer.get(args.arr);
    std.debug.print("DEBUG {any}\n", .{out});
    var slice = try py.allocator.alloc(u64, 5);
    // slice.* = .{ 1, 2, 3, 4, 5 };
    out = try py.PyBuffer.fromOwnedSlice(py.allocator, args.arr, u64, slice);
    // out.decref();
    return 0.0;
}

pub fn sum(args: *const struct { arr: py.PyObject }) !u64 {
    var out: py.PyBuffer = try py.PyBuffer.get(args.arr);
    // defer out.decref();
    const values = try out.asSliceView(u64);
    var s: u64 = 0;
    for (values) |v| s += v;
    return s;
}

pub fn reverse(args: *const struct { arr: py.PyObject }) !void {
    var out: py.PyBuffer = try py.PyBuffer.get(args.arr);
    // we can just work with slice, but this tests getPtr
    const length: usize = @intCast(out.shape.?[0]);
    const iter: usize = @divFloor(length, 2);
    for (0..iter) |i| {
        var left = try out.getPtr(u64, &[_]isize{@intCast(i)});
        var right = try out.getPtr(u64, &[_]isize{@intCast(length - i - 1)});
        const tmp: u64 = left.*;
        left.* = right.*;
        right.* = tmp;
    }
}

comptime {
    py.module(@This());
}
