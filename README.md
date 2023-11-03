# Ziggy Pydust

<p align="center">
  <a href="https://pydust.fulcrum.so">
    <img src="https://pydust.fulcrum.so/assets/ziggy-pydust.png" style="border-radius: 20px" />
  </a>
</p>
<p align="center">
    <em>A framework for writing and packaging native Python extension modules written in Zig.</em>
</p>
<p align="center">
<a href="https://github.com/fulcrum-so/ziggy-pydust/actions" target="_blank">
    <img src="https://img.shields.io/github/actions/workflow/status/fulcrum-so/ziggy-pydust/ci.yml?branch=develop&logo=github&style=" alt="Actions">
</a>
<a href="https://pypi.org/project/ziggy-pydust" target="_blank">
    <img src="https://img.shields.io/pypi/v/ziggy-pydust" alt="Package version">
</a>
<a href="https://docs.python.org/3/whatsnew/3.11.html" target="_blank">
    <img src="https://img.shields.io/pypi/pyversions/ziggy-pydust" alt="Python version">
</a>
<a href="https://github.com/fulcrum-so/ziggy-pydust/blob/develop/LICENSE" target="_blank">
    <img src="https://img.shields.io/github/license/fulcrum-so/ziggy-pydust" alt="License">
</a>
</p>

---

**Documentation**: <a href="https://pydust.fulcrum.so/latest" target="_blank">https://pydust.fulcrum.so/latest</a>

**API**: <a href="https://pydust.fulcrum.so/latest/zig" target="_blank">https://pydust.fulcrum.so/latest/zig</a>

**Source Code**: <a href="https://github.com/fulcrum-so/ziggy-pydust" target="_blank">https://github.com/fulcrum-so/ziggy-pydust</a>

**Template**: <a href="https://github.com/fulcrum-so/ziggy-pydust-template" target="_blank">https://github.com/fulcrum-so/ziggy-pydust-template</a>

---

Ziggy Pydust is a framework for writing and packaging native Python extension modules written in Zig.

- Package Python extension modules written in Zig.
- Pytest plugin to discover and run Zig tests.
- Comptime argument wrapping / unwrapping for interop with native Zig types.

```zig
const py = @import("pydust");

pub fn fibonacci(args: struct { n: u64 }) u64 {
    if (args.n < 2) return args.n;

    var sum: u64 = 0;
    var last: u64 = 0;
    var curr: u64 = 1;
    for (1..args.n) {
        sum = last + curr;
        last = curr;
        curr = sum;
    }
    return sum;
}

comptime {
    py.rootmodule(@This());
}
```

## Compatibility

Pydust supports:

- [Zig 0.11.0](https://ziglang.org/download/0.11.0/release-notes.html)
- [CPython >=3.11](https://docs.python.org/3.11/c-api/stable.html)

Please reach out if you're interested in helping us to expand compatibility.

## Getting Started

Pydust docs can be found [here](https://pydust.fulcrum.so).
Zig documentation (beta) can be found [here](https://pydust.fulcrum.so/latest/zig).

There is also a [template repository](https://github.com/fulcrum-so/ziggy-pydust-template) including Poetry build, Pytest and publishing from Github Actions.

## Contributing

We welcome contributions! Pydust is in its early stages so there is lots of low hanging
fruit when it comes to contributions.

- Assist other Pydust users with GitHub issues or discussions.
- Suggest or implement features, fix bugs, fix performance issues.
- Improve our documentation.
- Write articles or other content demonstrating how you have used Pydust.

## License

Pydust is released under the [Apache-2.0 license](https://opensource.org/licenses/APACHE-2.0).
