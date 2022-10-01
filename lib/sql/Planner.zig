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
    create_table: CreateTable,
    insert: Insert,
    select: RelationExprId,
};

pub const CreateTable = struct {
    name: sql.TableName,
    def: sql.TableDef,
    if_not_exists: bool,
};

pub const Insert = struct {
    table_name: sql.TableName,
    query: RelationExprId,
};

pub const RelationExpr = union(enum) {
    none,
    some,
    map: struct {
        input: RelationExprId,
        column_id: ColumnId,
        scalar: ScalarExprId,
    },
    project: struct {
        input: RelationExprId,
        columns: []const usize,
    },
};

pub const ScalarExpr = union(enum) {
    value: sql.Value,
    column: usize,
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
    is_null,
    is_not_null,
    bool_not,
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
    bit_and,
    bit_or,
};

pub const Error = error{
    OutOfMemory,
    NoPlan,
    InvalidLiteral,
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

pub fn planStatement(self: *Self, node_id: anytype) !StatementExpr {
    const p = self.parser;
    const node = node_id.get(p);
    switch (@TypeOf(node)) {
        N.statement_or_query => switch (node) {
            .select => |select| return .{ .select = try self.planRelation(select) },
            .create => |create| return self.planStatement(create),
            else => return error.NoPlan,
        },
        N.create => switch (node) {
            .create_table => |create_table| return self.planStatement(create_table),
            else => return error.NoPlan,
        },
        N.create_table => {
            const name = node.table_name.getSource(p);
            const defs_expr = node.column_defs.get(p).column_def.get(p);
            var key: ?sql.Key = null;
            const columns = try self.allocator.alloc(sql.ColumnDef, defs_expr.elements.len);
            for (columns) |*column, i| {
                const def_expr = defs_expr.elements[i].get(p);
                column.* = .{
                    .name = def_expr.column_name.getSource(p),
                    .typ = if (def_expr.typ.get(p)) |typ|
                        try self.planType(typ)
                    else
                        null,
                    .nullable = true, // no `NOT NULL` constraints in tests
                };
                if (def_expr.column_constraint.get(p)) |constraint| {
                    switch (constraint.get(p)) {
                        .key => |key_expr_id| {
                            const key_expr = key_expr_id.get(p);
                            key = .{
                                .columns = try self.allocator.dupe(usize, &.{i}),
                                .kind = switch (key_expr.kind.get(p)) {
                                    .PRIMARY => .primary,
                                    .UNIQUE => .unique,
                                },
                            };
                        },
                    }
                }
            }
            return .{ .create_table = .{
                .name = name,
                .def = .{ .columns = columns, .key = key },
                .if_not_exists = node.IF_NOT_EXISTS.get(p) != null,
            } };
        },
        N.insert => {
            const table_name = node.table_name.getSource(p);
            const table_def = self.database.table_defs.get(table_name) orelse
                return error.NoPlan;
            var query = try self.planRelation(node.values_or_select);
            if (node.column_names) |column_names_expr_id| {
                const column_names_expr = column_names_expr_id.get(p).column_name.get(p);
                const columns = try self.allocator.create(usize, column_names_expr.elements.len);
                for (columns.?) |*column, column_ix| {
                    const column_name = column_names_expr.elements[column_ix].getSource();
                    for (table_def.columns) |column_def, column_def_ix| {
                        if (u.deepEqual(column_name, column_def.name))
                            column.* = column_def_ix;
                        break;
                    } else return error.NoPlan;
                    query = self.pushRelation(.{ .project = .{
                        .input = query,
                        .columns = columns,
                    } });
                }
            }
            return .{ .insert = .{ .table_name = table_name, .query = query } };
        },
        else => @compileError("planStatement not implemented for " ++ @typeName(@TypeOf(node))),
    }
}

pub fn planType(self: *Self, node_id: NodeId("typ")) !sql.Type {
    const p = self.parser;
    const name = node_id.get(p).name.getSource(p);
    if (u.deepEqual(name, "INTEGER"))
        return .integer;
    if (u.deepEqual(name, "FLOAT"))
        return .real;
    if (u.deepEqual(name, "VARCHAR") or
        u.deepEqual(name, "TEXT"))
        return .text;
    return error.NoPlan;
}

pub fn pushRelation(self: *Self, relation: RelationExpr) Error!RelationExprId {
    const id = self.relation_exprs.items.len;
    try self.relation_exprs.append(relation);
    return id;
}

pub fn pushScalar(self: *Self, scalar: ScalarExpr) Error!ScalarExprId {
    const id = self.scalar_exprs.items.len;
    try self.scalar_exprs.append(scalar);
    return id;
}

pub fn planRelation(self: *Self, node_id: anytype) Error!RelationExprId {
    const p = self.parser;
    const node = node_id.get(p);
    switch (@TypeOf(node)) {
        N.select => {
            try self.noPlan(node.order_by);
            try self.noPlan(node.limit);
            const select_or_values = node.select_or_values.get(p);
            if (select_or_values.elements.len > 1) return error.NoPlan;
            return self.planRelation(select_or_values.elements[0]);
        },
        N.select_or_values => switch (node) {
            .select_body => |select_body| return self.planRelation(select_body),
            .values => |values| return self.planRelation(values),
        },
        N.values => return error.NoPlan,
        N.select_body => {
            try self.noPlan(node.distinct_or_all);
            try self.noPlan(node.from);
            try self.noPlan(node.where);
            try self.noPlan(node.group_by);
            try self.noPlan(node.having);
            try self.noPlan(node.window);
            var plan = try self.pushRelation(.some);
            for (node.result_column.get(p).elements) |result_column|
                plan = try self.pushRelation(.{ .map = .{
                    .input = plan,
                    .column_id = self.nextColumnId(),
                    .scalar = try self.planScalar(result_column),
                } });
            return plan;
        },
        else => @compileError("planRelation not implemented for " ++ @typeName(@TypeOf(node))),
    }
}

pub fn planScalar(self: *Self, node_id: anytype) Error!ScalarExprId {
    comptime {
        u.comptimeAssert(@hasDecl(@TypeOf(node_id), "is_node_id"), @TypeOf(node_id));
    }
    const p = self.parser;
    const node = node_id.get(p);
    switch (@TypeOf(node)) {
        N.result_column => switch (node) {
            .result_expr => |result_expr| return self.planScalar(result_expr),
            .star, .table_star => return error.NoPlan,
        },
        N.result_expr => return self.planScalar(node.expr),
        N.expr => return self.planScalar(node.expr_or),
        N.expr_or, N.expr_and, N.expr_comp, N.expr_add, N.expr_mult => {
            var plan = try self.planScalar(node.left);
            for (node.right.get(p).elements) |right_expr_id| {
                plan = try self.planScalarBinary(node, plan, right_expr_id);
            }
            return plan;
        },
        N.expr_not, N.expr_unary => {
            var plan = try self.planScalar(node.expr);
            for (node.op.get(p).elements) |op|
                plan = try self.pushScalar(.{ .unary = .{ .input = plan, .op = switch (@TypeOf(node)) {
                    N.expr_not => .bool_not,
                    N.expr_unary => switch (op.get(p)) {
                        .bit_not => .bit_not,
                        .plus => .plus,
                        .minus => .minus,
                    },
                    else => unreachable,
                } } });
            return plan;
        },
        N.expr_incomp => {
            var plan = try self.planScalar(node.left);
            for (node.right.get(p).elements) |right_expr| {
                switch (right_expr.get(p)) {
                    .expr_incomp_postop => |_| return error.NoPlan,
                    .expr_incomp_binop => |binop| plan = try self.planScalarBinary(node, plan, binop),
                    .expr_incomp_in => |_| return error.NoPlan,
                    .expr_incomp_between => |_| return error.NoPlan,
                }
            }
            return plan;
        },
        N.expr_atom => switch (node) {
            .value => |value| return self.planScalar(value),
            else => return error.NoPlan,
        },
        N.value => {
            const value = switch (node) {
                .number => number: {
                    // TODO
                    const source = node_id.getSource(p);
                    break :number if (std.fmt.parseInt(i64, source, 10)) |integer|
                        sql.Value{ .integer = integer }
                    else |_| if (std.fmt.parseFloat(f64, source)) |real|
                        sql.Value{ .real = real }
                    else |_|
                        return error.InvalidLiteral;
                },
                .string => string: {
                    const source = node_id.getSource(p);
                    var string = try u.ArrayList(u8).initCapacity(self.allocator, source.len - 2);
                    var i: usize = 1;
                    while (i < source.len - 1) : (i += 1) {
                        const char = source[i];
                        string.appendAssumeCapacity(char);
                        // The only way we can hit " in a "-string is if there is a ""-escape, so ditch one of them
                        if (char == source[0]) i += 1;
                    }
                    break :string sql.Value{ .text = string.toOwnedSlice() };
                },
                .NULL => sql.Value{ .nul = {} },
            };
            return self.pushScalar(.{ .value = value });
        },
        else => @compileError("planScalar not implemented for " ++ @typeName(@TypeOf(node))),
    }
}

fn planScalarBinary(self: *Self, parent: anytype, left: ScalarExprId, right_expr_id: anytype) Error!ScalarExprId {
    const p = self.parser;
    const right_expr = right_expr_id.get(p);
    const right = try self.planScalar(right_expr.right);
    return try self.pushScalar(.{ .binary = .{
        .inputs = .{ left, right },
        .op = switch (@TypeOf(parent)) {
            N.expr_or => .bool_or,
            N.expr_and => .bool_and,
            N.expr_incomp => switch (right_expr.op.get(p)) {
                .equal => .equal,
                .double_equal => .double_equal,
                .not_equal => .not_equal,
                .IS_DISTINCT_FROM => .is_distinct_from,
                .IS_NOT_DISTINCT_FROM => .is_not_distinct_from,
                .IS_NOT => .is_not,
                .IS => .is,
                .IN => .in,
                .MATCH => .match,
                .LIKE => .like,
                .REGEXP => .regexp,
                .GLOB => .glob,
                .NOT_IN => .not_in,
                .NOT_MATCH => .not_match,
                .NOT_LIKE => .not_like,
                .NOT_REGEXP => .not_regexp,
                .NOT_GLOB => .not_glob,
            },
            N.expr_comp => switch (right_expr.op.get(p)) {
                .less_than => .less_than,
                .greater_than => .greater_than,
                .less_than_or_equal => .less_than_or_equal,
                .greater_than_or_equal => .greater_than_or_equal,
            },
            N.expr_add => switch (right_expr.op.get(p)) {
                .plus => .plus,
                .minus => .minus,
            },
            N.expr_mult => switch (right_expr.op.get(p)) {
                .star => .star,
                .forward_slash => .forward_slash,
                .percent => .percent,
            },
            else => unreachable,
        },
    } });
}

fn nextColumnId(self: *Self) ColumnId {
    const id = self.next_column_id;
    self.next_column_id += 1;
    return id;
}

fn noPlan(self: *Self, node_id: anytype) Error!void {
    const p = self.parser;
    const node = node_id.get(p);
    if (node != null) return error.NoPlan;
}
