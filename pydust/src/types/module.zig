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
const Allocator = @import("std").mem.Allocator;
const mem = @import("../mem.zig");
const ffi = @import("../ffi.zig");
const py = @import("../pydust.zig");
const PyObjectMixin = @import("./obj.zig").PyObjectMixin;
const pytypes = @import("../pytypes.zig");
const tramp = @import("../trampoline.zig");
const State = @import("../discovery.zig").State;

const PyError = @import("../errors.zig").PyError;

pub fn PyModule(comptime root: type) type {
    return extern struct {
        obj: py.PyObject(root),

        const Self = @This();
        pub usingnamespace PyObjectMixin(root, "module", "PyModule", Self);

        pub fn import(name: [:0]const u8) !Self {
            return .{ .obj = .{ .py = ffi.PyImport_ImportModule(name) orelse return PyError.PyRaised } };
        }

        pub fn getState(self: Self, comptime ModState: type) !*ModState {
            const statePtr = ffi.PyModule_GetState(self.obj.py) orelse return PyError.PyRaised;
            return @ptrCast(@alignCast(statePtr));
        }

        pub fn addObjectRef(self: Self, name: [:0]const u8, obj: anytype) !void {
            const pyobject = py.object(root, obj);
            if (ffi.PyModule_AddObjectRef(self.obj.py, name.ptr, pyobject.py) < 0) {
                return PyError.PyRaised;
            }
        }

        /// Initialize a class that is defined within this module.
        /// Most useful during module.__exec__ initialization.
        pub fn init(self: Self, class_name: [:0]const u8, class_state: anytype) !*const @TypeOf(class_state) {
            const pytype = try self.obj.get(class_name);
            defer pytype.decref();

            const Cls = @TypeOf(class_state);

            if (State.getDefinition(root, Cls).type != .class) {
                @compileError("Can only init class objects");
            }

            if (@hasDecl(Cls, "__init__")) {
                @compileError("PyTypes with a __init__ method should be instantiated via Python with ptype.call(...)");
            }

            // Alloc the class
            const pyobj: *pytypes.PyTypeStruct(Cls) = @alignCast(@ptrCast(ffi.PyType_GenericAlloc(@ptrCast(pytype.py), 0) orelse return PyError.PyRaised));
            pyobj.root = class_state;
            return &pyobj.root;
        }

        /// Create and insantiate a PyModule object from a Python code string.
        pub fn fromCode(code: []const u8, filename: []const u8, module_name: []const u8) !Self {
            // Ensure null-termination of all strings
            const codeZ = try py.allocator.dupeZ(u8, code);
            defer py.allocator.free(codeZ);
            const filenameZ = try py.allocator.dupeZ(u8, filename);
            defer py.allocator.free(filenameZ);
            const module_nameZ = try py.allocator.dupeZ(u8, module_name);
            defer py.allocator.free(module_nameZ);

            const pycode = ffi.Py_CompileString(codeZ.ptr, filenameZ.ptr, ffi.Py_file_input) orelse return PyError.PyRaised;
            defer ffi.Py_DECREF(pycode);

            const pymod = ffi.PyImport_ExecCodeModuleEx(module_nameZ.ptr, pycode, filenameZ.ptr) orelse return PyError.PyRaised;
            return .{ .obj = .{ .py = pymod } };
        }
    };
}
