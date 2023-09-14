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

// --8<-- [start:valueerror]
pub fn raise_value_error(args: struct { message: py.PyString }) !void {
    try bar(args.message);
}
// --8<-- [end:valueerror]

fn bar(foo: py.PyString) !void {
    return py.ValueError.raise(try foo.asSlice());
}

comptime {
    py.module(@This());
}
