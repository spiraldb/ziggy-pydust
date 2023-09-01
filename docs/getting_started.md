# Getting Started

Pydust is currently designed to be embedded within a Python [Poetry](https://python-poetry.org/) project. [Reach out](https://github.com/fulcrum-so/ziggy-pydust/issues) if you'd like help integrating Pydust with other build setups.

## GitHub Template

By far the easiest way to get started is by creating a project from our GitHub template: [github.com/fulcrum-so/pydust-template/](https://github.com/fulcrum-so/pydust-template/)

This template includes:

* A Python Poetry project
* A `src/` directory containing a Pydust Python module
* Pytest setup for running both Python and Zig unit tests.
* GitHub Actions workflows for building and publishing the package.
* VSCode settings for recommended extensions, debugger configurations, etc. 

## Poetry Setup

Assuming you have an existing Poetry project, these are the changes you need to make to 
your `pyproject.toml` to setup Ziggy Pydust.

``` diff title="pyproject.toml"
[build-system]
- requires = ["poetry-core"]
+ requires = ["poetry-core", "ziggy-pydust"]
build-backend = "poetry.core.masonry.api"

[tool.poetry]
name = "pydust-template"
version = "0.1.0"
description = ""
authors = ["Nicholas Gates <nick@fulcrum.so>"]
readme = "README.md"
packages = [{include = "fibonacci"}]
+ include = [ { path = "src/", format = "sdist" } ]

+ [tool.poetry.build]
+ script = "build.py"

[tool.poetry.dependencies]
python = "^3.11"

[tool.poetry.group.dev.dependencies]
pytest = "^7.4.0"
+ ziggy-pydust = "^0.1.1"

```

As well as creating the `build.py` for Poetry to invoke the Pydust build.

``` python title="build.py"
from pydust.build import build

build()
```

## My First Module

Once Poetry is configured, you can start defining your Zig modules:

``` toml title="pyproject.toml"
[[tool.pydust.ext_module]]
name = "hello._lib"
root = "src/hello.zig"
```

``` zig title="src/hello.zig"
--8<-- "example/hello.zig"
```

And run `poetry install` to build your modules. After this, you should be
able to import your module from within `poetry shell` or `poetry run pytest`.

``` python title="test/test_hello.py"
--8<-- "test/test_hello.py"
```