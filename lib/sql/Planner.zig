const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;
const Node = sql.grammar.Node;
const N = sql.grammar.types; // TODO move these inside Node
const NodeId = sql.Parser.NodeId;

const Self = @This();
arena: *u.ArenaAllocator,
allocator: u.Allocator,
parser: sql.Parser,
database: sql.Database,
relation_exprs: u.ArrayList(RelationExpr),
scalar_exprs: u.ArrayList(ScalarExpr),

pub const RelationExprId = usize;
pub const ScalarExprId = usize;
pub const ColumnId = usize;

pub const StatementExpr = union(enum) {
    create_table: CreateTable,
    create_index: CreateIndex,
    insert: Insert,
    select: RelationExprId,
    drop_table: DropTable,
    drop_index: DropIndex,
    noop,
};

pub const CreateTable = struct {
    name: sql.TableName,
    def: sql.TableDef,
    if_not_exists: bool,
};

pub const CreateIndex = struct {
    name: sql.IndexName,
    def: sql.IndexDef,
    if_not_exists: bool,
};

pub const Insert = struct {
    table_name: sql.TableName,
    query: RelationExprId,
};

pub const DropTable = struct {
    name: sql.TableName,
    if_exists: bool,
};

pub const DropIndex = struct {
    name: sql.TableName,
    if_exists: bool,
};

pub const RelationExpr = union(enum) {
    none,
    some,
    map: struct {
        input: RelationExprId,
        scalar: ScalarExprId,
    },
    filter: struct {
        input: RelationExprId,
        cond: ScalarExprId,
    },
    project: struct {
        input: RelationExprId,
        columns: []const usize,
    },
    unio: struct {
        inputs: [2]RelationExprId,
        all: bool,
    },
    get_table: []const u8,
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
    shift_left,
    shift_right,
    bit_and,
    bit_or,
};

pub const Error = error{
    OutOfMemory,
    NoPlan,
    AbortPlan,
    InvalidLiteral,
};

pub fn init(
    arena: *u.ArenaAllocator,
    parser: sql.Parser,
    database: sql.Database,
) Self {
    const allocator = arena.allocator();
    return Self{
        .arena = arena,
        .allocator = allocator,
        .parser = parser,
        .database = database,
        .relation_exprs = u.ArrayList(RelationExpr).init(allocator),
        .scalar_exprs = u.ArrayList(ScalarExpr).init(allocator),
    };
}

pub fn planStatement(self: *Self, node_id: anytype) !StatementExpr {
    const p = self.parser;
    const node = node_id.get(p);
    switch (@TypeOf(node)) {
        N.statement_or_query => switch (node) {
            .select => |select| return .{ .select = try self.planRelation(select) },
            .create => |create| return self.planStatement(create),
            .insert => |insert| return self.planStatement(insert),
            .drop => |drop| return self.planStatement(drop),
            .reindex => return .{ .noop = {} },
            else => return error.NoPlan,
        },
        N.create => switch (node) {
            .create_table => |create_table| return self.planStatement(create_table),
            .create_index => |create_index| return self.planStatement(create_index),
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
                .def = .{
                    .columns = columns,
                    .key = key,
                },
                .if_not_exists = node.if_not_exists.get(p) != null,
            } };
        },
        N.create_index => {
            return .{ .create_index = .{
                .name = node.index_name.getSource(p),
                .def = .{
                    .table_name = node.table_name.getSource(p),
                },
                .if_not_exists = node.if_not_exists.get(p) != null,
            } };
        },
        N.insert => {
            try self.noPlan(node.insert_or);
            const table_name = node.table_name.getSource(p);
            const table_def = self.database.table_defs.get(table_name) orelse
                return error.AbortPlan;
            var query = try self.planRelation(node.select_or_values);
            if (node.column_names.get(p)) |column_names_expr_id| {
                const column_names_expr = column_names_expr_id.get(p).column_name.get(p);
                const columns = try self.allocator.alloc(usize, column_names_expr.elements.len);
                for (columns) |*column, column_ix| {
                    const column_name = column_names_expr.elements[column_ix].getSource(p);
                    column.* = column: {
                        for (table_def.columns) |column_def, column_def_ix| {
                            if (u.deepEqual(column_name, column_def.name))
                                break :column column_def_ix;
                        }
                        return error.NoPlan;
                    };
                    query = try self.pushRelation(.{ .project = .{
                        .input = query,
                        .columns = columns,
                    } });
                }
            }
            return .{ .insert = .{ .table_name = table_name, .query = query } };
        },
        N.drop => switch (node) {
            .drop_table => |drop_table| return self.planStatement(drop_table),
            .drop_index => |drop_index| return self.planStatement(drop_index),
            else => return error.NoPlan,
        },
        N.drop_table => {
            return .{ .drop_table = .{
                .name = node.table_name.getSource(p),
                .if_exists = node.if_exists.get(p) != null,
            } };
        },
        N.drop_index => {
            return .{ .drop_index = .{
                .name = node.index_name.getSource(p),
                .if_exists = node.if_exists.get(p) != null,
            } };
        },
        else => @compileError("planStatement not implemented for " ++ @typeName(@TypeOf(node))),
    }
}

pub fn planType(self: *Self, node_id: NodeId("typ")) !sql.Type {
    const p = self.parser;
    const name = node_id.get(p).name.getSource(p);
    // TODO fix case comparison
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
        N.values => {
            var plan = try self.pushRelation(.{ .none = {} });
            for (node.row.get(p).elements) |row| {
                const right = try self.planRelation(row);
                plan = try self.pushRelation(.{ .unio = .{
                    .inputs = .{ plan, right },
                    .all = true,
                } });
            }
            return plan;
        },
        N.row => {
            var plan = try self.pushRelation(.{ .some = {} });
            for (node.exprs.get(p).expr.get(p).elements) |expr| {
                const right = try self.planScalar(expr, null);
                plan = try self.pushRelation(.{ .map = .{
                    .input = plan,
                    .scalar = right,
                } });
            }
            return plan;
        },
        N.select_body => {
            try self.noPlan(node.distinct_or_all);
            try self.noPlan(node.group_by);
            try self.noPlan(node.having);
            try self.noPlan(node.window);
            const from_maybe = node.from.get(p);
            var plan = if (from_maybe) |from|
                try self.planRelation(from)
            else
                try self.pushRelation(.{ .some = {} });
            var num_input_columns = if (from_maybe) |_|
                try self.resolve(from_maybe, ColumnCount{})
            else
                0;
            var project_columns = u.ArrayList(usize).init(self.allocator);
            for (node.result_column.get(p).elements) |result_column|
                switch (result_column.get(p)) {
                    .result_expr => |result_expr| {
                        plan = try self.pushRelation(.{ .map = .{
                            .input = plan,
                            .scalar = try self.planScalar(result_expr, from_maybe),
                        } });
                        try project_columns.append(num_input_columns);
                        num_input_columns += 1;
                    },
                    .star => {
                        try project_columns.appendSlice(
                            try self.resolve(from_maybe, ColumnRefStar{ .table_name = null }),
                        );
                    },
                    .table_star => |table_star| {
                        const table_name = table_star.get(p).table_name.getSource(p);
                        try project_columns.appendSlice(
                            try self.resolve(from_maybe, ColumnRefStar{ .table_name = table_name }),
                        );
                    },
                };
            plan = try self.pushRelation(.{ .project = .{
                .input = plan,
                .columns = project_columns.toOwnedSlice(),
            } });
            if (node.where.get(p)) |where|
                plan = try self.pushRelation(.{ .filter = .{
                    .input = plan,
                    .cond = try self.planScalar(where.get(p).expr, from_maybe),
                } });
            return plan;
        },
        N.from => return self.planRelation(node.joins),
        N.joins => {
            if (node.join_clause.get(p).elements.len > 0)
                return error.NoPlan;
            return self.planRelation(node.table_or_subquery);
        },
        N.table_or_subquery => switch (node) {
            .table_as => |table_as| return self.planRelation(table_as),
            else => return error.NoPlan,
        },
        N.table_as => return self.pushRelation(.{ .get_table = node.table_name.getSource(p) }),
        else => @compileError("planRelation not implemented for " ++ @typeName(@TypeOf(node))),
    }
}

pub fn planScalar(self: *Self, node_id: anytype, env_node_id: anytype) Error!ScalarExprId {
    comptime {
        u.comptimeAssert(@hasDecl(@TypeOf(node_id), "is_node_id"), @TypeOf(node_id));
    }
    const p = self.parser;
    const node = node_id.get(p);
    switch (@TypeOf(node)) {
        N.result_expr => return self.planScalar(node.expr, env_node_id),
        N.expr => return self.planScalar(node.expr_or, env_node_id),
        N.expr_or, N.expr_and, N.expr_comp, N.expr_add, N.expr_mult, N.expr_bit => {
            var plan = try self.planScalar(node.left, env_node_id);
            for (node.right.get(p).elements) |right_expr_id| {
                plan = try self.planScalarBinary(node, plan, right_expr_id, env_node_id);
            }
            return plan;
        },
        N.expr_not, N.expr_unary => {
            var plan = try self.planScalar(node.expr, env_node_id);
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
            var plan = try self.planScalar(node.left, env_node_id);
            for (node.right.get(p).elements) |right_expr| {
                switch (right_expr.get(p)) {
                    .expr_incomp_postop => |_| return error.NoPlan,
                    .expr_incomp_binop => |binop| plan = try self.planScalarBinary(node, plan, binop, env_node_id),
                    .expr_incomp_in => |_| return error.NoPlan,
                    .expr_incomp_between => |expr_incomp_between| {
                        // https://www.sqlite.org/lang_expr.html#between
                        const start = try self.planScalar(expr_incomp_between.get(p).start, env_node_id);
                        const end = try self.planScalar(expr_incomp_between.get(p).end, env_node_id);
                        // TODO should avoid evaluating plan twice
                        plan = try self.pushScalar(.{ .binary = .{
                            .inputs = .{
                                try self.pushScalar(.{ .binary = .{
                                    .inputs = .{
                                        plan,
                                        start,
                                    },
                                    .op = .greater_than_or_equal,
                                } }),
                                try self.pushScalar(.{ .binary = .{
                                    .inputs = .{
                                        plan,
                                        end,
                                    },
                                    .op = .less_than_or_equal,
                                } }),
                            },
                            .op = .bool_and,
                        } });
                    },
                }
            }
            return plan;
        },
        N.expr_atom => switch (node) {
            .value => |value| return self.planScalar(value, env_node_id),
            .table_column_ref => |table_column_ref| return self.planScalar(table_column_ref, env_node_id),
            .column_ref => |column_ref| return self.planScalar(column_ref, env_node_id),
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
                .blob => blob: {
                    const source = node_id.getSource(p);
                    var blob = try u.ArrayList(u8).initCapacity(self.allocator, (source.len - 3) * 2);
                    var i: usize = 2;
                    while (i < source.len - 1) : (i += 1) {
                        if (std.fmt.parseInt(u16, source[i .. i + 1], 16)) |num|
                            blob.appendSliceAssumeCapacity(&@bitCast([2]u8, num))
                        else |_|
                            return error.InvalidLiteral;
                    }
                    break :blob sql.Value{ .blob = blob.toOwnedSlice() };
                },
                .NULL => sql.Value{ .nul = {} },
            };
            return self.pushScalar(.{ .value = value });
        },
        N.table_column_ref => {
            const ref = ColumnRef{
                .table_name = node.table_name.getSource(p),
                .column_name = node.column_name.getSource(p),
            };
            const column = try self.resolve(env_node_id, ref);
            return self.pushScalar(.{ .column = column });
        },
        N.column_ref => {
            const ref = ColumnRef{
                .table_name = null,
                .column_name = node.column_name.getSource(p),
            };
            const column = try self.resolve(env_node_id, ref);
            return self.pushScalar(.{ .column = column });
        },
        else => @compileError("planScalar not implemented for " ++ @typeName(@TypeOf(node))),
    }
}

fn planScalarBinary(self: *Self, parent: anytype, left: ScalarExprId, right_expr_id: anytype, env_node_id: anytype) Error!ScalarExprId {
    const p = self.parser;
    const right_expr = right_expr_id.get(p);
    const right = try self.planScalar(right_expr.right, env_node_id);
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
            N.expr_bit => switch (right_expr.op.get(p)) {
                .shift_left => .shift_left,
                .shift_right => .shift_right,
                .bit_and => .bit_and,
                .bit_or => .bit_or,
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

fn noPlan(self: *Self, node_id: anytype) Error!void {
    const p = self.parser;
    const node = node_id.get(p);
    if (node != null) return error.NoPlan;
}

const ColumnCount = struct {};

const ColumnRef = struct {
    table_name: ?[]const u8,
    column_name: []const u8,
};

const ColumnRefStar = struct {
    table_name: ?[]const u8,
};

fn Resolve(comptime ref: type) type {
    return switch (ref) {
        ColumnCount => usize,
        ColumnRef => usize,
        ColumnRefStar => []const usize,
        else => unreachable,
    };
}

fn resolve(self: *Self, env_node_id: anytype, ref: anytype) Error!Resolve(@TypeOf(ref)) {
    if (env_node_id == null)
        return error.AbortPlan;
    return self.resolveInner(env_node_id.?, ref, 0);
}

fn resolveInner(self: *Self, env_node_id: anytype, ref: anytype, offset: usize) Error!Resolve(@TypeOf(ref)) {
    const p = self.parser;
    const env_node = env_node_id.get(p);
    switch (@TypeOf(env_node)) {
        N.from => return self.resolveInner(env_node.joins, ref, offset),
        N.joins => {
            if (env_node.join_clause.get(p).elements.len > 0)
                return error.NoPlan;
            return self.resolveInner(env_node.table_or_subquery, ref, offset);
        },
        N.table_or_subquery => switch (env_node) {
            .table_as => |table_as| return self.resolveInner(table_as, ref, offset),
            else => return error.NoPlan,
        },
        N.table_as => {
            const table_def = self.database.table_defs.get(env_node.table_name.getSource(p)) orelse
                return error.AbortPlan;
            switch (@TypeOf(ref)) {
                ColumnCount => return table_def.columns.len,
                ColumnRef => {
                    var columns = u.ArrayList(usize).init(self.allocator);
                    const table_name = if (env_node.as_table.get(p)) |as_table|
                        as_table.get(p).table_name.getSource(p)
                    else
                        env_node.table_name.getSource(p);
                    if (ref.table_name != null and !u.deepEqual(ref.table_name.?, table_name))
                        return error.AbortPlan;
                    for (table_def.columns) |column_def, i|
                        if (u.deepEqual(ref.column_name, column_def.name))
                            try columns.append(i + offset);
                    switch (columns.items.len) {
                        1 => return columns.items[0],
                        else => return error.AbortPlan,
                    }
                },
                ColumnRefStar => {
                    const columns = try self.allocator.alloc(usize, table_def.columns.len);
                    for (columns) |*column, i|
                        column.* = i + offset;
                    return columns;
                },
                else => unreachable,
            }
        },
        else => @compileError("resolveInner not implemented for " ++ @typeName(@TypeOf(env_node))),
    }
}
