pub const __doc__ =
    \\Zig multi-line strings make it easy to define a docstring...
    \\
    \\..with lots of lines!
    \\
    \\P.S. I'm sure one day we'll hook into Zig's AST and read the Zig doc comments ;)
;

const std = @import("std");
const py = @import("pydust");

const Self = @This(); // (1)!

count: u32 = 0, // (2)!
name: py.PyString,

pub fn __new__() !Self { // (3)!
    return .{ .name = try py.PyString.fromSlice("Ziggy") };
}

pub fn increment(self: *Self) void { // (4)!
    self.count += 1;
}

pub fn count(self: *const Self) u32 {
    return self.count;
}

pub fn hello(
    self: *const Self,
    args: *const struct { name: py.PyString }, // (5)!
) !py.PyString {
    const str = try py.PyString.fromSlice("Hello, ");
    try str.append(args.name);
    try str.append(". It's ");
    try str.append(self.name);
    return str;
}

comptime {
    py.module(@This()); // (6)!
}
