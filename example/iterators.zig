// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

const std = @import("std");
const py = @import("pydust");

pub const Range = py.class("Range", struct {
    pub const __doc__ = "An example of iterable class";

    const Self = @This();

    lower: i64,
    upper: i64,
    step: i64,

    pub fn __new__(args: struct { lower: i64, upper: i64, step: i64 }) !Self {
        return .{ .lower = args.lower, .upper = args.upper, .step = args.step };
    }

    pub fn __iter__(self: *const Self) !*RangeIterator {
        return try py.init(RangeIterator, .{ .next = self.lower, .stop = self.upper, .step = self.step });
    }
});

pub const RangeIterator = py.class("RangeIterator", struct {
    pub const __doc__ = "Range iterator";

    const Self = @This();

    next: i64,
    stop: i64,
    step: i64,

    pub fn __new__(args: struct { next: i64, stop: i64, step: i64 }) !Self {
        return .{ .next = args.next, .stop = args.stop, .step = args.step };
    }

    pub fn __next__(self: *Self) !?i64 {
        if (self.next >= self.stop) {
            return null;
        }
        defer self.next += self.step;
        return self.next;
    }
});

comptime {
    py.module(@This());
}
