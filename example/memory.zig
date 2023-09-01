const py = @import("pydust");

// --8<-- [start:append]
fn append(left: py.PyString, right: []const u8) !py.PyObject {
    // Since we create the PyString, and no longer need it after
    // this function, we are responsible for calling decref on it.
    const rightPy = try py.PyString.fromSlice(right);
    defer rightPy.decref();

    try left.append(rightPy);
}
// --8<-- [end:append]

pub fn appendFoo(args: *const struct { left: py.PyString }) !void {
    try append(args.left, "foo");
}

comptime {
    py.module(@This());
}
