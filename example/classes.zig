const std = @import("std");
const py = @import("pydust");

pub const Animal = py.class("Animal", struct {
    pub const __doc__ = "Animal docstring";

    const Self = @This();
});

pub const Dog = py.subclass("Dog", &.{Animal}, struct {
    pub const __doc__ = "Adorable animal docstring";
    const Self = @This();

    name: [:0]const u8,

    pub fn __init__(self: *Self, args: *const extern struct { name: py.PyString }) !void {
        self.name = try args.name.asSlice();
    }

    pub fn get_name(self: *const Self) !py.PyString {
        return py.PyString.fromSlice(self.name);
    }

    pub fn make_noise() !py.PyString {
        return py.PyString.fromSlice("Bark!");
    }
});

pub const Owner = py.class("Owner", struct {
    pub const __doc__ = "Takes care of an animal";
    const Self = @This();

    pets: std.ArrayList(py.PyObject),

    pub fn __init__(self: *Self) !void {
        self.pets = std.ArrayList(py.PyObject).init(py.allocator);
    }

    pub fn adopt_puppy(self: *Self, args: *const extern struct { name: py.PyString }) !py.PyObject {
        const puppy = try py.init(Dog, .{ .name = args.name });
        try self.pets.append(puppy);
        return puppy;
    }
});

comptime {
    py.module(@This());
}
