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

    pub fn __new__(args: struct { count: u32 }) !@This() {
        return .{ .count = args.count };
    }
});
// --8<-- [end:constructor]

// --8<-- [start:subclass]
pub const Animal = py.class(struct {
    const Self = @This();

    species: py.PyString,

    pub fn species(self: Self) py.PyString {
        return self.species;
    }
});

pub const Dog = py.class(struct {
    const Self = @This();

    animal: Animal,
    breed: py.PyString,

    pub fn __new__(args: struct { breed: py.PyString }) !Self {
        args.breed.incref();
        return .{
            .animal = .{ .species = try py.PyString.create("dog") },
            .breed = args.breed,
        };
    }

    pub fn breed(self: Self) py.PyString {
        return self.breed;
    }
});

// --8<-- [end:subclass]

// --8<-- [start:rectangle]
pub const Rectangle = py.class(struct {
    const Self = @This();

    area: u32,
    height: py.attribute(u32),

    // A property defines getters and setters for instance attributes.
    // Either get, set or both can be defined.
    width: py.property(struct {
        const Prop = @This();

        w: u32,

        pub fn get(self: *const Prop) !u32 {
            return self.w;
        }

        pub fn set(self: *Prop, value: u32) !void {
            const rectangle = @fieldParentPtr(Rectangle, "width", self);
            rectangle.area = rectangle.height * value;

            self.w = value;
        }
    }),

    pub fn __new__(args: struct { width: u32, height: u32 }) !Self {
        return .{
            .area = args.width * args.height,
            .width = .{ .w = args.width },
            .height = args.height,
        };
    }
});
// --8<-- [end:rectangle]

comptime {
    py.rootmodule(@This());
}
