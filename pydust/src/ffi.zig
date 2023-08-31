// Export the Limited Python C API for use within PyDust.
const pyconf = @import("pyconf");

pub usingnamespace @cImport({
    if (pyconf.limited_api) {
        @cDefine("Py_LIMITED_API", pyconf.hexversion);
    }
    @cDefine("PY_SSIZE_T_CLEAN", {});
    @cInclude("Python.h");
});
