const py = @import("pydust");

// --8<-- [start:append]
fn append(left: py.PyString, right: []const u8) !void {
    const rightPy = try py.PyString.fromSlice(right);
    defer rightPy.decref();

    try left.append(rightPy);
}
// --8<-- [end:append]

// --8<-- [start:append2]
fn append2(left: py.PyString, right: []const u8) !void {
    try left.appendSlice(right);
}
// --8<-- [end:append2]

pub fn appendFoo(args: *const struct { left: py.PyString }) !void {
    try append(args.left, "foo");
}

comptime {
    py.module(@This());
}
