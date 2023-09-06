const py = @import("../pydust.zig");
const ffi = @import("../ffi.zig");
const tramp = @import("../trampoline.zig");
const PyError = @import("../errors.zig").PyError;

/// Mixin of PySequence functions.
pub fn SequenceMixin(comptime Self: type) type {
    return struct {
        pub fn contains(self: Self, value: anytype) !bool {
            const valueObj = try tramp.Trampoline(@TypeOf(value)).wrap(value);
            const result = ffi.PySequence_Contains(self.obj.py, valueObj.py);
            if (result < 0) return PyError.Propagate;
            return result == 1;
        }

        pub fn index(self: Self, value: anytype) !usize {
            const valueObj = try tramp.Trampoline(@TypeOf(value)).wrap(value);
            const idx = ffi.PySequence_Index(self.obj.py, valueObj.py);
            if (idx < 0) return PyError.Propagate;
            return @intCast(idx);
        }
    };
}
