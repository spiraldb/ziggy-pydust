const py = @import("./pydust.zig");
const tramp = @import("./trampoline.zig");

/// Return a Zig object representing the Python object. Does not steal a reference.
pub fn as(comptime T: type, obj: anytype) !T {
    return tramp.Trampoline(T).unwrap(obj);
}

/// Convert a Python object into a Zig object. Stealing the reference.
pub fn into(comptime T: type, obj: anytype) !T {
    return tramp.Trampoline(T).unwrapInto(obj);
}

const expect = @import("std").testing.expect;

test "as py -> zig" {
    py.initialize();
    defer py.finalize();

    // Start with a Python object
    const str = py.PyString.fromSlice("hello");
    try expect(py.refcnt(str) == 1);
}
