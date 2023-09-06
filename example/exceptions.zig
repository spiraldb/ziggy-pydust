const std = @import("std");
const py = @import("pydust");

// --8<-- [start:valueerror]
pub fn raise_value_error(args: struct { message: py.PyString }) !void {
    return py.ValueError.raise(try args.message.asSlice());
}
// --8<-- [end:valueerror]

comptime {
    py.module(@This());
}
