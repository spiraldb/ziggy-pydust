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
const Allocator = std.mem.Allocator;
const ffi = @import("ffi.zig");

pub const PyMemAllocator = struct {
    const Self = @This();

    pub fn allocator(self: *const Self) Allocator {
        return .{
            .ptr = @constCast(self),
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }

    fn alloc(ctx: *anyopaque, len: usize, ptr_align: u8, ret_addr: usize) ?[*]u8 {
        _ = ret_addr;
        _ = ptr_align;
        _ = ctx;
        return @ptrCast(ffi.PyMem_Malloc(len));
    }

    fn resize(ctx: *anyopaque, buf: []u8, buf_align: u8, new_len: usize, ret_addr: usize) bool {
        _ = ret_addr;
        _ = buf_align;
        _ = ctx;
        return ffi.PyMem_Realloc(buf.ptr, new_len) != null;
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
        _ = ret_addr;
        _ = buf_align;
        _ = ctx;
        ffi.PyMem_Free(buf.ptr);
    }
}{};

pub const TestingAllocator = struct {
    const Self = @This();

    const GPA = std.heap.GeneralPurposeAllocator(.{
        //.stack_trace_frames = 16,
    });

    pyalloc: ffi.PyMemAllocatorEx,
    gpa: GPA,
    enabled: bool,

    return_null: bool,

    pub fn init(self: *Self) void {
        self.* = Self{
            .pyalloc = .{
                .ctx = @ptrCast(self),
                .malloc = malloc,
                .calloc = calloc,
                .realloc = realloc,
                .free = free,
            },
            .gpa = GPA{},
            .enabled = false,
            .return_null = false,
        };
    }

    pub fn install(self: *TestingAllocator) void {
        ffi.PyMem_SetAllocator(0, &self.pyalloc);
        ffi.PyMem_SetAllocator(1, &self.pyalloc);
        ffi.PyMem_SetAllocator(2, &self.pyalloc);
    }

    pub fn uninstall(self: *TestingAllocator) void {
        // There's a bunch of types that hold internal free lists.
        // These get partially populated during Python's initialize phase, so now we just blast through
        // them all and fill up all the slots in our gpa allocator. That means all new allocations from user code
        // will live in the testing allocator and be correctly checked for leaks.

        self.enabled = false;

        // _PyExc_Fini(interp);
        // _PyFrame_Fini(interp);
        // _PyAsyncGen_Fini(interp);
        // _PyContext_Fini(interp);
        // _PyType_Fini(interp);
        // // Call _PyUnicode_ClearInterned() before _PyDict_Fini() since it uses
        // // a dict internally.
        // _PyUnicode_ClearInterned(interp);

        // _PyDict_Fini(interp);
        // _PyList_Fini(interp);
        // _PyTuple_Fini(interp);

        // _PySlice_Fini(interp);

        // _PyBytes_Fini(interp);
        // _PyUnicode_Fini(interp);
        // _PyFloat_Fini(interp);
        // _PyLong_Fini(interp);
    }

    fn getAllocator(ctx: ?*anyopaque) std.mem.Allocator {
        const self = getSelf(ctx);
        if (self.enabled) {
            return std.testing.allocator;
        } else {
            return self.gpa.allocator();
        }
    }

    fn malloc(ctx: ?*anyopaque, size: usize) callconv(.C) ?*anyopaque {
        const ptr = (getAllocator(ctx).allocAdvancedWithRetAddr(u8, null, size, @returnAddress()) catch @panic("OOM")).ptr;
        return ptr;
    }

    fn calloc(ctx: ?*anyopaque, length: usize, elem_size: usize) callconv(.C) ?*anyopaque {
        const slice = getAllocator(ctx).alloc(u8, length * elem_size) catch @panic("FAIL");
        @memset(slice, 0);
        return slice.ptr;
    }

    fn realloc(ctx: ?*anyopaque, ptr: ?*anyopaque, new_size: usize) callconv(.C) ?*anyopaque {
        // Python can realloc to zero, and then try to realloc again later the same thing.
        // However, Zig allocators will instead free the memory if new_size == 0.
        // So if we cannot find the old pointer, we just malloc a new one...

        if (ptr == null) {
            return malloc(ctx, new_size);
        }

        const slice = toSlice(ctx, ptr) orelse {
            return malloc(ctx, new_size);
        };

        const ally = slice.ally;
        if (!ally.resize(slice.bytes, new_size)) {
            const oldBytes = slice.bytes;
            const newBytes = ally.alloc(u8, new_size) catch @panic("OOM");
            @memcpy(newBytes[0..oldBytes.len], oldBytes);
            free(ctx, ptr);
            return newBytes.ptr;
        }
        return ptr;
    }

    fn free(ctx: ?*anyopaque, ptr: ?*anyopaque) callconv(.C) void {
        if (ptr == null) return;
        if (toSlice(ctx, ptr)) |slice| {
            slice.free();
        }
    }

    fn getSelf(ctx: ?*anyopaque) *Self {
        return @alignCast(@ptrCast(ctx orelse @panic("FAIL")));
    }

    fn toSlice(ctx: ?*anyopaque, ptr: ?*anyopaque) ?Slice {
        const self = getSelf(ctx);

        if (@intFromPtr(ptr) == std.math.maxInt(usize)) {
            // CPython tries to free 0xFFFFFFF... for some reason?
            return null;
        }

        const p: [*]u8 = @ptrCast(ptr orelse @panic(""));

        const testingGpa: *GPA = @ptrCast(@alignCast(std.testing.allocator.ptr));
        for ([_]*GPA{ &self.gpa, testingGpa }) |gpa| {
            if (gpa.small_allocations.get(@intFromPtr(p))) |small| {
                return .{ .ally = gpa.allocator(), .bytes = p[0..small.requested_size] };
            }
            if (gpa.large_allocations.get(@intFromPtr(p))) |large| {
                return .{ .ally = gpa.allocator(), .bytes = p[0..large.bytes.len] };
            }
        }

        return null;
    }

    const Slice = struct {
        ally: std.mem.Allocator,
        bytes: []u8,

        pub fn free(self: Slice) void {
            self.ally.free(self.bytes);
        }
    };
};
