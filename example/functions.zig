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

// --8<-- [start:function]
const py = @import("pydust");

pub fn double(args: struct { x: i64 }) i64 {
    return args.x * 2;
}

comptime {
    py.rootmodule(@This());
}
// --8<-- [end:function]

// --8<-- [start:kwargs]
pub fn with_kwargs(args: struct { x: f64, y: f64 = 42.0 }) f64 {
    return if (args.x < args.y) args.x * 2 else args.y;
}
// --8<-- [end:kwargs]

// --8<-- [start:varargs]
pub fn variadic(args: struct { hello: py.PyString, args: py.Args, kwargs: py.Kwargs }) !py.PyString {
    return py.PyString.createFmt(
        "Hello {s} with {} varargs and {} kwargs",
        .{ try args.hello.asSlice(), args.args.len, args.kwargs.count() },
    );
}
// --8<-- [end:varargs]
