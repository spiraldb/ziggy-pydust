const std = @import("std");
const ffi = @import("ffi.zig");
const tramp = @import("trampoline.zig");
const py = @import("pydust.zig");
const PyError = @import("errors.zig").PyError;
const Type = std.builtin.Type;

const MethodType = enum { STATIC, CLASS, INSTANCE };

pub const Signature = struct {
    name: [:0]const u8,
    selfParam: ?Type.Fn.Param = null,
    argsParam: ?Type.Fn.Param = null,
    kwargsParam: ?Type.Fn.Param = null,
    returnType: type,
};

const reservedNames = .{
    "__new__",
    "__init__",
    "__del__",
};

/// Parse the arguments of a Zig function into a Pydust function siganture.
pub fn parseSignature(comptime name: [:0]const u8, comptime func: Type.Fn, comptime SelfTypes: []const type) Signature {
    if (func.params.len > 3) {
        @compileError("Pydust function can have at most 3 parameters. A self ptr, and args and kwargs structs.");
    }

    var sig = Signature{
        // TODO(ngates): is this true?
        .returnType = func.return_type orelse @compileError("Pydust functions must always return or error."),
        .name = name,
    };

    for (func.params, 0..) |param, i| {
        if (i == 0) {
            if (isSelfArg(param, SelfTypes)) {
                sig.selfParam = param;
                continue;
            }
        }

        checkIsValidStructPtr(name, param.type.?);
        if (sig.argsParam != null) {
            sig.kwargsParam = param;
        } else {
            sig.argsParam = param;
        }
    }

    return sig;
}

pub fn isReserved(comptime name: []const u8) bool {
    for (reservedNames) |reserved| {
        if (std.mem.eql(u8, name, reserved)) {
            return true;
        }
    }
    return false;
}

pub fn getSelfParamFn(comptime Cls: type, comptime Self: type, comptime sig: Signature) type {
    return struct {
        pub fn unwrap(pyself: *ffi.PyObject) !sig.selfParam.?.type.? {
            if (sig.selfParam) |param| {
                return switch (param.type.?) {
                    py.PyObject => py.PyObject{ .py = pyself },
                    *Cls => &@fieldParentPtr(Self, "obj", pyself).state,
                    *const Cls => &@fieldParentPtr(Self, "obj", pyself).state,
                    else => @compileError("Unsupported self param type: " ++ @typeName(param.type.?)),
                };
            }
            @compileError("Tried to get pass self param to a function that doesn't expect it");
        }
    };
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

fn checkIsValidStructPtr(comptime funcName: [:0]const u8, comptime paramType: type) void {
    const typeInfo = @typeInfo(paramType);
    if (typeInfo != .Pointer or !typeInfo.Pointer.is_const or @typeInfo(typeInfo.Pointer.child) != .Struct) {
        @compileError("Args and Kwargs must be passed as const struct pointers in function " ++ funcName);
    }
}

pub fn wrap(comptime func: anytype, comptime sig: Signature, comptime selfParamFn: type, comptime flags: c_int) type {
    return struct {
        const Self = @This();

        //const argWrapper = tramp.fromPyObjects(name, sig.argsStruct);
        const resultWrapper = tramp.toPyObject(sig.returnType);

        pub const Doc = docTextSignature(sig);

        pub fn aspy() ffi.PyMethodDef {
            return .{
                .ml_name = sig.name.ptr,
                .ml_meth = @ptrCast(&fastcall),
                .ml_flags = ffi.METH_FASTCALL | flags,
                .ml_doc = &Doc,
            };
        }

        fn fastcall(
            pyself: *ffi.PyObject,
            pyargs: [*]ffi.PyObject,
            nargs: ffi.Py_ssize_t,
        ) callconv(.C) ?*ffi.PyObject {
            return fastcallInternal(pyself, pyargs, nargs) catch |err| tramp.setErrObj(err);
        }

        inline fn fastcallInternal(
            pyself: *ffi.PyObject,
            pyargs: [*]ffi.PyObject,
            nargs: ffi.Py_ssize_t,
        ) !?*ffi.PyObject {
            if (sig.selfParam == null) {
                // fn()
                if (sig.argsParam == null) {
                    // TODO(ngates): mark other function calls as always_inline?
                    return resultWrapper.unwrap(@call(.always_inline, func, .{}));
                }

                // fn(args)
                if (sig.kwargsParam == null) {
                    return resultWrapper.unwrap(func(try getArgs(pyargs, nargs)));
                }

                // fn(args, kwargs)
                @compileError("Kwargs are unsupported");
            } else {
                const selfParam = selfParamFn.unwrap(pyself) catch |err| return tramp.setErrObj(err);

                // fn(self)
                if (sig.argsParam == null) {
                    return resultWrapper.unwrap(func(selfParam));
                }

                // fn(self, args)
                if (sig.kwargsParam == null) {
                    return resultWrapper.unwrap(func(selfParam, try getArgs(pyargs, nargs)));
                }

                // fn(self, args, kwargs)
                @compileError("Kwargs are unsupported");
            }
        }

        // Cast the Python arguments into the requested argument struct.
        fn getArgs(pyargs: [*]ffi.PyObject, nargs: ffi.Py_ssize_t) !sig.argsParam.?.type.? {
            if (@typeInfo(@typeInfo(sig.argsParam.?.type.?).Pointer.child).Struct.fields.len != nargs) {
                return py.TypeError.raise("Incorrect number of arguments");
            }
            return @ptrCast(pyargs[0..@intCast(nargs)]);
        }
    };
}

/// Generate minimal function docstring to populate __text_signature__ function field.
/// Format is `funcName($self, arg0Name...)\n--\n\n`.
/// Self arg can be named however but must start with `$`
fn docTextSignature(comptime sig: Signature) [sigSize(sig):0]u8 {
    const args = sigArgs(sig) catch @compileError("Too many arguments");
    const argSize = sigSize(sig);

    var buffer: [argSize:0]u8 = undefined;
    writeTextSig(sig.name, args, &buffer) catch @compileError("Text signature buffer is too small");
    return buffer;
}

fn writeTextSig(name: []const u8, args: []const []const u8, buffer: [:0]u8) !void {
    var buf = std.io.fixedBufferStream(buffer);
    const writer = buf.writer();
    try writer.writeAll(name[0 .. name.len - 1]);
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

fn sigSize(comptime sig: Signature) usize {
    const args = sigArgs(sig) catch @compileError("Too many arguments");
    var argSize: u64 = sig.name.len - 1;
    // Count the size of the output string
    for (args) |arg| {
        argSize += arg.len + 2;
    }

    if (args.len > 0) {
        argSize -= 2;
    }

    // The size is the size of all arguments plus the padding after argument list
    return argSize + 8;
}

fn sigArgs(comptime sig: Signature) ![]const []const u8 {
    var sigargs: std.BoundedArray([]const u8, 100) = std.BoundedArray([]const u8, 100).init(0) catch @compileError("OOM");
    if (sig.selfParam) |_| {
        try sigargs.append("$self");
    }
    if (sig.argsParam) |argParam| {
        // Insert marker for positional only args
        try sigargs.append("/");
        // Assume struct pointer
        if (!std.meta.trait.is(.Pointer)(argParam.type.?) and !std.meta.trait.is(.Struct)(@typeInfo(@typeInfo(argParam.type.?).Pointer.child))) {
            @compileError("ArgParam can only be a struct pointer");
        }
        for (@typeInfo(@typeInfo(argParam.type.?).Pointer.child).Struct.fields) |field| {
            try sigargs.append(field.name);
        }
    }
    if (sig.kwargsParam) |_| {
        // Insert marker for keywords only args
        try sigargs.append("*");
        @compileError("Kwargs are not supported");
    }

    return sigargs.constSlice();
}
