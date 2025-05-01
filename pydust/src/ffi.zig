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

// Export the Limited Python C API for use within PyDust.
const pyconf = @import("pyconf");

pub usingnamespace @cImport({
    if (pyconf.limited_api) {
        @cDefine("Py_LIMITED_API", pyconf.hexversion);
    }
    @cDefine("PY_SSIZE_T_CLEAN", {});
    @cInclude("Python.h");

    // From 3.12 onwards, structmember.h is fixed to be including in Python.h
    // See https://github.com/python/cpython/pull/99014
    @cInclude("structmember.h");
});
