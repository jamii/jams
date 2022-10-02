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
        column_id: ColumnId,
        scalar: ScalarExprId,
    },
    filter: struct {
        input: RelationExprId,
        cond: ScalarExprId,
    },
    project: struct {
        input: RelationExprId,
        column_ids: []ColumnId,
    },
    unio: struct {
        inputs: [2]RelationExprId,
        all: bool,
    },
    get_table: struct {
        table_name: []const u8,
        column_ids: []ColumnId,
    },
    distinct: RelationExprId,
    //order_by: struct {
    //    input: RelationExprId,
    //    ordering: []const Ordering,
    //},
};

pub const Ordering = struct {
    column: ColumnId,
    desc: bool,
};

pub const ScalarExpr = union(enum) {
    value: sql.Value,
    column: ColumnId,
    unary: struct {
        input: ScalarExprId,
        op: UnaryOp,
    },
    binary: struct {
        inputs: [2]ScalarExprId,
        op: BinaryOp,
    },
    in: struct {
        not: bool,
        input: ScalarExprId,
        subplan: RelationExprId,
        // We can't plan correlated subqueries, and non-correlated subqueries are always safe to cache
        subplan_cache: ?sql.Evaluator.Relation,
    },
};

pub const ColumnId = struct {
    node_id: usize,
    // This should only be set if node_id is a relation expr.
    column_name: ?[]const u8,
    // This is initially null and is set by arrangeRelation/Scalar.
    ix: ?usize = null,
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
    match,
    like,
    regexp,
    glob,
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
    BadArrange,
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
            .select => |select| return self.planStatement(select),
            .create => |create| return self.planStatement(create),
            .insert => |insert| return self.planStatement(insert),
            .drop => |drop| return self.planStatement(drop),
            .reindex => return .{ .noop = {} },
            else => return error.NoPlan,
        },
        N.select => {
            const plan = try self.planRelation(node_id);
            _ = try self.arrangeRelation(plan);
            return .{ .select = plan };
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
                const column_ids = try self.allocator.alloc(ColumnId, column_names_expr.elements.len);
                for (column_ids) |*column_id, column_ix| {
                    const column_name = column_names_expr.elements[column_ix].getSource(p);
                    // Check that column exists in table
                    for (table_def.columns) |column_def| {
                        if (u.deepEqual(column_name, column_def.name))
                            break;
                    } else return error.NoPlan;
                    column_id.* = .{
                        .node_id = node.select_or_values.id,
                        .column_name = column_name,
                    };
                }
                query = try self.pushRelation(.{ .project = .{
                    .input = query,
                    .column_ids = column_ids,
                } });
            }
            _ = try self.arrangeRelation(query);
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
            try self.noPlan(node.limit);
            const select_or_values = node.select_or_values.get(p);
            if (select_or_values.elements.len > 1) return error.NoPlan;
            const select_or_values0 = select_or_values.elements[0];
            var plan = try self.planRelation(select_or_values0);
            try self.noPlan(node.order_by);
            //if (node.order_by.get(p)) |order_by| {
            //    var ordering = u.ArrayList(Ordering).init(self.allocator);
            //    const init_num_columns = try self.resolveNotNull(select_or_values0, ColumnCount{}, 0);
            //    var num_columns = init_num_columns;
            //    for (order_by.get(p).ordering_terms.get(p).ordering_term.get(p).elements) |term_id| {
            //        const term = term_id.get(p);
            //        try self.noPlan(term.collate);
            //        try self.noPlan(term.nulls_first_or_last);
            //        const column = num_columns;
            //        plan = try self.pushRelation(.{ .map = .{
            //            .input = plan,
            //            .scalar = try self.planScalar(term.expr, node.select_or_values),
            //        } });
            //        const desc = if (term.asc_or_desc.get(p)) |asc_or_desc|
            //            asc_or_desc.get(p) == .DESC
            //        else
            //            false;
            //        try ordering.append(.{
            //            .column = column,
            //            .desc = desc,
            //        });
            //    }
            //    plan = try self.pushRelation(.{ .order_by = .{
            //        .input = plan,
            //        .ordering = ordering.toOwnedSlice(),
            //    } });
            //    const project_columns = try self.allocator.alloc(usize, init_num_columns);
            //    for (project_columns) |*project_column, i|
            //        project_column.* = i;
            //    plan = try self.pushRelation(.{ .project = .{
            //        .input = plan,
            //        .columns = project_columns,
            //    } });
            //}
            return plan;
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
                    .column_id = .{
                        .node_id = expr.id,
                        .column_name = null,
                    },
                    .scalar = right,
                } });
            }
            return plan;
        },
        N.select_body => {
            try self.noPlan(node.group_by);
            try self.noPlan(node.having);
            try self.noPlan(node.window);
            const from_maybe = node.from.get(p);
            var plan = if (from_maybe) |from|
                try self.planRelation(from)
            else
                try self.pushRelation(.{ .some = {} });
            if (node.where.get(p)) |where|
                plan = try self.pushRelation(.{
                    .filter = .{
                        .input = plan,
                        // TODO where should resolve from both from_maybe and select_body
                        .cond = try self.planScalar(where.get(p).expr, from_maybe),
                    },
                });
            var project_column_ids = u.ArrayList(ColumnId).init(self.allocator);
            for (node.result_column.get(p).elements) |result_column|
                switch (result_column.get(p)) {
                    .result_expr => |result_expr| {
                        const column_id = ColumnId{
                            .node_id = result_expr.id,
                            .column_name = null,
                        };
                        plan = try self.pushRelation(.{ .map = .{
                            .input = plan,
                            .column_id = column_id,
                            .scalar = try self.planScalar(result_expr, from_maybe),
                        } });
                        try project_column_ids.append(column_id);
                    },
                    .star => {
                        try project_column_ids.appendSlice(
                            try self.resolve(from_maybe, ColumnRefStar{ .table_name = null }),
                        );
                    },
                    .table_star => |table_star| {
                        const table_name = table_star.get(p).table_name.getSource(p);
                        try project_column_ids.appendSlice(
                            try self.resolve(from_maybe, ColumnRefStar{ .table_name = table_name }),
                        );
                    },
                };
            plan = try self.pushRelation(.{ .project = .{
                .input = plan,
                .column_ids = project_column_ids.toOwnedSlice(),
            } });
            if (node.distinct_or_all.get(p)) |distinct_or_all| {
                if (distinct_or_all.get(p) == .DISTINCT)
                    plan = try self.pushRelation(.{ .distinct = plan });
            }
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
        N.table_as => {
            return self.pushRelation(.{ .get_table = .{
                .table_name = node.table_name.getSource(p),
                .column_ids = try self.resolveNotNull(node_id, ColumnRefStar{ .table_name = null }, 0),
            } });
        },
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
                    .expr_incomp_postop => |expr_incomp_postop| {
                        for (expr_incomp_postop.get(p).op.get(p).elements) |op| {
                            plan = try self.pushScalar(.{ .binary = .{
                                .inputs = .{
                                    plan,
                                    try self.pushScalar(.{ .value = sql.Value.NULL }),
                                },
                                .op = switch (op.get(p)) {
                                    .ISNULL => .is,
                                    .NOTNULL, .NOT_NULL => .is_not,
                                },
                            } });
                        }
                    },
                    .expr_incomp_binop => |binop| plan = try self.planScalarBinary(node, plan, binop, env_node_id),
                    .expr_incomp_in => |expr_incomp_in| {
                        const subplan = subplan: {
                            switch (expr_incomp_in.get(p).right.get(p)) {
                                .exprs => |exprs| {
                                    var subplan = try self.pushRelation(.{ .none = {} });
                                    for (exprs.get(p).expr.get(p).elements) |expr|
                                        subplan = try self.pushRelation(.{ .unio = .{
                                            .inputs = .{
                                                subplan,
                                                try self.pushRelation(.{ .map = .{
                                                    .input = try self.pushRelation(.{ .some = {} }),
                                                    .column_id = .{
                                                        .node_id = expr.id,
                                                        .column_name = null,
                                                    },
                                                    .scalar = try self.planScalar(expr, env_node_id),
                                                } }),
                                            },
                                            .all = true,
                                        } });
                                    break :subplan subplan;
                                },
                                .select => |select|
                                // TODO handle correlated variables
                                break :subplan try self.planRelation(select),
                            }
                        };
                        plan = try self.pushScalar(.{ .in = .{
                            .not = expr_incomp_in.get(p).NOT.get(p) != null,
                            .input = plan,
                            .subplan = subplan,
                            .subplan_cache = null,
                        } });
                    },
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
            .subexpr => |subexpr| return self.planScalar(subexpr, env_node_id),
            .table_column_ref => |table_column_ref| return self.planScalar(table_column_ref, env_node_id),
            .column_ref => |column_ref| return self.planScalar(column_ref, env_node_id),
            .value => |value| return self.planScalar(value, env_node_id),
            else => return error.NoPlan,
        },
        N.subexpr => return self.planScalar(node.expr, env_node_id),
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
                .MATCH => .match,
                .LIKE => .like,
                .REGEXP => .regexp,
                .GLOB => .glob,
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

const ColumnRef = struct {
    table_name: ?[]const u8,
    column_name: []const u8,
};

const ColumnRefStar = struct {
    table_name: ?[]const u8,
};

fn Resolve(comptime ref: type) type {
    return switch (ref) {
        ColumnRef => ColumnId,
        ColumnRefStar => []ColumnId,
        else => unreachable,
    };
}

fn resolve(self: *Self, env_node_id: anytype, ref: anytype) Error!Resolve(@TypeOf(ref)) {
    if (env_node_id == null)
        return error.AbortPlan;
    return self.resolveNotNull(env_node_id.?, ref, 0);
}

fn resolveNotNull(self: *Self, env_node_id: anytype, ref: anytype, offset: usize) Error!Resolve(@TypeOf(ref)) {
    const p = self.parser;
    const env_node = env_node_id.get(p);
    switch (@TypeOf(env_node)) {
        N.select_or_values => switch (env_node) {
            .select_body => |select_body| return self.resolveNotNull(select_body, ref, offset),
            .values => return error.NoPlan,
        },
        N.select_body => {
            // TODO
            unreachable;
        },
        N.from => return self.resolveNotNull(env_node.joins, ref, offset),
        N.joins => {
            if (env_node.join_clause.get(p).elements.len > 0)
                return error.NoPlan;
            return self.resolveNotNull(env_node.table_or_subquery, ref, offset);
        },
        N.table_or_subquery => switch (env_node) {
            .table_as => |table_as| return self.resolveNotNull(table_as, ref, offset),
            else => return error.NoPlan,
        },
        N.table_as => {
            const table_def = self.database.table_defs.get(env_node.table_name.getSource(p)) orelse
                return error.AbortPlan;
            switch (@TypeOf(ref)) {
                ColumnRef => {
                    var column_ids = u.ArrayList(ColumnId).init(self.allocator);
                    const table_name = if (env_node.as_table.get(p)) |as_table|
                        as_table.get(p).table_name.getSource(p)
                    else
                        env_node.table_name.getSource(p);
                    if (ref.table_name != null and !u.deepEqual(ref.table_name.?, table_name))
                        return error.AbortPlan;
                    for (table_def.columns) |column_def|
                        if (u.deepEqual(ref.column_name, column_def.name))
                            try column_ids.append(.{
                                .node_id = env_node_id.id,
                                .column_name = ref.column_name,
                            });
                    switch (column_ids.items.len) {
                        1 => return column_ids.items[0],
                        else => return error.AbortPlan,
                    }
                },
                ColumnRefStar => {
                    const column_ids = try self.allocator.alloc(ColumnId, table_def.columns.len);
                    for (column_ids) |*column_id, i|
                        column_id.* = .{
                            .node_id = env_node_id.id,
                            .column_name = table_def.columns[i].name,
                        };
                    return column_ids;
                },
                else => unreachable,
            }
        },
        else => @compileError("resolveNotNull not implemented for " ++ @typeName(@TypeOf(env_node))),
    }
}

fn arrangeRelation(self: *Self, relation_expr_id: RelationExprId) Error![]ColumnId {
    const relation_expr = &self.relation_exprs.items[relation_expr_id];
    switch (relation_expr.*) {
        .none, .some => return &.{},
        .map => |*map| {
            const input = try self.arrangeRelation(map.input);
            try self.arrangeScalar(map.scalar, input);
            map.column_id.ix = input.len;
            var column_ids = try u.ArrayList(ColumnId).initCapacity(self.allocator, input.len + 1);
            column_ids.appendSliceAssumeCapacity(input);
            column_ids.appendAssumeCapacity(map.column_id);
            return column_ids.toOwnedSlice();
        },
        .filter => |filter| {
            const input = try self.arrangeRelation(filter.input);
            try self.arrangeScalar(filter.cond, input);
            return input;
        },
        .project => |project| {
            const input = try self.arrangeRelation(project.input);
            for (project.column_ids) |*column_id|
                try arrangeColumnId(column_id, input);
            return project.column_ids;
        },
        .unio => |unio| {
            const left = try self.arrangeRelation(unio.inputs[0]);
            const right = try self.arrangeRelation(unio.inputs[1]);
            var column_ids = try u.ArrayList(ColumnId).initCapacity(self.allocator, left.len + right.len);
            column_ids.appendSliceAssumeCapacity(left);
            column_ids.appendSliceAssumeCapacity(right);
            return column_ids.toOwnedSlice();
        },
        .get_table => |get_table| {
            return get_table.column_ids;
        },
        .distinct => |distinct_input| {
            return try self.arrangeRelation(distinct_input);
        },
    }
}

fn arrangeScalar(self: *Self, scalar_expr_id: ScalarExprId, input: []const ColumnId) Error!void {
    const scalar_expr = &self.scalar_exprs.items[scalar_expr_id];
    switch (scalar_expr.*) {
        .value => {},
        .column => |*column_id| {
            try arrangeColumnId(column_id, input);
        },
        .unary => |unary| {
            try self.arrangeScalar(unary.input, input);
        },
        .binary => |binary| {
            try self.arrangeScalar(binary.inputs[0], input);
            try self.arrangeScalar(binary.inputs[1], input);
        },
        .in => |in| {
            try self.arrangeScalar(in.input, input);
            _ = try self.arrangeRelation(in.subplan);
        },
    }
}

fn arrangeColumnId(column_id: *ColumnId, input: []const ColumnId) Error!void {
    column_id.ix = ix: {
        for (input) |input_column_id, input_column_ix| {
            if (column_id.node_id == input_column_id.node_id and
                u.deepEqual(column_id.column_name, input_column_id.column_name))
                break :ix input_column_ix;
        }
        u.dump(.{ column_id, input });
        return error.BadArrange;
    };
}
