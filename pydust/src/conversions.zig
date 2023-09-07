const py = @import("./pydust.zig");
const tramp = @import("./trampoline.zig");

pub fn toObject(obj: anytype) !py.PyObject {
    return tramp.Trampoline(@TypeOf(obj)).wrap(obj);
}

/// Return a Zig object representing the Python object. Does not steal a reference.
pub fn as(comptime T: type, obj: anytype) !T {
    return tramp.Trampoline(T).unwrap(py.PyObject.of(obj));
}

/// Convert a Python object into a Zig object. Stealing the reference.
pub fn into(comptime T: type, obj: anytype) !T {
    return tramp.Trampoline(T).unwrapInto(py.PyObject.of(obj));
}

const testing = @import("std").testing;
const expect = testing.expect;

test "as py -> zig" {
    py.initialize();
    defer py.finalize();

    // Start with a Python object
    const str = try py.PyString.fromSlice("hello");
    try expect(py.refcnt(str) == 1);

    // Return a slice representation of it, and ensure the refcnt is untouched
    _ = try py.as([]const u8, str);
    try expect(py.refcnt(str) == 1);

    // Return a PyObject representation of it, and ensure the refcnt is untouched.
    _ = try py.as(py.PyObject, str);
    try expect(py.refcnt(str) == 1);
}

test "into py -> zig" {
    py.initialize();
    defer py.finalize();

    // Start with a Python object
    const str = try py.PyString.fromSlice("hello");

    str.incref();
    try expect(py.refcnt(str) == 2);

    // Turn it into a slice, ensuring we eat a reference
    _ = try py.into([]const u8, str);
    try expect(py.refcnt(str) == 1);

    str.incref();
    try expect(py.refcnt(str) == 2);

    // Turn it into a PyObject, we expect the refcnt to remain the same.
    // Can think of it as destroying the ref to str, but creating a new strong reference to the result.
    _ = try py.into(py.PyObject, str);
    try expect(py.refcnt(str) == 2);

    // Clean up
    str.decref();
}
