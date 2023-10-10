# Global Interpreter Lock

Pydust provides two functions for managing GIL state: `py.nogil` and `py.gil`.

## No GIL / Allow Threads

The `py.nogil` function allows Pydust code to release the Python GIL. This allows Python threads to continue to
make progress while Zig code is running.

Each call to `py.nogil()` must have a corresponding `acquire()` call.

See the [Python documentation](https://docs.python.org/3.11/c-api/init.html#releasing-the-gil-from-extension-code) for more information.

=== "Zig"

    ```zig
    --8<-- "example/gil.zig:gil"
    ```

=== "Python"

    ```python
    --8<-- "test/test_gil.py:gil"
    ```

## Acquire GIL

The `py.gil` function allows Pydust code to re-acquire the Python GIL before calling back into Python code.
This can be particularly useful with Zig or C libraries that make use of callbacks.

Each call to `py.gil()` must have a corresponding `release()` call.

See the [Python documentation](https://docs.python.org/3.11/c-api/init.html#non-python-created-threads) for more information.
