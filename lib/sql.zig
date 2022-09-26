pub const util = @import("sql/util.zig");
pub const BnfParser = @import("sql/BnfParser.zig");
pub const Parser = @import("sql/Parser.zig");

const std = @import("std");
const u = util;

pub const Database = struct {
    allocator: u.Allocator,
    bnf: *const BnfParser,

    pub fn init(allocator: u.Allocator, bnf: *const BnfParser) !Database {
        return Database{
            .allocator = allocator,
            .bnf = bnf,
        };
    }

    pub fn deinit(self: *Database) void {
        _ = self;
    }

    pub fn runStatement(self: *Database, statement: []const u8) !void {
        var parser = Parser.init(self.allocator, self.bnf, statement);
        try parser.parseStatement();
        return error.Unimplemented;
    }

    pub fn runQuery(self: *Database, query: []const u8) ![]const []const Value {
        var parser = Parser.init(self.allocator, self.bnf, query);
        try parser.parseQuery();
        return error.Unimplemented;
    }
};

pub const Type = enum {
    nul,
    integer,
    real,
    text,
    blob,
};

/// https://www.sqlite.org/datatype3.html
pub const Value = union(Type) {
    nul,
    integer: i64,
    real: f64,
    text: []const u8,
    blob: []const u8,

    // https://www.sqlite.org/datatype3.html#comparisons
};

test {}
