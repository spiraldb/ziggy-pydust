const std = @import("std");
const py = @import("../pydust.zig");
const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;

/// Wrapper for Python Py_buffer.
/// See: https://docs.python.org/3/c-api/buffer.html
pub const PyBuffer = extern struct {
    const Self = @This();

    buf: ?[*]u8,
    obj: py.PyObject,
    // product(shape) * itemsize.
    // For contiguous arrays, this is the length of the underlying memory block.
    // For non-contiguous arrays, it is the length that the logical structure would
    // have if it were copied to a contiguous representation.
    len: isize,
    itemsize: isize,
    readonly: c_int,
    ndim: c_int,
    format: [*:0]u8,
    shape: [*:0]isize,
    strides: [*:0]isize,
    suboffsets: [*:0]isize,
    internal: ?*anyopaque,

    pub fn get(obj: py.PyObject) !Self {
        return getWithFlag(obj, ffi.PyBUF_FULL);
    }

    pub fn getro(obj: py.PyObject) !Self {
        return getWithFlag(obj, ffi.PyBUF_FULL_RO);
    }

    pub fn getWithFlag(obj: py.PyObject, flag: c_int) !Self {
        if (ffi.PyObject_CheckBuffer(obj.py) != 1) {
            // TODO(marko): This should be an error once we figure out how to do it
            @panic("not a buffer");
        }
        var out: Self = undefined;
        if (ffi.PyObject_GetBuffer(obj.py, @ptrCast(&out), flag) != 0) {
            // TODO(marko): This should be an error once we figure out how to do it
            @panic("unable to get buffer");
        }
        return out;
    }

    pub fn asSliceView(self: *const Self, comptime value_type: type) ![]value_type {
        if (ffi.PyBuffer_IsContiguous(@ptrCast(self), 'C') != 1) {
            // TODO(marko): This should be an error once we figure out how to do it
            @panic("only continuous buffers are supported for view - use getPtr instead");
        }
        return @alignCast(std.mem.bytesAsSlice(value_type, self.buf.?[0..@intCast(self.len)]));
    }

    pub fn fromOwnedSlice(comptime value_type: type, values: []value_type) !Self {
        _ = values;
        // TODO(marko): We need to create an object using PyType_FromSpec and register buffer release
        @panic("not implemented");
    }

    pub fn getPtr(self: *const Self, comptime value_type: type, item: [*]const isize) !*value_type {
        var ptr: *anyopaque = ffi.PyBuffer_GetPointer(@ptrCast(self), item) orelse return PyError.Propagate;
        return @ptrCast(@alignCast(ptr));
    }

    pub fn incref(self: *Self) void {
        self.obj.incref();
    }

    pub fn decref(self: *Self) void {
        // decrefs the underlying object
        ffi.PyBuffer_Release(@ptrCast(self));
    }
};
