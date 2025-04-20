const std = @import("std");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const DynamicBitSet = std.DynamicBitSet;
const allocator = std.heap.c_allocator;

pub fn oom() noreturn {
    std.debug.panic("Out of memory", .{});
}

pub const Spreadsheet = struct {
    // Each driver has a formula that produces a timeseries with `driver_cell_count` values.
    driver_cell_count: u32,
    driver_formulas: []const DriverFormula,

    // Tables contain data from external systems.
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

// Use 32 bit indexes everywhere, limiting us to a maximum of 4 billion cells.
pub const DriverIndex = u32;
pub const CellIndex = u32;
pub const TableIndex = u32;
pub const ColumnIndex = u32;

// Driver formulas are represented as a stack machine to keep all the exprs in contiguous memory.
// Driver formulas are evaluated at some CellIndex, which can be referred to by using `this` in a CellIndexFormula.
pub const DriverFormula = []const DriverFormulaExpr;
pub const DriverFormulaExpr = union(enum) {
    constant: f64,
    // Read a cell from another driver.
    cell: struct {
        driver_index: DriverIndex,
        cell_index_formula: CellIndexFormula,
    },
    // Pop two results off stack and add them together.
    add,
    // Read a table, filter out some rows, and sum the values at `this` CellIndex.
    sum_column: struct {
        table_index: TableIndex,
        column_index: ColumnIndex,
        filters: []const Filter,
        // TODO Add a CellIndexFormula rather than always using `this`.
    },

    pub fn format(expr: DriverFormulaExpr, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (expr) {
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

// Cell index formulas are represented as a stack machine to keep all the exprs in contiguous memory.
pub const CellIndexFormula = []const CellIndexFormulaExpr;
pub const CellIndexFormulaExpr = union(enum) {
    // Return the CellIndex at which the current driver formula is being evaluated.
    this,
    constant: i32,
    // Pop two results off stack and add them together.
    add,

    pub fn format(expr: CellIndexFormulaExpr, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (expr) {
            .this => try writer.print("this", .{}),
            .constant => |constant| try writer.print("{}", .{constant}),
            .add => try writer.print("+", .{}),
        }
    }
};

// A table of data from an external system.
pub const Table = struct {
    row_count: usize,
    columns: []Column,
};

pub const Column = union(enum) {
    // A string dimension.
    // The value for row r is stored at bytes[starts[r]..starts[r+1]]
    dimension_string: struct {
        bytes: []const u8,
        starts: []const u32,
    },
    // A timeseries value.
    // The value for row r and cell c is stored at vectors[(row_count * c) + r]
    vectors: []const f64,
};

pub const Filter = union(enum) {
    // Keep only rows whose value at `column_index` is less than `string`.
    less_than: struct {
        column_index: ColumnIndex,
        string: []const u8,
    },

    pub fn format(filter: Filter, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (filter) {
            .less_than => |less_than| try writer.print("column{} < \"{}\"", .{ less_than.column_index, std.zig.fmtEscapes(less_than.string) }),
        }
    }
};

// Evaluate `filters` against the rows in `table`.
// Sets `row_bitset` to true at each row that satisfies all the filters.
pub fn eval_filters(
    filters: []const Filter,
    table: *Table,
    row_bitset: *DynamicBitSet,
) void {
    assert(row_bitset.unmanaged.bit_length >= table.row_count);
    row_bitset.unmanaged.setAll();
    for (filters) |filter| {
        switch (filter) {
            .less_than => |less_than| {
                switch (table.columns[less_than.column_index]) {
                    .dimension_string => |dim| {
                        for (dim.starts[0 .. dim.starts.len - 1], dim.starts[1..], 0..) |lo, hi, row_index| {
                            if (std.mem.order(u8, dim.bytes[lo..hi], less_than.string) != .lt)
                                row_bitset.unset(row_index);
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

// Whether to leave generated drivers in dependency order or shuffle them randomly.
const Order = enum {
    linear,
    shuffled,
};

// Whether to generate recursive drivers or not.
const Recursion = enum {
    recursive,
    non_recursive,
};

// Generate a random spreadsheet.
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
            .columns = columns,
        };
    }

    const schedule = allocator.alloc(DriverIndex, driver_count) catch oom();
    defer allocator.free(schedule);

    // We want to generate an acylic spreadsheet, so generate a random schedule and only allow drivers to refer to other drivers earlier in the schedule.
    for (schedule, 0..) |*p, i| p.* = @intCast(i);
    if (order == .shuffled) {
        // Shuffle the schedule order so that evaluation isn't trivial.
        random.shuffle(DriverIndex, schedule);
    }

    const driver_formulas = allocator.alloc(DriverFormula, driver_count) catch oom();
    // Always returned.

    for (schedule, 0..) |driver_index, schedule_index| {
        var output = ArrayList(DriverFormulaExpr).init(allocator);
        defer output.deinit();

        const upstream = switch (recursion) {
            .non_recursive => schedule[0..schedule_index],
            // For recursive spreadsheets, allow drivers to refer to themselves.
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

// Generate a random `DriverFormula` into `output`.
// The result may refer to any drivers in `upstream`.
fn generate_driver_formula(
    random: std.Random,
    upstream: []const DriverIndex,
    driver_index: DriverIndex,
    tables: []const Table,
    output: *ArrayList(DriverFormulaExpr),
) void {
    switch (random.enumValue(std.meta.Tag(DriverFormulaExpr))) {
        .constant => {
            output.append(.{ .constant = random.float(f64) }) catch oom();
        },
        .cell => {
            if (upstream.len == 0) {
                output.append(.{ .constant = random.float(f64) }) catch oom();
            } else {
                const cell_driver_index = upstream[random.uintLessThan(usize, upstream.len)];

                var cell_index_formula = ArrayList(CellIndexFormulaExpr).init(allocator);
                defer cell_index_formula.deinit();

                if (cell_driver_index == driver_index) {
                    // To ensure that recursive formula don't generate cycles, only allow them to refer to earlier cells.
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
            generate_driver_formula(random, upstream, driver_index, tables, output);
            generate_driver_formula(random, upstream, driver_index, tables, output);
            output.append(.add) catch oom();
        },
        .sum_column => {
            const table_index = random.uintLessThan(TableIndex, @intCast(tables.len));
            const column_count = tables[table_index].columns.len;
            // Rather than be careful about picking a vectors column, we'll just say that sums over other columns always returns zero.
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

// Generate a random `CellIndexFormula` into `output`.
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

// Benchmark evaluation of large random spreadsheets using different engines.
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
