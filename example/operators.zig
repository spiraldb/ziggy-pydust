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

// --8<-- [start:all]
pub const Ops = py.class(struct {
    const Self = @This();

    num: u64,

    pub fn __new__(args: struct { num: u64 }) Self {
        return .{ .num = args.num };
    }

    pub fn num(self: *const Self) u64 {
        return self.num;
    }

    pub fn __add__(self: *const Self, other: *const Self) !*Self {
        return py.init(Self, .{ .num = self.num + other.num });
    }

    pub fn __iadd__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num += other.num;
        return self;
    }

    pub fn __sub__(self: *const Self, other: *const Self) !*Self {
        return py.init(Self, .{ .num = self.num - other.num });
    }

    pub fn __isub__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num -= other.num;
        return self;
    }

    pub fn __mul__(self: *const Self, other: *const Self) !*Self {
        return py.init(Self, .{ .num = self.num * other.num });
    }

    pub fn __imul__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num *= other.num;
        return self;
    }

    pub fn __mod__(self: *const Self, other: *const Self) !*Self {
        return py.init(Self, .{ .num = try std.math.mod(u64, self.num, other.num) });
    }

    pub fn __imod__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num = try std.math.mod(u64, self.num, other.num);
        return self;
    }

    pub fn __divmod__(self: *const Self, other: *const Self) !py.PyTuple {
        return py.PyTuple.create(.{ self.num / other.num, std.math.mod(u64, self.num, other.num) });
    }

    pub fn __pow__(self: *const Self, other: *const Self) !*Self {
        return py.init(Self, .{ .num = std.math.pow(u64, self.num, other.num) });
    }

    pub fn __ipow__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num = std.math.pow(u64, self.num, other.num);
        return self;
    }

    pub fn __lshift__(self: *const Self, other: *const Self) !*Self {
        py.incref(self);
        return py.init(Self, .{ .num = self.num << @as(u6, @intCast(other.num)) });
    }

    pub fn __ilshift__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num = self.num << @as(u6, @intCast(other.num));
        return self;
    }

    pub fn __rshift__(self: *const Self, other: *const Self) !*Self {
        py.incref(self);
        return py.init(Self, .{ .num = self.num >> @as(u6, @intCast(other.num)) });
    }

    pub fn __irshift__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num = self.num >> @as(u6, @intCast(other.num));
        return self;
    }

    pub fn __and__(self: *const Self, other: *const Self) !*Self {
        return py.init(Self, .{ .num = self.num & other.num });
    }

    pub fn __iand__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num = self.num & other.num;
        return self;
    }

    pub fn __xor__(self: *const Self, other: *const Self) !*Self {
        return py.init(Self, .{ .num = self.num ^ other.num });
    }

    pub fn __ixor__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num = self.num ^ other.num;
        return self;
    }

    pub fn __or__(self: *const Self, other: *const Self) !*Self {
        return py.init(Self, .{ .num = self.num | other.num });
    }

    pub fn __ior__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num = self.num | other.num;
        return self;
    }

    pub fn __truediv__(self: *const Self, other: *const Self) !*Self {
        return py.init(Self, .{ .num = self.num / other.num });
    }

    pub fn __itruediv__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num = self.num / other.num;
        return self;
    }

    pub fn __floordiv__(self: *const Self, other: *const Self) !*Self {
        return py.init(Self, .{ .num = self.num / other.num });
    }

    pub fn __ifloordiv__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num = self.num / other.num;
        return self;
    }

    pub fn __matmul__(self: *const Self, other: *const Self) !*Self {
        return py.init(Self, .{ .num = self.num * other.num });
    }

    pub fn __imatmul__(self: *Self, other: *const Self) !*Self {
        py.incref(self);
        self.num *= other.num;
        return self;
    }
});
// --8<-- [end:all]

// --8<-- [start:ops]
pub const Operator = py.class(struct {
    const Self = @This();

    num: u64,

    pub fn __new__(args: struct { num: u64 }) Self {
        return .{ .num = args.num };
    }

    pub fn num(self: *const Self) u64 {
        return self.num;
    }

    pub fn __truediv__(self: *const Self, other: py.PyObject) !py.PyObject {
        if (try py.PyFloat.check(other)) {
            const numF: f64 = @floatFromInt(self.num);
            return py.create(numF / try py.as(f64, other));
        } else if (try py.PyLong.check(other)) {
            return py.create(self.num / try py.as(u64, other));
        } else if (try py.isinstance(other, try py.self(Self))) {
            const otherO: *Self = try py.as(*Self, other);
            return py.object(try py.init(Self, .{ .num = self.num / otherO.num }));
        } else {
            return py.TypeError.raise("Unsupported number type for Operator division");
        }
    }
});
// --8<-- [end:ops]

// --8<-- [start:richcmp]
pub const Comparator = py.class(struct {
    const Self = @This();

    num: u64,

    pub fn __new__(args: struct { num: u64 }) Self {
        return .{ .num = args.num };
    }

    pub fn __richcompare__(self: *const Self, other: *const Self, op: py.CompareOp) bool {
        return switch (op) {
            .LT => self.num < other.num,
            .LE => self.num <= other.num,
            .EQ => self.num == other.num,
            .NE => self.num != other.num,
            .GT => self.num > other.num,
            .GE => self.num >= other.num,
        };
    }
});
// --8<-- [end:richcmp]

// --8<-- [start:equals]
pub const Equals = py.class(struct {
    const Self = @This();

    num: u64,

    pub fn __new__(args: struct { num: u64 }) Self {
        return .{ .num = args.num };
    }

    pub fn __eq__(self: *const Self, other: *const Self) bool {
        return self.num == other.num;
    }
});
// --8<-- [end:equals]

// --8<-- [start:lessthan]
pub const LessThan = py.class(struct {
    const Self = @This();

    name: py.PyString,

    pub fn __new__(args: struct { name: py.PyString }) Self {
        args.name.incref();
        return .{ .name = args.name };
    }

    pub fn __lt__(self: *const Self, other: *const Self) !bool {
        const le = try self.__le__(other);
        if (le) {
            const selfName = try self.name.asSlice();
            const otherName = try other.name.asSlice();

            if (std.mem.eql(u8, selfName, otherName)) {
                return false;
            }
        }
        return le;
    }

    pub fn __le__(self: *const Self, other: *const Self) !bool {
        const selfName = try self.name.asSlice();
        const otherName = try other.name.asSlice();
        if (selfName.len > otherName.len) {
            return false;
        }
        for (0..selfName.len) |i| {
            if (selfName[i] > otherName[i]) {
                return false;
            }
        }
        return true;
    }
});
// --8<-- [end:lessthan]

comptime {
    py.rootmodule(@This());
}
