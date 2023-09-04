const std = @import("std");
const py = @import("pydust");

pub const Animal = py.class("Animal", struct {
    pub const __doc__ = "Animal docstring";

    const Self = @This();

    state: i64,

    pub fn __init__(self: *Self, args: *const extern struct { state: py.PyLong }) !void {
        self.state = try args.state.as(i64);
    }

    pub fn get_state(self: *Self) !i64 {
        return self.state;
    }
});

pub const Dog = py.subclass("Dog", &.{Animal}, struct {
    pub const __doc__ = "Adorable animal docstring";
    const Self = @This();

    name: py.PyString,

    pub fn __init__(self: *Self, args: *const extern struct { name: py.PyString }) !void {
        var super = try py.super(Animal, self);
        try super.__init__(&.{ .state = try py.PyLong.from(i64, 1) });
        self.name = args.name;
    }

    pub fn get_name(self: *const Self) !py.PyString {
        return self.name;
    }

    pub fn make_noise() !py.PyString {
        return py.PyString.fromSlice("Bark!");
    }
});

pub const Owner = py.class("Owner", struct {
    pub const __doc__ = "Takes care of an animal";

    pub fn adopt_puppy(args: *const extern struct { name: py.PyString }) !py.PyObject {
        return try py.init(Dog, .{ .name = args.name });
    }
});

comptime {
    py.module(@This());
}
