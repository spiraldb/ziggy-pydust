const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run library tests");

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "pydust/src/pydust.zig" },
        .main_pkg_path = .{ .path = "pydust/src" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.linkLibC();
    main_tests.addIncludePath(.{ .path = getPythonIncludePath(b.allocator) catch @panic("Missing python") });
    main_tests.addLibraryPath(.{ .path = getPythonLibraryPath(b.allocator) catch @panic("Missing python") });
    main_tests.linkSystemLibrary("python3.11");
    main_tests.addAnonymousModule("pyconf", .{ .source_file = .{ .path = "./pyconf.dummy.zig" } });

    const run_main_tests = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_main_tests.step);

    const example_lib = b.addSharedLibrary(.{
        .name = "examples",
        .root_source_file = .{ .path = "example/modules.zig" },
        .main_pkg_path = .{ .path = "example/" },
        .target = target,
        .optimize = optimize,
    });
    example_lib.addAnonymousModule("pydust", .{ .source_file = .{ .path = "pydust/src/pydust.zig" } });
    b.installArtifact(example_lib);

    // Option for emitting test binary based on the given root source.
    // This is used for debugging as in .vscode/tasks.json
    const test_debug_root = b.option([]const u8, "test-debug-root", "The root path of a file emitted as a binary for use with the debugger");
    if (test_debug_root) |root| {
        main_tests.root_src = .{ .path = root };
        const test_bin_install = b.addInstallBinFile(main_tests.getEmittedBin(), "test.bin");
        b.getInstallStep().dependOn(&test_bin_install.step);
    }
}

fn getPythonIncludePath(allocator: std.mem.Allocator) ![]const u8 {
    const includeResult = try std.process.Child.exec(.{
        .allocator = allocator,
        .argv = &.{ "python", "-c", "import sysconfig; print(sysconfig.get_path('include'), end='')" },
    });
    defer allocator.free(includeResult.stderr);
    return includeResult.stdout;
}

fn getPythonLibraryPath(allocator: std.mem.Allocator) ![]const u8 {
    const includeResult = try std.process.Child.exec(.{
        .allocator = allocator,
        .argv = &.{ "python", "-c", "import sysconfig; print(sysconfig.get_config_var('LIBDIR'), end='')" },
    });
    defer allocator.free(includeResult.stderr);
    return includeResult.stdout;
}
