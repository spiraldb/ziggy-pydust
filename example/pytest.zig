const std = @import("std");
const py = @import("pydust");

// --8<-- [start:example]
test "pydust pytest" {
    const str = try py.PyString.fromSlice("hello");
    defer str.decref();

    try std.testing.expectEqualStrings("hello", try str.asSlice());
}
// --8<-- [end:example]

test "pydust-expected-failure" {
    const str = try py.PyString.fromSlice("hello");
    defer str.decref();

    try std.testing.expectEqualStrings("world", try str.asSlice());
}
