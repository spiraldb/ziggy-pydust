const std = @import("std");
const py = @import("pydust");

pub const Animal = py.class("Animal", struct {
    pub const __doc__ = "Animal docstring";

    const Self = @This();

    state: u64,

    pub fn __init__(self: *Self, args: *const extern struct { state: py.PyLong }) !void {
        self.state = try args.state.as(u64);
    }

    pub fn get_kind(self: *Self) !u64 {
        return self.state;
    }
});

pub const Dog = py.subclass("Dog", &.{Animal}, struct {
    pub const __doc__ = "Adorable animal docstring";
    const Self = @This();

    animal: Animal,
    name: py.PyString,

    pub fn __init__(self: *Self, args: *const extern struct { name: py.PyString }) !void {
        var state = try py.PyLong.from(u64, 1);
        defer state.obj.decref();
        try Animal.__init__(&self.animal, &.{ .state = state });
        self.name = args.name;
    }

    pub fn get_self(self: *Self) !py.PyObject {
        return py.self(self);
    }

    pub fn get_name(self: *Self) !py.PyString {
        return py.PyString.fromSlice(self.name);
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
