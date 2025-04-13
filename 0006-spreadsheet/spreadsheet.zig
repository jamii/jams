const std = @import("std");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const DynamicBitSet = std.DynamicBitSet;
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
const FlatIndex = u32;

inline fn to_flat_index(driver_cell_count: u32, driver_index: DriverIndex, cell_index: CellIndex) FlatIndex {
    return (driver_index * driver_cell_count) + cell_index;
}

inline fn from_flat_index(driver_cell_count: u32, flat_index: FlatIndex) struct { DriverIndex, CellIndex } {
    return .{
        @divTrunc(flat_index, driver_cell_count),
        flat_index % driver_cell_count,
    };
}

const Scratchpad = struct {
    cells: []f64,
    driver_stack: ArrayList(f64),
    cell_index_stack: ArrayList(i32),

    fn init(spreadsheet: Spreadsheet) Scratchpad {
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
            .cells = allocator.alloc(f64, spreadsheet.driver_formulas.len * spreadsheet.driver_cell_count) catch oom(),
            .driver_stack = ArrayList(f64).initCapacity(allocator, driver_stack_size_max) catch oom(),
            .cell_index_stack = ArrayList(i32).initCapacity(allocator, cell_index_stack_size_max) catch oom(),
        };
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

const Schedule = []FlatIndex;

fn create_schedule(spreadsheet: Spreadsheet, scratchpad: *Scratchpad) Schedule {
    const schedule_len = spreadsheet.driver_cell_count * spreadsheet.driver_formulas.len;

    var schedule = ArrayList(FlatIndex).initCapacity(allocator, schedule_len) catch oom();
    defer schedule.deinit();

    var scheduled = DynamicBitSet.initEmpty(allocator, schedule_len) catch oom();
    defer scheduled.deinit();

    for (0..spreadsheet.driver_formulas.len) |driver_index| {
        for (0..spreadsheet.driver_cell_count) |cell_index| {
            if (!scheduled.isSet(to_flat_index(spreadsheet.driver_cell_count, @intCast(driver_index), @intCast(cell_index))))
                visit_cell(spreadsheet, scratchpad, &schedule, &scheduled, @intCast(driver_index), @intCast(cell_index));
        }
    }

    assert(schedule.items.len == schedule_len);
    return schedule.toOwnedSlice() catch oom();
}

fn visit_cell(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    schedule: *ArrayList(FlatIndex),
    scheduled: *DynamicBitSet,
    driver_index: DriverIndex,
    cell_index: CellIndex,
) void {
    const flat_index = to_flat_index(spreadsheet.driver_cell_count, driver_index, cell_index);
    scheduled.set(flat_index);
    for (spreadsheet.driver_formulas[driver_index]) |expr| {
        switch (expr) {
            .constant, .add => {},
            .cell => |cell| {
                if (eval_cell_index(spreadsheet, scratchpad, cell.cell_index_formula, cell_index)) |evalled_cell_index| {
                    if (!scheduled.isSet(to_flat_index(spreadsheet.driver_cell_count, cell.driver_index, evalled_cell_index)))
                        visit_cell(spreadsheet, scratchpad, schedule, scheduled, cell.driver_index, evalled_cell_index);
                } else {
                    // TODO How are out-of-bounds cell indexes handled?
                }
            },
        }
    }
    schedule.appendAssumeCapacity(flat_index);
}

fn eval_spreadsheet(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    schedule: Schedule,
) void {
    for (schedule) |flat_index| {
        const driver_index, const cell_index = from_flat_index(spreadsheet.driver_cell_count, flat_index);
        const formula = spreadsheet.driver_formulas[driver_index];
        const value = eval_driver(spreadsheet, scratchpad, formula, cell_index);
        scratchpad.cells[flat_index] = value;
    }
}

fn eval_driver(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    formula: DriverFormula,
    this_cell_index: CellIndex,
) f64 {
    const stack = &scratchpad.driver_stack;
    assert(stack.items.len == 0);
    const driver_cell_count = spreadsheet.driver_cell_count;
    for (formula) |expr| {
        switch (expr) {
            .constant => |constant| {
                stack.appendAssumeCapacity(constant);
            },
            .cell => |cell| {
                if (eval_cell_index(spreadsheet, scratchpad, cell.cell_index_formula, this_cell_index)) |cell_index| {
                    stack.appendAssumeCapacity(scratchpad.cells[to_flat_index(driver_cell_count, cell.driver_index, cell_index)]);
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
    scratchpad: *Scratchpad,
    formula: CellIndexFormula,
    this_cell_index: CellIndex,
) ?CellIndex {
    const stack = &scratchpad.cell_index_stack;
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
    const result = stack.pop().?;
    if (result >= 0 and @as(u32, @intCast(result)) < spreadsheet.driver_cell_count) {
        return @intCast(result);
    } else {
        return null;
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

    var scratchpad = Scratchpad.init(spreadsheet);
    // Leaked.

    const before_create_schedule = std.time.nanoTimestamp();

    const schedule = create_schedule(spreadsheet, &scratchpad);
    // Leaked.

    std.debug.print("create_schedule: {d:.2} seconds for {} drivers\n", .{
        @as(f64, @floatFromInt(std.time.nanoTimestamp() - before_create_schedule)) / 1e9,
        spreadsheet.driver_formulas.len,
    });

    const before_eval_spreadsheet = std.time.nanoTimestamp();
    eval_spreadsheet(spreadsheet, &scratchpad, schedule);
    std.debug.print("eval_spreadsheet: {d:.2} seconds for {} drivers\n", .{
        @as(f64, @floatFromInt(std.time.nanoTimestamp() - before_eval_spreadsheet)) / 1e9,
        spreadsheet.driver_formulas.len,
    });

    std.debug.print("{} {}\n", .{ scratchpad.cells[0], scratchpad.cells[scratchpad.cells.len - 1] });
    std.debug.print("{} {}\n", .{ schedule[0], schedule[schedule.len - 1] });
}
