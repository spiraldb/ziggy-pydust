const std = @import("std");

fn getPydustRootPath(allocator: std.mem.Allocator) ![]const u8 {
    const includeResult = try std.process.Child.exec(.{
        .allocator = allocator,
        .argv = &.{
            "python",
            "-c",
            \\import os
            \\import pydust
            \\print(os.path.join(os.path.dirname(pydust.__file__), 'src', 'pydust.zig'), end='')
            \\
        },
    });
    allocator.free(includeResult.stderr);
    return includeResult.stdout;
}


pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run library tests");
    const test_build_step = b.step("test-build", "Build test runners");

    const pydust = getPydustRootPath(b.allocator) catch @panic("Failed to locate Pydust source code");

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "hello");
        pyconf.addOption(bool, "limited_api", true);
        pyconf.addOption([:0]const u8, "hexversion", "0x030b05f0");

        const libhello = b.addSharedLibrary(.{
            .name = "hello",
            .root_source_file = .{ .path = "example/hello.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonInclude(pydust, libhello, pyconf);

        // Install the shared library within the source tree
        const installhello = b.addInstallFileWithDir(
            libhello.getEmittedBin(),
            .{ .custom = ".." },  // Relative to project root: zig-out/../
            "example/hello.abi3.so",
        );
        b.getInstallStep().dependOn(&installhello.step);

        const testhello = b.addTest(.{
            .root_source_file = .{ .path = "example/hello.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonRuntime(pydust, testhello, pyconf);

        // Install the test binary
        const installtesthello = b.addInstallBinFile(
            testhello.getEmittedBin(),
            "hello.test.bin",
        );
        test_build_step.dependOn(&installtesthello.step);

        // Run the tests as part of zig build test.
        const run_testhello = b.addRunArtifact(testhello);
        test_step.dependOn(&run_testhello.step);


    }

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "modules");
        pyconf.addOption(bool, "limited_api", true);
        pyconf.addOption([:0]const u8, "hexversion", "0x030b05f0");

        const libmodules = b.addSharedLibrary(.{
            .name = "modules",
            .root_source_file = .{ .path = "example/modules.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonInclude(pydust, libmodules, pyconf);

        // Install the shared library within the source tree
        const installmodules = b.addInstallFileWithDir(
            libmodules.getEmittedBin(),
            .{ .custom = ".." },  // Relative to project root: zig-out/../
            "example/modules.abi3.so",
        );
        b.getInstallStep().dependOn(&installmodules.step);

        const testmodules = b.addTest(.{
            .root_source_file = .{ .path = "example/modules.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonRuntime(pydust, testmodules, pyconf);

        // Install the test binary
        const installtestmodules = b.addInstallBinFile(
            testmodules.getEmittedBin(),
            "modules.test.bin",
        );
        test_build_step.dependOn(&installtestmodules.step);

        // Run the tests as part of zig build test.
        const run_testmodules = b.addRunArtifact(testmodules);
        test_step.dependOn(&run_testmodules.step);


    }

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "pytest");
        pyconf.addOption(bool, "limited_api", true);
        pyconf.addOption([:0]const u8, "hexversion", "0x030b05f0");

        const libpytest = b.addSharedLibrary(.{
            .name = "pytest",
            .root_source_file = .{ .path = "example/pytest.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonInclude(pydust, libpytest, pyconf);

        // Install the shared library within the source tree
        const installpytest = b.addInstallFileWithDir(
            libpytest.getEmittedBin(),
            .{ .custom = ".." },  // Relative to project root: zig-out/../
            "example/pytest.abi3.so",
        );
        b.getInstallStep().dependOn(&installpytest.step);

        const testpytest = b.addTest(.{
            .root_source_file = .{ .path = "example/pytest.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonRuntime(pydust, testpytest, pyconf);

        // Install the test binary
        const installtestpytest = b.addInstallBinFile(
            testpytest.getEmittedBin(),
            "pytest.test.bin",
        );
        test_build_step.dependOn(&installtestpytest.step);

        // Run the tests as part of zig build test.
        const run_testpytest = b.addRunArtifact(testpytest);
        test_step.dependOn(&run_testpytest.step);


    }

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "result_types");
        pyconf.addOption(bool, "limited_api", true);
        pyconf.addOption([:0]const u8, "hexversion", "0x030b05f0");

        const libresult_types = b.addSharedLibrary(.{
            .name = "result_types",
            .root_source_file = .{ .path = "example/result_types.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonInclude(pydust, libresult_types, pyconf);

        // Install the shared library within the source tree
        const installresult_types = b.addInstallFileWithDir(
            libresult_types.getEmittedBin(),
            .{ .custom = ".." },  // Relative to project root: zig-out/../
            "example/result_types.abi3.so",
        );
        b.getInstallStep().dependOn(&installresult_types.step);

        const testresult_types = b.addTest(.{
            .root_source_file = .{ .path = "example/result_types.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonRuntime(pydust, testresult_types, pyconf);

        // Install the test binary
        const installtestresult_types = b.addInstallBinFile(
            testresult_types.getEmittedBin(),
            "result_types.test.bin",
        );
        test_build_step.dependOn(&installtestresult_types.step);

        // Run the tests as part of zig build test.
        const run_testresult_types = b.addRunArtifact(testresult_types);
        test_step.dependOn(&run_testresult_types.step);


    }

    // Option for emitting test binary based on the given root source. This can be helpful for debugging.
    const debugRoot = b.option(
        []const u8,
        "debug-root",
        "The root path of a file emitted as a binary for use with the debugger",
    );
    if (debugRoot) |root| {
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "debug");
        pyconf.addOption(bool, "limited_api", false);
        pyconf.addOption([:0]const u8, "hexversion", "0x030b05f0");

        const testdebug = b.addTest(.{
            .root_source_file = .{ .path = root },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonRuntime(pydust, testdebug, pyconf);

        const debugBin = b.addInstallBinFile(testdebug.getEmittedBin(), "debug.bin");
        b.getInstallStep().dependOn(&debugBin.step);
    }


}

fn configurePythonInclude(
    pydust: []const u8, compile: *std.Build.CompileStep, pyconf: *std.Build.Step.Options,
) void {
    compile.addAnonymousModule("pydust", .{
        .source_file = .{ .path = pydust },
        .dependencies = &.{.{ .name = "pyconf", .module = pyconf.createModule() }},
    });
    compile.addIncludePath(.{ .path = "/opt/homebrew/opt/python@3.11/Frameworks/Python.framework/Versions/3.11/include/python3.11" });
    compile.linkLibC();
    compile.linker_allow_shlib_undefined = true;
}

fn configurePythonRuntime(
    pydust: []const u8, compile: *std.Build.CompileStep, pyconf: *std.Build.Step.Options
) void {
    configurePythonInclude(pydust, compile, pyconf);
    compile.linkSystemLibrary("python3.11");
    compile.addLibraryPath(.{ .path =  "/opt/homebrew/opt/python@3.11/Frameworks/Python.framework/Versions/3.11/lib" });
}

