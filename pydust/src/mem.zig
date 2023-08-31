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
