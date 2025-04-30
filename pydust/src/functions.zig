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
const ffi = @import("ffi.zig");
const py = @import("pydust.zig");
const tramp = @import("trampoline.zig");
const State = @import("discovery.zig").State;
const PyError = @import("errors.zig").PyError;
const Type = std.builtin.Type;

const MethodType = enum { STATIC, CLASS, INSTANCE };

pub fn Signature(comptime root: type) type {
    return struct {
        name: []const u8,
        selfParam: ?type = null,
        argsParam: ?type = null,
        returnType: type,
        nargs: usize = 0,
        nkwargs: usize = 0,
        varargsIdx: ?usize = null,
        varkwargsIdx: ?usize = null,

        pub fn supportsKwargs(comptime self: @This()) bool {
            return self.nkwargs > 0 or self.varkwargsIdx != null;
        }

        pub fn isModuleMethod(comptime self: @This()) bool {
            if (self.selfParam) |Self| {
                return State.getDefinition(root, @typeInfo(Self).pointer.child).type == .module;
            }
            return false;
        }
    };
}

pub const UnaryOperators = std.StaticStringMap(c_int).initComptime(.{
    .{ "__neg__", ffi.Py_nb_negative },
    .{ "__pos__", ffi.Py_nb_positive },
    .{ "__abs__", ffi.Py_nb_absolute },
    .{ "__invert__", ffi.Py_nb_invert },
    .{ "__int__", ffi.Py_nb_int },
    .{ "__float__", ffi.Py_nb_float },
    .{ "__index__", ffi.Py_nb_index },
});

pub const BinaryOperators = std.StaticStringMap(c_int).initComptime(.{
    .{ "__add__", ffi.Py_nb_add },
    .{ "__iadd__", ffi.Py_nb_inplace_add },
    .{ "__sub__", ffi.Py_nb_subtract },
    .{ "__isub__", ffi.Py_nb_inplace_subtract },
    .{ "__mul__", ffi.Py_nb_multiply },
    .{ "__imul__", ffi.Py_nb_inplace_multiply },
    .{ "__mod__", ffi.Py_nb_remainder },
    .{ "__imod__", ffi.Py_nb_inplace_remainder },
    .{ "__divmod__", ffi.Py_nb_divmod },
    .{ "__pow__", ffi.Py_nb_power },
    .{ "__ipow__", ffi.Py_nb_inplace_power },
    .{ "__lshift__", ffi.Py_nb_lshift },
    .{ "__ilshift__", ffi.Py_nb_inplace_lshift },
    .{ "__rshift__", ffi.Py_nb_rshift },
    .{ "__irshift__", ffi.Py_nb_inplace_rshift },
    .{ "__and__", ffi.Py_nb_and },
    .{ "__iand__", ffi.Py_nb_inplace_and },
    .{ "__xor__", ffi.Py_nb_xor },
    .{ "__ixor__", ffi.Py_nb_inplace_xor },
    .{ "__or__", ffi.Py_nb_or },
    .{ "__ior__", ffi.Py_nb_inplace_or },
    .{ "__truediv__", ffi.Py_nb_true_divide },
    .{ "__itruediv__", ffi.Py_nb_inplace_true_divide },
    .{ "__floordiv__", ffi.Py_nb_floor_divide },
    .{ "__ifloordiv__", ffi.Py_nb_inplace_floor_divide },
    .{ "__matmul__", ffi.Py_nb_matrix_multiply },
    .{ "__imatmul__", ffi.Py_nb_inplace_matrix_multiply },
    .{ "__getitem__", ffi.Py_mp_subscript },
    .{ "__getattr__", ffi.Py_tp_getattro },
});

// TODO(marko): Move this somewhere.
fn keys(comptime stringMap: type) [stringMap.kvs.len][]const u8 {
    var keys_: [stringMap.kvs.len][]const u8 = undefined;
    for (stringMap.kvs, 0..) |kv, i| {
        keys_[i] = kv.key;
    }
    return keys_;
}

pub const compareFuncs = .{
    "__lt__",
    "__le__",
    "__eq__",
    "__ne__",
    "__gt__",
    "__ge__",
};

const reservedNames = .{
    "__bool__",
    "__buffer__",
    "__del__",
    "__hash__",
    "__init__",
    "__iter__",
    "__len__",
    "__new__",
    "__next__",
    "__release_buffer__",
    "__repr__",
    "__richcompare__",
    "__str__",
} ++ compareFuncs ++ BinaryOperators.keys() ++ UnaryOperators.keys();

/// Parse the arguments of a Zig function into a Pydust function siganture.
pub fn parseSignature(comptime root: type, comptime name: []const u8, comptime func: Type.Fn, comptime SelfTypes: []const type) Signature(root) {
    var sig = Signature(root){
        .returnType = func.return_type orelse @compileError("Pydust functions must always return or error."),
        .name = name,
    };

    switch (func.params.len) {
        2 => {
            sig.selfParam = func.params[0].type.?;
            sig.argsParam = func.params[1].type.?;
        },
        1 => {
            const param = func.params[0];
            if (isSelfArg(param, SelfTypes)) {
                sig.selfParam = param.type.?;
            } else {
                sig.argsParam = param.type.?;
                checkArgsParam(sig.argsParam.?);
            }
        },
        0 => {},
        else => @compileError("Pydust function can have at most 2 parameters. A self ptr and a parameters struct."),
    }

    // Count up the parameters
    if (sig.argsParam) |p| {
        sig.nargs = argCount(root, p);
        sig.nkwargs = kwargCount(root, p);
        sig.varargsIdx = varArgsIdx(root, p);
        sig.varkwargsIdx = varKwargsIdx(root, p);
    }

    return sig;
}

pub fn argCount(comptime root: type, comptime ArgsParam: type) usize {
    var n: usize = 0;
    inline for (@typeInfo(ArgsParam).@"struct".fields) |field| {
        if (field.type != py.Args(root) and field.type != py.Kwargs(root) and field.defaultValue() == null) {
            n += 1;
        }
    }
    return n;
}

pub fn kwargCount(comptime root: type, comptime ArgsParam: type) usize {
    var n: usize = 0;
    inline for (@typeInfo(ArgsParam).@"struct".fields) |field| {
        if (field.type != py.Args(root) and field.type != py.Kwargs(root) and field.defaultValue() != null) {
            n += 1;
        }
    }
    return n;
}

pub fn varArgsIdx(comptime root: type, comptime ArgsParam: type) ?usize {
    const info = @typeInfo(ArgsParam).@"struct";
    for (info.fields, 0..) |field, i| {
        if (field.type == py.Args(root)) {
            return i;
        }
    }
    return null;
}

pub fn varKwargsIdx(comptime root: type, comptime ArgsParam: type) ?usize {
    const info = @typeInfo(ArgsParam).@"struct";
    for (info.fields, 0..) |field, i| {
        if (field.type == py.Kwargs(root)) {
            return i;
        }
    }
    return null;
}

fn isReserved(comptime name: []const u8) bool {
    @setEvalBranchQuota(10000);
    for (reservedNames) |reserved| {
        if (std.mem.eql(u8, name, reserved)) {
            return true;
        }
    }
    return false;
}

/// Check whether the first parameter of the function is one of the valid "self" types.
fn isSelfArg(comptime param: Type.Fn.Param, comptime SelfTypes: []const type) bool {
    for (SelfTypes) |SelfType| {
        if (param.type.? == SelfType) {
            return true;
        }
    }
    return false;
}

fn checkArgsParam(comptime Args: type) void {
    const typeInfo = @typeInfo(Args);
    if (typeInfo != .@"struct") {
        @compileError("Pydust args must be defined as a struct");
    }

    const fields = typeInfo.@"struct".fields;
    var kwargs = false;
    for (fields) |field| {
        if (field.defaultValue() != null) {
            kwargs = true;
        } else {
            if (kwargs) {
                @compileError("Args struct cannot have positional fields after keyword (defaulted) fields");
            }
        }
    }
}

pub fn wrap(comptime root: type, comptime definition: type, comptime func: anytype, comptime sig: Signature(root), comptime flags: c_int) type {
    return struct {
        const doc = textSignature(root, sig);

        /// Return a PyMethodDef for this wrapped function.
        pub fn aspy() ffi.PyMethodDef {
            return .{
                .ml_name = sig.name.ptr,
                .ml_meth = if (sig.supportsKwargs()) @ptrCast(&fastcallKwargs) else @ptrCast(&fastcall),
                .ml_flags = blk: {
                    var ml_flags: c_int = ffi.METH_FASTCALL | flags;

                    // We can only set METH_STATIC and METH_CLASS on class methods, not module methods.
                    if (State.getDefinition(root, definition).type == .class and sig.selfParam == null) {
                        ml_flags |= ffi.METH_STATIC;
                    }
                    // TODO(ngates): check for METH_CLASS

                    if (sig.supportsKwargs()) {
                        ml_flags |= ffi.METH_KEYWORDS;
                    }

                    break :blk ml_flags;
                },
                .ml_doc = &doc,
            };
        }

        fn fastcall(
            pyself: *ffi.PyObject,
            pyargs: [*]ffi.PyObject,
            nargs: ffi.Py_ssize_t,
        ) callconv(.C) ?*ffi.PyObject {
            const resultObject = internal(
                .{ .py = pyself },
                @as([*]py.PyObject(root), @ptrCast(pyargs))[0..@intCast(nargs)],
            ) catch return null;
            return resultObject.py;
        }

        inline fn internal(pyself: py.PyObject(root), pyargs: []py.PyObject(root)) PyError!py.PyObject(root) {
            const self = if (sig.selfParam) |Self| try castSelf(Self, pyself) else null;

            if (sig.argsParam) |Args| {
                const args = try unwrapArgs(root, Args, pyargs, py.Kwargs(root).init(py.allocator));
                const result = if (sig.selfParam) |_| func(self, args) else func(args);
                return py.createOwned(root, tramp.coerceError(root, result));
            } else {
                const result = if (sig.selfParam) |_| func(self) else func();
                return py.createOwned(root, tramp.coerceError(root, result));
            }
        }

        fn fastcallKwargs(
            pyself: *ffi.PyObject,
            pyargs: [*]ffi.PyObject,
            nargs: ffi.Py_ssize_t,
            kwnames: ?*ffi.PyObject,
        ) callconv(.C) ?*ffi.PyObject {
            const allArgs: [*]py.PyObject(root) = @ptrCast(pyargs);
            const args = allArgs[0..@intCast(nargs)];

            const nkwargs = if (kwnames) |names| py.len(root, names) catch return null else 0;
            const kwargs = allArgs[args.len .. args.len + nkwargs];

            // Construct a StringHashMap of keyword arguments.
            var kwargsMap = py.Kwargs(root).init(py.allocator);
            defer kwargsMap.deinit();
            if (kwnames) |rawnames| {
                const names = py.PyTuple(root).unchecked(.{ .py = rawnames });
                std.debug.assert(names.length() == kwargs.len);
                for (0..names.length(), kwargs) |i, v| {
                    const k = names.getItem(py.PyString(root), i) catch return null;
                    kwargsMap.put(k.asSlice() catch return null, v) catch return null;
                }
            }

            const resultObject = internalKwargs(.{ .py = pyself }, args, kwargsMap) catch return null;
            return resultObject.py;
        }

        inline fn internalKwargs(
            pyself: py.PyObject(root),
            pyargs: py.Args(root),
            pykwargs: py.Kwargs(root),
        ) PyError!py.PyObject(root) {
            const args = try unwrapArgs(root, sig.argsParam.?, pyargs, pykwargs);
            const self = if (sig.selfParam) |Self| try castSelf(Self, pyself) else null;
            const result = if (sig.selfParam) |_| func(self, args) else func(args);
            return py.createOwned(root, tramp.coerceError(root, result));
        }

        inline fn castSelf(comptime Self: type, pyself: py.PyObject(root)) !Self {
            if (comptime sig.isModuleMethod()) {
                const mod = py.PyModule(root){ .obj = pyself };
                return try mod.getState(@typeInfo(Self).pointer.child);
            } else {
                return py.unchecked(root, Self, pyself);
            }
        }
    };
}

/// Unwrap the args and kwargs into the requested args struct.
pub fn unwrapArgs(comptime root: type, comptime Args: type, pyargs: py.Args(root), pykwargs: py.Kwargs(root)) !Args {
    var kwargs = pykwargs;
    var args: Args = undefined;

    const s = @typeInfo(Args).@"struct";
    var argIdx: usize = 0;
    inline for (s.fields) |field| {
        if (field.defaultValue()) |def_value| {
            // We have a kwarg.
            if (kwargs.fetchRemove(field.name)) |entry| {
                @field(args, field.name) = try py.as(root, field.type, entry.value);
            } else {
                // Use the default value
                @field(args, field.name) = def_value;
            }
        } else if (field.type != py.Args(root) and field.type != py.Kwargs(root)) {
            // Otherwise, we have a regular argument.
            if (argIdx >= pyargs.len) {
                return py.TypeError(root).raiseFmt("Expected {d} arg{s}", .{
                    argCount(root, Args), if (argCount(root, Args) > 1) "s" else "",
                });
            }
            const value = pyargs[argIdx];
            argIdx += 1;
            @field(args, field.name) = try py.as(root, field.type, value);
        }
    }

    // Now to handle var args.
    if (argIdx < pyargs.len and comptime varArgsIdx(root, Args) == null) {
        return py.TypeError(root).raiseFmt("Too many args, expected {d}", .{argCount(root, Args)});
    }
    if (comptime varArgsIdx(root, Args)) |idx| {
        @field(args, s.fields[idx].name) = pyargs[argIdx..];
    }

    if (kwargs.count() > 0 and comptime varKwargsIdx(root, Args) == null) {
        var iterator = kwargs.keyIterator();
        return py.TypeError(root).raiseFmt("Unexpected kwarg '{s}'", .{iterator.next().?.*});
    }
    if (comptime varKwargsIdx(root, Args)) |idx| {
        @field(args, s.fields[idx].name) = kwargs;
    }

    return args;
}

pub fn Methods(comptime root: type, comptime definition: type) type {
    const empty = ffi.PyMethodDef{ .ml_name = null, .ml_meth = null, .ml_flags = 0, .ml_doc = null };

    return struct {
        const methodCount = b: {
            var mc: u32 = 0;
            for (@typeInfo(definition).@"struct".decls) |decl| {
                // TODO: FIXME
                const value = @field(definition, decl.name);
                const typeInfo = @typeInfo(@TypeOf(value));

                if (typeInfo != .@"fn" or isReserved(decl.name)) { // or State.isPrivate(root, &value)) {
                    continue;
                }
                mc += 1;
            }
            break :b mc;
        };

        pub const pydefs: [methodCount + 1]ffi.PyMethodDef = blk: {
            var defs: [methodCount + 1]ffi.PyMethodDef = undefined;

            var idx: u32 = 0;
            @setEvalBranchQuota(10000);
            for (@typeInfo(definition).@"struct".decls) |decl| {
                const value = @field(definition, decl.name);
                const typeInfo = @typeInfo(@TypeOf(value));

                // For now, we skip non-function declarations.
                // TODO: FIXME
                if (typeInfo != .@"fn" or isReserved(decl.name)) { // or State.isPrivate(root, &value)) {
                    continue;
                }

                const sig = parseSignature(root, decl.name, typeInfo.@"fn", &.{ py.PyObject(root), *definition, *const definition });
                defs[idx] = wrap(root, definition, value, sig, 0).aspy();
                idx += 1;
            }
            defs[methodCount] = empty;

            break :blk defs;
        };
    };
}

/// Generate minimal function docstring to populate __text_signature__ function field.
/// Format is `funcName($self, arg0Name...)\n--\n\n`.
/// Self arg can be named however but must start with `$`
pub fn textSignature(comptime root: type, comptime sig: Signature(root)) [sigSize(root, sig):0]u8 {
    const args = sigArgs(root, sig) catch @compileError("Too many arguments");
    const argSize = sigSize(root, sig);

    var buffer: [argSize:0]u8 = undefined;
    writeTextSig(sig.name, args, &buffer) catch @compileError("Text signature buffer is too small");
    return buffer;
}

fn writeTextSig(name: []const u8, args: []const []const u8, buffer: [:0]u8) !void {
    var buf = std.io.fixedBufferStream(buffer);
    const writer = buf.writer();
    try writer.writeAll(name);
    try writer.writeByte('(');
    for (args, 0..) |arg, i| {
        try writer.writeAll(arg);

        if (i < args.len - 1) {
            try writer.writeAll(", ");
        }
    }
    try writer.writeAll(")\n--\n\n");
    buffer[buffer.len] = 0;
}

fn sigSize(comptime root: type, comptime sig: Signature(root)) usize {
    const args = sigArgs(root, sig) catch @compileError("Too many arguments");
    var argSize: u64 = sig.name.len;
    // Count the size of the output string
    for (args) |arg| {
        // +2 for ", "
        argSize += arg.len + 2;
    }

    if (args.len > 0) {
        argSize -= 2;
    }

    // The size is the size of all arguments plus the padding after argument list
    // "(" + ")\n--\n\n" => 7
    return argSize + 7;
}

fn sigArgs(comptime root: type, comptime sig: Signature(root)) ![]const []const u8 {
    // 5 = self + "/" + "*" + "*args" + "**kwargs"
    const ArgBuf = std.BoundedArray([]const u8, sig.nargs + sig.nkwargs + 5);
    var sigargs = ArgBuf.init(0) catch @compileError("OOM");
    if (sig.selfParam) |self| {
        if (self == @TypeOf(py.PyObject(root))) {
            try sigargs.append("$cls");
        } else {
            try sigargs.append("$self");
        }
    }

    if (sig.argsParam) |Args| {
        const fields = @typeInfo(Args).@"struct".fields;

        var inKwargs = false;
        var inVarargs = false;
        for (fields) |field| {
            if (field.defaultValue()) |def| {
                // We have a kwarg
                if (!inKwargs) {
                    inKwargs = true;
                    // Marker for end of positional only args
                    try sigargs.append("/");
                    // Marker for start of keyword only args
                    try sigargs.append("*");
                }

                try sigargs.append(std.fmt.comptimePrint("{s}={s}", .{ field.name, valueToStr(field.type, &def) }));
            } else if (field.type == py.Args(root)) {
                if (!inVarargs) {
                    inVarargs = true;
                    // Marker for end of positional only args
                    try sigargs.append("/");
                }
                try sigargs.append(std.fmt.comptimePrint("*{s}", .{field.name}));
            } else if (field.type == py.Kwargs(root)) {
                if (!inKwargs) {
                    inKwargs = true;
                    if (!inVarargs) {
                        // Marker for end of positional only args unless varargs (*args) is present
                        try sigargs.append("/");
                    }
                    // Note: we don't mark the start of keyword only args since that's implied by **.
                    // See https://bugs.python.org/issue2613
                }
                try sigargs.append(std.fmt.comptimePrint("**{s}", .{field.name}));
            } else {
                // We have an arg
                try sigargs.append(field.name);
            }
        }

        if (!inKwargs) {
            // Always mark end of positional only args
            try sigargs.append("/");
        }
    }

    return sigargs.constSlice();
}

fn valueToStr(comptime T: type, value: *const anyopaque) []const u8 {
    return switch (@typeInfo(T)) {
        inline .pointer => |p| p: {
            break :p switch (p.child) {
                inline u8 => std.fmt.comptimePrint("\"{s}\"", .{@as(*const T, @alignCast(@ptrCast(value))).*}),
                inline else => "...",
            };
        },
        inline .bool => if (@as(*const bool, @ptrCast(value)).*) "True" else "False",
        inline .@"struct" => "...",
        inline .optional => |o| if (@as(*const ?o.child, @alignCast(@ptrCast(value))).* == null) "None" else "...",
        inline else => std.fmt.comptimePrint("{any}", .{@as(*const T, @alignCast(@ptrCast(value))).*}),
    };
}
