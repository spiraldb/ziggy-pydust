const py = @import("pydust");

pub fn double(args: struct { x: i64 }) i64 {
    return args.x * 2;
}

comptime {
    py.module(@This());
}
