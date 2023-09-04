const py = @import("./pydust.zig");

pub fn import(module_name: [:0]const u8) !py.PyObject {
    return (try py.PyModule.import(module_name)).obj;
}
