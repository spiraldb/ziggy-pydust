# Ziggy Pydust

A framework for writing and packaging native Python extension modules written in Zig.

* Package Python extension modules written in Zig.
* Pytest plugin to discover and run Zig tests.
* Comptime argument wrapping / unwrapping for interop with native Zig types.

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
    py.module(@This());
}
```

## Compatibility

Pydust supports:

* [Zig 0.11.0](https://ziglang.org/download/0.11.0/release-notes.html)
* [CPython >=3.11](https://docs.python.org/3.11/c-api/stable.html)

Please reach out if you're interested in helping us to expand compatibility.

## Getting Started

Pydust docs can be found [here](https://pydust.fulcrum.so).

There is also a [template repository](https://github.com/fulcrum-so/ziggy-pydust-template) including Poetry build, Pytest and publishing from Github Actions.

## Contributing

We welcome contributions! Pydust is in its early stages so there is lots of low hanging
fruit when it comes to contributions.

* Assist other Pydust users with GitHub issues or discussions.
* Suggest or implement features, fix bugs, fix performance issues.
* Improve our documentation.
* Write articles or other content demonstrating how you have used Pydust.

## License

Pydust is released under the [Apache-2.0 license](https://opensource.org/licenses/APACHE-2.0).
