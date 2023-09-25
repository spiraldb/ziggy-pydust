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

const Allocator = @import("std").mem.Allocator;

pub const PyError = error{
    // PyError.PyRaised should be returned when an exception has been set but not caught in
    // the Python interpreter. This tells Pydust to return PyNULL and allow Python to raise
    // the exception to the end user.
    PyRaised,
} || Allocator.Error;
