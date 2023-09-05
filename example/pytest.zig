const std = @import("std");
const py = @import("pydust");

// --8<-- [start:example]
test "pydust pytest" {
    py.initialize();
    defer py.finalize();

    const str = try py.PyString.fromSlice("hello");
    defer str.decref();

    try std.testing.expectEqualStrings("hello", try str.asSlice());
}
// --8<-- [end:example]

test "pydust-expected-failure" {
    py.initialize();
    defer py.finalize();

    const str = try py.PyString.fromSlice("hello");
    defer str.decref();

    try std.testing.expectEqualStrings("world", try str.asSlice());
}

pub fn raise_value_error(args: *const struct { message: py.PyString }) !void {
    return py.ValueError.raise(try args.message.asSlice());
}

comptime {
    py.module(@This());
}
