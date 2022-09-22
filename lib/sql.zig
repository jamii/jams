pub const util = @import("./sql/util.zig");

const std = @import("std");
const u = util;

pub const Database = struct {
    pub fn init(allocator: u.Allocator) Database {
        return .{ .allocator = allocator };
    }

    pub fn exec(self: *Database) void {
        _ = self;
    }

    pub fn query(self: *Database) []const []const Value {
        _ = self;
        return &.{};
    }
};

/// https://www.sqlite.org/datatype3.html
pub const Value = union(enum) {
    Null,
    Integer: i64,
    Real: f64,
    Test: []const u8,
    Blob: []const u8,

    // https://www.sqlite.org/datatype3.html#comparisons
};

test {}
