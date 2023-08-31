const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run library tests");

    const configurePython = ConfigurePythonStep.add(b, .{});

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "pydust/src/pydust.zig" },
        .main_pkg_path = .{ .path = "pydust/src" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.linkLibC();
    main_tests.addIncludePath(configurePython.getIncludePath());
    main_tests.addLibraryPath(configurePython.getLibraryPath());
    main_tests.linkSystemLibrary("python3.11");
    const run_main_tests = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_main_tests.step);

    // Option for emitting test binary based on the given root source.
    // This is used for debugging as in .vscode/tasks.json
    const test_debug_root = b.option([]const u8, "test-debug-root", "The root path of a file emitted as a binary for use with the debugger");
    if (test_debug_root) |root| {
        main_tests.root_src = .{ .path = root };
        const test_bin_install = b.addInstallBinFile(main_tests.getEmittedBin(), "test.bin");
        b.getInstallStep().dependOn(&test_bin_install.step);
    }
}

pub const ConfigurePythonStep = struct {
    step: std.build.Step,
    options: Options,

    // Output paths
    includePath: std.build.GeneratedFile,
    libPath: std.build.GeneratedFile,

    const Options = struct {
        pythonExe: []const u8 = "python3",
    };

    pub fn add(b: *std.Build, options: Options) *ConfigurePythonStep {
        const self = b.allocator.create(ConfigurePythonStep) catch @panic("OOM");
        self.* = .{
            .step = std.build.Step.init(.{
                .id = .custom,
                .name = "configure python",
                .owner = b,
                .makeFn = ConfigurePythonStep.make,
            }),
            .options = options,
            .includePath = .{ .step = &self.step },
            .libPath = .{ .step = &self.step },
        };

        return self;
    }

    fn make(step: *std.build.Step, prog: *std.Progress.Node) anyerror!void {
        prog.setName("Configure Python");
        prog.activate();
        const self = @fieldParentPtr(ConfigurePythonStep, "step", step);

        const includeResult = try std.process.Child.exec(.{
            .allocator = step.owner.allocator,
            .argv = &.{ self.options.pythonExe, "-c", "import sysconfig; print(sysconfig.get_path('include'), end='')" },
        });
        defer step.owner.allocator.free(includeResult.stderr);
        self.includePath.path = includeResult.stdout;

        const libResult = try std.process.Child.exec(.{
            .allocator = step.owner.allocator,
            .argv = &.{ self.options.pythonExe, "-c", "import sysconfig; print(sysconfig.get_config_var('LIBDIR'), end='')" },
        });
        defer step.owner.allocator.free(libResult.stderr);
        self.libPath.path = libResult.stdout;

        prog.end();
    }

    pub fn getIncludePath(self: *ConfigurePythonStep) std.Build.LazyPath {
        return .{ .generated = &self.includePath };
    }

    pub fn getLibraryPath(self: *ConfigurePythonStep) std.Build.LazyPath {
        return .{ .generated = &self.libPath };
    }
};
