const std = @import("std");
const Allocator = @import("std").mem.Allocator;
const mem = @import("../mem.zig");
const ffi = @import("../ffi.zig");
const py = @import("../types.zig");
const PyObjectMixin = @import("./obj.zig").PyObjectMixin;

const PyError = @import("../errors.zig").PyError;

pub const PyModule = extern struct {
    obj: py.PyObject,

    pub usingnamespace PyObjectMixin("module", "PyModule", @This());

    pub fn import(name: [:0]const u8) !PyModule {
        return .{ .obj = .{ .py = ffi.PyImport_ImportModule(name) orelse return PyError.Propagate } };
    }

    pub fn getState(self: *const PyModule, comptime state: type) !*state {
        const statePtr = ffi.PyModule_GetState(self.obj.py) orelse return PyError.Propagate;
        return @ptrCast(@alignCast(statePtr));
    }

    pub fn addObjectRef(self: *const PyModule, name: [:0]const u8, obj: py.PyObject) !void {
        if (ffi.PyModule_AddObjectRef(self.obj.py, name.ptr, obj.py) < 0) {
            return PyError.Propagate;
        }
    }

    /// Create and insantiate a PyModule object from a Python code string.
    pub fn fromCode(code: []const u8, filename: []const u8, module_name: []const u8) !PyModule {
        const pycode = ffi.Py_CompileString(code.ptr, filename.ptr, ffi.Py_file_input) orelse return PyError.Propagate;
        defer ffi.Py_DECREF(pycode);

        const pymod = ffi.PyImport_ExecCodeModuleEx(module_name.ptr, pycode, filename.ptr) orelse return PyError.Propagate;
        return .{ .obj = .{ .py = pymod } };
    }
};
