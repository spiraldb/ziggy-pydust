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
const py = @import("../pydust.zig");
const PyObjectMixin = @import("./obj.zig").PyObjectMixin;

const ffi = py.ffi;
const PyError = @import("../errors.zig").PyError;

pub const PyGIL = extern struct {
    state: ffi.PyGILState_STATE,

    /// Acqiure the GIL. Ensure to call `release` when done, e.g. using `defer gil.release()`.
    pub fn ensure() PyGIL {
        return .{ .state = ffi.PyGILState_Ensure() };
    }

    pub fn release(self: PyGIL) void {
        ffi.PyGILState_Release(self.state);
    }
};
