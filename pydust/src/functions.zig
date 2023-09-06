const std = @import("std");
const ffi = @import("ffi.zig");
const tramp = @import("trampoline.zig");
const py = @import("pydust.zig");
const PyError = @import("errors.zig").PyError;
const Type = std.builtin.Type;

const MethodType = enum { STATIC, CLASS, INSTANCE };

pub const Signature = struct {
    name: []const u8,
    selfParam: ?type = null,
    argsParam: ?type = null,
    returnType: type,
    nargs: usize = 0,
    nkwargs: usize = 0,
};

const reservedNames = .{
    "__new__",
    "__init__",
    "__len__",
    "__del__",
    "__buffer__",
    "__release_buffer__",
};

/// Parse the arguments of a Zig function into a Pydust function siganture.
pub fn parseSignature(comptime name: []const u8, comptime func: Type.Fn, comptime SelfTypes: []const type) Signature {
    var sig = Signature{
        // TODO(ngates): is this true?
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
                if (@typeInfo(param.type.?) != .Struct) {
                    // TODO(ngates): check there are no args after kwargs.
                    @compileError("Pydust arguments must be defined in a struct");
                }
                sig.argsParam = param.type.?;
            }
        },
        0 => {},
        else => @compileError("Pydust function can have at most 2 parameters. A self ptr and a parameters struct."),
    }

    // Count up the parameters
    if (sig.argsParam) |p| {
        sig.nargs = argCount(p);
        sig.nkwargs = kwargCount(p);
    }

    return sig;
}

pub fn argCount(comptime argsParam: type) usize {
    var n: usize = 0;
    inline for (@typeInfo(argsParam).Struct.fields) |field| {
        if (field.default_value == null) {
            n += 1;
        }
    }
    return n;
}

pub fn kwargCount(comptime argsParam: type) usize {
    var n: usize = 0;
    inline for (@typeInfo(argsParam).Struct.fields) |field| {
        if (field.default_value != null) {
            n += 1;
        }
    }
    return n;
}

pub fn isReserved(comptime name: []const u8) bool {
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

pub fn wrap(comptime func: anytype, comptime sig: Signature, comptime flags: c_int) type {
    return struct {
        const doc = docTextSignature(sig);

        /// Return a PyMethodDef for this wrapped function.
        pub fn aspy() ffi.PyMethodDef {
            return .{
                .ml_name = sig.name.ptr ++ "",
                .ml_meth = if (sig.nkwargs > 0) @ptrCast(&fastcallKwargs) else @ptrCast(&fastcall),
                .ml_flags = ffi.METH_FASTCALL | flags | if (sig.nkwargs > 0) ffi.METH_KEYWORDS else 0,
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
                @as([*]py.PyObject, @ptrCast(pyargs))[0..@intCast(nargs)],
            ) catch |err| return tramp.setErrObj(err);
            return resultObject.py;
        }

        inline fn internal(pyself: py.PyObject, pyargs: []py.PyObject) !py.PyObject {
            const self = if (sig.selfParam) |Self| try tramp.Trampoline(Self).unwrap(pyself) else null;
            const resultTrampoline = tramp.Trampoline(sig.returnType);

            if (sig.argsParam) |Args| {
                // Create an args struct and populate it with pyargs.
                var args: Args = undefined;
                if (argCount(Args) != pyargs.len) {
                    return py.TypeError.raiseComptimeFmt("expected {d} args", .{argCount(Args)});
                }
                inline for (@typeInfo(Args).Struct.fields, 0..) |field, i| {
                    @field(args, field.name) = try tramp.Trampoline(field.type).unwrap(pyargs[i]);
                }

                var callArgs = if (sig.selfParam) |_| .{ self, args } else .{args};
                const result = @call(.always_inline, func, callArgs);
                return resultTrampoline.wrap(result);
            } else {
                var callArgs = if (sig.selfParam) |_| .{self} else .{};
                const result = @call(.always_inline, func, callArgs);
                return resultTrampoline.wrap(result);
            }
        }

        fn fastcallKwargs(
            pyself: *ffi.PyObject,
            pyargs: [*]ffi.PyObject,
            nargs: ffi.Py_ssize_t,
            kwnames: *ffi.PyObject,
        ) callconv(.C) ?*ffi.PyObject {
            return internalKwargs(
                .{ .py = pyself },
                @as([*]py.PyObject, @ptrCast(pyargs))[0..nargs],
                py.PyTuple.of(.{ .py = kwnames }),
            ) catch |err| tramp.setErrObj(err);
        }

        inline fn internalKwargs(pyself: py.PyObject, pyargs: []py.PyObject, kwnames: py.PyTuple) !py.PyObject {
            _ = kwnames;
            _ = pyargs;
            _ = pyself;
        }
    };

    // return struct {
    //     const Self = @This();

    //     //const argWrapper = tramp.fromPyObjects(name, sig.argsStruct);
    //     const resultWrapper = tramp.Trampoline(sig.returnType);

    //     pub fn aspy() ffi.PyMethodDef {
    //         return .{
    //             .ml_name = sig.name.ptr ++ "",
    //             .ml_meth = @ptrCast(&fastcall),
    //             .ml_flags = ffi.METH_FASTCALL | flags,
    //             .ml_doc = &Doc,
    //         };
    //     }

    //     fn fastcall(
    //         pyself: *ffi.PyObject,
    //         pyargs: [*]ffi.PyObject,
    //         nargs: ffi.Py_ssize_t,
    //     ) callconv(.C) ?*ffi.PyObject {
    //         return fastcallInternal(pyself, pyargs, nargs) catch |err| tramp.setErrObj(err);
    //     }

    //     inline fn fastcallInternal(
    //         pyself: *ffi.PyObject,
    //         pyargs: [*]ffi.PyObject,
    //         nargs: ffi.Py_ssize_t,
    //     ) !?*ffi.PyObject {
    //         if (sig.selfParam) |selfParam| {
    //             _ = selfParam;
    //             const self = try tramp.Trampoline(sig.selfParam.?).unwrap(.{ .py = pyself });

    //             // fn(self)
    //             if (sig.argsParam == null) {
    //                 return resultWrapper.wrapRaw(func(self));
    //             }

    //             // fn(self, args)
    //             return resultWrapper.wrapRaw(func(self, try getArgs(pyargs, nargs)));
    //         } else {
    //             // fn()
    //             if (sig.argsParam == null) {
    //                 // TODO(ngates): mark other function calls as always_inline?
    //                 return resultWrapper.wrapRaw(@call(.always_inline, func, .{}));
    //             }

    //             // fn(args)
    //             return resultWrapper.wrapRaw(func(try getArgs(pyargs, nargs)));
    //         }
    //     }

    //     // Cast the Python arguments into the requested argument struct.
    //     fn getArgs(pyargs: [*]ffi.PyObject, nargs: ffi.Py_ssize_t) !sig.argsParam.? {
    //         if (@typeInfo(@typeInfo(sig.argsParam.?).Pointer.child).Struct.fields.len != nargs) {
    //             return py.TypeError.raise("Incorrect number of arguments");
    //         }
    //         return @ptrCast(pyargs[0..@intCast(nargs)]);
    //     }
    // };
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

fn sigSize(comptime sig: Signature) usize {
    const args = sigArgs(sig) catch @compileError("Too many arguments");
    var argSize: u64 = sig.name.len;
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
        if (!std.meta.trait.is(.Struct)(argParam)) {
            @compileError("ArgParam can only be a struct");
        }
        for (@typeInfo(argParam).Struct.fields) |field| {
            try sigargs.append(field.name);
        }
    }
    // if (sig.kwargsParam) |_| {
    //     // Insert marker for keywords only args
    //     try sigargs.append("*");
    //     @compileError("Kwargs are not supported");
    // }

    return sigargs.constSlice();
}
