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

// --8<-- [start:defining]
pub const SomeClass = py.class(struct {
    pub const __doc__ = "Some class defined in Zig accessible from Python";

    count: u32 = 0,
});
// --8<-- [end:defining]

// --8<-- [start:constructor]
pub const ConstructableClass = py.class(struct {
    count: u32 = 0,

    pub fn __init__(self: *@This(), args: struct { count: u32 }) void {
        self.count = args.count;
    }
});
// --8<-- [end:constructor]

// --8<-- [start:subclass]
pub const Animal = py.class(struct {
    const Self = @This();

    species: py.PyString,

    pub fn species(self: *Self) py.PyString {
        return self.species;
    }
});

pub const Dog = py.class(struct {
    const Self = @This();

    animal: Animal,
    breed: py.PyString,

    pub fn __init__(self: *Self, args: struct { breed: py.PyString }) !void {
        args.breed.incref();
        self.* = .{
            .animal = .{ .species = try py.PyString.create("dog") },
            .breed = args.breed,
        };
    }

    pub fn breed(self: *Self) py.PyString {
        return self.breed;
    }
});

// --8<-- [end:subclass]

// --8<-- [start:properties]
pub const User = py.class(struct {
    const Self = @This();

    pub fn __init__(self: *Self, args: struct { name: py.PyString }) void {
        args.name.incref();
        self.* = .{ .name = args.name, .email = .{} };
    }

    name: py.PyString,
    email: py.property(struct {
        const Prop = @This();

        e: ?py.PyString = null,

        pub fn get(prop: *const Prop) ?py.PyString {
            return prop.e;
        }

        pub fn set(prop: *Prop, value: py.PyString) !void {
            const self: *Self = @fieldParentPtr(Self, "email", prop);
            if (std.mem.indexOfScalar(u8, try value.asSlice(), '@') == null) {
                return py.ValueError.raiseFmt("Invalid email address for {s}", .{try self.name.asSlice()});
            }
            prop.e = value;
        }
    }),

    greeting: py.property(struct {
        pub fn get(self: *const Self) !py.PyString {
            return py.PyString.createFmt("Hello, {s}!", .{try self.name.asSlice()});
        }
    }) = .{},
});
// --8<-- [end:properties]

// --8<-- [start:attributes]
pub const Counter = py.class(struct {
    const Self = @This();

    count: py.attribute(usize) = .{ .value = 0 },

    pub fn __init__(self: *Self) void {
        _ = self;
    }

    pub fn increment(self: *Self) void {
        self.count.value += 1;
    }
});
// --8<-- [end:attributes]

// --8<-- [start:staticmethods]
pub const Math = py.class(struct {
    pub fn add(args: struct { x: i32, y: i32 }) i32 {
        return args.x + args.y;
    }
});
// --8<-- [end:staticmethods]

// --8<-- [start:zigonly]
pub const ZigOnlyMethod = py.class(struct {
    const Self = @This();
    number: i32,

    pub fn __init__(self: *Self, args: struct { x: i32 }) void {
        self.number = args.x;
    }

    pub usingnamespace py.zig(struct {
        pub fn get_number(self: *const Self) i32 {
            return self.number;
        }
    });

    pub fn reexposed(self: *const Self) i32 {
        return self.get_number();
    }
});
// --8<-- [end:zigonly]

pub const Hash = py.class(struct {
    const Self = @This();
    number: u32,

    pub fn __init__(self: *Self, args: struct { x: u32 }) void {
        self.number = args.x;
    }

    pub fn __hash__(self: *const Self) usize {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHashStrat(&hasher, self, .DeepRecursive);
        return hasher.final();
    }
});

pub const Callable = py.class(struct {
    const Self = @This();

    pub fn __init__(self: *Self) void {
        _ = self;
    }

    pub fn __call__(self: *const Self, args: struct { i: u32 }) u32 {
        _ = self;
        return args.i;
    }
});

pub const GetAttr = py.class(struct {
    const Self = @This();

    pub fn __init__(self: *Self) void {
        _ = self;
    }

    pub fn __getattr__(self: *const Self, attr: py.PyString) !py.PyObject {
        const name = try attr.asSlice();
        if (std.mem.eql(u8, name, "number")) {
            return py.create(42);
        }
        return py.object(self).getAttribute(name);
    }
});

comptime {
    py.rootmodule(@This());
}
