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

fn checkArgsParam(comptime Args: type) void {
    const typeInfo = @typeInfo(Args);
    if (typeInfo != .Struct) {
        @compileError("Pydust args must be defined as a struct");
    }

    const fields = typeInfo.Struct.fields;
    var kwargs = false;
    for (fields) |field| {
        if (field.default_value != null) {
            kwargs = true;
        } else {
            if (kwargs) {
                @compileError("Args struct cannot have positional fields after keyword (defaulted) fields");
            }
        }
    }
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
            kwnames: ?*ffi.PyObject,
        ) callconv(.C) ?*ffi.PyObject {
            const allArgs: [*]py.PyObject = @ptrCast(pyargs);
            const args = allArgs[0..@intCast(nargs)];

            const nkwargs = if (kwnames) |names| py.len(names) catch return null else 0;
            const kwargs = allArgs[args.len .. args.len + nkwargs];

            const resultObject = internalKwargs(
                .{ .py = pyself },
                args,
                kwargs,
                if (kwnames) |names| py.PyTuple.of(.{ .py = names }) catch return null else null,
            ) catch |err| return tramp.setErrObj(err);
            return resultObject.py;
        }

        inline fn internalKwargs(pyself: py.PyObject, pyargs: []py.PyObject, pykwargs: []py.PyObject, kwnames: ?py.PyTuple) !py.PyObject {
            const Args = sig.argsParam.?; // We must have args if we know we have kwargs
            var args: Args = undefined;

            if (pyargs.len < argCount(Args)) {
                return py.TypeError.raiseComptimeFmt("expected {d} args", .{argCount(Args)});
            }

            inline for (@typeInfo(Args).Struct.fields, 0..) |field, i| {
                if (field.default_value) |def_value| {
                    // We have a kwarg.
                    const fieldName = try py.PyString.fromSlice(field.name);
                    defer fieldName.decref();

                    const defaultValue: *field.type = @alignCast(@ptrCast(@constCast(def_value)));

                    if (kwnames) |names| {
                        if (try names.contains(fieldName)) {
                            const idx = try names.index(fieldName);
                            const arg = try tramp.Trampoline(field.type).unwrap(pykwargs[idx]);
                            @field(args, field.name) = arg;
                        } else {
                            @field(args, field.name) = defaultValue.*;
                        }
                    } else {
                        @field(args, field.name) = defaultValue.*;
                    }
                } else {
                    // We have an arg
                    const arg = try tramp.Trampoline(field.type).unwrap(pyargs[i]);
                    @field(args, field.name) = arg;
                }
            }

            // Now we loop over the kwnames at runtime and check they all exist in the fieldNames
            const fieldNames = std.meta.fieldNames(Args);
            // TODO(ngates): use PySeq iterator when we support it
            for (0..pykwargs.len) |i| {
                const names = kwnames orelse @panic("Expected kwnames with non-empty kwargs slice");

                const kwname = try (try py.PyString.of(try names.getItem(i))).asSlice();
                var exists = false;
                for (fieldNames) |name| {
                    if (std.mem.eql(u8, name, kwname)) {
                        exists = true;
                        break;
                    }
                }

                if (!exists) {
                    return py.TypeError.raiseFmt("unexpected kwarg '{s}'", .{kwname});
                }
            }

            const self = if (sig.selfParam) |Self| try tramp.Trampoline(Self).unwrap(pyself) else null;
            var callArgs = if (sig.selfParam) |_| .{ self, args } else .{args};
            const result = @call(.always_inline, func, callArgs);
            return tramp.Trampoline(sig.returnType).wrap(result);
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

    if (sig.argsParam) |Args| {
        const fields = @typeInfo(Args).Struct.fields;

        var inKwargs = false;
        for (fields) |field| {
            if (field.default_value == null) {
                // We have an arg
                try sigargs.append(field.name);
            } else {
                // We have a kwarg
                if (!inKwargs) {
                    inKwargs = true;
                    // Marker for end of positional only args
                    try sigargs.append("/");
                    // Marker for start of keyword only args
                    try sigargs.append("*");
                }
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
