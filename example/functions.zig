const py = @import("pydust");

pub fn double(args: *const extern struct { x: py.PyLong }) !py.PyLong {
    return try py.PyLong.from(i64, try args.x.as(i64) * 2);
}

comptime {
    py.module(@This());
}
