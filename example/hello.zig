const py = @import("pydust");

pub fn hello() !py.PyString {
    return try py.PyString.create("Hello!");
}

comptime {
    py.module(@This());
}
