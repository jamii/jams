pub const util = @import("sql/util.zig");
pub const GrammarParser = @import("sql/GrammarParser.zig");
pub const grammar = @import("sql/grammar.zig");
pub const Parser = @import("sql/Parser.zig");

const std = @import("std");
const u = util;

pub const Database = struct {
    allocator: u.Allocator,

    pub fn init(allocator: u.Allocator) !Database {
        return Database{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Database) void {
        _ = self;
    }

    pub fn runStatement(self: *Database, statement: []const u8) !void {
        var parser = Parser.init(self.allocator, self.bnf, statement);
        defer parser.deinit();
        _ = try parser.parse(self.bnf.sql_procedure_statement.?);
        return error.Unimplemented;
    }

    pub fn runQuery(self: *Database, query: []const u8) ![]const []const Value {
        var parser = Parser.init(self.allocator, self.bnf, query);
        defer parser.deinit();
        _ = try parser.parse(self.bnf.query_specification.?);
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
