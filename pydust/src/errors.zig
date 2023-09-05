const std = @import("std");

pub const PyError = error{
    // Propagate an error raised from another Python function call.
    // This is the equivalent of returning PyNULL and allowing the already set error info to remain.
    Propagate,
    Raised,
} || std.mem.Allocator.Error;
