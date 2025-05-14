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
const py = @import("pydust.zig");
const Type = @import("pytypes.zig").Type;
const State = @import("discovery.zig").State;

pub fn Attribute(comptime root: type) type {
    return struct {
        name: [:0]const u8,
        ctor: fn (module: py.PyModule(root)) py.PyError!py.PyObject(root),
    };
}

/// Finds the attributes on a module or class definition.
pub fn Attributes(comptime root: type, comptime definition: type) type {
    return struct {
        const attr_count = blk: {
            var cnt = 0;
            for (@typeInfo(definition).@"struct".decls) |decl| {
                const value = @field(definition, decl.name);

                if (State.findDefinition(root, value)) |def| {
                    if (def.type == .class) {
                        cnt += 1;
                    }
                }
            }
            break :blk cnt;
        };

        pub const attributes: [attr_count]Attribute(root) = blk: {
            var attrs: [attr_count]Attribute(root) = undefined;
            var idx = 0;
            for (@typeInfo(definition).@"struct".decls) |decl| {
                const value = @field(definition, decl.name);

                if (State.findDefinition(root, value)) |def| {
                    if (def.type == .class) {
                        const Closure = struct {
                            pub fn init(module: py.PyModule(root)) !py.PyObject(root) {
                                const typedef = Type(root, decl.name ++ "", def.definition);
                                return try typedef.init(module);
                            }
                        };
                        attrs[idx] = .{ .name = decl.name ++ "", .ctor = Closure.init };
                        idx += 1;
                    }
                }
            }
            break :blk attrs;
        };
    };
}
