//! Like ./scalar.zig, but we evaluate an entire driver at once rather than cell by cell.
//! This can't handle recursive formulas without substantially complicating the scheduling.

const std = @import("std");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const DynamicBitSet = std.DynamicBitSet;
const allocator = std.heap.c_allocator;

const oom = @import("./spreadsheet.zig").oom;
const Spreadsheet = @import("./spreadsheet.zig").Spreadsheet;
const DriverIndex = @import("./spreadsheet.zig").DriverIndex;
const CellIndex = @import("./spreadsheet.zig").CellIndex;
const DriverFormula = @import("./spreadsheet.zig").DriverFormula;
const CellIndexFormula = @import("./spreadsheet.zig").CellIndexFormula;
const eval_filters = @import("./spreadsheet.zig").eval_filters;

// Temporary storage for evaluating a spreadsheet.
pub const Scratchpad = struct {
    cells: []f64,

    // A driver index is in `scheduling` when it is in the process of being scheduled, but its dependencies haven't been scheduled yet.
    scheduling: DynamicBitSet,

    // A driver index is in `scheduled` when it has been added to the schedule.
    scheduled: DynamicBitSet,

    // Stack for `DriverFormula`s
    driver_stack: []f64,

    // Stack for `CellIndexFormula`s.
    cell_index_stack: []i32,

    // Bitset used for `eval_filters`.
    row_bitset: DynamicBitSet,

    pub fn init(spreadsheet: Spreadsheet) Scratchpad {
        var driver_stack_size_max: usize = 0;
        var cell_index_stack_size_max: usize = 0;
        for (spreadsheet.driver_formulas) |driver_formula| {
            driver_stack_size_max = @max(driver_stack_size_max, driver_formula.len);
            for (driver_formula) |expr| {
                switch (expr) {
                    .constant, .add, .sum_column => {},
                    .cell => |cell| {
                        cell_index_stack_size_max = @max(cell_index_stack_size_max, cell.cell_index_formula.len);
                    },
                }
            }
        }
        var max_row_count: usize = 0;
        for (spreadsheet.tables) |table| {
            max_row_count = @max(max_row_count, table.row_count);
        }
        return .{
            .cells = allocator.alloc(f64, spreadsheet.driver_formulas.len * spreadsheet.driver_cell_count) catch oom(),
            .scheduling = DynamicBitSet.initEmpty(allocator, spreadsheet.driver_formulas.len * spreadsheet.driver_cell_count) catch oom(),
            .scheduled = DynamicBitSet.initEmpty(allocator, spreadsheet.driver_formulas.len * spreadsheet.driver_cell_count) catch oom(),
            // Both stacks have to be large enough to evaluate an entire timeseries, rather than just one cell.
            .driver_stack = allocator.alloc(f64, driver_stack_size_max * spreadsheet.driver_cell_count) catch oom(),
            .cell_index_stack = allocator.alloc(i32, cell_index_stack_size_max * spreadsheet.driver_cell_count) catch oom(),
            .row_bitset = DynamicBitSet.initEmpty(allocator, max_row_count) catch oom(),
        };
    }

    pub fn deinit(scratchpad: *Scratchpad) void {
        allocator.free(scratchpad.cells);
        scratchpad.scheduling.deinit();
        scratchpad.scheduled.deinit();
        allocator.free(scratchpad.driver_stack);
        allocator.free(scratchpad.cell_index_stack);
        scratchpad.row_bitset.deinit();
    }
};

pub const Schedule = []DriverIndex;

// Figure out what order to evaluate drivers in.
pub fn create_schedule(spreadsheet: Spreadsheet, scratchpad: *Scratchpad) Schedule {
    const schedule_len = spreadsheet.driver_formulas.len;

    var schedule = ArrayList(DriverIndex).initCapacity(allocator, schedule_len) catch oom();
    defer schedule.deinit();

    scratchpad.scheduling.unmanaged.unsetAll();
    scratchpad.scheduled.unmanaged.unsetAll();

    for (0..spreadsheet.driver_formulas.len) |driver_index| {
        if (!scratchpad.scheduled.isSet(driver_index))
            visit_driver(spreadsheet, scratchpad, &schedule, @intCast(driver_index));
    }

    assert(schedule.items.len == schedule_len);
    return schedule.toOwnedSlice() catch oom();
}

fn visit_driver(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    schedule: *ArrayList(DriverIndex),
    driver_index: DriverIndex,
) void {
    scratchpad.scheduling.set(driver_index);
    for (spreadsheet.driver_formulas[driver_index]) |expr| {
        switch (expr) {
            .constant, .add, .sum_column => {},
            .cell => |cell| {
                if (!scratchpad.scheduled.isSet(cell.driver_index)) {
                    if (scratchpad.scheduling.isSet(cell.driver_index))
                        std.debug.panic("Cycle detected!", .{});
                    visit_driver(spreadsheet, scratchpad, schedule, cell.driver_index);
                }
            },
        }
    }
    scratchpad.scheduling.unset(driver_index);
    scratchpad.scheduled.set(driver_index);
    schedule.appendAssumeCapacity(driver_index);
}

// Evaluate `spreadsheet` in `schedule` order, storing the results in `scratchpad.cells`.
pub fn eval_spreadsheet(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    schedule: Schedule,
) void {
    for (schedule) |driver_index| {
        const formula = spreadsheet.driver_formulas[driver_index];
        std.mem.copyForwards(
            f64,
            scratchpad.cells[driver_index * spreadsheet.driver_cell_count ..][0..spreadsheet.driver_cell_count],
            eval_driver(spreadsheet, scratchpad, formula),
        );
    }
}

fn eval_driver(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    formula: DriverFormula,
) []f64 {
    const stack = scratchpad.driver_stack;
    var stack_index: usize = 0;
    const driver_cell_count = spreadsheet.driver_cell_count;
    for (formula) |expr| {
        switch (expr) {
            .constant => |constant| {
                const outputs = stack[stack_index * driver_cell_count ..][0..driver_cell_count];
                stack_index += 1;
                for (outputs) |*output| output.* = constant;
            },
            .cell => |cell| {
                const inputs = scratchpad.cells[cell.driver_index * driver_cell_count ..][0..driver_cell_count];
                const cell_indexes = eval_cell_index(spreadsheet, scratchpad, cell.cell_index_formula);
                const outputs = stack[stack_index * driver_cell_count ..][0..driver_cell_count];
                stack_index += 1;
                for (cell_indexes, outputs) |cell_index, *output| {
                    if (cell_index >= 0 and @as(u32, @intCast(cell_index)) < driver_cell_count) {
                        output.* = inputs[@intCast(cell_index)];
                    } else {
                        // TODO How are out-of-bounds cell indexes handled?
                        output.* = 0;
                    }
                }
            },
            .add => {
                stack_index -= 1;
                const inputs = stack[stack_index * driver_cell_count ..][0..driver_cell_count];
                stack_index -= 1;
                const outputs = stack[stack_index * driver_cell_count ..][0..driver_cell_count];
                stack_index += 1;
                for (inputs, outputs) |input, *output| output.* += input;
            },
            .sum_column => |sum_column| {
                const outputs = stack[stack_index * driver_cell_count ..][0..driver_cell_count];
                for (outputs) |*output| output.* = 0;
                const table = &spreadsheet.tables[sum_column.table_index];
                // Currently filters can't refer to `this`, so we only have to evaluate them once per driver.
                eval_filters(sum_column.filters, table, &scratchpad.row_bitset);
                switch (table.columns[sum_column.column_index]) {
                    .dimension_string => {},
                    .vectors => |vectors| {
                        for (0..driver_cell_count) |cell_index| {
                            const vector = vectors[cell_index * table.row_count ..][0..table.row_count];
                            for (vector, 0..) |float, row_index| {
                                if (scratchpad.row_bitset.isSet(row_index)) outputs[cell_index] += float;
                            }
                        }
                    },
                }
                stack_index += 1;
            },
        }
    }
    assert(stack_index == 1);
    return stack[0..driver_cell_count];
}

fn eval_cell_index(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    formula: CellIndexFormula,
) []i32 {
    const stack = scratchpad.cell_index_stack;
    var stack_index: usize = 0;
    const driver_cell_count = spreadsheet.driver_cell_count;
    for (formula) |expr| {
        switch (expr) {
            .this => {
                const outputs = stack[stack_index * driver_cell_count ..][0..driver_cell_count];
                stack_index += 1;
                for (outputs, 0..) |*output, this| output.* = @intCast(this);
            },
            .constant => |constant| {
                const outputs = stack[stack_index * driver_cell_count ..][0..driver_cell_count];
                stack_index += 1;
                for (outputs) |*output| output.* = constant;
            },
            .add => {
                stack_index -= 1;
                const inputs = stack[stack_index * driver_cell_count ..][0..driver_cell_count];
                stack_index -= 1;
                const outputs = stack[stack_index * driver_cell_count ..][0..driver_cell_count];
                stack_index += 1;
                for (inputs, outputs) |input, *output| output.* += input;
            },
        }
    }
    assert(stack_index == 1);
    return stack[0..driver_cell_count];
}
