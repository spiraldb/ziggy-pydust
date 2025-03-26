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

fn root() struct { *py.State, type } {
    comptime var state = py.State{};
    const spec = struct {
        // --8<-- [start:defining]
        pub const SomeClass = state.class(struct {
            pub const __doc__ = "Some class defined in Zig accessible from Python";

            count: u32 = 0,
        });
        // --8<-- [end:defining]

        // --8<-- [start:constructor]
        pub const ConstructableClass = state.class(struct {
            count: u32 = 0,

            pub fn __init__(self: *@This(), args: struct { count: u32 }) void {
                self.count = args.count;
            }
        });
        // --8<-- [end:constructor]

        // --8<-- [start:subclass]
        pub const Animal = state.class(struct {
            const Self = @This();

            species: py.PyString(state),

            pub fn species(self: *Self) py.PyString(state) {
                return self.species;
            }
        });

        pub const Dog = state.class(struct {
            const Self = @This();

            animal: Animal,
            breed: py.PyString(state),

            pub fn __init__(self: *Self, args: struct { breed: py.PyString(state) }) !void {
                args.breed.incref();
                self.* = .{
                    .animal = .{ .species = try py.PyString(state).create("dog") },
                    .breed = args.breed,
                };
            }

            pub fn breed(self: *Self) py.PyString(state) {
                return self.breed;
            }
        });

        // --8<-- [end:subclass]

        // --8<-- [start:properties]
        pub const User = state.class(struct {
            const Self = @This();

            pub fn __init__(self: *Self, args: struct { name: py.PyString(state) }) void {
                args.name.incref();
                self.* = .{ .name = args.name, .email = .{} };
            }

            name: py.PyString(state),
            email: Email.definition,
            greeting: Greeting.definition = .{},

            const Email = py.property(struct {
                const Prop = @This();

                e: ?py.PyString(state) = null,

                pub fn get(prop: *const Prop) ?py.PyString(state) {
                    if (prop.e) |e| e.incref();
                    return prop.e;
                }

                pub fn set(prop: *Prop, value: py.PyString(state)) !void {
                    const self: *Self = @fieldParentPtr("email", prop);
                    if (std.mem.indexOfScalar(u8, try value.asSlice(), '@') == null) {
                        return py.ValueError.raiseFmt("Invalid email address for {s}", .{try self.name.asSlice()});
                    }
                    value.incref();
                    prop.e = value;
                }
            });

            const Greeting = py.property(struct {
                pub fn get(self: *const Self) !py.PyString(state) {
                    return py.PyString(state).createFmt("Hello, {s}!", .{try self.name.asSlice()});
                }
            });

            pub fn __del__(self: *Self) void {
                self.name.decref();
                if (self.email.e) |e| e.decref();
            }
        });
        // --8<-- [end:properties]

        // --8<-- [start:attributes]
        pub const Counter = state.class(struct {
            const Self = @This();

            count: Count.definition = .{ .value = 0 },
            const Count = py.attribute(usize);

            pub fn __init__(self: *Self) void {
                _ = self;
            }

            pub fn increment(self: *Self) void {
                self.count.value += 1;
            }
        });
        // --8<-- [end:attributes]

        // --8<-- [start:staticmethods]
        pub const Math = state.class(struct {
            pub fn add(args: struct { x: i32, y: i32 }) i32 {
                return args.x + args.y;
            }
        });
        // --8<-- [end:staticmethods]

        // --8<-- [start:zigonly]
        pub const ZigOnlyMethod = state.class(struct {
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

        pub const Hash = state.class(struct {
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

        pub const Callable = state.class(struct {
            const Self = @This();

            pub fn __init__(self: *Self) void {
                _ = self;
            }

            pub fn __call__(self: *const Self, args: struct { i: u32 }) u32 {
                _ = self;
                return args.i;
            }
        });

        pub const GetAttr = state.class(struct {
            const Self = @This();

            pub fn __init__(self: *Self) void {
                _ = self;
            }

            pub fn __getattr__(self: *const Self, attr: py.PyString(state)) !py.PyObject {
                const name = try attr.asSlice();
                if (std.mem.eql(u8, name, "number")) {
                    return py.create(42);
                }
                return py.object(self).getAttribute(name);
            }
        });
    };
    return .{ &state, spec };
}

comptime {
    py.rootmodule(root);
}
