const py = @import("./pydust.zig");
const tramp = @import("./trampoline.zig");

/// Zig PyObject-like -> ffi.PyObject. Convert a Zig PyObject-like value into a py.PyObject.
///  e.g. py.PyObject, py.PyTuple, ffi.PyObject, etc.
pub fn object(value: anytype) py.PyObject {
    return tramp.Trampoline(@TypeOf(value)).asObject(value);
}

/// Zig -> Python. Return a Python representation of a Zig object.
/// For Zig primitives, this constructs a new Python object.
/// For PyObject-like values, this returns the value without creating a new reference.
pub fn createOwned(value: anytype) !py.PyObject {
    return tramp.Trampoline(@TypeOf(value)).wrap(value);
}

/// Zig -> Python. Convert a Zig object into a Python object. Returns a new object.
pub fn create(value: anytype) !py.PyObject {
    return tramp.Trampoline(@TypeOf(value)).wrapNew(value);
}

/// Python -> Zig. Return a Zig object representing the Python object.
pub fn as(comptime T: type, obj: anytype) !T {
    return tramp.Trampoline(T).unwrap(object(obj));
}

const testing = @import("std").testing;
const expect = testing.expect;

test "as py -> zig" {
    py.initialize();
    defer py.finalize();

    // Start with a Python object
    const str = try py.PyString.create("hello");
    try expect(py.refcnt(str) == 1);

    // Return a slice representation of it, and ensure the refcnt is untouched
    _ = try py.as([]const u8, str);
    try expect(py.refcnt(str) == 1);

    // Return a PyObject representation of it, and ensure the refcnt is untouched.
    _ = try py.as(py.PyObject, str);
    try expect(py.refcnt(str) == 1);
}
