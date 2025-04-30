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
pub fn NotImplemented(comptime root: type) py.PyObject(root) {
    // It's important that we incref the Py_NotImplemented singleton
    const notImplemented = py.PyObject(root){ .py = if (ffi.PY_VERSION_HEX < 0x030D0000)
        ffi.Py_NotImplemented()
    else
        ffi.Py_GetConstantBorrowed(ffi.Py_CONSTANT_NOT_IMPLEMENTED) };
    notImplemented.incref();
    return notImplemented;
}

/// Returns a new reference to Py_None.
pub fn None(comptime root: type) py.PyObject(root) {
    // It's important that we incref the Py_None singleton
    const none = py.PyObject(root){ .py = if (ffi.PY_VERSION_HEX < 0x030D0000) 
        ffi.Py_None()
    else
        ffi.Py_GetConstantBorrowed(ffi.Py_CONSTANT_NONE) };
    none.incref();
    return none;
}

/// Returns a new reference to Py_False.
pub inline fn False(comptime root: type) py.PyBool(root) {
    return py.PyBool(root).false_();
}

/// Returns a new reference to Py_True.
pub inline fn True(comptime root: type) py.PyBool(root) {
    return py.PyBool(root).true_();
}

pub inline fn decref(comptime root: type, value: anytype) void {
    py.object(root, value).decref();
}

pub inline fn incref(comptime root: type, value: anytype) void {
    py.object(root, value).incref();
}

/// Checks whether a given object is callable. Equivalent to Python's callable(o).
pub fn callable(comptime root: type, object: anytype) bool {
    const obj = try py.object(root, object);
    return ffi.PyCallable_Check(obj.py) == 1;
}

/// Call a callable object with no arguments.
///
/// If the result is a new reference, then as always the caller is responsible for calling decref on it.
/// That means for new references the caller should ask for a return type that they are unable to decref,
/// for example []const u8.
pub fn call0(comptime root: type, comptime T: type, object: anytype) !T {
    const result = ffi.PyObject_CallNoArgs(py.object(root, object).py) orelse return PyError.PyRaised;
    return try py.as(root, T, result);
}

/// Call a callable object with the given arguments.
///
/// If the result is a new reference, then as always the caller is responsible for calling decref on it.
/// That means for new references the caller should ask for a return type that they are unable to decref,
/// for example []const u8.
pub fn call(comptime root: type, comptime ReturnType: type, object: anytype, args: anytype, kwargs: anytype) !ReturnType {
    const pyobj = py.object(root, object);

    var argsPy = try if (@typeInfo(@TypeOf(args)) == .Optional and args == null)
        py.PyTuple(root).new(0)
    else
        py.PyTuple(root).checked(try py.create(root, args));

    defer argsPy.decref();

    var kwargsPy: ?py.PyDict(root) = null;
    defer {
        if (kwargsPy) |kwpy| {
            kwpy.decref();
        }
    }
    if (!(@typeInfo(@TypeOf(kwargs)) == .Optional and kwargs == null)) {
        // Annoyingly our trampoline turns an empty kwargs struct into a PyTuple.
        // This will be fixed by #94
        const kwobj = try py.create(root, kwargs);
        if (try py.len(root, kwobj) == 0) {
            kwobj.decref();
        } else {
            kwargsPy = try py.PyDict(root).checked(kwobj);
        }
    }

    // Note, the caller is responsible for returning a result type that they are able to decref.
    const result = ffi.PyObject_Call(pyobj.py, argsPy.obj.py, if (kwargsPy) |kwpy| kwpy.obj.py else null) orelse return PyError.PyRaised;
    return try py.as(root, ReturnType, result);
}

/// Convert an object into a dictionary. Equivalent of Python dict(o).
pub fn dict(comptime root: type, object: anytype) !py.PyDict(root) {
    const Dict: py.PyObject = .{ .py = @alignCast(@ptrCast(&ffi.PyDict_Type)) };
    const pyobj = try py.create(root, object);
    defer pyobj.decref();
    return Dict.call(py.PyDict(root), .{pyobj}, .{});
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
pub fn is_none(comptime root: type, object: anytype) bool {
    const obj = py.object(root, object);
    return ffi.Py_IsNone(obj.py) == 1;
}

/// Import a module by fully-qualified name returning a PyObject.
pub fn import(comptime root: type, module_name: [:0]const u8) !py.PyObject(root) {
    return (try py.PyModule(root).import(module_name)).obj;
}

/// Allocate a Pydust class, but does not initialize the memory.
pub fn alloc(comptime root: type, comptime Cls: type) PyError!*Cls {
    const pytype = try self(root, Cls);
    defer pytype.decref();

    // Alloc the class
    // NOTE(ngates): we currently don't allow users to override tp_alloc, therefore we can shortcut
    // using ffi.PyType_GetSlot(tp_alloc) since we know it will always return ffi.PyType_GenericAlloc
    const pyobj: *pytypes.PyTypeStruct(Cls) = @alignCast(@ptrCast(ffi.PyType_GenericAlloc(@ptrCast(pytype.obj.py), 0) orelse return PyError.PyRaised));
    return &pyobj.state;
}

/// Allocate and instantiate a class defined in Pydust.
pub inline fn init(comptime root: type, comptime Cls: type, state: Cls) PyError!*Cls {
    const cls: *Cls = try alloc(root, Cls);
    cls.* = state;
    return cls;
}

/// Check if object is an instance of cls.
pub fn isinstance(comptime root: type, object: anytype, cls: anytype) !bool {
    const pyobj = py.object(root, object);
    const pycls = py.object(root, cls);

    const result = ffi.PyObject_IsInstance(pyobj.py, pycls.py);
    if (result < 0) return PyError.PyRaised;
    return result == 1;
}

/// Return an iterator for the given object if it has one. Equivalent to iter(obj) in Python.
pub fn iter(comptime root: type, object: anytype) !py.PyIter(root) {
    const iterator = ffi.PyObject_GetIter(py.object(root, object).py) orelse return PyError.PyRaised;
    return py.PyIter(root).unchecked(.{ .py = iterator });
}

/// Get the length of the given object. Equivalent to len(obj) in Python.
pub fn len(comptime root: type, object: anytype) !usize {
    const length = ffi.PyObject_Length(py.object(root, object).py);
    if (length < 0) return PyError.PyRaised;
    return @intCast(length);
}

/// Return the runtime module state for a Pydust module definition.
pub fn moduleState(comptime root: type, comptime Module: type) !*Module {
    if (State.getDefinition(root, Module).type != .module) {
        @compileError("Not a module definition: " ++ Module);
    }

    const mod = py.PyModule.unchecked(try lift(root, Module));
    defer mod.decref();

    return mod.getState(Module);
}

/// Return the next item of an iterator. Equivalent to next(obj) in Python.
pub fn next(comptime T: type, iterator: anytype) !?T {
    const pyiter = try py.PyIter.checked(iterator);
    return try pyiter.next(T);
}

/// Return "false" if the object is considered to be truthy, and true otherwise.
pub fn not_(comptime root: type, object: anytype) !bool {
    const result = ffi.PyObject_Not(py.object(root, object).py);
    if (result < 0) return PyError.PyRaised;
    return result == 1;
}

/// Return the reference count of the object.
pub fn refcnt(comptime root: type, object: anytype) isize {
    const pyobj = py.object(root, object);
    return pyobj.refcnt();
}

/// Compute a string representation of object - using str(o).
pub fn str(comptime root: type, object: anytype) !py.PyString(root) {
    const pyobj = py.object(root, object);
    return py.PyString(root).unchecked(.{ .py = ffi.PyObject_Str(pyobj.py) orelse return PyError.PyRaised });
}

/// Compute a string representation of object - using repr(o).
pub fn repr(comptime root: type, object: anytype) !py.PyString(root) {
    const pyobj = py.object(root, object);
    return py.PyString(root).unchecked(.{ .py = ffi.PyObject_Repr(pyobj.py) orelse return PyError.PyRaised });
}

/// Returns the PyType object representing the given Pydust class.
pub fn self(comptime root: type, comptime Class: type) !py.PyType(root) {
    if (State.getDefinition(root, Class).type != .class) {
        @compileError("Not a class definition: " ++ Class);
    }
    return py.PyType(root).unchecked(try lift(root, Class));
}

/// The equivalent of Python's super() builtin. Returns a PyObject.
pub fn super(comptime root: type, comptime Super: type, selfInstance: anytype) !py.PyObject(root) {
    const mod = State.getContaining(root, Super, .module);

    const imported = try import(root, State.getIdentifier(root, mod).name);
    defer imported.decref();

    const superPyType = try imported.get(State.getIdentifier(root, Super).name);
    defer superPyType.decref();

    const superBuiltin: py.PyObject(root) = .{ .py = @alignCast(@ptrCast(&ffi.PySuper_Type)) };
    return superBuiltin.call(.{ superPyType, py.object(root, selfInstance) }, .{});
}

pub fn tuple(comptime root: type, object: anytype) !py.PyTuple(root) {
    const pytuple = ffi.PySequence_Tuple(py.object(root, object).py) orelse return PyError.PyRaised;
    return py.PyTuple(root).unchecked(.{ .py = pytuple });
}

/// Return the PyType object for a given Python object.
/// Returns a borrowed reference.
pub fn type_(comptime root: type, object: anytype) py.PyType(root) {
    return .{ .obj = .{ .py = @as(
        ?*ffi.PyObject,
        @ptrCast(@alignCast(py.object(root, object).py.ob_type)),
    ).? } };
}

pub fn eq(comptime root: type, a: anytype, b: anytype) !bool {
    return compare(root, py.object(root, a), py.object(root, b), py.CompareOp.EQ);
}

pub fn ne(comptime root: type, a: anytype, b: anytype) !bool {
    return compare(root, py.object(root, a), py.object(root, b), py.CompareOp.NE);
}

pub fn lt(comptime root: type, a: anytype, b: anytype) !bool {
    return compare(root, py.object(root, a), py.object(root, b), py.CompareOp.LT);
}

pub fn le(comptime root: type, a: anytype, b: anytype) !bool {
    return compare(root, py.object(root, a), py.object(root, b), py.CompareOp.LE);
}

pub fn gt(comptime root: type, a: anytype, b: anytype) !bool {
    return compare(root, py.object(root, a), py.object(root, b), py.CompareOp.GT);
}

pub fn ge(comptime root: type, a: anytype, b: anytype) !bool {
    return compare(root, py.object(root, a), py.object(root, b), py.CompareOp.GE);
}

inline fn compare(comptime root: type, a: py.PyObject(root), b: py.PyObject(root), op: py.CompareOp) !bool {
    const res = ffi.PyObject_RichCompareBool(a.py, b.py, @intFromEnum(op));
    if (res == -1) {
        return PyError.PyRaised;
    }
    return res == 1;
}

/// Lifts a Pydust struct into its corresponding runtime Python object.
/// Returns a new reference.
fn lift(comptime root: type, comptime PydustStruct: type) !py.PyObject(root) {
    // Grab the qualified name, importing the root module first.
    comptime var qualName = State.getIdentifier(root, PydustStruct).qualifiedName;

    var mod = try import(root, qualName[0]);

    // Recursively resolve submodules / nested classes
    if (comptime qualName.len > 1) {
        inline for (qualName[1 .. qualName.len - 1]) |part| {
            const prev_mod = mod;
            mod = try mod.get(part);
            prev_mod.decref();
        }

        const prev_mod = mod;
        mod = try mod.get(qualName[qualName.len - 1]);
        prev_mod.decref();
    }

    // Grab the attribute using the final part of the qualified name.
    return mod;
}

const testing = std.testing;

test "is_none" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    const none = None(root);
    defer none.decref();

    try testing.expect(is_none(root, none));
}

test "compare" {
    py.initialize();
    defer py.finalize();

    const root = @This();

    const num = try py.PyLong(root).create(0);
    defer num.decref();
    const num2 = try py.PyLong(root).create(1);
    defer num2.decref();

    try testing.expect(try le(root, num, num2));
    try testing.expect(try lt(root, num, num2));
    try testing.expect(!(try ge(root, num, num2)));
    try testing.expect(!(try gt(root, num, num2)));
    try testing.expect(try ne(root, num, num2));
    try testing.expect(!(try eq(root, num, num2)));
}
