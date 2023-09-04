const py = @import("pydust");

pub fn hello() !py.PyString {
    return try py.PyString.fromSlice("Hello!");
}

comptime {
    py.module(@This());
}
