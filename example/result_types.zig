const py = @import("pydust");

pub fn pyobject() !py.PyObject {
    return (try py.PyString.fromSlice("hello")).obj;
}

pub fn pystring() !py.PyString {
    return try py.PyString.fromSlice("hello");
}

pub fn zigvoid() void {}

pub fn zigbool() bool {
    return true;
}

pub fn zigu32() u32 {
    return 32;
}

pub fn zigu64() u64 {
    return 64;
}

pub fn zigi32() i32 {
    return -32;
}

pub fn zigi64() i64 {
    return -64;
}

pub fn zigf32() f32 {
    return 3.2;
}

pub fn zigf64() f64 {
    return 6.4;
}

const StructResult = struct { foo: u64, bar: bool };

pub fn zigstruct() StructResult {
    return .{ .foo = 1234, .bar = true };
}

comptime {
    py.module(@This());
}
