const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;

const Self = @This();
arena: *u.ArenaAllocator,
allocator: u.Allocator,
planner: sql.Planner,
database: *sql.Database,
juice: usize,

pub const Error = error{
    OutOfMemory,
    OutOfJuice,
    TypeError,
    NoEval,
    AbortEval,
};

pub fn init(
    arena: *u.ArenaAllocator,
    planner: sql.Planner,
    database: *sql.Database,
    juice: usize,
) Self {
    const allocator = arena.allocator();
    return Self{
        .arena = arena,
        .allocator = allocator,
        .planner = planner,
        .database = database,
        .juice = juice,
    };
}

pub const Relation = []const Row;
pub const Row = []const Scalar;
pub const Scalar = sql.Value; // TODO move from sql to here

pub fn evalStatement(self: *Self, statement_expr: sql.Planner.StatementExpr) Error!Relation {
    switch (statement_expr) {
        .select => |select| return self.evalRelation(select),
        .create_table => |create_table| {
            const exists = self.database.tables.contains(create_table.name);
            if (exists)
                return if (create_table.if_not_exists) &.{} else error.AbortEval
            else {
                try self.database.tables.put(
                    try u.deepClone(self.database.allocator, create_table.name),
                    try u.deepClone(self.database.allocator, create_table.def),
                );
                return &.{};
            }
        },
    }
}

fn evalRelation(self: *Self, relation_expr_id: sql.Planner.RelationExprId) Error!Relation {
    try self.useJuice();
    const relation_expr = self.planner.relation_exprs.items[relation_expr_id];
    switch (relation_expr) {
        .none => return &.{},
        .some => return self.allocator.dupe(Row, &.{&.{}}),
        .map => |map| {
            const input = try self.evalRelation(map.input);
            var output = u.ArrayList(Row).init(self.allocator);
            for (input) |input_row| {
                try self.useJuice();
                const value = try self.evalScalar(map.scalar, input_row);
                const output_row = try std.mem.concat(self.allocator, Scalar, &.{
                    input_row,
                    &.{value},
                });
                try output.append(output_row);
            }
            return output.toOwnedSlice();
        },
    }
}

fn evalScalar(self: *Self, scalar_expr_id: sql.Planner.ScalarExprId, env: Row) Error!Scalar {
    try self.useJuice();
    const scalar_expr = self.planner.scalar_exprs.items[scalar_expr_id];
    switch (scalar_expr) {
        .value => |value| return value,
        .column => |column| return env[column],
        .unary => |unary| {
            const input = try self.evalScalar(unary.input, env);
            switch (unary.op) {
                .is_null, .is_not_null => {},
                else => if (input == .nul) return Scalar.NULL,
            }
            switch (unary.op) {
                .is_null => return Scalar.fromBool(input == .nul),
                .is_not_null => return Scalar.fromBool(input != .nul),
                .bool_not => return Scalar.fromBool(!(try input.toBool())),
                .bit_not => return error.NoEval,
                .plus => {
                    if (input != .integer) return error.TypeError;
                    return input;
                },
                .minus => {
                    if (input != .integer) return error.TypeError;
                    return Scalar{ .integer = -input.integer };
                },
            }
        },
        .binary => |binary| {
            var left = try self.evalScalar(binary.inputs[0], env);
            var right = try self.evalScalar(binary.inputs[1], env);
            switch (binary.op) {
                else => {
                    if (left == .nul) return Scalar.NULL;
                    if (right == .nul) return Scalar.NULL;
                },
            }
            return switch (binary.op) {
                .bool_and => return Scalar.fromBool(try left.toBool() and try right.toBool()),
                .bool_or => return Scalar.fromBool(try left.toBool() or try right.toBool()),
                .equal => return Scalar.fromBool(u.deepEqual(left, right)),
                .not_equal => return Scalar.fromBool(!u.deepEqual(left, right)),
                .less_than => return Scalar.fromBool(Scalar.order(left, right) == .lt),
                .greater_than => return Scalar.fromBool(Scalar.order(left, right) == .gt),
                .less_than_or_equal => return Scalar.fromBool(Scalar.order(left, right) != .gt),
                .greater_than_or_equal => return Scalar.fromBool(Scalar.order(left, right) != .lt),
                .plus, .minus, .star, .forward_slash => {
                    if (!left.isNumeric()) return error.TypeError;
                    if (!right.isNumeric()) return error.TypeError;
                    if (left == .real and right == .integer)
                        right = right.promoteToReal();
                    if (right == .real and left == .integer)
                        left = left.promoteToReal();
                    return if (left == .real and right == .real)
                        switch (binary.op) {
                            .plus => Scalar{ .real = left.real + right.real },
                            .minus => Scalar{ .real = left.real - right.real },
                            .star => Scalar{ .real = left.real * right.real },
                            .forward_slash => Scalar{ .real = left.real / right.real },
                            else => unreachable,
                        }
                    else switch (binary.op) {
                        .plus => Scalar{ .integer = left.integer + right.integer },
                        .minus => Scalar{ .integer = left.integer - right.integer },
                        .star => Scalar{ .integer = left.integer * right.integer },
                        .forward_slash => Scalar{ .integer = @divTrunc(left.integer, right.integer) },
                        else => unreachable,
                    };
                },
                else => error.NoEval,
            };
        },
    }
}

fn useJuice(self: *Self) !void {
    if (self.juice == 0) return error.OutOfJuice;
    self.juice -= 1;
}
