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
const py = @import("pydust");

pub fn pyobject() !py.PyObject {
    return (try py.PyString.create("hello")).obj;
}

pub fn pystring() !py.PyString {
    return py.PyString.create("hello world");
}

pub fn zigvoid() void {}

pub fn zigbool() bool {
    return true;
}

pub fn zigu32() u32 {
    return 32;
}

pub fn zigu64() u64 {
    return 8589934592;
}

// TODO: support numbers bigger than long
// pub fn zigu128() u128 {
//     return 9223372036854775809;
// }

pub fn zigi32() i32 {
    return -32;
}

pub fn zigi64() i64 {
    return -8589934592;
}

// TODO: support numbers bigger than long
// pub fn zigi128() i128 {
//     return -9223372036854775809;
// }

pub fn zigf16() f16 {
    return 32720.0;
}

pub fn zigf32() f32 {
    return 2.71 * std.math.pow(f32, 10, 38);
}

pub fn zigf64() f64 {
    return 2.71 * std.math.pow(f64, 10, 39);
}

const TupleResult = struct { py.PyObject, u64 };

pub fn zigtuple() !TupleResult {
    return .{ py.object(try py.PyString.create("hello")), 128 };
}

const StructResult = struct { foo: u64, bar: bool };

pub fn zigstruct() StructResult {
    return .{ .foo = 1234, .bar = true };
}

comptime {
    py.rootmodule(@This());
}
