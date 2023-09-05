const Allocator = @import("std").mem.Allocator;

pub const PyError = error{
    // Propagate an error raised from another Python function call.
    // This is the equivalent of returning PyNULL and allowing the already set error info to remain.
    Propagate,
    Raised,
} || Allocator.Error;
