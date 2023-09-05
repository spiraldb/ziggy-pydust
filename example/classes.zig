const std = @import("std");
const py = @import("pydust");

const Errors = error{UnknownKind};

pub const Animal = py.class("Animal", struct {
    pub const __doc__ = "Animal docstring";

    const Self = @This();

    kind: u64,

    pub fn __init__(self: *Self, args: *const extern struct { kind: py.PyLong }) !void {
        self.kind = try args.kind.as(u64);
    }

    pub fn get_kind(self: *Self) !py.PyLong {
        return py.PyLong.from(u64, self.kind);
    }

    pub fn get_kind_name(self: *Self) !py.PyString {
        return switch (self.kind) {
            1 => py.PyString.fromSlice("Dog"),
            2 => py.PyString.fromSlice("Cat"),
            3 => py.PyString.fromSlice("Parrot"),
            else => py.RuntimeError.raise("Unknown animal kind"),
        };
    }
});

pub const Dog = py.subclass("Dog", &.{Animal}, struct {
    pub const __doc__ = "Adorable animal docstring";
    const Self = @This();

    animal: Animal,
    name: py.PyString,

    pub fn __init__(self: *Self, args: *const extern struct { name: py.PyString }) !void {
        var kind = try py.PyLong.from(u64, 1);
        defer kind.decref();
        try Animal.__init__(&self.animal, &.{ .kind = kind });
        args.name.incref();
        self.name = args.name;
    }

    pub fn __del__(self: *Self) void {
        self.name.decref();
    }

    pub fn get_name(self: *const Self) !py.PyString {
        return self.name;
    }

    pub fn make_noise() !py.PyString {
        return py.PyString.fromSlice("Bark!");
    }

    pub fn get_kind_name(self: *Self) !py.PyString {
        var super = try py.super(Dog, self);
        var superKind = try super.get("get_kind_name");
        var kindStr = py.PyString.of(try superKind.call0());
        kindStr = try kindStr.appendSlice(" named ");
        kindStr = try kindStr.append(self.name);
        return kindStr;
    }
});

pub const Owner = py.class("Owner", struct {
    pub const __doc__ = "Takes care of an animal";

    pub fn name_puppy(args: *const extern struct { name: py.PyString }) !py.PyObject {
        return try py.init(Dog, .{ .name = args.name });
    }
});

comptime {
    py.module(@This());
}
