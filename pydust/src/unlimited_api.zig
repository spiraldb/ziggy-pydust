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

// Shims for CPython functions that don't exist in stable ABI implemented using stable ABI methods

const std = @import("std");
const ffi = @import("ffi.zig");
const py = @import("pydust.zig");

pub fn finalize(self: *ffi.PyObject) void {
    const pytype = py.type_(self);
    const finalizeFn = pytype.getSlot(ffi.Py_tp_finalize);
    if (finalizeFn) |fin| {
        if (ffi.PyObject_GC_IsFinalized(self) == 1) {
            return;
        }

        const finFn: *const fn (*ffi.PyObject) void = @alignCast(@ptrCast(fin));
        finFn(self);

        if (pytype.hasFeature(ffi.Py_TPFLAGS_HAVE_GC)) {
            pygcSetFinalized(self);
        }
    }
}

pub fn finalizeFromDealloc(self: *ffi.PyObject) void {
    if (self.ob_refcnt != 0) {
        std.debug.panic("PyObject_CallFinalizerFromDealloc called on object with a non-zero refcount", .{});
    }

    // Temporarily resurrect the object.
    self.ob_refcnt = 1;

    finalize(self);

    if (self.ob_refcnt <= 0) {
        std.debug.panic("refcount is too small", .{});
    }

    self.ob_refcnt -= 1;

    if (self.ob_refcnt != 0) {
        std.debug.panic("Object has been resurrected by the finalizer.", .{});
    }
}

const _PyGC_PREV_MASK_FINALIZED: usize = 1;

/// Copy of CPython's PyGC_HEAD
const PyGC_Head = extern struct {
    _gc_next: usize,
    _gc_prev: usize,
};

inline fn asGcHead(op: *ffi.PyObject) *PyGC_Head {
    const ptr = @intFromPtr(op) - @sizeOf(PyGC_Head);
    return @ptrFromInt(ptr);
}

inline fn gcHeadSetFinalized(gcHead: *PyGC_Head) void {
    gcHead._gc_prev |= _PyGC_PREV_MASK_FINALIZED;
}

inline fn pygcSetFinalized(self: *ffi.PyObject) void {
    var gc: *PyGC_Head = asGcHead(self);
    gcHeadSetFinalized(gc);
}
