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

const py = @import("pydust");

// --8<-- [start:append]
pub fn append(args: struct { left: py.PyString }) !py.PyString {
    // Since we create right, we must also decref it.
    const right = try py.PyString.create("right");
    defer right.decref();

    // Left is given to us as a borrowed reference from the caller.
    // Since append steals the left-hand-side, we must incref first.
    args.left.incref();
    return args.left.append(right);
}
// --8<-- [end:append]

// --8<-- [start:concat]
pub fn concat(args: struct { left: py.PyString }) !py.PyString {
    return args.left.concatSlice("right");
}
// --8<-- [end:concat]

comptime {
    py.module(@This());
}
