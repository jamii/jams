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

pub const Relation = u.ArrayList(Row);
pub const Row = u.ArrayList(Scalar);
pub const Scalar = sql.Value; // TODO move from sql to here

pub fn evalStatement(self: *Self, statement_expr: sql.Planner.StatementExpr) Error!Relation {
    const empty_relation = Relation.init(self.allocator);
    switch (statement_expr) {
        .select => |select| return self.evalRelation(select),
        .create_table => |create_table| {
            const exists = self.database.table_defs.contains(create_table.name);
            if (exists)
                return if (create_table.if_not_exists) empty_relation else error.AbortEval
            else {
                try self.database.table_defs.put(
                    try u.deepClone(self.database.allocator, create_table.name),
                    try u.deepClone(self.database.allocator, create_table.def),
                );
                try self.database.tables.put(
                    try u.deepClone(self.database.allocator, create_table.name),
                    sql.Table.init(self.database.allocator),
                );
                return empty_relation;
            }
        },
        .create_index => |create_index| {
            const exists = self.database.index_defs.contains(create_index.name);
            if (exists)
                return if (create_index.if_not_exists) empty_relation else error.AbortEval
            else {
                try self.database.index_defs.put(
                    try u.deepClone(self.database.allocator, create_index.name),
                    try u.deepClone(self.database.allocator, create_index.def),
                );
                return empty_relation;
            }
        },
        .insert => |insert| {
            const table = self.database.tables.getPtr(insert.table_name).?;
            const rows = try self.evalRelation(insert.query);
            for (rows.items) |row|
                // unique keys are not tested in slt
                try table.append(try u.deepClone(self.database.allocator, row.items));
            return empty_relation;
        },
        .drop_table => |drop_table| {
            const exists = self.database.table_defs.contains(drop_table.name);
            if (!exists)
                return if (drop_table.if_exists) empty_relation else error.AbortEval
            else {
                _ = self.database.table_defs.remove(drop_table.name);
                _ = self.database.tables.remove(drop_table.name);
                var to_remove = u.ArrayList(sql.IndexName).init(self.allocator);
                var iter = self.database.index_defs.iterator();
                while (iter.next()) |entry|
                    if (u.deepEqual(drop_table.name, entry.value_ptr.table_name))
                        try to_remove.append(entry.key_ptr.*);
                for (to_remove.items) |index_name|
                    _ = self.database.index_defs.remove(index_name);
                return empty_relation;
            }
        },
        .drop_index => |drop_index| {
            const exists = self.database.index_defs.contains(drop_index.name);
            if (!exists)
                return if (drop_index.if_exists) empty_relation else error.AbortEval
            else {
                _ = self.database.index_defs.remove(drop_index.name);
                return empty_relation;
            }
        },
        .noop => return empty_relation,
    }
}

fn evalRelation(self: *Self, relation_expr_id: sql.Planner.RelationExprId) Error!Relation {
    try self.useJuice();
    const relation_expr = self.planner.relation_exprs.items[relation_expr_id];
    var output = Relation.init(self.allocator);
    switch (relation_expr) {
        .none => {},
        .some => try output.append(Row.init(self.allocator)),
        .map => |map| {
            const input = try self.evalRelation(map.input);
            for (input.items) |*input_row| {
                try self.useJuice();
                const value = try self.evalScalar(map.scalar, input_row.*);
                try input_row.append(value);
            }
            output = input;
        },
        .filter => |filter| {
            const input = try self.evalRelation(filter.input);
            for (input.items) |input_row| {
                try self.useJuice();
                const cond = try self.evalScalar(filter.cond, input_row);
                if (try cond.toBool())
                    try output.append(input_row);
            }
        },
        .project => |project| {
            const input = try self.evalRelation(project.input);
            for (input.items) |input_row| {
                try self.useJuice();
                var output_row = try Row.initCapacity(self.allocator, project.columns.len);
                for (project.columns) |column|
                    output_row.appendAssumeCapacity(input_row.items[column]);
                try output.append(output_row);
            }
        },
        .unio => |unio| {
            const left = try self.evalRelation(unio.inputs[0]);
            const right = try self.evalRelation(unio.inputs[1]);
            if (unio.all) {
                output = left;
                try output.appendSlice(right.items);
            } else {
                var set = u.DeepHashSet(Row).init(self.allocator);
                for (left.items) |row| try set.put(row, {});
                for (right.items) |row| try set.put(row, {});
                var iter = set.keyIterator();
                while (iter.next()) |row| try output.append(row.*);
            }
        },
        .get_table => |table_name| {
            const table = self.database.tables.get(table_name) orelse
                return error.AbortEval;
            for (table.items) |input_row| {
                var output_row = try Row.initCapacity(self.allocator, input_row.len);
                output_row.appendSliceAssumeCapacity(input_row);
                try output.append(output_row);
            }
        },
    }
    //u.dump(.{ relation_expr, output });
    return output;
}

fn evalScalar(self: *Self, scalar_expr_id: sql.Planner.ScalarExprId, env: Row) Error!Scalar {
    try self.useJuice();
    const scalar_expr = self.planner.scalar_exprs.items[scalar_expr_id];
    switch (scalar_expr) {
        .value => |value| return value,
        .column => |column| return env.items[column],
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
                            .forward_slash => if (right.real == 0)
                                Scalar.NULL
                            else
                                Scalar{ .real = left.real / right.real },
                            else => unreachable,
                        }
                    else switch (binary.op) {
                        .plus => Scalar{ .integer = left.integer + right.integer },
                        .minus => Scalar{ .integer = left.integer - right.integer },
                        .star => Scalar{ .integer = left.integer * right.integer },
                        .forward_slash => if (right.integer == 0)
                            Scalar.NULL
                        else
                            Scalar{ .integer = @divTrunc(left.integer, right.integer) },
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
