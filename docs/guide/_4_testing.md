# Pytest Plugin

Pydust ships with a Pytest plugin that builds, collects and executes your Zig tests. This 
means testing should work out-of-the-box with your existing Python project and you never
need to interact directly with the Zig build system if you don't want to.

The Zig documentation provides an [excellent introduction to writing tests](https://ziglang.org/documentation/master/#Zig-Test).

!!! Note

    Zig tests are currently spawned as a separate process. This means you must manually call `py.initialize()` and
    `defer py.finalize()` in order to setup and teardown a Python interpreter.

``` zig title="example/pytest.zig"
--8<-- "example/pytest.zig:example"
```

After running `poetry run pytest` you should see your Zig tests included in your Pytest output:

``` bash linenums="0"
================================== test session starts ==================================
platform darwin -- Python 3.11.5, pytest-7.4.0, pluggy-1.3.0
plugins: ziggy-pydust-0.2.1
collected 7 items

example/pytest.zig .x                                                             [100%]

============================= 1 passed, 1 xfailed in 0.30s ==============================
```