const py = @import("pydust");

// --8<-- [start:append]
fn append(left: *py.PyString, right: []const u8) !py.PyString {
    const rightPy = try py.PyString.fromSlice(right);
    defer rightPy.decref();

    return left.append(rightPy);
}
// --8<-- [end:append]

// --8<-- [start:append2]
fn append2(left: *py.PyString, right: []const u8) !py.PyString {
    return left.appendSlice(right);
}
// --8<-- [end:append2]

pub fn appendFoo(args: *const struct { left: py.PyString }) !py.PyString {
    return append(@constCast(&args.left), "foo");
}

comptime {
    py.module(@This());
}
