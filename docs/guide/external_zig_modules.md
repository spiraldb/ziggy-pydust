# External Zig Modules

In order to use third party Zig dependencies, first, we need to set pydust `self_managed` mode to `true` in `pyproject.toml`, this way, you get to manage your own `build.zig`:

```toml linenums="0"
[tool.pydust]
self_managed = true
```

Fetch the required library with `zig fetch`. In this example we'll use [sam701/zig-toml](https://github.com/sam701/zig-toml) and [jetzig-framework/zmd](https://github.com/jetzig-framework/zmd).

Fetch the libraries with `zig fetch`:
```sh linenums="0"
zig fetch --save git+https://github.com/jetzig-framework/zmd.git
zig fetch --save git+https://github.com/sam701/zig-toml
```

Then, pass a list of modules to `pydust.addPythonModule`. This is an example of a `build.zig` file that uses an external Zig module:

```zig title="build.zig" hl_lines="14-26 34"
const std = @import("std");
const py = @import("./pydust.build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptionsQueryOnly(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run library tests");

    const pydust = py.addPydust(b, .{
        .test_step = test_step,
    });

    const zmd = b.dependency("zmd", .{
        .target = target,
        .optimize = optimize,
    });

    const toml = b.dependency("toml", .{
        .target = target,
        .optimize = optimize,
    });

    var modules: [2]std.Build.Module.Import = undefined;
    modules[0] = std.Build.Module.Import{ .name = "zmd", .module = zmd.module("zmd") };
    modules[1] = std.Build.Module.Import{ .name = "toml", .module = toml.module("toml") };

    _ = pydust.addPythonModule(.{
        .name = "hello",
        .root_source_file = b.path("src/hello.zig"),
        .limited_api = true,
        .target = target,
        .optimize = optimize,
        .imports = &modules,
    });
}
```

Now you can import your modules from the Zig source files of you project!
