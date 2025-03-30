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
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;
const PyObjectMixin = @import("./obj.zig").PyObjectMixin;
const State = @import("../discovery.zig").State;

pub fn PyMemoryView(comptime root: type) type {
    return extern struct {
        obj: py.PyObject(root),

        pub const Flags = struct {
            const PyBUF_READ: c_int = 0x100;
            const PyBUF_WRITE: c_int = 0x200;
        };

        const Self = @This();
        pub usingnamespace PyObjectMixin(root, "memoryview", "PyMemoryView", Self);

        pub fn fromSlice(slice: anytype) !Self {
            const sliceType = Slice(@TypeOf(slice));
            const sliceTpInfo = @typeInfo(sliceType);

            const flag = if (sliceTpInfo == .Pointer and sliceTpInfo.Pointer.is_const) Flags.PyBUF_READ else Flags.PyBUF_WRITE;
            return .{ .obj = .{
                .py = py.ffi.PyMemoryView_FromMemory(@constCast(slice.ptr), @intCast(slice.len), flag) orelse return py.PyError.PyRaised,
            } };
        }

        pub fn fromObject(obj: py.PyObject) !Self {
            return .{ .obj = .{
                .py = py.ffi.PyMemoryView_FromObject(obj.py) orelse return py.PyError.PyRaised,
            } };
        }

        fn Slice(comptime T: type) type {
            switch (@typeInfo(T)) {
                .Pointer => |ptr_info| {
                    var new_ptr_info = ptr_info;
                    switch (ptr_info.size) {
                        .Slice => {},
                        .One => switch (@typeInfo(ptr_info.child)) {
                            .Array => |info| new_ptr_info.child = info.child,
                            else => @compileError("invalid type given to PyMemoryview"),
                        },
                        else => @compileError("invalid type given to PyMemoryview"),
                    }
                    new_ptr_info.size = .Slice;
                    return @Type(.{ .Pointer = new_ptr_info });
                },
                else => @compileError("invalid type given to PyMemoryview"),
            }
        }
    };
}

test "from array" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    const array = "static string";
    const mv = try PyMemoryView(root).fromSlice(array);
    defer mv.decref();

    var buf = try mv.obj.getBuffer(py.PyBuffer(root).Flags.ANY_CONTIGUOUS);
    try std.testing.expectEqualSlices(u8, array, buf.asSlice(u8));
    try std.testing.expect(buf.readonly);
}

test "from slice" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    const array = "This is a static string";
    const slice: []const u8 = try std.testing.allocator.dupe(u8, array);
    defer std.testing.allocator.free(slice);
    const mv = try PyMemoryView(root).fromSlice(slice);
    defer mv.decref();

    var buf = try mv.obj.getBuffer(py.PyBuffer(root).Flags.ANY_CONTIGUOUS);
    try std.testing.expectEqualSlices(u8, array, buf.asSlice(u8));
    try std.testing.expect(buf.readonly);
}

test "from mutable slice" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    const array = "This is a static string";
    const slice = try std.testing.allocator.alloc(u8, array.len);
    defer std.testing.allocator.free(slice);
    const mv = try PyMemoryView(root).fromSlice(slice);
    defer mv.decref();
    @memcpy(slice, array);

    var buf = try mv.obj.getBuffer(py.PyBuffer(root).Flags.ANY_CONTIGUOUS);
    try std.testing.expectEqualSlices(u8, array, buf.asSlice(u8));
    try std.testing.expect(!buf.readonly);
}
