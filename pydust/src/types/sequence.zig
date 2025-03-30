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

const py = @import("../pydust.zig");
const ffi = @import("../ffi.zig");
const PyError = @import("../errors.zig").PyError;
const State = @import("../discovery.zig").State;

/// Mixin of PySequence functions.
pub fn SequenceMixin(comptime root: type, comptime Self: type) type {
    return struct {
        pub fn contains(self: Self, value: anytype) !bool {
            const result = ffi.PySequence_Contains(self.obj.py, py.object(root, value).py);
            if (result < 0) return PyError.PyRaised;
            return result == 1;
        }

        pub fn index(self: Self, value: anytype) !usize {
            const idx = ffi.PySequence_Index(self.obj.py, py.object(root, value).py);
            if (idx < 0) return PyError.PyRaised;
            return @intCast(idx);
        }
    };
}
