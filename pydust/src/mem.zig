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
        _ = new_len;
        _ = buf_align;
        _ = buf;
        _ = ctx;
        // We have a couple of options: return true, or return false...

        // Firstly, we can never call PyMem_Realloc since that can internally copy data and return a new ptr.
        // We have no way of passing that pointer back to the caller and buf will have been freed.

        // 1) We could say we successfully resized if new_len < buf.len, and not actually do anything.
        // This would work since we never use the slice length in the free function and PyMem will internally
        // keep track of the initial alloc size.

        // 2) We could say we _always_ fail to resize and force the caller to decide whether to blindly slice
        // or to copy data into a new place.

        // 3) We could succeed if new_len > 75% of buf.len. This minimises the amount of "dead" memory we pass
        // around, but it seems like a somewhat arbitrary threshold to hard-code in the allocator.

        // For now, we go with 2)
        return false;
    }

    fn free(ctx: *anyopaque, buf: []u8, buf_align: u8, ret_addr: usize) void {
        _ = ret_addr;
        _ = buf_align;
        _ = ctx;
        ffi.PyMem_Free(buf.ptr);
    }
}{};
