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
const builtin = @import("builtin");
const std = @import("std");
const Step = std.Build.Step;
const LazyPath = std.Build.LazyPath;
const GeneratedFile = std.Build.GeneratedFile;

pub const PydustOptions = struct {
    // Optionally pass your test_step and we will hook up the Pydust Zig tests.
    test_step: ?*Step = null,
};

pub const PythonModuleOptions = struct {
    name: [:0]const u8,
    root_source_file: std.Build.LazyPath,
    limited_api: bool = true,
    target: std.Target.Query,
    optimize: std.builtin.Mode,
    main_pkg_path: ?std.Build.LazyPath = null,

    pub fn short_name(self: *const PythonModuleOptions) [:0]const u8 {
        if (std.mem.lastIndexOfScalar(u8, self.name, '.')) |short_name_idx| {
            return self.name[short_name_idx + 1 .. :0];
        }
        return self.name;
    }
};

pub const PythonModule = struct {
    library_step: *std.Build.Step.Compile,
    test_step: *std.Build.Step.Compile,
};

/// Configure a Pydust step in the build. From this, you can define Python modules.
pub fn addPydust(b: *std.Build, options: PydustOptions) *PydustStep {
    return PydustStep.add(b, options);
}

pub const PydustStep = struct {
    owner: *std.Build,
    allocator: std.mem.Allocator,
    options: PydustOptions,

    test_build_step: *Step,
    generate_stubs: *Step,
    check_stubs: bool,

    python_exe: []const u8,
    libpython: []const u8,
    hexversion: []const u8,

    pydust_source_file: []const u8,
    python_include_dir: []const u8,
    python_library_dir: []const u8,

    pub fn add(b: *std.Build, options: PydustOptions) *PydustStep {
        const test_build_step = b.step("pydust-test-build", "Build Pydust test runners");
        const generate_stubs = b.step("generate-stubs", "Generate pyi stubs for the compiled binary");
        const check_stubs = b.option(bool, "check-stubs", "Check that existing stubs are up to date instead of generating new ones") orelse false;

        const python_exe = blk: {
            if (b.option([]const u8, "python-exe", "Python executable to use")) |exe| {
                break :blk exe;
            }
            if (getStdOutput(b.allocator, &.{ "poetry", "env", "info", "--executable" })) |exe| {
                // Strip off the trailing newline
                break :blk exe[0 .. exe.len - 1];
            } else |_| {
                break :blk "python3";
            }
        };

        const libpython = getLibpython(
            b.allocator,
            python_exe,
        ) catch @panic("Cannot find libpython");
        const hexversion = getPythonOutput(
            b.allocator,
            python_exe,
            "import sys; print(f'{sys.hexversion:#010x}', end='')",
        ) catch @panic("Cannot get python hexversion");

        var self = b.allocator.create(PydustStep) catch @panic("OOM");

        self.* = .{
            .owner = b,
            .allocator = b.allocator,
            .options = options,
            .test_build_step = test_build_step,
            .generate_stubs = generate_stubs,
            .check_stubs = check_stubs,
            .python_exe = python_exe,
            .libpython = libpython,
            .hexversion = hexversion,
            .pydust_source_file = "",
            .python_include_dir = "",
            .python_library_dir = "",
        };
        // Eagerly run path discovery to work around ZLS support.
        self.python_include_dir = self.pythonOutput(
            "import os, sysconfig; print(os.path.relpath(sysconfig.get_path('include')), end='')",
        ) catch @panic("Failed to setup Python");
        self.python_library_dir = self.pythonOutput(
            "import os, sysconfig; print(os.path.relpath(sysconfig.get_config_var('LIBDIR')), end='')",
        ) catch @panic("Failed to setup Python");
        self.pydust_source_file = self.pythonOutput(
            "import pydust; import os; print(os.path.relpath(os.path.join(os.path.dirname(pydust.__file__), 'src/pydust.zig')), end='')",
        ) catch @panic("Failed to setup Python");

        // Option for emitting test binary based on the given root source. This can be helpful for debugging.
        const debugRoot = b.option(
            []const u8,
            "debug-root",
            "The root path of a file emitted as a binary for use with the debugger",
        );
        if (debugRoot) |root| {
            {
                const pyconf = b.addOptions();
                pyconf.addOption([:0]const u8, "module_name", "debug");
                pyconf.addOption(bool, "limited_api", false);
                pyconf.addOption([]const u8, "hexversion", hexversion);

                const testdebug = b.addTest(.{
                    .root_source_file = b.path(root),
                    .target = b.resolveTargetQuery(.{}),
                    .optimize = .Debug,
                });
                testdebug.root_module.addOptions("pyconf", pyconf);
                const testdebug_module = b.createModule(.{
                    .root_source_file = b.path(self.pydust_source_file),
                    .imports = &.{.{ .name = "pyconf", .module = pyconf.createModule() }},
                });
                testdebug_module.addIncludePath(b.path(self.python_include_dir));
                testdebug.root_module.addImport("pydust", testdebug_module);
                testdebug.linkLibC();
                testdebug.linkSystemLibrary(libpython);
                testdebug.addLibraryPath(b.path(self.python_library_dir));
                // Needed to support miniconda statically linking libpython on macos
                testdebug.addRPath(b.path(self.python_library_dir));

                const debugBin = b.addInstallBinFile(testdebug.getEmittedBin(), "debug.bin");
                b.getInstallStep().dependOn(&debugBin.step);
            }
        }

        return self;
    }

    /// Adds a Pydust Python module. The resulting library and test binaries can be further configured with
    /// additional dependencies or modules.
    pub fn addPythonModule(self: *PydustStep, options: PythonModuleOptions) PythonModule {
        const b = self.owner;

        const short_name = options.short_name();

        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", options.name);
        pyconf.addOption(bool, "limited_api", options.limited_api);
        pyconf.addOption([]const u8, "hexversion", self.hexversion);

        // Configure and install the Python module shared library
        const lib = b.addSharedLibrary(.{
            .name = short_name,
            .root_source_file = options.root_source_file,
            .target = b.resolveTargetQuery(options.target),
            .optimize = options.optimize,
            //.main_pkg_path = options.main_pkg_path,
        });
        lib.root_module.addOptions("pyconf", pyconf);
        const lib_module = b.createModule(.{
            .root_source_file = b.path(self.pydust_source_file),
            .imports = &.{.{ .name = "pyconf", .module = pyconf.createModule() }},
        });
        lib_module.addIncludePath(b.path(self.python_include_dir));
        lib.root_module.addImport("pydust", lib_module);
        lib.linkLibC();
        lib.linker_allow_shlib_undefined = true;

        // Install the shared library within the source tree
        const install = b.addInstallFileWithDir(
            lib.getEmittedBin(),
            // TODO(ngates): find this somehow?
            .{ .custom = ".." }, // Relative to project root: zig-out/../
            libraryDestRelPath(self.allocator, options) catch @panic("OOM"),
        );
        b.getInstallStep().dependOn(&install.step);

        // Invoke stub generator on the emitted binary
        const workingDir = std.fs.cwd().realpathAlloc(self.allocator, ".") catch @panic("OOM");
        var genArgs: []const []const u8 = undefined;
        if (self.check_stubs) {
            genArgs = &.{ self.python_exe, "-m", "pydust.generate_stubs", options.name, workingDir, "--check" };
        } else {
            genArgs = &.{ self.python_exe, "-m", "pydust.generate_stubs", options.name, workingDir };
        }
        const stubs = b.addSystemCommand(genArgs);
        stubs.step.dependOn(&install.step);
        self.generate_stubs.dependOn(&stubs.step);

        // Configure a test runner for the module
        const libtest = b.addTest(.{
            .root_source_file = options.root_source_file,
            // .main_pkg_path = options.main_pkg_path,
            .target = b.resolveTargetQuery(options.target),
            .optimize = options.optimize,
        });
        libtest.root_module.addOptions("pyconf", pyconf);
        const libtest_module = b.createModule(.{
            .root_source_file = b.path(self.pydust_source_file),
            .imports = &.{.{ .name = "pyconf", .module = pyconf.createModule() }},
        });
        libtest_module.addIncludePath(b.path(self.python_include_dir));
        libtest.root_module.addImport("pydust", libtest_module);
        libtest.linkLibC();
        libtest.linkSystemLibrary(self.libpython);
        libtest.addLibraryPath(b.path(self.python_library_dir));
        // Needed to support miniconda statically linking libpython on macos
        libtest.addRPath(b.path(self.python_library_dir));

        // Install the test binary
        const install_libtest = b.addInstallBinFile(
            libtest.getEmittedBin(),
            testDestRelPath(self.allocator, short_name) catch @panic("OOM"),
        );
        self.test_build_step.dependOn(&install_libtest.step);

        // Run the tests as part of zig build test.
        if (self.options.test_step) |test_step| {
            const run_libtest = b.addRunArtifact(libtest);
            test_step.dependOn(&run_libtest.step);
        }

        return .{
            .library_step = lib,
            .test_step = libtest,
        };
    }

    fn libraryDestRelPath(allocator: std.mem.Allocator, options: PythonModuleOptions) ![]const u8 {
        const name = options.name;

        if (!options.limited_api) {
            @panic("Pydust currently only supports limited API");
        }

        const suffix = ".abi3.so";
        const destPath = try allocator.alloc(u8, name.len + suffix.len);

        // Take the module name, replace dots for slashes.
        @memcpy(destPath[0..name.len], name);
        std.mem.replaceScalar(u8, destPath[0..name.len], '.', '/');

        // Append the suffix
        @memcpy(destPath[name.len..], suffix);

        return destPath;
    }

    fn testDestRelPath(allocator: std.mem.Allocator, short_name: []const u8) ![]const u8 {
        const suffix = ".test.bin";
        const destPath = try allocator.alloc(u8, short_name.len + suffix.len);

        @memcpy(destPath[0..short_name.len], short_name);
        @memcpy(destPath[short_name.len..], suffix);

        return destPath;
    }

    fn pythonOutput(self: *PydustStep, code: []const u8) ![]const u8 {
        return getPythonOutput(self.allocator, self.python_exe, code);
    }
};

fn getLibpython(allocator: std.mem.Allocator, python_exe: []const u8) ![]const u8 {
    const ldlibrary = try getPythonOutput(
        allocator,
        python_exe,
        "import sysconfig; print(sysconfig.get_config_var('LDLIBRARY'), end='')",
    );

    var libname = ldlibrary;

    // Strip libpython3.11.a.so => python3.11.a.so
    if (std.mem.eql(u8, ldlibrary[0..3], "lib")) {
        libname = libname[3..];
    }

    // Strip python3.11.a.so => python3.11.a
    const lastIdx = std.mem.lastIndexOfScalar(u8, libname, '.') orelse libname.len;
    libname = libname[0..lastIdx];

    return libname;
}

fn getPythonOutput(allocator: std.mem.Allocator, python_exe: []const u8, code: []const u8) ![]const u8 {
    const result = try runProcess(.{
        .allocator = allocator,
        .argv = &.{ python_exe, "-c", code },
    });
    if (result.term.Exited != 0) {
        std.debug.print("Failed to execute {s}:\n{s}\n", .{ code, result.stderr });
        std.process.exit(1);
    }
    allocator.free(result.stderr);
    return result.stdout;
}

fn getStdOutput(allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
    const result = try runProcess(.{ .allocator = allocator, .argv = argv });
    if (result.term.Exited != 0) {
        std.debug.print("Failed to execute {any}:\n{s}\n", .{ argv, result.stderr });
        std.process.exit(1);
    }
    allocator.free(result.stderr);
    return result.stdout;
}

const runProcess = if (builtin.zig_version.minor >= 12) std.process.Child.run else std.process.Child.exec;
