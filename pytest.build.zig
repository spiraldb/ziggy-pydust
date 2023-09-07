const std = @import("std");

fn getPydustRootPath(allocator: std.mem.Allocator, python: []const u8) ![]const u8 {
    const includeResult = try std.process.Child.exec(.{
        .allocator = allocator,
        .argv = &.{
            python,
            "-c",
            \\import os
            \\import pydust
            \\print(os.path.join(os.path.dirname(pydust.__file__), 'src', 'pydust.zig'), end='')
            \\
        },
    });
    if (includeResult.term.Exited != 0) {
        std.debug.print("Failed to locate pydust: {s}", .{includeResult.stderr});
        std.os.exit(1);
    }

    allocator.free(includeResult.stderr);
    return includeResult.stdout;
}


pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run library tests");
    const test_build_step = b.step("test-build", "Build test runners");

    const python_exe = b.option(
        []const u8,
        "python-exe",
        "The path of a Python executable to use",
    );
    const pydust = getPydustRootPath(
        b.allocator,
        python_exe orelse "python",
    ) catch @panic("Failed to locate Pydust source code");

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "example.exceptions");
        pyconf.addOption(bool, "limited_api", true);
        pyconf.addOption([:0]const u8, "hexversion", "0x030b05f0");

        const libexceptions = b.addSharedLibrary(.{
            .name = "exceptions",
            .root_source_file = .{ .path = "example/exceptions.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonInclude(pydust, libexceptions, pyconf);

        // Install the shared library within the source tree
        const installexceptions = b.addInstallFileWithDir(
            libexceptions.getEmittedBin(),
            .{ .custom = ".." },  // Relative to project root: zig-out/../
            "example/exceptions.abi3.so",
        );
        b.getInstallStep().dependOn(&installexceptions.step);

        const testexceptions = b.addTest(.{
            .root_source_file = .{ .path = "example/exceptions.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonRuntime(pydust, testexceptions, pyconf);

        // Install the test binary
        const installtestexceptions = b.addInstallBinFile(
            testexceptions.getEmittedBin(),
            "exceptions.test.bin",
        );
        test_build_step.dependOn(&installexceptions.step);
        test_build_step.dependOn(&installtestexceptions.step);

        // Run the tests as part of zig build test.
        const run_testexceptions = b.addRunArtifact(testexceptions);
        test_step.dependOn(&run_testexceptions.step);


    }

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "example.hello");
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
        test_build_step.dependOn(&installhello.step);
        test_build_step.dependOn(&installtesthello.step);

        // Run the tests as part of zig build test.
        const run_testhello = b.addRunArtifact(testhello);
        test_step.dependOn(&run_testhello.step);


    }

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "example.memory");
        pyconf.addOption(bool, "limited_api", true);
        pyconf.addOption([:0]const u8, "hexversion", "0x030b05f0");

        const libmemory = b.addSharedLibrary(.{
            .name = "memory",
            .root_source_file = .{ .path = "example/memory.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonInclude(pydust, libmemory, pyconf);

        // Install the shared library within the source tree
        const installmemory = b.addInstallFileWithDir(
            libmemory.getEmittedBin(),
            .{ .custom = ".." },  // Relative to project root: zig-out/../
            "example/memory.abi3.so",
        );
        b.getInstallStep().dependOn(&installmemory.step);

        const testmemory = b.addTest(.{
            .root_source_file = .{ .path = "example/memory.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonRuntime(pydust, testmemory, pyconf);

        // Install the test binary
        const installtestmemory = b.addInstallBinFile(
            testmemory.getEmittedBin(),
            "memory.test.bin",
        );
        test_build_step.dependOn(&installmemory.step);
        test_build_step.dependOn(&installtestmemory.step);

        // Run the tests as part of zig build test.
        const run_testmemory = b.addRunArtifact(testmemory);
        test_step.dependOn(&run_testmemory.step);


    }

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "example.modules");
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
        test_build_step.dependOn(&installmodules.step);
        test_build_step.dependOn(&installtestmodules.step);

        // Run the tests as part of zig build test.
        const run_testmodules = b.addRunArtifact(testmodules);
        test_step.dependOn(&run_testmodules.step);


    }

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "example.pytest");
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
        test_build_step.dependOn(&installpytest.step);
        test_build_step.dependOn(&installtestpytest.step);

        // Run the tests as part of zig build test.
        const run_testpytest = b.addRunArtifact(testpytest);
        test_step.dependOn(&run_testpytest.step);


    }

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "example.result_types");
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
        test_build_step.dependOn(&installresult_types.step);
        test_build_step.dependOn(&installtestresult_types.step);

        // Run the tests as part of zig build test.
        const run_testresult_types = b.addRunArtifact(testresult_types);
        test_step.dependOn(&run_testresult_types.step);


    }

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "example.functions");
        pyconf.addOption(bool, "limited_api", true);
        pyconf.addOption([:0]const u8, "hexversion", "0x030b05f0");

        const libfunctions = b.addSharedLibrary(.{
            .name = "functions",
            .root_source_file = .{ .path = "example/functions.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonInclude(pydust, libfunctions, pyconf);

        // Install the shared library within the source tree
        const installfunctions = b.addInstallFileWithDir(
            libfunctions.getEmittedBin(),
            .{ .custom = ".." },  // Relative to project root: zig-out/../
            "example/functions.abi3.so",
        );
        b.getInstallStep().dependOn(&installfunctions.step);

        const testfunctions = b.addTest(.{
            .root_source_file = .{ .path = "example/functions.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonRuntime(pydust, testfunctions, pyconf);

        // Install the test binary
        const installtestfunctions = b.addInstallBinFile(
            testfunctions.getEmittedBin(),
            "functions.test.bin",
        );
        test_build_step.dependOn(&installfunctions.step);
        test_build_step.dependOn(&installtestfunctions.step);

        // Run the tests as part of zig build test.
        const run_testfunctions = b.addRunArtifact(testfunctions);
        test_step.dependOn(&run_testfunctions.step);


    }

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "example.classes");
        pyconf.addOption(bool, "limited_api", true);
        pyconf.addOption([:0]const u8, "hexversion", "0x030b05f0");

        const libclasses = b.addSharedLibrary(.{
            .name = "classes",
            .root_source_file = .{ .path = "example/classes.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonInclude(pydust, libclasses, pyconf);

        // Install the shared library within the source tree
        const installclasses = b.addInstallFileWithDir(
            libclasses.getEmittedBin(),
            .{ .custom = ".." },  // Relative to project root: zig-out/../
            "example/classes.abi3.so",
        );
        b.getInstallStep().dependOn(&installclasses.step);

        const testclasses = b.addTest(.{
            .root_source_file = .{ .path = "example/classes.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonRuntime(pydust, testclasses, pyconf);

        // Install the test binary
        const installtestclasses = b.addInstallBinFile(
            testclasses.getEmittedBin(),
            "classes.test.bin",
        );
        test_build_step.dependOn(&installclasses.step);
        test_build_step.dependOn(&installtestclasses.step);

        // Run the tests as part of zig build test.
        const run_testclasses = b.addRunArtifact(testclasses);
        test_step.dependOn(&run_testclasses.step);


    }

     {
        // For each Python ext_module, generate a shared library and test runner.
        const pyconf = b.addOptions();
        pyconf.addOption([:0]const u8, "module_name", "example.buffers");
        pyconf.addOption(bool, "limited_api", true);
        pyconf.addOption([:0]const u8, "hexversion", "0x030b05f0");

        const libbuffers = b.addSharedLibrary(.{
            .name = "buffers",
            .root_source_file = .{ .path = "example/buffers.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonInclude(pydust, libbuffers, pyconf);

        // Install the shared library within the source tree
        const installbuffers = b.addInstallFileWithDir(
            libbuffers.getEmittedBin(),
            .{ .custom = ".." },  // Relative to project root: zig-out/../
            "example/buffers.abi3.so",
        );
        b.getInstallStep().dependOn(&installbuffers.step);

        const testbuffers = b.addTest(.{
            .root_source_file = .{ .path = "example/buffers.zig" },
            .main_pkg_path = .{ .path = "example/" },
            .target = target,
            .optimize = optimize,
        });
        configurePythonRuntime(pydust, testbuffers, pyconf);

        // Install the test binary
        const installtestbuffers = b.addInstallBinFile(
            testbuffers.getEmittedBin(),
            "buffers.test.bin",
        );
        test_build_step.dependOn(&installbuffers.step);
        test_build_step.dependOn(&installtestbuffers.step);

        // Run the tests as part of zig build test.
        const run_testbuffers = b.addRunArtifact(testbuffers);
        test_step.dependOn(&run_testbuffers.step);


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
    compile.addIncludePath(.{ .path = "/Users/ngates/.pyenv/versions/3.11.5/include/python3.11" });
    compile.linkLibC();
    compile.linker_allow_shlib_undefined = true;
}

fn configurePythonRuntime(
    pydust: []const u8, compile: *std.Build.CompileStep, pyconf: *std.Build.Step.Options
) void {
    configurePythonInclude(pydust, compile, pyconf);
    compile.linkSystemLibrary("python3.11");
    compile.addLibraryPath(.{ .path =  "/Users/ngates/.pyenv/versions/3.11.5/lib" });
}

