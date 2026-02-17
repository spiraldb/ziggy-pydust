// limitations under the License.

// Export the Limited Python C API for use within PyDust.

const pyconf = @import("pyconf");

pub const ffi = @cImport({
    if (pyconf.limited_api) {
        @cDefine("Py_LIMITED_API", pyconf.hexversion);
    }

    @cDefine("PY_SSIZE_T_CLEAN", {});

    @cInclude("Python.h");

    // From 3.12 onwards, structmember.h is fixed to be including in Python.h

    // See https://github.com/python/cpython/pull/99014

    @cInclude("structmember.h");
});

