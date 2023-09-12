# Python Buffer Protocol

Python objects implementing the [Buffer Protocol](https://docs.python.org/3/c-api/buffer.html#) can be used with zero copy.

```zig
--8<-- "example/buffers.zig:sum"
```

This function accepts Python [arrays](https://docs.python.org/3/library/array.html#module-array), Numpy arrays, or any other buffer protocol implementation.

```python
--8<-- "test/test_buffers.py:sum"
```

!!! Note

    Understanding [request types](https://docs.python.org/3/c-api/buffer.html#buffer-request-types) is important when working with buffers. Common request types are implemented as `py.PyBuffer.Flags`, e.g. `py.PyBuffer.Flags.FULL_RO`.


You can implement a buffer protocol in a Pydust module by implementing `__buffer__` and optionally `__release_buffer__` methods.

```zig
--8<-- "example/buffers.zig:protocol"
```
