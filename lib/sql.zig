pub const util = @import("sql/util.zig");
pub const GrammarParser = @import("sql/GrammarParser.zig");
pub const grammar = @import("sql/grammar.zig");
pub const Tokenizer = @import("sql/Tokenizer.zig");
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

    pub fn run(self: *Database, sql: []const u8) ![]const []const Value {
        var arena = u.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const sql_z = try arena.allocator().dupeZ(u8, sql);
        var tokenizer = Tokenizer.init(sql_z);
        const tokens = try tokenizer.tokenize(arena.allocator());
        var parser = Parser.init(&arena, tokens);
        const parsed = (try parser.parse("statement_or_query")) orelse return error.ParseError;
        u.dump(parsed);
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
