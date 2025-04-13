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
    driver_stack: ArrayList(f64),
    cell_index_stack: ArrayList(i32),

    fn init(spreadsheet: Spreadsheet) DriverCells {
        var driver_stack_size_max: usize = 0;
        var cell_index_stack_size_max: usize = 0;
        for (spreadsheet.driver_formulas) |driver_formula| {
            driver_stack_size_max = @max(driver_stack_size_max, driver_formula.len);
            for (driver_formula) |expr| {
                switch (expr) {
                    .constant, .add => {},
                    .cell => |cell| {
                        cell_index_stack_size_max = @max(cell_index_stack_size_max, cell.cell_index_formula.len);
                    },
                }
            }
        }
        return .{
            .driver_cell_count = spreadsheet.driver_cell_count,
            .cells = allocator.alloc(f64, spreadsheet.driver_formulas.len * spreadsheet.driver_cell_count) catch oom(),
            .driver_stack = ArrayList(f64).initCapacity(allocator, driver_stack_size_max) catch oom(),
            .cell_index_stack = ArrayList(i32).initCapacity(allocator, cell_index_stack_size_max) catch oom(),
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
        cell_index_formula: CellIndexFormula,
    },
    add, // Pop two results off stack.
    // TODO Add aggregates over drivers.
    // TODO Add aggregates and filters over source data.
};

const CellIndexFormula = []CellIndexFormulaExpr;
const CellIndexFormulaExpr = union(enum) {
    this,
    constant: i32,
    add, // Pop two results off stack.
};

const Schedule = []DriverCellIndex;

fn create_schedule(spreadsheet: Spreadsheet, driver_cells: *DriverCells) Schedule {
    const schedule_len = spreadsheet.driver_cell_count * spreadsheet.driver_formulas.len;

    var schedule = ArrayList(DriverCellIndex).initCapacity(allocator, schedule_len) catch oom();
    // Always returned

    var scheduled = AutoHashMap(DriverCellIndex, void).init(allocator);
    scheduled.ensureTotalCapacity(@intCast(schedule_len)) catch oom();
    defer scheduled.deinit();

    for (0..spreadsheet.driver_formulas.len) |driver_index| {
        for (0..spreadsheet.driver_cell_count) |cell_index| {
            visit_cell(spreadsheet, driver_cells, &schedule, &scheduled, @intCast(driver_index), @intCast(cell_index));
        }
    }

    assert(schedule.items.len == schedule_len);
    return schedule.items;
}

fn visit_cell(
    spreadsheet: Spreadsheet,
    driver_cells: *DriverCells,
    schedule: *ArrayList(DriverCellIndex),
    scheduled: *AutoHashMap(DriverCellIndex, void),
    driver_index: DriverIndex,
    cell_index: CellIndex,
) void {
    if (!scheduled.contains(.{ .driver_index = driver_index, .cell_index = cell_index })) {
        scheduled.putAssumeCapacity(.{ .driver_index = driver_index, .cell_index = cell_index }, {});
        visit_dependencies(spreadsheet, driver_cells, schedule, scheduled, spreadsheet.driver_formulas[driver_index], cell_index);
        schedule.appendAssumeCapacity(.{ .driver_index = driver_index, .cell_index = cell_index });
    }
}

fn visit_dependencies(
    spreadsheet: Spreadsheet,
    driver_cells: *DriverCells,
    schedule: *ArrayList(DriverCellIndex),
    scheduled: *AutoHashMap(DriverCellIndex, void),
    formula: DriverFormula,
    this_cell_index: CellIndex,
) void {
    for (formula) |expr| {
        switch (expr) {
            .constant, .add => {},
            .cell => |cell| {
                if (in_bounds(spreadsheet, eval_cell_index(spreadsheet, driver_cells, cell.cell_index_formula, this_cell_index))) |cell_index| {
                    visit_cell(spreadsheet, driver_cells, schedule, scheduled, cell.driver_index, cell_index);
                } else {
                    // No dependency - just returns zero.
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

fn eval_spreadsheet(
    spreadsheet: Spreadsheet,
    driver_cells: *DriverCells,
    schedule: Schedule,
) void {
    for (schedule) |item| {
        const formula = spreadsheet.driver_formulas[item.driver_index];
        const value = eval_driver(spreadsheet, driver_cells, formula, item.cell_index);
        driver_cells.set(item.driver_index, item.cell_index, value);
    }
}

fn eval_driver(
    spreadsheet: Spreadsheet,
    driver_cells: *DriverCells,
    formula: DriverFormula,
    this_cell_index: CellIndex,
) f64 {
    const stack = &driver_cells.driver_stack;
    assert(stack.items.len == 0);
    for (formula) |expr| {
        switch (expr) {
            .constant => |constant| {
                stack.appendAssumeCapacity(constant);
            },
            .cell => |cell| {
                if (in_bounds(spreadsheet, eval_cell_index(spreadsheet, driver_cells, cell.cell_index_formula, this_cell_index))) |cell_index| {
                    stack.appendAssumeCapacity(driver_cells.get(cell.driver_index, cell_index));
                } else {
                    // TODO How are out-of-bounds cell indexes handled?
                    stack.appendAssumeCapacity(0);
                }
            },
            .add => {
                const value1 = stack.pop().?;
                const value0 = stack.pop().?;
                stack.appendAssumeCapacity(value0 + value1);
            },
        }
    }
    return stack.pop().?;
}

fn eval_cell_index(
    spreadsheet: Spreadsheet,
    driver_cells: *DriverCells,
    formula: CellIndexFormula,
    this_cell_index: CellIndex,
) i32 {
    _ = spreadsheet;
    const stack = &driver_cells.cell_index_stack;
    assert(stack.items.len == 0);
    for (formula) |expr| {
        switch (expr) {
            .this => {
                stack.appendAssumeCapacity(@intCast(this_cell_index));
            },
            .constant => |constant| {
                stack.appendAssumeCapacity(constant);
            },
            .add => {
                const value1 = stack.pop().?;
                const value0 = stack.pop().?;
                stack.appendAssumeCapacity(value0 + value1);
            },
        }
    }
    return stack.pop().?;
}

fn generate_spreadsheet(random: std.Random) Spreadsheet {
    const driver_count: u32 = 1000000;
    const driver_cell_count: u32 = 20;

    const driver_formulas = allocator.alloc(DriverFormula, driver_count) catch oom();
    // Always returned.

    for (driver_formulas, 0..) |*driver_formula, driver_index| {
        var output = ArrayList(DriverFormulaExpr).init(allocator);
        defer output.deinit();

        generate_driver_formula(random, @intCast(driver_index), &output);
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
    output: *ArrayList(DriverFormulaExpr),
) void {
    switch (random.enumValue(std.meta.Tag(DriverFormulaExpr))) {
        .constant => {
            output.append(.{ .constant = random.float(f64) }) catch oom();
        },
        .cell => {
            // TODO Allow generating cyclic formula and just exclude them in the schedule.
            const driver_index = random.uintAtMost(DriverIndex, driver_index_max);

            var cell_index_formula = ArrayList(CellIndexFormulaExpr).init(allocator);
            defer cell_index_formula.deinit();

            generate_cell_index_formula(random, &cell_index_formula);
            output.append(.{ .cell = .{
                .driver_index = driver_index,
                .cell_index_formula = cell_index_formula.toOwnedSlice() catch oom(),
            } }) catch oom();
        },
        .add => {
            generate_driver_formula(random, driver_index_max, output);
            generate_driver_formula(random, driver_index_max, output);
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

pub fn main() void {
    var rng = std.Random.DefaultPrng.init(42);
    const random = rng.random();

    const spreadsheet = generate_spreadsheet(random);
    // Leaked.

    var driver_cells = DriverCells.init(spreadsheet);
    // Leaked.

    const before_create_schedule = std.time.nanoTimestamp();

    const schedule = create_schedule(spreadsheet, &driver_cells);
    // Leaked.

    std.debug.print("create_schedule: {d:.2} seconds for {} drivers\n", .{
        @as(f64, @floatFromInt(std.time.nanoTimestamp() - before_create_schedule)) / 1e9,
        spreadsheet.driver_formulas.len,
    });

    const before_eval_spreadsheet = std.time.nanoTimestamp();
    eval_spreadsheet(spreadsheet, &driver_cells, schedule);
    std.debug.print("eval_spreadsheet: {d:.2} seconds for {} drivers\n", .{
        @as(f64, @floatFromInt(std.time.nanoTimestamp() - before_eval_spreadsheet)) / 1e9,
        spreadsheet.driver_formulas.len,
    });

    std.debug.print("{any} {}\n", .{ spreadsheet.driver_formulas[0], driver_cells.get(0, 0) });
    std.debug.print("{any}\n", .{schedule[0..40]});
}
