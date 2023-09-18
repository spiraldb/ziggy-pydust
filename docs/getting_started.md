# Getting Started

Pydust is currently designed to be embedded within a Python [Poetry](https://python-poetry.org/) project. [Reach out](https://github.com/fulcrum-so/ziggy-pydust/issues) if you'd like help integrating Pydust with other build setups.

See also the [generated Zig documentation](https://pydust.fulcrum.so/zig).

## GitHub Template

By far the easiest way to get started is by creating a project from our GitHub template: [github.com/fulcrum-so/ziggy-pydust-template/](https://github.com/fulcrum-so/ziggy-pydust-template/)

This template includes:

- A Python Poetry project
- A `src/` directory containing a Pydust Python module
- Pytest setup for running both Python and Zig unit tests.
- GitHub Actions workflows for building and publishing the package.
- VSCode settings for recommended extensions, debugger configurations, etc.

## Poetry Setup

Assuming you have an existing Poetry project, these are the changes you need to make to
your `pyproject.toml` to setup Ziggy Pydust. But first, add Pydust as a dev dependency:

```bash
poetry add -G dev ziggy-pydust
```

```diff title="pyproject.toml"
[tool.poetry]
name = "your-package"
packages = [ { include = "your-module" } ]
+ include = [ { path = "src/", format = "sdist" }, { path = "your-module/*.so", format = "wheel" } ]

+ [tool.poetry.build]
+ script = "build.py"

[build-system]
- requires = ["poetry-core"]
+ requires = ["poetry-core", "ziggy-pydust==0.TODO_SET_MINOR_VERSION.*"]
build-backend = "poetry.core.masonry.api"
```

!!! note

    We recommend locking the build dependency minor version before `ziggy-pydust` is `1.0`.

As well as creating the `build.py` for Poetry to invoke the Pydust build.

```python title="build.py"
from pydust.build import build

build()
```

## My First Module

Once Poetry is configured, add a Pydust module to your `pyproject.toml` and start writing some Zig!

```toml title="pyproject.toml"
[[tool.pydust.ext_module]]
name = "example.hello"
root = "src/hello.zig"
```

```zig title="src/hello.zig"
--8<-- "example/hello.zig:ex"
```

Running `poetry install` will build your modules. After this, you will be
able to import your module from within `poetry shell` or `poetry run pytest`.

```python title="test/test_hello.py"
--8<-- "test/test_hello.py:ex"
```

## Zig Language Server

!!! warning

    Currently ZLS (at least when running in VSCode) requires a small amount of manual setup.

In the root of your project, create a `zls.build.json` file containing the path to your python executable.
This can be obtained by running `poetry env info -e`.

```json title="zls.build.json"
{
    "build_options": [
        {
            "name": "python-exe",
            "value": "/path/to/your/poetry/venv/bin/python",
        }
    ]
}
```

## Self-managed Mode

Pydust makes it easy to get started building a Zig extension for Python. But when your use-case becomes sufficiently
complex, you may wish to have full control of your `build.zig` file.

By default, Pydust will generated two files:

* `pydust.build.zig` - a Zig file used for bootstrapping Pydust and configuring Python modules.
* `build.zig` - a valid Zig build configuration based on the `tool.pydust.ext_module` entries in your `pyproject.toml`.

In self-managed mode, Pydust will only generate the `pydust.build.zig` file and your are free to manage your own `build.zig`.
To enable this mode, set the flag in your `pyproject.toml` and remove any `ext_module` entries.

```diff title="pyproject.toml"
[tool.pydust]
+ self_managed = true

- [[tool.pydust.ext_module]]
- name = "example.hello"
- root = "example/hello.zig"
```

You can then configure Python modules from a custom `build.zig` file:

```zig title="build.zig"
const std = @import("std");
const py = @import("./pydust.build.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Each Python module consists of a library_step and a test_step
    const module = pydust.addPythonModule(.{
        .name = "example.hello",
        .root_source_file = .{ .path = "example/hello.zig" },
        .target = target,
        .optimize = optimize,
    });
    module.library_step.addModule(..., ...);
    module.test_step.addModule(..., ...);
}
```