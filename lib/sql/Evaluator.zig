const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;

const Self = @This();
arena: *u.ArenaAllocator,
allocator: u.Allocator,
planner: sql.Planner,
juice: usize,

pub const Error = error{
    OutOfMemory,
    OutOfJuice,
    TypeError,
    NoEval,
};

pub fn init(
    arena: *u.ArenaAllocator,
    planner: sql.Planner,
    juice: usize,
) Self {
    const allocator = arena.allocator();
    return Self{
        .arena = arena,
        .allocator = allocator,
        .planner = planner,
        .juice = juice,
    };
}

pub const Relation = []const Row;
pub const Row = []const Scalar;
pub const Scalar = sql.Value; // TODO move from sql to here

pub fn evalStatement(self: *Self, statement_expr: sql.Planner.StatementExpr) Error!Relation {
    switch (statement_expr) {
        .select => |select| return self.evalRelation(select),
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
            _ = input;
            return switch (unary.op) {
                else => error.NoEval,
            };
        },
        .binary => |binary| {
            const left = try self.evalScalar(binary.inputs[0], env);
            const right = try self.evalScalar(binary.inputs[1], env);
            _ = left;
            _ = right;
            return switch (binary.op) {
                else => error.NoEval,
            };
        },
    }
}

fn useJuice(self: *Self) !void {
    if (self.juice == 0) return error.OutOfJuice;
    self.juice -= 1;
}
