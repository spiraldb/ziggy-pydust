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

const root = @This();

// --8<-- [start:all]
pub const Ops = py.class(struct {
    const Self = @This();

    num_: u64,

    pub fn __init__(self: *Self, args: struct { num: u64 }) !void {
        self.num_ = args.num;
    }

    pub fn num(self: *const Self) u64 {
        return self.num_;
    }

    pub fn __add__(self: *const Self, other: *const Self) !*Self {
        return py.init(root, Self, .{ .num_ = self.num_ + other.num_ });
    }

    pub fn __iadd__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ += other.num_;
        return self;
    }

    pub fn __sub__(self: *const Self, other: *const Self) !*Self {
        return py.init(root, Self, .{ .num_ = self.num_ - other.num_ });
    }

    pub fn __isub__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ -= other.num_;
        return self;
    }

    pub fn __mul__(self: *const Self, other: *const Self) !*Self {
        return py.init(root, Self, .{ .num_ = self.num_ * other.num_ });
    }

    pub fn __imul__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ *= other.num_;
        return self;
    }

    pub fn __mod__(self: *const Self, other: *const Self) !*Self {
        return py.init(root, Self, .{ .num_ = try std.math.mod(u64, self.num_, other.num_) });
    }

    pub fn __imod__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ = try std.math.mod(u64, self.num_, other.num_);
        return self;
    }

    pub fn __divmod__(self: *const Self, other: *const Self) !py.PyTuple(root) {
        return py.PyTuple(root).create(.{ self.num_ / other.num_, std.math.mod(u64, self.num_, other.num_) });
    }

    pub fn __pow__(self: *const Self, other: *const Self) !*Self {
        return py.init(root, Self, .{ .num_ = std.math.pow(u64, self.num_, other.num_) });
    }

    pub fn __ipow__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ = std.math.pow(u64, self.num_, other.num_);
        return self;
    }

    pub fn __lshift__(self: *const Self, other: *const Self) !*Self {
        py.incref(root, self);
        return py.init(root, Self, .{ .num_ = self.num_ << @as(u6, @intCast(other.num_)) });
    }

    pub fn __ilshift__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ = self.num_ << @as(u6, @intCast(other.num_));
        return self;
    }

    pub fn __rshift__(self: *const Self, other: *const Self) !*Self {
        py.incref(root, self);
        return py.init(root, Self, .{ .num_ = self.num_ >> @as(u6, @intCast(other.num_)) });
    }

    pub fn __irshift__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ = self.num_ >> @as(u6, @intCast(other.num_));
        return self;
    }

    pub fn __and__(self: *const Self, other: *const Self) !*Self {
        return py.init(root, Self, .{ .num_ = self.num_ & other.num_ });
    }

    pub fn __iand__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ = self.num_ & other.num_;
        return self;
    }

    pub fn __xor__(self: *const Self, other: *const Self) !*Self {
        return py.init(root, Self, .{ .num_ = self.num_ ^ other.num_ });
    }

    pub fn __ixor__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ = self.num_ ^ other.num_;
        return self;
    }

    pub fn __or__(self: *const Self, other: *const Self) !*Self {
        return py.init(root, Self, .{ .num_ = self.num_ | other.num_ });
    }

    pub fn __ior__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ = self.num_ | other.num_;
        return self;
    }

    pub fn __truediv__(self: *const Self, other: *const Self) !*Self {
        return py.init(root, Self, .{ .num_ = self.num_ / other.num_ });
    }

    pub fn __itruediv__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ = self.num_ / other.num_;
        return self;
    }

    pub fn __floordiv__(self: *const Self, other: *const Self) !*Self {
        return py.init(root, Self, .{ .num_ = self.num_ / other.num_ });
    }

    pub fn __ifloordiv__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ = self.num_ / other.num_;
        return self;
    }

    pub fn __matmul__(self: *const Self, other: *const Self) !*Self {
        return py.init(root, Self, .{ .num_ = self.num_ * other.num_ });
    }

    pub fn __imatmul__(self: *Self, other: *const Self) !*Self {
        py.incref(root, self);
        self.num_ *= other.num_;
        return self;
    }
});
// --8<-- [end:all]

pub const UnaryOps = py.class(struct {
    const Self = @This();

    num_: i64,

    pub fn __init__(self: *Self, args: struct { num: i64 }) !void {
        self.num_ = args.num;
    }

    pub fn num(self: *const Self) i64 {
        return self.num_;
    }

    pub fn __neg__(self: *Self) !py.PyLong(root) {
        return py.PyLong(root).create(-self.num_);
    }

    pub fn __pos__(self: *Self) !*Self {
        py.incref(root, self);
        return self;
    }

    pub fn __abs__(self: *Self) !*Self {
        return py.init(root, Self, .{ .num_ = @as(i64, @intCast(@abs(self.num_))) });
    }

    pub fn __invert__(self: *Self) !*Self {
        return py.init(root, Self, .{ .num_ = ~self.num_ });
    }

    pub fn __int__(self: *Self) !py.PyLong(root) {
        return py.PyLong(root).create(self.num_);
    }

    pub fn __float__(self: *Self) !py.PyFloat(root) {
        return py.PyFloat(root).create(@as(f64, @floatFromInt(self.num_)));
    }

    pub fn __index__(self: *Self) !py.PyLong(root) {
        return py.PyLong(root).create(self.num_);
    }

    pub fn __bool__(self: *Self) !bool {
        return self.num_ == 1;
    }
});

// --8<-- [start:ops]
pub const Operator = py.class(struct {
    const Self = @This();

    num_: u64,

    pub fn __init__(self: *Self, args: struct { num: u64 }) void {
        self.num_ = args.num;
    }

    pub fn num(self: *const Self) u64 {
        return self.num_;
    }

    pub fn __truediv__(self: *const Self, other: py.PyObject(root)) !py.PyObject(root) {
        const selfCls = try py.self(root, Self);
        defer selfCls.decref();

        if (try py.PyFloat(root).check(other)) {
            const numF: f64 = @floatFromInt(self.num_);
            return py.create(root, numF / try py.as(root, f64, other));
        } else if (try py.PyLong(root).check(other)) {
            return py.create(root, self.num_ / try py.as(root, u64, other));
        } else if (try py.isinstance(root, other, selfCls)) { // TODO(ngates): #193
            const otherO: *Self = try py.as(root, *Self, other);
            return py.object(root, try py.init(root, Self, .{ .num_ = self.num_ / otherO.num_ }));
        } else {
            return py.TypeError(root).raise("Unsupported number type for Operator division");
        }
    }
});
// --8<-- [end:ops]

// --8<-- [start:richcmp]
pub const Comparator = py.class(struct {
    const Self = @This();

    num: u64,

    pub fn __init__(self: *Self, args: struct { num: u64 }) void {
        self.num = args.num;
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

    pub fn __init__(self: *Self, args: struct { num: u64 }) void {
        self.num = args.num;
    }

    pub fn __eq__(self: *const Self, other: *const Self) bool {
        return self.num == other.num;
    }
});
// --8<-- [end:equals]

// --8<-- [start:lessthan]
pub const LessThan = py.class(struct {
    const Self = @This();

    name: py.PyString(root),

    pub fn __init__(self: *Self, args: struct { name: py.PyString(root) }) void {
        args.name.incref();
        self.name = args.name;
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
    py.rootmodule(root);
}
