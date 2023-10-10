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
const py = @import("./pydust.zig");

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
        // As per this issue, we will hack an aligned allocator.
        // https://bugs.python.org/msg232221
        _ = ret_addr;
        _ = ctx;

        // FIXME(ngates): we should have a separate allocator for re-entrant cases like this
        // that require the GIL, without always paying the cost of acquiring it.
        const gil = py.gil();
        defer gil.release();

        // Zig gives us ptr_align as power of 2
        // This may not always fit into a byte, we should figure out a better way to store the shift value.
        const alignment: u8 = @intCast(@as(u8, 1) << @intCast(ptr_align));

        // By default, ptr_align == 1 which gives us our 1 byte header to store the alignment shift
        const raw_ptr: usize = @intFromPtr(ffi.PyMem_Malloc(len + alignment) orelse return null);

        const shift: u8 = @intCast(alignment - (raw_ptr % alignment));
        std.debug.assert(0 < shift and shift <= alignment);

        const aligned_ptr: usize = raw_ptr + shift;

        // Store the shift in the first byte before the aligned ptr
        // We know from above that we are guaranteed to own that byte.
        @as(*u8, @ptrFromInt(aligned_ptr - 1)).* = shift;

        return @ptrFromInt(aligned_ptr);
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
        _ = buf_align;
        _ = ctx;
        _ = ret_addr;

        const gil = py.gil();
        defer gil.release();

        // Fetch the alignment shift. We could check it matches the buf_align, but it's a bit annoying.
        const aligned_ptr: usize = @intFromPtr(buf.ptr);
        const shift = @as(*const u8, @ptrFromInt(aligned_ptr - 1)).*;

        const raw_ptr: *anyopaque = @ptrFromInt(aligned_ptr - shift);
        ffi.PyMem_Free(raw_ptr);
    }
}{};
