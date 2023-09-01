const std = @import("std");
const py = @import("pydust");

const Self = @This();

pub const __doc__ =
    \\A docstring for the example module.
    \\
    \\With lots of lines...
    \\
    \\One day we'll parse these from Zig doc comments in the AST :)
;

/// Internal module state can be declared as struct fields.
///
/// Default values must be set inline, or in the __new__ function if
/// they cannot be defaulted at comptime.
count: u32 = 0,
name: py.PyString,

pub fn __new__() !Self {
    return .{ .name = try py.PyString.fromSlice("Nick") };
}

pub fn hello() !py.PyString {
    return try py.PyString.fromSlice("Hello!");
}

pub fn whoami(self: *const Self) !py.PyString {
    return self.name;
}

/// Functions taking a "self" parameter are passed the module state.
pub fn increment(self: *Self) void {
    self.count += 1;
}

pub fn count(self: *const Self) u32 {
    return self.count;
}

comptime {
    py.module(@This());
}

// TODO(marko): Move this to submodule
pub usingnamespace @import("buffers.zig");
