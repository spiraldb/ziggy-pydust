// Export the Limited Python C API for use within PyDust.
pub usingnamespace @cImport({
    @cDefine("Py_LIMITED_API", "0x030A0000"); // 3.10
    @cDefine("PY_SSIZE_T_CLEAN", {});
    @cInclude("Python.h");
});
