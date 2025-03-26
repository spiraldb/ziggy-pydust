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

fn root() struct { *py.State, type } {
    comptime var state = py.State{};
    const spec = struct {
        // --8<-- [start:valueerror]
        pub fn raise_value_error(args: struct { message: py.PyString(&state) }) !void {
            return py.ValueError.raise(try args.message.asSlice());
        }
        // --8<-- [end:valueerror]

        pub const CustomError = error{Oops};

        pub fn raise_custom_error() !void {
            return CustomError.Oops;
        }
    };
    return .{ &state, spec };
}

comptime {
    py.rootmodule(root);
}
