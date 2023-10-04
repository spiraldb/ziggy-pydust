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

// --8<-- [start:ex]
pub const __doc__ =
    \\Zig multi-line strings make it easy to define a docstring...
    \\
    \\..with lots of lines!
    \\
    \\P.S. I'm sure one day we'll hook into Zig's AST and read the Zig doc comments ;)
;

const std = @import("std");
const py = @import("pydust");

const Self = @This(); // (1)!

count: u32 = 0, // (2)!
name: py.PyString,

pub fn __new__() !Self { // (3)!
    return .{ .name = try py.PyString.create("Ziggy") };
}

pub fn increment(self: *Self) void { // (4)!
    self.count += 1;
}

pub fn count(self: *const Self) u32 {
    return self.count;
}

pub fn whoami(self: *const Self) py.PyString {
    return self.name;
}

pub fn hello(
    self: *const Self,
    args: struct { name: py.PyString }, // (5)!
) !py.PyString {
    return py.PyString.createFmt(
        "Hello, {s}. It's {s}",
        .{ try args.name.asSlice(), try self.name.asSlice() },
    );
}

pub const submod = py.module(struct { // (6)!
    pub fn world() !py.PyString {
        return try py.PyString.create("Hello, World!");
    }
});

comptime {
    py.rootmodule(@This()); // (7)!
}
// --8<-- [end:ex]
