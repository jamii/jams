const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;
const Node = sql.grammar.Node;
const N = sql.grammar.types; // TODO move these inside Node
const NodeId = sql.Parser.NodeId;

const Self = @This();
arena: *u.ArenaAllocator,
allocator: u.Allocator,
tokenizer: sql.Tokenizer,
parser: sql.Parser,
relation_exprs: u.ArrayList(RelationExpr),
scalar_exprs: u.ArrayList(ScalarExpr),
next_column_id: usize,

pub const RelationExprId = usize;
pub const ScalarExprId = usize;
pub const ColumnId = usize;

pub const StatementExpr = union(enum) {
    select: RelationExprId,
};

pub const RelationExpr = union(enum) {
    none,
    some,
    map: struct {
        input: RelationExprId,
        column_id: ColumnId,
        expr: ScalarExprId,
    },
};

pub const ScalarExpr = union(enum) {
    value: sql.Value,
    unary: struct {
        input: ScalarExprId,
        op: UnaryOp,
    },
    binary: struct {
        inputs: [2]ScalarExprId,
        op: BinaryOp,
    },
};

pub const UnaryOp = enum {
    not,
    is_null,
    is_not_null,
    bit_not,
    plus,
    minus,
};

pub const BinaryOp = enum {
    bool_and,
    bool_or,
    equal,
    double_equal,
    not_equal,
    is_distinct_from,
    is_not_distinct_from,
    is_not,
    is,
    in,
    match,
    like,
    regexp,
    glob,
    not_in,
    not_match,
    not_like,
    not_regexp,
    not_glob,
    less_than,
    greater_than,
    less_than_or_equal,
    greater_than_or_equal,
    plus,
    minus,
    star,
    forward_slash,
    percent,
    bit_not,
    bit_and,
    bit_or,
};

pub fn init(
    arena: *u.ArenaAllocator,
    tokenizer: sql.Tokenizer,
    parser: sql.Parser,
) Self {
    const allocator = arena.allocator();
    return Self{
        .arena = arena,
        .allocator = allocator,
        .tokenizer = tokenizer,
        .parser = parser,
        .relation_exprs = u.ArrayList(RelationExpr).init(allocator),
        .scalar_exprs = u.ArrayList(ScalarExpr).init(allocator),
        .next_column_id = 0,
    };
}

pub fn planStatement(self: *Self, node_id: NodeId("statement_or_query")) !StatementExpr {
    const p = self.parser;
    const node = node_id.get(p);
    switch (node) {
        .select => |select| return .{ .select = try self.planRelation(select) },
        else => return error.NoPlan,
    }
}

pub fn pushRelation(self: *Self, relation: RelationExpr) !RelationExprId {
    const id = self.relation_exprs.items.len;
    try self.relation_exprs.append(relation);
    return id;
}

pub fn pushScalar(self: *Self, scalar: ScalarExpr) !ScalarExprId {
    const id = self.scalar_exprs.items.len;
    try self.scalar_exprs.append(scalar);
    return id;
}

pub fn planRelation(self: *Self, node_id: anytype) !RelationExprId {
    const p = self.parser;
    const node = node_id.get(p);
    switch (@TypeOf(node)) {
        N.select => return error.NoPlan,
        else => @compileError("planRelation " ++ @typeName(@TypeOf(node))),
    }
}

pub fn planScalar(self: *Self, node_id: anytype) !ScalarExprId {
    const p = self.parser;
    const node = node_id.get(p);
    switch (@TypeOf(node)) {
        else => @compileError("planRelation " ++ @typeName(@TypeOf(node))),
    }
}

fn nextColumn(self: *Self) ColumnId {
    const id = self.next_column_id;
    self.next_column_id += 1;
    return id;
}

fn noPlan(self: *Self, thing: anytype) !void {
    _ = self;
    if (thing != null) return error.NoPlan;
}
