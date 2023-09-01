const std = @import("std");
const py = @import("pydust");

const Self = @This();

pub const __doc__ =
    \\Using buffer protocol to accept arrays, e.g. numpy.
;

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
    const length: usize = @intCast(out.shape[0]);
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
