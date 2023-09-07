const std = @import("std");
const py = @import("pydust");

pub const Range = py.class("Range", struct {
    pub const __doc__ = "An example of iterable class";

    const Self = @This();

    lower: i64,
    upper: i64,
    step: i64,

    pub fn __new__(args: struct { lower: i64, upper: i64, step: i64 }) !Self {
        return .{ .lower = args.lower, .upper = args.upper, .step = args.step };
    }

    pub fn __iter__(self: *const Self) !*RangeIterator {
        return try py.init(RangeIterator, .{ .next = self.lower, .stop = self.upper, .step = self.step });
    }
});

pub const RangeIterator = py.class("Iterable", struct {
    pub const __doc__ = "Range iterator";

    const Self = @This();

    next: i64,
    stop: i64,
    step: i64,

    pub fn __new__(args: struct { next: i64, stop: i64, step: i64 }) !Self {
        return .{ .next = args.next, .stop = args.stop, .step = args.step };
    }

    pub fn __next__(self: *Self) ?i64 {
        if (self.next >= self.stop) {
            return null;
        }
        defer self.next += self.step;
        return self.next;
    }
});

comptime {
    py.module(@This());
}
