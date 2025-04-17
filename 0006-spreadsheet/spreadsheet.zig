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
    // TODO Add source data.

    pub fn deinit(spreadsheet: Spreadsheet) void {
        for (spreadsheet.driver_formulas) |driver_formula| {
            for (driver_formula) |expr| {
                switch (expr) {
                    .constant, .add => {},
                    .cell => |cell| {
                        allocator.free(cell.cell_index_formula);
                    },
                }
            }
            allocator.free(driver_formula);
        }
        allocator.free(spreadsheet.driver_formulas);
    }
};

pub const DriverIndex = u32;
pub const CellIndex = u32;

pub const DriverFormula = []const DriverFormulaExpr;
pub const DriverFormulaExpr = union(enum) {
    constant: f64,
    cell: struct {
        driver_index: DriverIndex,
        cell_index_formula: CellIndexFormula,
    },
    add, // Pop two results off stack.
    // TODO Add aggregates over drivers.
    // TODO Add aggregates and filters over source data.

    pub fn format(self: DriverFormulaExpr, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .constant => |constant| try writer.print("{}", .{constant}),
            .cell => |cell| try writer.print("driver{}{any}", .{ cell.driver_index, cell.cell_index_formula }),
            .add => try writer.print("+", .{}),
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

const Order = enum {
    linear,
    shuffled,
};

fn generate_spreadsheet(random: std.Random, order: Order, driver_count: u32) Spreadsheet {
    const driver_cell_count: u32 = 20;

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

        generate_driver_formula(random, schedule[0..schedule_index], &output);
        driver_formulas[driver_index] = output.toOwnedSlice() catch oom();
    }

    return .{
        .driver_cell_count = driver_cell_count,
        .driver_formulas = driver_formulas,
    };
}

fn generate_driver_formula(
    random: std.Random,
    schedule: []const DriverIndex,
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
                const driver_index = schedule[random.uintLessThan(usize, schedule.len)];

                var cell_index_formula = ArrayList(CellIndexFormulaExpr).init(allocator);
                defer cell_index_formula.deinit();

                generate_cell_index_formula(random, &cell_index_formula);
                output.append(.{ .cell = .{
                    .driver_index = driver_index,
                    .cell_index_formula = cell_index_formula.toOwnedSlice() catch oom(),
                } }) catch oom();
            }
        },
        .add => {
            generate_driver_formula(random, schedule, output);
            generate_driver_formula(random, schedule, output);
            output.append(.add) catch oom();
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
        var rng = std.Random.DefaultPrng.init(42);
        const random = rng.random();

        const spreadsheet = generate_spreadsheet(random, order, 1_000_000);
        defer spreadsheet.deinit();

        inline for (engines) |engine| {
            std.debug.print("{} {}\n", .{ order, engine });

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

            std.debug.print("{} {}\n", .{ scratchpad.cells[0], scratchpad.cells[scratchpad.cells.len - 1] });
            //std.debug.print("{any} {any}\n", .{ schedule[0..10], schedule[schedule.len - 10] });
            std.debug.print("{any}\n{any}\n", .{ spreadsheet.driver_formulas[0..10], spreadsheet.driver_formulas[spreadsheet.driver_formulas.len - 10] });

            std.debug.print("\n---\n\n", .{});
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
    for (0..1000) |seed| {
        var rng = std.Random.DefaultPrng.init(seed);
        const random = rng.random();

        const spreadsheet = generate_spreadsheet(random, .shuffled, 100);
        defer spreadsheet.deinit();

        try test_eval_all_equal(engines, spreadsheet);
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
    };
    try test_eval_constant(recursive_engines, spreadsheet, &.{
        5,  4, 3, 2, 1,
        9,  7, 5, 3, 1,
        10, 8, 6, 4, 2,
    });
}
