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
const std = @import("std");
const py = @import("./pydust.zig");
const pytypes = @import("./pytypes.zig");
const State = @import("./discovery.zig").State;
const ffi = @import("./ffi.zig");
const PyError = @import("./errors.zig").PyError;

/// Zig enum for python richcompare op int.
/// The order of enums has to match the values of ffi.Py_LT, etc
pub const CompareOp = enum {
    LT,
    LE,
    EQ,
    NE,
    GT,
    GE,
};

/// Returns a new reference to Py_NotImplemented.
pub fn NotImplemented() py.PyObject {
    // It's important that we incref the Py_NotImplemented singleton
    const notImplemented = py.PyObject{ .py = ffi.Py_NotImplemented };
    notImplemented.incref();
    return notImplemented;
}

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

pub inline fn decref(value: anytype) void {
    py.object(value).decref();
}

pub inline fn incref(value: anytype) void {
    py.object(value).incref();
}

/// Checks whether a given object is callable. Equivalent to Python's callable(o).
pub fn callable(object: anytype) bool {
    const obj = try py.object(object);
    return ffi.PyCallable_Check(obj.py) == 1;
}

/// Call a callable object with no arguments.
///
/// If the result is a new reference, then as always the caller is responsible for calling decref on it.
/// That means for new references the caller should ask for a return type that they are unable to decref,
/// for example []const u8.
pub fn call0(comptime T: type, object: anytype) !T {
    const result = ffi.PyObject_CallNoArgs(py.object(object).py) orelse return PyError.PyRaised;
    return try py.as(T, result);
}

/// Call a callable object with the given arguments.
///
/// If the result is a new reference, then as always the caller is responsible for calling decref on it.
/// That means for new references the caller should ask for a return type that they are unable to decref,
/// for example []const u8.
pub fn call(comptime ReturnType: type, object: anytype, args: anytype, kwargs: anytype) !ReturnType {
    const pyobj = py.object(object);

    var argsPy: py.PyTuple = undefined;
    if (@typeInfo(@TypeOf(args)) == .Optional and args == null) {
        argsPy = try py.PyTuple.new(0);
    } else {
        argsPy = try py.PyTuple.checked(try py.create(args));
    }
    defer argsPy.decref();

    // TODO(ngates): avoid creating empty dict for kwargs
    var kwargsPy: py.PyDict = undefined;
    if (@typeInfo(@TypeOf(kwargs)) == .Optional and kwargs == null) {
        kwargsPy = try py.PyDict.new();
    } else {
        // Annoyingly our trampoline turns an empty kwargs struct into a PyTuple.
        // This will be fixed by #94
        const kwobj = try py.create(kwargs);
        if (try py.len(kwobj) == 0) {
            kwobj.decref();
            kwargsPy = try py.PyDict.new();
        } else {
            kwargsPy = try py.PyDict.checked(kwobj);
        }
    }
    defer kwargsPy.decref();

    // Note, the caller is responsible for returning a result type that they are able to decref.
    const result = ffi.PyObject_Call(pyobj.py, argsPy.obj.py, kwargsPy.obj.py) orelse return PyError.PyRaised;
    return try py.as(ReturnType, result);
}

/// Convert an object into a dictionary. Equivalent of Python dict(o).
pub fn dict(object: anytype) !py.PyDict {
    const Dict: py.PyObject = .{ .py = @alignCast(@ptrCast(&ffi.PyDict_Type)) };
    const pyobj = try py.create(object);
    defer pyobj.decref();
    return Dict.call(py.PyDict, .{pyobj}, .{});
}

pub const PyGIL = struct {
    const Self = @This();

    state: ffi.PyGILState_STATE,

    pub fn release(self_: Self) void {
        ffi.PyGILState_Release(self_.state);
    }
};

/// Ensure the current thread holds the Python GIL.
/// Must be accompanied by a call to release().
pub fn gil() PyGIL {
    return .{ .state = ffi.PyGILState_Ensure() };
}

pub const PyNoGIL = struct {
    const Self = @This();

    state: *ffi.PyThreadState,

    pub fn acquire(self_: Self) void {
        ffi.PyEval_RestoreThread(self_.state);
    }
};

/// Release the GIL from the current thread.
/// Must be accompanied by a call to acquire().
pub fn nogil() PyNoGIL {
    // TODO(ngates): can this fail?
    return .{ .state = ffi.PyEval_SaveThread() orelse unreachable };
}

/// Checks whether a given object is None. Avoids incref'ing None to do the check.
pub fn is_none(object: anytype) bool {
    const obj = py.object(object);
    return ffi.Py_IsNone(obj.py) == 1;
}

/// Import a module by fully-qualified name returning a PyObject.
pub fn import(module_name: [:0]const u8) !py.PyObject {
    return (try py.PyModule.import(module_name)).obj;
}

/// Instantiate a class defined in Pydust.
pub inline fn init(comptime Cls: type, args: Cls) PyError!*Cls {
    const pytype = try self(Cls);

    // Alloc the class
    // NOTE(ngates): we currently don't allow users to override tp_alloc, therefore we can shortcut
    // using ffi.PyType_GetSlot(tp_alloc) since we know it will always return ffi.PyType_GenericAlloc
    const pyobj: *pytypes.PyTypeStruct(Cls) = @alignCast(@ptrCast(ffi.PyType_GenericAlloc(@ptrCast(pytype.py), 0) orelse return PyError.PyRaised));
    pyobj.state = args;

    return &pyobj.state;
}

/// Check if object is an instance of cls.
pub fn isinstance(object: anytype, cls: anytype) !bool {
    const pyobj = py.object(object);
    const pycls = py.object(cls);

    const result = ffi.PyObject_IsInstance(pyobj.py, pycls.py);
    if (result < 0) return PyError.PyRaised;
    return result == 1;
}

/// Return an iterator for the given object if it has one. Equivalent to iter(obj) in Python.
pub fn iter(object: anytype) !py.PyIter {
    const iterator = ffi.PyObject_GetIter(py.object(object).py) orelse return PyError.PyRaised;
    return py.PyIter.unchecked(.{ .py = iterator });
}

/// Get the length of the given object. Equivalent to len(obj) in Python.
pub fn len(object: anytype) !usize {
    const length = ffi.PyObject_Length(py.object(object).py);
    if (length < 0) return PyError.PyRaised;
    return @intCast(length);
}

/// Return the next item of an iterator. Equivalent to next(obj) in Python.
pub fn next(comptime T: type, iterator: anytype) !?T {
    const pyiter = try py.PyIter.checked(iterator);
    return try pyiter.next(T);
}

/// Return "false" if the object is considered to be truthy, and true otherwise.
pub fn not_(object: anytype) !bool {
    const result = ffi.PyObject_Not(py.object(object).py);
    if (result < 0) return PyError.PyRaised;
    return result == 1;
}

/// Return the reference count of the object.
pub fn refcnt(object: anytype) isize {
    const pyobj = py.object(object);
    return pyobj.py.ob_refcnt;
}

/// Compute a string representation of object - using str(o).
pub fn str(object: anytype) !py.PyString {
    const pyobj = py.object(object);
    return py.PyString.unchecked(.{ .py = ffi.PyObject_Str(pyobj.py) orelse return PyError.PyRaised });
}

/// Compute a string representation of object - using repr(o).
pub fn repr(object: anytype) !py.PyString {
    const pyobj = py.object(object);
    return py.PyString.unchecked(.{ .py = ffi.PyObject_Repr(pyobj.py) orelse return PyError.PyRaised });
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
    const pytuple = ffi.PySequence_Tuple(py.object(object).py) orelse return PyError.PyRaised;
    return py.PyTuple.unchecked(.{ .py = pytuple });
}

pub fn type_(object: anytype) !py.PyType {
    return .{ .obj = .{ .py = @as(
        ?*ffi.PyObject,
        @ptrCast(@alignCast(ffi.Py_TYPE(py.object(object).py))),
    ) orelse return PyError.PyRaised } };
}

// TODO(ngates): What's the easiest / cheapest way to do this?
// For now, we just check the name
pub fn self(comptime PydustType: type) !py.PyObject {
    if (@typeInfo(PydustType) != .Struct) {
        @compileError("py.self should be called on a Pydust struct type. e.g. py.self(MyClass)");
    }

    // We import the root module, then grab the class from it.
    const root = try import(State.getRootModule().name);
    defer root.decref();

    // Grab the qualified name, stripping the root module prefix.
    var qualName = State.getIdentifier(PydustType).qualifiedName[1..];

    var mod = root;
    inline for (qualName[0 .. qualName.len - 1]) |part| {
        mod = try mod.get(part);
    }
    const className = qualName[qualName.len - 1];

    return mod.get(className);
}

const testing = std.testing;

test "is_none" {
    py.initialize();
    defer py.finalize();

    const none = None();
    defer none.decref();

    try testing.expect(is_none(none));
}
