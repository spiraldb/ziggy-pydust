// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//         http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

const std = @import("std");
const py = @import("pydust");

// --8<-- [start:class]
pub const Animal = py.class("Animal", struct {
    pub const __doc__ = "Animal docstring";

    const Self = @This();

    kind: u64,

    pub fn get_kind(self: *Self) !u64 {
        return self.kind;
    }

    pub fn get_kind_name(self: *Self) !py.PyString {
        return switch (self.kind) {
            1 => py.PyString.create("Dog"),
            2 => py.PyString.create("Cat"),
            3 => py.PyString.create("Parrot"),
            else => py.RuntimeError.raise("Unknown animal kind"),
        };
    }
});
// --8<-- [end:class]

// --8<-- [start:subclass]
pub const Dog = py.subclass("Dog", &.{Animal}, struct {
    pub const __doc__ = "Adorable animal docstring";
    const Self = @This();

    // A subclass of a Pydust class is required to hold its parent's state.
    animal: Animal,
    name: py.PyString,

    pub fn __new__(args: struct { name: py.PyString }) !Self {
        args.name.incref();
        return .{
            .animal = .{ .kind = 1 },
            .name = args.name,
        };
    }

    pub fn __del__(self: *Self) void {
        self.name.decref();
    }

    pub fn __len__(self: *const Self) !usize {
        _ = self;
        return 4;
    }

    pub fn __str__(self: *const Self) !py.PyString {
        var pystr = try py.PyString.create("Dog named ");
        return pystr.append(self.name);
    }

    pub fn __repr__(self: *const Self) !py.PyString {
        var pyrepr = try py.PyString.create("Dog(");
        pyrepr = try pyrepr.append(self.name);
        return pyrepr.appendSlice(")");
    }

    pub fn __add__(self: *const Self, other: py.PyString) !*Self {
        const name = try self.name.append(other);
        return py.init(Self, .{ .name = name });
    }

    pub fn get_name(self: *const Self) !py.PyString {
        return self.name;
    }

    pub fn make_noise(args: struct { is_loud: bool = false }) !py.PyString {
        if (args.is_loud) {
            return py.PyString.create("Bark!");
        } else {
            return py.PyString.create("bark...");
        }
    }

    pub fn get_kind_name(self: *Self) !py.PyString {
        var super = try py.super(Dog, self);
        var superKind = try super.get("get_kind_name");
        var kindStr = try py.PyString.checked(try superKind.call0());
        kindStr = try kindStr.appendSlice(" named ");
        kindStr = try kindStr.append(self.name);
        return kindStr;
    }
});
// --8<-- [end:subclass]

// --8<-- [start:init]
pub const Owner = py.class("Owner", struct {
    pub const __doc__ = "Takes care of an animal";

    pub fn name_puppy(args: struct { name: py.PyString }) !*Dog {
        return try py.init(Dog, .{ .name = args.name });
    }
});
// --8<-- [end:init]

comptime {
    py.module(@This());
}
