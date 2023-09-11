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
const pydust = @import("pydust.build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const pythonInc = getPythonIncludePath(b.allocator) catch @panic("Missing python");
    const pythonLib = getPythonLibraryPath(b.allocator) catch @panic("Missing python");

    const test_step = b.step("test", "Run library tests");
    const docs_step = b.step("docs", "Generate docs");

    // We never build this lib, but we use it to generate docs.
    const pydust_lib = b.addSharedLibrary(.{
        .name = "pydust",
        .root_source_file = .{ .path = "pydust/src/pydust.zig" },
        .main_pkg_path = .{ .path = "pydust/src" },
        .target = target,
        .optimize = optimize,
    });
    pydust_lib.addIncludePath(.{ .path = pythonInc });
    pydust_lib.addAnonymousModule("pyconf", .{ .source_file = .{ .path = "./pyconf.dummy.zig" } });

    const pydust_docs = b.addInstallDirectory(.{
        .source_dir = pydust_lib.getEmittedDocs(),
        // Emit the Zig docs into zig-out/../docs/zig
        .install_dir = .{ .custom = "../docs" },
        .install_subdir = "zig",
    });
    docs_step.dependOn(&pydust_docs.step);

    const main_tests = b.addTest(.{
        .root_source_file = .{ .path = "pydust/src/pydust.zig" },
        .main_pkg_path = .{ .path = "pydust/src" },
        .target = target,
        .optimize = optimize,
    });
    main_tests.linkLibC();
    main_tests.addIncludePath(.{ .path = pythonInc });
    main_tests.addLibraryPath(.{ .path = pythonLib });
    main_tests.linkSystemLibrary("python3.11");
    main_tests.addAnonymousModule("pyconf", .{ .source_file = .{ .path = "./pyconf.dummy.zig" } });

    const run_main_tests = b.addRunArtifact(main_tests);
    test_step.dependOn(&run_main_tests.step);

    // Setup a library target to trick the Zig Language Server into providing completions for @import("pydust")
    const example_lib = b.addSharedLibrary(.{
        .name = "example",
        .root_source_file = .{ .path = "example/hello.zig" },
        .main_pkg_path = .{ .path = "example" },
        .target = target,
        .optimize = optimize,
    });
    example_lib.linkLibC();
    main_tests.addIncludePath(.{ .path = pythonInc });
    main_tests.addLibraryPath(.{ .path = pythonLib });
    main_tests.linkSystemLibrary("python3.11");
    main_tests.addAnonymousModule("pydust", .{ .source_file = .{ .path = "pydust/src/pydust.zig" } });
    main_tests.addAnonymousModule("pyconf", .{ .source_file = .{ .path = "./pyconf.dummy.zig" } });

    // Option for emitting test binary based on the given root source.
    // This is used for debugging as in .vscode/tasks.json
    const test_debug_root = b.option([]const u8, "test-debug-root", "The root path of a file emitted as a binary for use with the debugger");
    if (test_debug_root) |root| {
        main_tests.root_src = .{ .path = root };
        const test_bin_install = b.addInstallBinFile(main_tests.getEmittedBin(), "test.bin");
        b.getInstallStep().dependOn(&test_bin_install.step);
    }
}

fn getPythonIncludePath(
    allocator: std.mem.Allocator,
) ![]const u8 {
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
