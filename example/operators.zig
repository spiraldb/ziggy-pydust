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

comptime {
    py.rootmodule(@This());
}
