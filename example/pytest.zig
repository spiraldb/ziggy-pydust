const std = @import("std");
const py = @import("pydust");

pub fn hello(args: struct { name: py.PyString }) py.PyString {
    return args.name;
}

const testing = std.testing;

test "pydust-pytest" {
    const str = try py.PyString.fromSlice("hello");
    try testing.expectEqualStrings("hello", try str.asSlice());
}
