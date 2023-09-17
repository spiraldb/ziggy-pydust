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

//! This file exposes functions equivalent to the Python builtins module (or other builtin syntax).
//! These functions similarly operate over all types of PyObject-like values.
//!
//! See https://docs.python.org/3/library/functions.html for full reference.
const py = @import("./pydust.zig");
const State = @import("./discovery.zig").State;
const ffi = @import("./ffi.zig");
const PyError = @import("./errors.zig").PyError;

/// Returns a new reference to Py_None.
pub fn None() py.PyObject {
    // It's important that we incref the Py_None singleton
    const none = py.PyObject{ .py = ffi.Py_None };
    none.incref();
    return none;
}

/// Returns a new reference to Py_False.
pub inline fn False() py.PyBool {
    return py.PyBool.false_();
}

/// Returns a new reference to Py_True.
pub inline fn True() py.PyBool {
    return py.PyBool.true_();
}

/// Checks whether a given object is callable. Equivalent to Python's callable(o).
pub fn callable(object: anytype) bool {
    const obj = try py.object(object);
    return ffi.PyCallable_Check(obj.py) == 1;
}

/// Convert an object into a dictionary. Equivalent of Python dict(o).
pub fn dict(object: anytype) !py.PyDict {
    const Dict: py.PyObject = .{ .py = @alignCast(@ptrCast(&ffi.PyDict_Type)) };
    const pyobj = try py.create(object);
    defer pyobj.decref();
    return Dict.call(py.PyDict, .{pyobj}, .{});
}

/// Checks whether a given object is None. Avoids incref'ing None to do the check.
pub fn is_none(object: anytype) bool {
    const obj = try py.object(object);
    return ffi.Py_IsNone(obj.py) == 1;
}

/// Get the length of the given object. Equivalent to len(obj) in Python.
pub fn len(object: anytype) !usize {
    const length = ffi.PyObject_Length(py.object(object).py);
    if (length < 0) return PyError.Propagate;
    return @intCast(length);
}

/// Import a module by fully-qualified name returning a PyObject.
pub fn import(module_name: [:0]const u8) !py.PyObject {
    return (try py.PyModule.import(module_name)).obj;
}

/// Return the reference count of the object.
pub fn refcnt(object: anytype) isize {
    const pyobj = py.object(object);
    return pyobj.py.ob_refcnt;
}

/// Compute a string representation of object - using str(o).
pub fn str(object: anytype) !py.PyString {
    const pyobj = py.object(object);
    return py.PyString.unchecked(.{ .py = ffi.PyObject_Str(pyobj.py) orelse return PyError.Propagate });
}

/// Compute a string representation of object - using repr(o).
pub fn repr(object: anytype) !py.PyString {
    const pyobj = py.object(object);
    return py.PyString.unchecked(.{ .py = ffi.PyObject_Repr(pyobj.py) orelse return PyError.Propagate });
}

/// The equivalent of Python's super() builtin. Returns a PyObject.
pub fn super(comptime Super: type, selfInstance: anytype) !py.PyObject {
    const module = State.getContaining(Super, .module);
    const imported = try import(State.getIdentifier(module).name);
    const superPyType = try imported.get(State.getIdentifier(Super).name);
    const pyObj = py.object(selfInstance);

    const superBuiltin: py.PyObject = .{ .py = @alignCast(@ptrCast(&ffi.PySuper_Type)) };
    return superBuiltin.call(.{ superPyType, pyObj }, .{});
}

pub fn tuple(object: anytype) !py.PyTuple {
    const pytuple = ffi.PySequence_Tuple(py.object(object).py) orelse return PyError.Propagate;
    return py.PyTuple.unchecked(.{ .py = pytuple });
}

pub fn type_(object: anytype) !py.PyObject {
    return .{ .py = ffi.Py_TYPE(py.object(object).py) orelse return PyError.Propagate };
}
