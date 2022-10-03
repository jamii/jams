pub const util = @import("sql/util.zig");
pub const GrammarParser = @import("sql/GrammarParser.zig");
pub const grammar = @import("sql/grammar.zig");
pub const Tokenizer = @import("sql/Tokenizer.zig");
pub const Parser = @import("sql/Parser.zig");
pub const Planner = @import("sql/Planner.zig");
pub const Evaluator = @import("sql/Evaluator.zig");

const std = @import("std");
const u = util;

pub const Database = struct {
    arena: *u.ArenaAllocator,
    allocator: u.Allocator,
    table_defs: u.DeepHashMap(TableName, TableDef),
    tables: u.DeepHashMap(TableName, Table),
    index_defs: u.DeepHashMap(IndexName, IndexDef),

    pub fn init(arena: *u.ArenaAllocator) !Database {
        const allocator = arena.allocator();
        return Database{
            .arena = arena,
            .allocator = allocator,
            .table_defs = u.DeepHashMap(TableName, TableDef).init(allocator),
            .tables = u.DeepHashMap(TableName, Table).init(allocator),
            .index_defs = u.DeepHashMap(IndexName, IndexDef).init(allocator),
        };
    }

    pub fn run(self: *Database, arena: *u.ArenaAllocator, sql: []const u8) !Evaluator.Relation {
        const sql_z = try arena.allocator().dupeZ(u8, sql);
        var tokenizer = Tokenizer.init(arena, sql_z);
        try tokenizer.tokenize();
        var parser = Parser.init(arena, tokenizer, false);
        const root_id = try parser.parse("root") orelse return error.ParseError;
        //const root_id = (try parser.parse("root")) orelse {
        //    u.dump("Failure!");
        //    parser = Parser.init(arena, tokenizer, true);
        //    _ = try parser.parse("root");
        //    u.dump(tokenizer.tokens.items);
        //    //u.dump(parser.failures.items);
        //    if (parser.greatestFailure()) |failure| {
        //        u.dump(failure);
        //        const failure_pos = parser.getFailureSourcePos(failure);
        //        std.debug.print("{s} !!! {s}\n", .{
        //            sql[0..failure_pos],
        //            sql[failure_pos..],
        //        });
        //    }
        //    unreachable;
        //};
        //try countRuleUsage(parser, root_id);
        //u.dump(parser);
        var planner = Planner.init(arena, parser, self.*);
        const statement = try planner.planStatement(root_id.get(parser).statement_or_query);
        var evaluator = Evaluator.init(arena, planner, self, 1000000);
        const relation = evaluator.evalStatement(statement);
        return relation;
    }
};

pub const TableName = []const u8;
pub const ColumnName = []const u8;
pub const IndexName = []const u8;

pub const TableDef = struct {
    columns: []const ColumnDef,
    key: ?Key, // tests never contain more than one key
};

pub const ColumnDef = struct {
    name: ColumnName,
    typ: ?Type,
    nullable: bool,
};

pub const IndexDef = struct {
    table_name: TableName,
};

pub const Key = struct {
    columns: []const usize,
    kind: enum { primary, unique },
};

pub const Table = u.ArrayList([]const Value);

pub const Type = enum {
    nul,
    integer,
    real,
    text,
    blob,
    column,
};

/// https://www.sqlite.org/datatype3.html
pub const Value = union(Type) {
    nul,
    integer: i64,
    real: f64,
    text: []const u8,
    blob: []const u8,
    column: []const Value,

    pub const NULL = Value{ .nul = {} };
    pub const TRUE = Value{ .integer = 1 };
    pub const FALSE = Value{ .integer = 0 };

    pub fn toBool(self: Value) !bool {
        // sqlite actually has some horrible implicit casts, but we'll be sane here
        if (self != .integer) return error.TypeError;
        return self.integer != FALSE.integer;
    }

    pub fn fromBool(b: bool) Value {
        return if (b) TRUE else FALSE;
    }

    pub fn order(a: Value, b: Value) std.math.Order {
        // TODO sqlite has complex casting logic here https://www.sqlite.org/datatype3.html#comparisons
        // but other databases don't, so we may get away with strict comparisons
        return if (a == .integer and b == .real)
            u.deepOrder(@intToFloat(f64, a.integer), b.real)
        else if (a == .real and b == .integer)
            u.deepOrder(a.real, @intToFloat(f64, b.integer))
        else
            u.deepOrder(a, b);
    }

    pub fn isNumeric(self: Value) bool {
        return self == .integer or self == .real;
    }

    pub fn promoteToReal(self: Value) Value {
        return Value{ .real = @intToFloat(f64, self.integer) };
    }

    pub fn promoteIfNeeded(a: *Value, b: *Value) void {
        if (a.* == .real and b.* == .integer)
            b.* = b.promoteToReal();
        if (b.* == .real and a.* == .integer)
            a.* = a.promoteToReal();
    }
};

var rule_usage = u.DeepHashMap([]const u8, struct { q: usize, s: usize }).init(std.heap.page_allocator);

fn countRuleUsage(parser: Parser, root_id: Parser.NodeId("root")) !void {
    var used_rules = u.DeepHashSet([]const u8).init(std.heap.page_allocator);
    defer used_rules.deinit();
    try collectUsedRules(parser, root_id.id, &used_rules);
    var iter = used_rules.keyIterator();
    const is_query = root_id.get(parser).statement_or_query.get(parser) == .select;
    while (iter.next()) |rule_name| {
        const entry = try rule_usage.getOrPutValue(rule_name.*, .{ .s = 0, .q = 0 });
        if (is_query)
            entry.value_ptr.q += 1
        else
            entry.value_ptr.s += 1;
    }
}
fn collectUsedRules(parser: Parser, node_id: usize, used_rules: *u.DeepHashSet([]const u8)) !void {
    const node = parser.nodes.items[node_id];
    try used_rules.put(@tagName(node), {});
    for (parser.node_children.items[node_id]) |child_id|
        try collectUsedRules(parser, child_id, used_rules);
}

pub fn dumpRuleUsage() !void {
    const NameAndCount = struct {
        name: []const u8,
        count: @TypeOf(rule_usage.get("").?),
    };
    var counts = u.ArrayList(NameAndCount).init(std.heap.page_allocator);
    defer counts.deinit();
    inline for (@typeInfo(grammar.rules).Struct.decls) |decl|
        try counts.append(.{
            .name = decl.name,
            .count = rule_usage.get(decl.name) orelse .{ .s = 0, .q = 0 },
        });
    std.sort.sort(NameAndCount, counts.items, {}, (struct {
        fn lessThan(_: void, a: NameAndCount, b: NameAndCount) bool {
            return (a.count.q + a.count.s) < (b.count.q + b.count.s);
        }
    }).lessThan);
    u.dump(counts.items);
}
