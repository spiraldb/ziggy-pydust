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
