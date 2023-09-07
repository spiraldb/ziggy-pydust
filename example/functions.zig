// --8<-- [start:function]
const py = @import("pydust");

pub fn double(args: struct { x: i64 }) i64 {
    return args.x * 2;
}

comptime {
    py.module(@This());
}
// --8<-- [end:function]

// --8<-- [start:kwargs]
pub fn with_kwargs(args: struct { x: f64, y: f64 = 42.0 }) f64 {
    return if (args.x < args.y) args.x * 2 else args.y;
}
// --8<-- [end:kwargs]
