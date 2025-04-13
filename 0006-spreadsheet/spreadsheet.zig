const std = @import("std");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const AutoHashMap = std.AutoHashMap;
const allocator = std.heap.c_allocator;

fn oom() noreturn {
    std.debug.panic("OOM", .{});
}

const Spreadsheet = struct {
    // Assume that every driver has the same number of cells.
    driver_cell_count: u32,
    driver_formulas: []DriverFormula,
    // TODO Add source data.
};

const DriverIndex = u32;
const CellIndex = u32;
const DriverCellIndex = struct {
    driver_index: DriverIndex,
    cell_index: CellIndex,
};

const DriverCells = struct {
    driver_cell_count: u32,
    cells: []f64,
    stack: ArrayList(f64),

    fn init(spreadsheet: Spreadsheet) DriverCells {
        var stack_size_max: usize = 0;
        for (spreadsheet.driver_formulas) |driver_formula| {
            stack_size_max = @max(stack_size_max, driver_formula.len);
        }
        return .{
            .driver_cell_count = spreadsheet.driver_cell_count,
            .cells = allocator.alloc(f64, spreadsheet.driver_formulas.len * spreadsheet.driver_cell_count) catch oom(),
            .stack = ArrayList(f64).initCapacity(allocator, stack_size_max) catch oom(),
        };
    }

    fn get(self: DriverCells, driver_index: DriverIndex, cell_index: CellIndex) f64 {
        return self.cells[(driver_index * self.driver_cell_count) + cell_index];
    }

    fn set(self: DriverCells, driver_index: DriverIndex, cell_index: CellIndex, value: f64) void {
        self.cells[(driver_index * self.driver_cell_count) + cell_index] = value;
    }
};

const DriverFormula = []DriverFormulaExpr;
const DriverFormulaExpr = union(enum) {
    constant: f64,
    cell: struct {
        driver_index: DriverIndex,
        cell_index_formula: *CellIndexFormula,
    },
    add, // Pop two results off stack.
    // TODO Add aggregates over drivers.
    // TODO Add aggregates and filters over source data.
};

// TODO Pack into rpn.
const CellIndexFormula = union(enum) {
    this,
    constant: i32,
    add: [2]*CellIndexFormula,
};

const Schedule = []DriverCellIndex;

fn create_schedule(spreadsheet: Spreadsheet) Schedule {
    const schedule_len = spreadsheet.driver_cell_count * spreadsheet.driver_formulas.len;

    var schedule = ArrayList(DriverCellIndex).initCapacity(allocator, schedule_len) catch oom();
    // Always returned

    var scheduled = AutoHashMap(DriverCellIndex, void).init(allocator);
    scheduled.ensureTotalCapacity(@intCast(schedule_len)) catch oom();
    defer scheduled.deinit();

    for (0..spreadsheet.driver_formulas.len) |driver_index| {
        for (0..spreadsheet.driver_cell_count) |cell_index| {
            visit_cell(spreadsheet, &schedule, &scheduled, @intCast(driver_index), @intCast(cell_index));
        }
    }

    assert(schedule.items.len == schedule_len);
    return schedule.items;
}

fn visit_cell(
    spreadsheet: Spreadsheet,
    schedule: *ArrayList(DriverCellIndex),
    scheduled: *AutoHashMap(DriverCellIndex, void),
    driver_index: DriverIndex,
    cell_index: CellIndex,
) void {
    if (!scheduled.contains(.{ .driver_index = driver_index, .cell_index = cell_index })) {
        scheduled.putAssumeCapacity(.{ .driver_index = driver_index, .cell_index = cell_index }, {});
        visit_dependencies(spreadsheet, schedule, scheduled, spreadsheet.driver_formulas[driver_index], cell_index);
        schedule.appendAssumeCapacity(.{ .driver_index = driver_index, .cell_index = cell_index });
    }
}

fn visit_dependencies(
    spreadsheet: Spreadsheet,
    schedule: *ArrayList(DriverCellIndex),
    scheduled: *AutoHashMap(DriverCellIndex, void),
    formula: DriverFormula,
    this_cell_index: CellIndex,
) void {
    for (formula) |expr| {
        switch (expr) {
            .constant, .add => {},
            .cell => |cell| {
                if (in_bounds(spreadsheet, eval_cell_index(spreadsheet, cell.cell_index_formula.*, this_cell_index))) |cell_index| {
                    visit_cell(spreadsheet, schedule, scheduled, cell.driver_index, cell_index);
                } else {
                    // No dependency - gets filled in as zero.
                }
            },
        }
    }
}

fn in_bounds(spreadsheet: Spreadsheet, cell_index: i32) ?CellIndex {
    if (cell_index < 0 or @as(u32, @intCast(cell_index)) >= spreadsheet.driver_cell_count) {
        return null;
    } else {
        return @intCast(cell_index);
    }
}

fn eval_spreadsheet(spreadsheet: Spreadsheet, schedule: Schedule) DriverCells {
    var driver_cells = DriverCells.init(spreadsheet);
    // Always returned

    for (schedule) |item| {
        const formula = spreadsheet.driver_formulas[item.driver_index];
        const value = eval_driver(spreadsheet, &driver_cells, formula, item.cell_index);
        driver_cells.set(item.driver_index, item.cell_index, value);
    }

    return driver_cells;
}

fn eval_driver(
    spreadsheet: Spreadsheet,
    driver_cells: *DriverCells,
    formula: DriverFormula,
    this_cell_index: CellIndex,
) f64 {
    assert(driver_cells.stack.items.len == 0);
    for (formula) |expr| {
        switch (expr) {
            .constant => |constant| {
                driver_cells.stack.appendAssumeCapacity(constant);
            },
            .cell => |cell| {
                if (in_bounds(spreadsheet, eval_cell_index(spreadsheet, cell.cell_index_formula.*, this_cell_index))) |cell_index| {
                    driver_cells.stack.appendAssumeCapacity(driver_cells.get(cell.driver_index, cell_index));
                } else {
                    // TODO How are out-of-bounds cell indexes handled?
                    driver_cells.stack.appendAssumeCapacity(0);
                }
            },
            .add => {
                const value1 = driver_cells.stack.pop().?;
                const value0 = driver_cells.stack.pop().?;
                driver_cells.stack.appendAssumeCapacity(value0 + value1);
            },
        }
    }
    return driver_cells.stack.pop().?;
}

fn eval_cell_index(
    spreadsheet: Spreadsheet,
    formula: CellIndexFormula,
    this_cell_index: CellIndex,
) i32 {
    switch (formula) {
        .this => {
            return @intCast(this_cell_index);
        },
        .constant => |constant| {
            return constant;
        },
        .add => |add| {
            const value0 = eval_cell_index(spreadsheet, add[0].*, this_cell_index);
            const value1 = eval_cell_index(spreadsheet, add[1].*, this_cell_index);
            return value0 + value1;
        },
    }
}

fn generate_spreadsheet(random: std.Random) Spreadsheet {
    const driver_count: u32 = 1000000;
    const driver_cell_count: u32 = 20;

    const driver_formulas = allocator.alloc(DriverFormula, driver_count) catch oom();
    // Always returned.

    for (driver_formulas, 0..) |*driver_formula, driver_index| {
        var output = ArrayList(DriverFormulaExpr).init(allocator);
        defer output.deinit();

        generate_driver_formula(random, @intCast(driver_index), driver_cell_count, &output);
        driver_formula.* = output.toOwnedSlice() catch oom();
    }

    return .{
        .driver_cell_count = driver_cell_count,
        .driver_formulas = driver_formulas,
    };
}

fn generate_driver_formula(
    random: std.Random,
    driver_index_max: DriverIndex,
    driver_cell_count: u32,
    output: *ArrayList(DriverFormulaExpr),
) void {
    switch (random.enumValue(std.meta.Tag(DriverFormulaExpr))) {
        .constant => {
            output.append(.{ .constant = random.float(f64) }) catch oom();
        },
        .cell => {
            // TODO Allow generating cyclic formula and just exclude them in the schedule.
            const driver_index = random.uintAtMost(DriverIndex, driver_index_max);

            const cell_index_formula = allocator.create(CellIndexFormula) catch oom();
            // Always returned

            cell_index_formula.* = generate_cell_index_formula(random, driver_cell_count);
            output.append(.{ .cell = .{ .driver_index = driver_index, .cell_index_formula = cell_index_formula } }) catch oom();
        },
        .add => {
            generate_driver_formula(random, driver_index_max, driver_cell_count, output);
            generate_driver_formula(random, driver_index_max, driver_cell_count, output);
            output.append(.add) catch oom();
        },
    }
}

fn generate_cell_index_formula(random: std.Random, driver_cell_count: u32) CellIndexFormula {
    switch (random.enumValue(std.meta.Tag(CellIndexFormula))) {
        .this => {
            return .this;
        },
        .constant => {
            // It's ok to go out of bounds but we want reasonable odds of being in bounds too,
            // so don't use a totally random int.
            const bound: i32 = @intCast(driver_cell_count);
            return .{ .constant = random.intRangeLessThan(i32, -bound, bound) };
        },
        .add => {
            const add0 = allocator.create(CellIndexFormula) catch oom();
            // Always returned

            const add1 = allocator.create(CellIndexFormula) catch oom();
            // Always returned

            add0.* = generate_cell_index_formula(random, driver_cell_count);
            add1.* = generate_cell_index_formula(random, driver_cell_count);
            return .{ .add = .{ add0, add1 } };
        },
    }
}

pub fn main() void {
    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();

    const spreadsheet = generate_spreadsheet(random);
    // Leaked.

    const before_create_schedule = std.time.nanoTimestamp();

    const schedule = create_schedule(spreadsheet);
    // Leaked.

    std.debug.print("create_schedule: {d:.2} seconds per {} drivers\n", .{
        @as(f64, @floatFromInt(std.time.nanoTimestamp() - before_create_schedule)) / 1e9,
        spreadsheet.driver_formulas.len,
    });

    const before_eval_spreadsheet = std.time.nanoTimestamp();

    const driver_cells = eval_spreadsheet(spreadsheet, schedule);
    // Leaked.

    std.debug.print("eval_spreadsheet: {d:.2} seconds per {} drivers\n", .{
        @as(f64, @floatFromInt(std.time.nanoTimestamp() - before_eval_spreadsheet)) / 1e9,
        spreadsheet.driver_formulas.len,
    });

    std.debug.print("{any} {}\n", .{ spreadsheet.driver_formulas[0], driver_cells.get(0, 0) });
}
