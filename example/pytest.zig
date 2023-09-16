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

// --8<-- [start:example]
test "pydust pytest" {
    py.initialize();
    defer py.finalize();

    const str = try py.PyString.create("hello");
    defer str.decref();

    try std.testing.expectEqualStrings("hello", try str.asSlice());
}
// --8<-- [end:example]

test "pydust-expected-failure" {
    py.initialize();
    defer py.finalize();

    const str = try py.PyString.create("hello");
    defer str.decref();

    try std.testing.expectEqualStrings("world", try str.asSlice());
}
