const std = @import("std");
const py = @import("pydust");

pub const Animal = py.class("Animal", struct {
    pub const __doc__ = "Animal docstring";

    const Self = @This();

    kind: u64,

    pub fn __new__(args: struct { kind: u64 }) !Self {
        return .{ .kind = args.kind };
    }

    pub fn get_kind(self: *Self) !u64 {
        return self.kind;
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

    // A subclass of a Pydust class is required to hold its parent's state.
    animal: Animal,
    name: py.PyString,

    pub fn __new__(args: struct { name: py.PyString }) !Self {
        args.name.incref();
        return .{
            .animal = try Animal.__new__(.{ .kind = 1 }),
            .name = args.name,
        };
    }

    pub fn __del__(self: *Self) void {
        self.name.decref();
    }

    pub fn __len__(self: *const Self) usize {
        _ = self;
        return 4;
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
        var kindStr = try py.PyString.of(try superKind.call0());
        kindStr = try kindStr.appendSlice(" named ");
        kindStr = try kindStr.append(self.name);
        return kindStr;
    }
});

pub const Owner = py.class("Owner", struct {
    pub const __doc__ = "Takes care of an animal";

    pub fn name_puppy(args: struct { name: py.PyString }) !*Dog {
        return try py.init(Dog, .{ .name = args.name });
    }
});

comptime {
    py.module(@This());
}
