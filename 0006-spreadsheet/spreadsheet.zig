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

const DriverFormula = union(enum) {
    constant: f64,
    cell: struct {
        driver_index: DriverIndex,
        cell_index_formula: *CellIndexFormula,
    },
    add: [2]*DriverFormula,
    // TODO Add aggregates over drivers.
    // TODO Add aggregates and filters over source data.
};

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
    switch (formula) {
        .constant => {},
        .cell => |cell| {
            if (in_bounds(spreadsheet, eval_cell_index(spreadsheet, cell.cell_index_formula.*, this_cell_index))) |cell_index| {
                visit_cell(spreadsheet, schedule, scheduled, cell.driver_index, cell_index);
            } else {
                // No dependency - gets filled in as zero.
            }
        },
        .add => |add| {
            visit_dependencies(spreadsheet, schedule, scheduled, add[0].*, this_cell_index);
            visit_dependencies(spreadsheet, schedule, scheduled, add[1].*, this_cell_index);
        },
    }
}

fn in_bounds(spreadsheet: Spreadsheet, cell_index: i32) ?CellIndex {
    if (cell_index < 0 or @as(u32, @intCast(cell_index)) >= spreadsheet.driver_cell_count) {
        return null;
    } else {
        return @intCast(cell_index);
    }
}

fn eval_spreadsheet(spreadsheet: Spreadsheet, schedule: Schedule) [][]f64 {
    const driver_cells = allocator.alloc([]f64, spreadsheet.driver_formulas.len) catch oom();
    // Always returned

    for (driver_cells) |*driver_cell| {
        driver_cell.* = allocator.alloc(f64, spreadsheet.driver_cell_count) catch oom();
        // Always returned
    }

    for (schedule) |item| {
        const formula = spreadsheet.driver_formulas[item.driver_index];
        const value = eval_driver(spreadsheet, driver_cells, formula, item.cell_index);
        driver_cells[item.driver_index][item.cell_index] = value;
    }

    return driver_cells;
}

fn eval_driver(spreadsheet: Spreadsheet, driver_cells: [][]f64, formula: DriverFormula, this_cell_index: CellIndex) f64 {
    switch (formula) {
        .constant => |constant| {
            return constant;
        },
        .cell => |cell| {
            if (in_bounds(spreadsheet, eval_cell_index(spreadsheet, cell.cell_index_formula.*, this_cell_index))) |cell_index| {
                return driver_cells[cell.driver_index][cell_index];
            } else {
                // TODO How are out-of-bounds months handled?
                return 0;
            }
        },
        .add => |add| {
            const value0 = eval_driver(spreadsheet, driver_cells, add[0].*, this_cell_index);
            const value1 = eval_driver(spreadsheet, driver_cells, add[1].*, this_cell_index);
            return value0 + value1;
        },
    }
}

fn eval_cell_index(spreadsheet: Spreadsheet, formula: CellIndexFormula, this_cell_index: CellIndex) i32 {
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
        driver_formula.* = generate_driver_formula(random, @intCast(driver_index), driver_cell_count);
    }

    return .{
        .driver_cell_count = driver_cell_count,
        .driver_formulas = driver_formulas,
    };
}

fn generate_driver_formula(random: std.Random, driver_index_max: DriverIndex, driver_cell_count: u32) DriverFormula {
    switch (random.enumValue(std.meta.Tag(DriverFormula))) {
        .constant => {
            return .{ .constant = random.float(f64) };
        },
        .cell => {
            // TODO Allow generating cyclic formula and just exclude them in the schedule.
            const driver_index = random.uintAtMost(DriverIndex, driver_index_max);

            const cell_index_formula = allocator.create(CellIndexFormula) catch oom();
            // Always returned

            cell_index_formula.* = generate_cell_index_formula(random, driver_cell_count);
            return .{ .cell = .{ .driver_index = driver_index, .cell_index_formula = cell_index_formula } };
        },
        .add => {
            const add0 = allocator.create(DriverFormula) catch oom();
            // Always returned

            const add1 = allocator.create(DriverFormula) catch oom();
            // Always returned

            add0.* = generate_driver_formula(random, driver_index_max, driver_cell_count);
            add1.* = generate_driver_formula(random, driver_index_max, driver_cell_count);
            return .{ .add = .{ add0, add1 } };
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

    std.debug.print("{}\n", .{driver_cells[0][0]});
}
