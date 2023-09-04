const std = @import("std");
const py = @import("pydust");

pub const Animal = py.class("Animal", struct {
    pub const __doc__ = "Animal docstring";
});

pub const Dog = py.subclass("Dog", &.{Animal}, struct {
    pub const __doc__ = "Adorable animal docstring";
    const Self = @This();

    name: py.PyString,

    pub fn __init__(self: *Self, args: *const extern struct { name: py.PyString }) !void {
        args.name.incref();
        self.name = args.name;
    }

    pub fn __finalize__(self: *Self) void {
        self.name.decref();
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
