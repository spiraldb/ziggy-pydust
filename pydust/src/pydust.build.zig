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
    target: std.zig.CrossTarget,
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
    library_step: *std.build.CompileStep,
    test_step: *std.build.CompileStep,
};

/// Configure a Pydust step in the build. From this, you can define Python modules.
pub fn addPydust(b: *std.Build, options: PydustOptions) *PydustStep {
    return PydustStep.add(b, options);
}

pub const PydustStep = struct {
    step: Step,
    allocator: std.mem.Allocator,
    options: PydustOptions,

    test_build_step: *Step,

    python_exe: []const u8,
    libpython: []const u8,
    hexversion: []const u8,

    pydust_source_file: GeneratedFile,
    python_include_dir: GeneratedFile,
    python_library_dir: GeneratedFile,

    pub fn add(b: *std.Build, options: PydustOptions) *PydustStep {
        const test_build_step = b.step("pydust-test-build", "Build Pydust test runners");

        const python_exe = b.option([]const u8, "python-exe", "Python executable to use") orelse "python3";

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
            .step = Step.init(.{
                .id = .custom,
                .name = "configure pydust",
                .owner = b,
                .makeFn = make,
            }),
            .allocator = b.allocator,
            .options = options,
            .test_build_step = test_build_step,
            .python_exe = python_exe,
            .libpython = libpython,
            .hexversion = hexversion,
            .pydust_source_file = .{ .step = &self.step },
            .python_include_dir = .{ .step = &self.step },
            .python_library_dir = .{ .step = &self.step },
        };

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

                const testdebug = b.addTest(.{ .root_source_file = .{ .path = root }, .target = .{}, .optimize = .Debug });
                testdebug.addOptions("pyconf", pyconf);
                testdebug.addAnonymousModule("pydust", .{
                    .source_file = .{ .generated = &self.pydust_source_file },
                    .dependencies = &.{.{ .name = "pyconf", .module = pyconf.createModule() }},
                });
                testdebug.addIncludePath(.{ .generated = &self.python_include_dir });
                testdebug.linkLibC();
                testdebug.linkSystemLibrary(libpython);
                testdebug.addLibraryPath(.{ .generated = &self.python_library_dir });
                // Needed to support miniconda statically linking libpython on macos
                testdebug.addRPath(.{ .generated = &self.python_library_dir });

                const debugBin = b.addInstallBinFile(testdebug.getEmittedBin(), "debug.bin");
                b.getInstallStep().dependOn(&debugBin.step);
            }
        }

        return self;
    }

    /// Adds a Pydust Python module. The resulting library and test binaries can be further configured with
    /// additional dependencies or modules.
    pub fn addPythonModule(self: *PydustStep, options: PythonModuleOptions) PythonModule {
        const b = self.step.owner;

        const short_name = options.short_name();

        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", options.name);
        pyconf.addOption(bool, "limited_api", options.limited_api);
        pyconf.addOption([]const u8, "hexversion", self.hexversion);

        // Configure and install the Python module shared library
        const lib = b.addSharedLibrary(.{
            .name = short_name,
            .root_source_file = options.root_source_file,
            .target = options.target,
            .optimize = options.optimize,
            .main_pkg_path = options.main_pkg_path,
        });
        lib.addOptions("pyconf", pyconf);
        lib.addAnonymousModule("pydust", .{
            .source_file = .{ .generated = &self.pydust_source_file },
            .dependencies = &.{.{ .name = "pyconf", .module = pyconf.createModule() }},
        });
        lib.addIncludePath(.{ .generated = &self.python_include_dir });
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

        // Configure a test runner for the module
        const libtest = b.addTest(.{
            .root_source_file = options.root_source_file,
            .main_pkg_path = options.main_pkg_path,
            .target = options.target,
            .optimize = options.optimize,
        });
        libtest.addOptions("pyconf", pyconf);
        libtest.addAnonymousModule("pydust", .{
            .source_file = .{ .generated = &self.pydust_source_file },
            .dependencies = &.{.{ .name = "pyconf", .module = pyconf.createModule() }},
        });
        libtest.addIncludePath(.{ .generated = &self.python_include_dir });
        libtest.linkLibC();
        libtest.linkSystemLibrary(self.libpython);
        libtest.addLibraryPath(.{ .generated = &self.python_library_dir });
        // Needed to support miniconda statically linking libpython on macos
        libtest.addRPath(.{ .generated = &self.python_library_dir });

        // Install the test binary
        const install_libtest = b.addInstallBinFile(
            libtest.getEmittedBin(),
            testDestRelPath(self.allocator, short_name) catch @panic("OOM"),
        );
        // self.test_build_step.dependOn(&installexceptions.step);
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

    /// During this step we discover the locations of the Python include and lib directories
    fn make(step: *Step, progress: *std.Progress.Node) !void {
        _ = progress;
        const self = @fieldParentPtr(PydustStep, "step", step);

        self.python_include_dir.path = try self.pythonOutput(
            "import sysconfig; print(sysconfig.get_path('include'), end='')",
        );

        self.python_library_dir.path = try self.pythonOutput(
            "import sysconfig; print(sysconfig.get_config_var('LIBDIR'), end='')",
        );

        self.pydust_source_file.path = try self.pythonOutput(
            "import pydust; import os; print(os.path.join(os.path.dirname(pydust.__file__), 'src/pydust.zig'), end='')",
        );
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
    const result = try std.process.Child.exec(.{
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
