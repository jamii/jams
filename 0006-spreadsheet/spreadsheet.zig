const std = @import("std");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const DynamicBitSet = std.DynamicBitSet;
const allocator = std.heap.c_allocator;

pub fn oom() noreturn {
    std.debug.panic("OOM", .{});
}

pub const Spreadsheet = struct {
    // Assume that every driver has the same number of cells.
    driver_cell_count: u32,
    driver_formulas: []const DriverFormula,
    tables: []Table,

    pub fn deinit(spreadsheet: Spreadsheet) void {
        for (spreadsheet.driver_formulas) |driver_formula| {
            for (driver_formula) |expr| {
                switch (expr) {
                    .constant, .add => {},
                    .cell => |cell| {
                        allocator.free(cell.cell_index_formula);
                    },
                    .sum_column => |sum_column| {
                        for (sum_column.filters) |filter| {
                            switch (filter) {
                                .less_than => |less_than| allocator.free(less_than.string),
                            }
                        }
                        allocator.free(sum_column.filters);
                    },
                }
            }
            allocator.free(driver_formula);
        }
        allocator.free(spreadsheet.driver_formulas);

        for (spreadsheet.tables) |*table| {
            table.bitset.deinit();
            for (table.columns) |column| {
                switch (column) {
                    .dimension_string => |dim| {
                        allocator.free(dim.starts);
                        allocator.free(dim.bytes);
                    },
                    .vectors => |vectors| {
                        allocator.free(vectors);
                    },
                }
            }
            allocator.free(table.columns);
        }
        allocator.free(spreadsheet.tables);
    }
};

pub const DriverIndex = u32;
pub const CellIndex = u32;
pub const TableIndex = u32;
pub const ColumnIndex = u32;

pub const DriverFormula = []const DriverFormulaExpr;
pub const DriverFormulaExpr = union(enum) {
    constant: f64,
    cell: struct {
        driver_index: DriverIndex,
        cell_index_formula: CellIndexFormula,
    },
    add, // Pop two results off stack.
    // TODO Add aggregates over drivers.
    sum_column: struct {
        table_index: TableIndex,
        column_index: ColumnIndex,
        filters: []const Filter,
    },

    pub fn format(self: DriverFormulaExpr, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .constant => |constant| try writer.print("{}", .{constant}),
            .cell => |cell| try writer.print("driver{}{any}", .{ cell.driver_index, cell.cell_index_formula }),
            .add => try writer.print("+", .{}),
            .sum_column => |sum_column| {
                try writer.print("table{}", .{sum_column.table_index});
                for (sum_column.filters) |filter| {
                    try writer.print(".filter({})", .{filter});
                }
                try writer.print(".sum(column{})", .{sum_column.column_index});
            },
        }
    }
};

pub const CellIndexFormula = []const CellIndexFormulaExpr;
pub const CellIndexFormulaExpr = union(enum) {
    this,
    constant: i32,
    add, // Pop two results off stack.

    pub fn format(self: CellIndexFormulaExpr, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .this => try writer.print("this", .{}),
            .constant => |constant| try writer.print("{}", .{constant}),
            .add => try writer.print("+", .{}),
        }
    }
};

pub const Table = struct {
    row_count: usize,
    bitset: DynamicBitSet,
    columns: []Column,
};

pub const Column = union(enum) {
    // A string dimension.
    // Stored sorted by row.
    dimension_string: struct {
        // The value for row i is stored at bytes[starts[i]..starts[i+1]]
        bytes: []const u8,
        starts: []const u32,
    },
    // A timeseries value.
    // Stored sorted by cell, then row.
    vectors: []const f64,
};

pub const Filter = union(enum) {
    less_than: struct {
        column_index: ColumnIndex,
        string: []const u8,
    },

    pub fn format(self: Filter, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .less_than => |less_than| try writer.print("column{} < \"{}\"", .{ less_than.column_index, std.zig.fmtEscapes(less_than.string) }),
        }
    }
};

pub fn eval_filters(
    filters: []const Filter,
    table: *Table,
) void {
    table.bitset.unmanaged.setAll();
    for (filters) |filter| {
        switch (filter) {
            .less_than => |less_than| {
                switch (table.columns[less_than.column_index]) {
                    .dimension_string => |dim| {
                        for (dim.starts[0 .. dim.starts.len - 1], dim.starts[1..], 0..) |lo, hi, row_index| {
                            // TODO This might benefit from inlining the unset math.
                            if (std.mem.order(u8, dim.bytes[lo..hi], less_than.string) != .lt) table.bitset.unset(row_index);
                        }
                    },
                    .vectors => {
                        // Just return true.
                    },
                }
            },
        }
    }
}

const Order = enum {
    linear,
    shuffled,
};

const Recursion = enum {
    non_recursive,
    recursive,
};

fn generate_spreadsheet(random: std.Random, order: Order, recursion: Recursion, driver_count: u32) Spreadsheet {
    const table_count = 10;
    const driver_cell_count: u32 = 20;

    const tables = allocator.alloc(Table, table_count) catch oom();
    for (tables) |*table| {
        const column_count = 1 + random.uintLessThan(usize, 9);
        const row_count = random.uintLessThan(usize, 100);
        const columns = allocator.alloc(Column, column_count) catch oom();
        for (columns) |*column| {
            switch (random.enumValue(std.meta.Tag(Column))) {
                .dimension_string => {
                    const starts = allocator.alloc(u32, row_count + 1) catch oom();
                    var byte_count: u32 = 0;
                    for (starts) |*start| {
                        start.* = byte_count;
                        byte_count += random.uintLessThan(u32, 64);
                    }
                    const bytes = allocator.alloc(u8, byte_count) catch oom();
                    random.bytes(bytes);
                    column.* = .{ .dimension_string = .{
                        .starts = starts,
                        .bytes = bytes,
                    } };
                },
                .vectors => {
                    const floats = allocator.alloc(f64, row_count * driver_cell_count) catch oom();
                    for (floats) |*float| float.* = random.float(f64);
                    column.* = .{ .vectors = floats };
                },
            }
        }
        table.* = .{
            .row_count = row_count,
            .bitset = DynamicBitSet.initFull(allocator, row_count) catch oom(),
            .columns = columns,
        };
    }

    const schedule = allocator.alloc(DriverIndex, driver_count) catch oom();
    defer allocator.free(schedule);

    for (schedule, 0..) |*p, i| p.* = @intCast(i);
    if (order == .shuffled) {
        // We want to generate an acylic spreadsheet, but still require non-trivial scheduling.
        // So generate a random schedule and only allow drivers to refer to other drivers eariler in the schedule.
        random.shuffle(DriverIndex, schedule);
    }

    const driver_formulas = allocator.alloc(DriverFormula, driver_count) catch oom();
    // Always returned.

    for (schedule, 0..) |driver_index, schedule_index| {
        var output = ArrayList(DriverFormulaExpr).init(allocator);
        defer output.deinit();

        const upstream = switch (recursion) {
            .non_recursive => schedule[0..schedule_index],
            .recursive => schedule[0 .. schedule_index + 1],
        };
        generate_driver_formula(random, upstream, driver_index, tables, &output);
        driver_formulas[driver_index] = output.toOwnedSlice() catch oom();
    }

    return .{
        .driver_cell_count = driver_cell_count,
        .driver_formulas = driver_formulas,
        .tables = tables,
    };
}

fn generate_driver_formula(
    random: std.Random,
    schedule: []const DriverIndex,
    driver_index: DriverIndex,
    tables: []const Table,
    output: *ArrayList(DriverFormulaExpr),
) void {
    switch (random.enumValue(std.meta.Tag(DriverFormulaExpr))) {
        .constant => {
            output.append(.{ .constant = random.float(f64) }) catch oom();
        },
        .cell => {
            if (schedule.len == 0) {
                output.append(.{ .constant = random.float(f64) }) catch oom();
            } else {
                const cell_driver_index = schedule[random.uintLessThan(usize, schedule.len)];

                var cell_index_formula = ArrayList(CellIndexFormulaExpr).init(allocator);
                defer cell_index_formula.deinit();

                if (cell_driver_index == driver_index) {
                    // Ensure that recursive formula don't form cycles
                    cell_index_formula.append(.this) catch oom();
                    cell_index_formula.append(.{ .constant = random.intRangeLessThan(i32, -3, 0) }) catch oom();
                    cell_index_formula.append(.add) catch oom();
                } else {
                    generate_cell_index_formula(random, &cell_index_formula);
                }
                output.append(.{ .cell = .{
                    .driver_index = cell_driver_index,
                    .cell_index_formula = cell_index_formula.toOwnedSlice() catch oom(),
                } }) catch oom();
            }
        },
        .add => {
            generate_driver_formula(random, schedule, driver_index, tables, output);
            generate_driver_formula(random, schedule, driver_index, tables, output);
            output.append(.add) catch oom();
        },
        .sum_column => {
            const table_index = random.uintLessThan(TableIndex, @intCast(tables.len));
            const column_count = tables[table_index].columns.len;
            // Rather than be careful about picking a vectors column, we'll just say that sum over a dimensions column returns zero.
            const column_index = random.uintLessThan(ColumnIndex, @intCast(column_count));
            const filters = allocator.alloc(Filter, random.uintLessThan(usize, 3)) catch oom();
            for (filters) |*filter| {
                const bytes = allocator.alloc(u8, random.uintLessThan(usize, 64)) catch oom();
                random.bytes(bytes);
                filter.* = .{
                    .less_than = .{
                        // Rather than be careful about picking a dimension_string column, we'll just say that filters over other columns always return true.
                        .column_index = random.uintLessThan(ColumnIndex, @intCast(column_count)),
                        .string = bytes,
                    },
                };
            }
            output.append(.{ .sum_column = .{
                .table_index = table_index,
                .column_index = column_index,
                .filters = filters,
            } }) catch oom();
        },
    }
}

fn generate_cell_index_formula(
    random: std.Random,
    output: *ArrayList(CellIndexFormulaExpr),
) void {
    switch (random.enumValue(std.meta.Tag(CellIndexFormulaExpr))) {
        .this => {
            output.append(.this) catch oom();
        },
        .constant => {
            output.append(.{ .constant = random.intRangeLessThan(i32, -3, 3) }) catch oom();
        },
        .add => {
            generate_cell_index_formula(random, output);
            generate_cell_index_formula(random, output);
            output.append(.add) catch oom();
        },
    }
}

const engines = .{
    @import("./scalar.zig"),
    @import("./scalar_fused.zig"),
    @import("./vector.zig"),
};

const recursive_engines = .{
    @import("./scalar.zig"),
    @import("./scalar_fused.zig"),
    // @import("./vector.zig"), // can't handle recursion without mixed scheduling
};

pub fn main() void {
    for ([2]Order{ .linear, .shuffled }) |order| {
        inline for ([2]Recursion{ .non_recursive, .recursive }) |recursion| {
            var rng = std.Random.DefaultPrng.init(42);
            const random = rng.random();

            const spreadsheet = generate_spreadsheet(random, order, recursion, 1_000_000);
            defer spreadsheet.deinit();

            std.debug.print("driver{} = {any}\n", .{
                spreadsheet.driver_formulas.len - 1,
                spreadsheet.driver_formulas[spreadsheet.driver_formulas.len - 1],
            });

            const test_engines = switch (recursion) {
                .non_recursive => engines,
                .recursive => recursive_engines,
            };
            inline for (test_engines) |engine| {
                std.debug.print("{s} {s} {}\n", .{ @tagName(order), @tagName(recursion), engine });

                var scratchpad = engine.Scratchpad.init(spreadsheet);
                defer scratchpad.deinit();

                const before_create_schedule = std.time.nanoTimestamp();

                const schedule = engine.create_schedule(spreadsheet, &scratchpad);
                defer if (@TypeOf(schedule) != void) allocator.free(schedule);

                std.debug.print("create_schedule: {d:.2} seconds for {} drivers\n", .{
                    @as(f64, @floatFromInt(std.time.nanoTimestamp() - before_create_schedule)) / 1e9,
                    spreadsheet.driver_formulas.len,
                });

                const before_eval_spreadsheet = std.time.nanoTimestamp();
                engine.eval_spreadsheet(spreadsheet, &scratchpad, schedule);
                std.debug.print("eval_spreadsheet: {d:.2} seconds for {} drivers\n", .{
                    @as(f64, @floatFromInt(std.time.nanoTimestamp() - before_eval_spreadsheet)) / 1e9,
                    spreadsheet.driver_formulas.len,
                });

                std.debug.print("---\n", .{});
            }
        }
    }
}

fn test_eval_all_equal(test_engines: anytype, spreadsheet: Spreadsheet) !void {
    assert(engines.len != 0);

    var expected: []f64 = undefined;
    defer allocator.free(expected);

    inline for (test_engines, 0..) |engine, i| {
        var scratchpad = engine.Scratchpad.init(spreadsheet);
        defer scratchpad.deinit();

        const schedule = engine.create_schedule(spreadsheet, &scratchpad);
        defer if (@TypeOf(schedule) != void) allocator.free(schedule);

        engine.eval_spreadsheet(spreadsheet, &scratchpad, schedule);
        if (i == 0) {
            expected = allocator.dupe(f64, scratchpad.cells) catch oom();
        } else {
            try std.testing.expectEqualSlices(f64, expected, scratchpad.cells);
        }
    }
}

test "all engines produce the same results" {
    inline for ([2]Recursion{ .non_recursive, .recursive }) |recursion| {
        for (0..1000) |seed| {
            var rng = std.Random.DefaultPrng.init(seed);
            const random = rng.random();

            const spreadsheet = generate_spreadsheet(random, .shuffled, recursion, 100);
            defer spreadsheet.deinit();

            const test_engines = switch (recursion) {
                .non_recursive => engines,
                .recursive => recursive_engines,
            };
            try test_eval_all_equal(test_engines, spreadsheet);
        }
    }
}

fn test_eval_constant(test_engines: anytype, spreadsheet: Spreadsheet, expected: []const f64) !void {
    inline for (test_engines) |engine| {
        var scratchpad = engine.Scratchpad.init(spreadsheet);
        defer scratchpad.deinit();

        const schedule = engine.create_schedule(spreadsheet, &scratchpad);
        defer if (@TypeOf(schedule) != void) allocator.free(schedule);

        engine.eval_spreadsheet(spreadsheet, &scratchpad, schedule);
        try std.testing.expectEqualSlices(f64, expected, scratchpad.cells);
    }
}

test "empty spreadsheet" {
    const spreadsheet = Spreadsheet{
        .driver_cell_count = 5,
        .driver_formulas = &[_]DriverFormula{},
        .tables = &.{},
    };
    try test_eval_constant(engines, spreadsheet, &.{});
}

test "simple spreadsheet" {
    const spreadsheet = Spreadsheet{
        .driver_cell_count = 5,
        .driver_formulas = &[_]DriverFormula{
            &[_]DriverFormulaExpr{
                .{ .constant = 42 },
            },
            &[_]DriverFormulaExpr{
                .{ .cell = .{
                    .driver_index = 2,
                    .cell_index_formula = &[_]CellIndexFormulaExpr{
                        .this,
                        .{ .constant = 2 },
                        .add,
                    },
                } },
            },
            &[_]DriverFormulaExpr{
                .{ .constant = 1 },
                .{ .constant = 2 },
                .add,
            },
        },
        .tables = &.{},
    };
    try test_eval_constant(engines, spreadsheet, &.{
        42, 42, 42, 42, 42,
        3,  3,  3,  0,  0,
        3,  3,  3,  3,  3,
    });
}

test "recursive spreadsheet" {
    const spreadsheet = Spreadsheet{
        .driver_cell_count = 5,
        .driver_formulas = &[_]DriverFormula{
            &[_]DriverFormulaExpr{
                .{ .cell = .{
                    .driver_index = 0,
                    .cell_index_formula = &[_]CellIndexFormulaExpr{
                        .this,
                        .{ .constant = 1 },
                        .add,
                    },
                } },
                .{ .constant = 1 },
                .add,
            },
            &[_]DriverFormulaExpr{
                .{ .cell = .{
                    .driver_index = 2,
                    .cell_index_formula = &[_]CellIndexFormulaExpr{
                        .this,
                        .{ .constant = 1 },
                        .add,
                    },
                } },
                .{ .constant = 1 },
                .add,
            },
            &[_]DriverFormulaExpr{
                .{ .cell = .{
                    .driver_index = 1,
                    .cell_index_formula = &[_]CellIndexFormulaExpr{
                        .this,
                    },
                } },
                .{ .constant = 1 },
                .add,
            },
        },
        .tables = &.{},
    };
    try test_eval_constant(recursive_engines, spreadsheet, &.{
        5,  4, 3, 2, 1,
        9,  7, 5, 3, 1,
        10, 8, 6, 4, 2,
    });
}
