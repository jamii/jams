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
    BadEvalColumn,
    BadEvalAggregate,
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
            var input = try self.evalRelation(filter.input);
            var i: usize = 0;
            for (input.items) |input_row| {
                try self.useJuice();
                const cond = try self.evalScalar(filter.cond, input_row);
                if (cond != .nul and try cond.toBool()) {
                    input.items[i] = input_row;
                    i += 1;
                }
            }
            input.shrinkRetainingCapacity(i);
            output = input;
        },
        .project => |project| {
            const input = try self.evalRelation(project.input);
            for (input.items) |*input_row| {
                try self.useJuice();
                var output_row = try Row.initCapacity(self.allocator, project.column_refs.len);
                for (project.column_refs) |column_ref| {
                    const scalar = input_row.items[column_ref.ix];
                    if (scalar == .column) {
                        if (scalar.column.len > 0)
                            // sqlite magic - just pick an arbitrary row
                            output_row.appendAssumeCapacity(scalar.column[0]);
                    } else output_row.appendAssumeCapacity(scalar);
                }
                input_row.* = output_row;
            }
            output = input;
        },
        .unio => |unio| {
            var left = try self.evalRelation(unio.inputs[0]);
            const right = try self.evalRelation(unio.inputs[1]);
            if (unio.all) {
                try left.appendSlice(right.items);
            } else {
                var set = u.DeepHashSet(Row).init(self.allocator);
                for (left.items) |row| {
                    try self.useJuice();
                    try set.put(row, {});
                }
                for (right.items) |row| {
                    try self.useJuice();
                    try set.put(row, {});
                }
                left.shrinkRetainingCapacity(0);
                var iter = set.keyIterator();
                while (iter.next()) |row| try left.append(row.*);
            }
            output = left;
        },
        .get_table => |get_table| {
            const table = self.database.tables.get(get_table.table_name) orelse
                return error.AbortEval;
            for (table.items) |input_row| {
                try self.useJuice();
                var output_row = try Row.initCapacity(self.allocator, input_row.len);
                output_row.appendSliceAssumeCapacity(input_row);
                try output.append(output_row);
            }
        },
        .distinct => |distinct| {
            var input = try self.evalRelation(distinct);
            var set = u.DeepHashSet(Row).init(self.allocator);
            for (input.items) |row| {
                try self.useJuice();
                try set.put(row, {});
            }
            input.shrinkRetainingCapacity(0);
            var iter = set.keyIterator();
            while (iter.next()) |row| try input.append(row.*);
            output = input;
        },
        .order_by => |order_by| {
            const input = try self.evalRelation(order_by.input);
            std.sort.sort(Row, input.items, order_by.orderings, (struct {
                fn lessThan(orderings: []sql.Planner.Ordering, a: Row, b: Row) bool {
                    for (orderings) |ordering|
                        switch (Scalar.order(a.items[ordering.column_ref.ix], b.items[ordering.column_ref.ix])) {
                            .eq => continue,
                            .lt => return !ordering.desc,
                            .gt => return ordering.desc,
                        };
                    return false;
                }
            }).lessThan);
            return input;
        },
        .as => |as| return self.evalRelation(as.input),
        .group_by => |group_by| {
            const input = try self.evalRelation(group_by.input);
            const output_columns = try self.allocator.alloc(u.ArrayList(Scalar), group_by.num_columns.?);
            for (output_columns) |*output_column|
                output_column.* = u.ArrayList(Scalar).init(self.allocator);
            for (input.items) |row|
                for (row.items) |value, i|
                    try output_columns[i].append(value);
            var output_row = try Row.initCapacity(self.allocator, group_by.num_columns.?);
            for (output_columns) |*output_column|
                output_row.appendAssumeCapacity(.{ .column = output_column.toOwnedSlice() });
            try output.append(output_row);
            return output;
        },
    }
    return output;
}

fn evalScalar(self: *Self, scalar_expr_id: sql.Planner.ScalarExprId, env: Row) Error!Scalar {
    const scalar_expr = &self.planner.scalar_exprs.items[scalar_expr_id];
    switch (scalar_expr.*) {
        .value => |value| return value,
        .column => |column| {
            return if (column.ix >= env.items.len)
                error.BadEvalColumn
            else
                env.items[column.ix];
        },
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
                    // In sqlite you can do `+ 'foo'` and get `'foo'`
                    return input;
                },
                .minus => {
                    return switch (input) {
                        .integer => |integer| Scalar{ .integer = -integer },
                        .real => |real| Scalar{ .real = -real },
                        else => error.TypeError,
                    };
                },
                .abs => {
                    return switch (input) {
                        .integer => |integer| Scalar{
                            .integer = std.math.absInt(integer) catch
                            // Don't really care about overflow
                                unreachable,
                        },
                        .real => |real| Scalar{ .real = @fabs(real) },
                        else => error.TypeError,
                    };
                },
            }
        },
        .binary => |binary| {
            var left = try self.evalScalar(binary.inputs[0], env);
            var right = try self.evalScalar(binary.inputs[1], env);
            switch (binary.op) {
                .is, .is_not => {},
                else => {
                    if (left == .nul) return Scalar.NULL;
                    if (right == .nul) return Scalar.NULL;
                },
            }
            return switch (binary.op) {
                .bool_and => return Scalar.fromBool(try left.toBool() and try right.toBool()),
                .bool_or => return Scalar.fromBool(try left.toBool() or try right.toBool()),
                .equal, .is => return Scalar.fromBool(Scalar.order(left, right) == .eq),
                .not_equal, .is_not => return Scalar.fromBool(Scalar.order(left, right) != .eq),
                .less_than => return Scalar.fromBool(Scalar.order(left, right) == .lt),
                .greater_than => return Scalar.fromBool(Scalar.order(left, right) == .gt),
                .less_than_or_equal => return Scalar.fromBool(Scalar.order(left, right) != .gt),
                .greater_than_or_equal => return Scalar.fromBool(Scalar.order(left, right) != .lt),
                .plus, .minus, .star, .forward_slash => {
                    if (!left.isNumeric()) return error.TypeError;
                    if (!right.isNumeric()) return error.TypeError;
                    Scalar.promoteIfNeeded(&left, &right);
                    return if (left == .real)
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
                .nullif => {
                    return if (Scalar.order(left, right) == .eq)
                        Scalar.NULL
                    else
                        left;
                },
                else => error.NoEval,
            };
        },
        .aggregate => |aggregate| {
            var input = try self.evalScalar(aggregate.input, env);
            if (input != .column)
                return error.BadEvalAggregate;
            var column = input.column;
            if (aggregate.distinct) {
                var scalars = u.DeepHashSet(Scalar).init(self.allocator);
                for (column) |scalar|
                    if (scalar != .nul)
                        try scalars.put(scalar, {});
                var new_column = try u.ArrayList(Scalar).initCapacity(self.allocator, scalars.count());
                var iter = scalars.keyIterator();
                while (iter.next()) |scalar|
                    new_column.appendAssumeCapacity(scalar.*);
                column = new_column.toOwnedSlice();
            }
            switch (aggregate.op) {
                .count => {
                    var count: i64 = 0;
                    for (column) |scalar|
                        if (scalar != .nul) {
                            count += 1;
                        };
                    return Scalar{ .integer = count };
                },
                .sum => {
                    var sum = Scalar{ .integer = 0 };
                    for (column) |scalar|
                        if (scalar != .nul) {
                            var scalar_promoted = scalar;
                            Scalar.promoteIfNeeded(&sum, &scalar_promoted);
                            if (sum == .integer)
                                sum = .{ .integer = sum.integer + scalar_promoted.integer }
                            else
                                sum = .{ .real = sum.real + scalar_promoted.real };
                        };
                    return sum;
                },
                .min => {
                    var min = Scalar.NULL;
                    for (column) |scalar|
                        if (scalar != .nul) {
                            if (min == .nul or Scalar.order(scalar, min) == .lt)
                                min = scalar;
                        };

                    return min;
                },
                .max => {
                    var max = Scalar.NULL;
                    for (column) |scalar|
                        if (scalar != .nul) {
                            if (max == .nul or Scalar.order(scalar, max) == .gt)
                                max = scalar;
                        };
                    return max;
                },
                .avg => {
                    var count: f64 = 0.0;
                    var sum = Scalar{ .real = 0 };
                    for (column) |scalar|
                        if (scalar != .nul) {
                            count += 1;
                            sum = .{ .real = sum.real + scalar.promoteToReal().real };
                        };
                    return Scalar{ .real = sum.real / count };
                },
            }
        },
        .coalesce => |coalesce| {
            for (coalesce.inputs) |coalesce_input| {
                const input = try self.evalScalar(coalesce_input, env);
                if (input != .nul) return input;
            }
            return Scalar.NULL;
        },
        .in => |*in| {
            const input = try self.evalScalar(in.input, env);
            const subplan = in.subplan_cache orelse try self.evalRelation(in.subplan);
            in.subplan_cache = subplan;
            var input_in_subplan = false;

            if (input == .nul)
                return if (subplan.items.len == 0) Scalar.FALSE else Scalar.NULL;
            for (subplan.items) |row| {
                if (u.deepEqual(input, row.items[0]))
                    input_in_subplan = true;
            }
            if (!input_in_subplan)
                for (subplan.items) |row|
                    if (row.items[0] == .nul)
                        return Scalar.NULL;
            return Scalar.fromBool(input_in_subplan);
        },
    }
}

fn useJuice(self: *Self) !void {
    if (self.juice == 0) return error.OutOfJuice;
    self.juice -= 1;
}
