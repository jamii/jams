//! The simplest possible engine.

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

// We store cells all together in one slice and index them by `FlatIndex`.
pub const FlatIndex = u32;
inline fn to_flat_index(driver_cell_count: u32, driver_index: DriverIndex, cell_index: CellIndex) FlatIndex {
    return (driver_index * driver_cell_count) + cell_index;
}
inline fn from_flat_index(driver_cell_count: u32, flat_index: FlatIndex) struct { DriverIndex, CellIndex } {
    return .{
        @divTrunc(flat_index, driver_cell_count),
        flat_index % driver_cell_count,
    };
}

// Temporary storage for evaluating a spreadsheet.
pub const Scratchpad = struct {
    cells: []f64,

    // A cell index is in `scheduling` when it is in the process of being scheduled, but its dependencies haven't been scheduled yet.
    scheduling: DynamicBitSet,

    // A cell index is in `scheduled` when it has been added to the schedule.
    scheduled: DynamicBitSet,

    // Stack for `DriverFormula`s
    driver_stack: ArrayList(f64),

    // Stack for `CellIndexFormula`s.
    cell_index_stack: ArrayList(i32),

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
            .driver_stack = ArrayList(f64).initCapacity(allocator, driver_stack_size_max) catch oom(),
            .cell_index_stack = ArrayList(i32).initCapacity(allocator, cell_index_stack_size_max) catch oom(),
            .row_bitset = DynamicBitSet.initEmpty(allocator, max_row_count) catch oom(),
        };
    }

    pub fn deinit(scratchpad: *Scratchpad) void {
        allocator.free(scratchpad.cells);
        scratchpad.scheduling.deinit();
        scratchpad.scheduled.deinit();
        scratchpad.driver_stack.deinit();
        scratchpad.cell_index_stack.deinit();
        scratchpad.row_bitset.deinit();
    }
};

pub const Schedule = []FlatIndex;

// Figure out what order to evaluate cells in.
pub fn create_schedule(spreadsheet: Spreadsheet, scratchpad: *Scratchpad) Schedule {
    const schedule_len = spreadsheet.driver_cell_count * spreadsheet.driver_formulas.len;

    var schedule = ArrayList(FlatIndex).initCapacity(allocator, schedule_len) catch oom();
    defer schedule.deinit();

    scratchpad.scheduling.unmanaged.unsetAll();
    scratchpad.scheduled.unmanaged.unsetAll();

    for (0..spreadsheet.driver_formulas.len) |driver_index| {
        for (0..spreadsheet.driver_cell_count) |cell_index| {
            if (!scratchpad.scheduled.isSet(to_flat_index(spreadsheet.driver_cell_count, @intCast(driver_index), @intCast(cell_index))))
                visit_cell(spreadsheet, scratchpad, &schedule, @intCast(driver_index), @intCast(cell_index));
        }
    }

    assert(schedule.items.len == schedule_len);
    return schedule.toOwnedSlice() catch oom();
}

fn visit_cell(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    schedule: *ArrayList(FlatIndex),
    driver_index: DriverIndex,
    cell_index: CellIndex,
) void {
    const flat_index = to_flat_index(spreadsheet.driver_cell_count, driver_index, cell_index);
    scratchpad.scheduling.set(flat_index);
    for (spreadsheet.driver_formulas[driver_index]) |expr| {
        switch (expr) {
            .constant, .add, .sum_column => {},
            .cell => |cell| {
                if (eval_cell_index(scratchpad, spreadsheet.driver_cell_count, cell.cell_index_formula, cell_index)) |evalled_cell_index| {
                    const expr_flat_index = to_flat_index(spreadsheet.driver_cell_count, cell.driver_index, evalled_cell_index);
                    if (!scratchpad.scheduled.isSet(expr_flat_index)) {
                        if (scratchpad.scheduling.isSet(expr_flat_index))
                            std.debug.panic("Cycle detected!", .{});
                        visit_cell(spreadsheet, scratchpad, schedule, cell.driver_index, evalled_cell_index);
                    }
                } else {
                    // TODO How are out-of-bounds cell indexes handled?
                }
            },
        }
    }
    scratchpad.scheduling.unset(flat_index);
    scratchpad.scheduled.set(flat_index);
    schedule.appendAssumeCapacity(flat_index);
}

// Evaluate `spreadsheet` in `schedule` order, storing the results in `scratchpad.cells`.
pub fn eval_spreadsheet(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    schedule: Schedule,
) void {
    for (schedule) |flat_index| {
        const driver_index, const cell_index = from_flat_index(spreadsheet.driver_cell_count, flat_index);
        const value = eval_driver(spreadsheet, scratchpad, driver_index, cell_index);
        scratchpad.cells[flat_index] = value;
    }
}

fn eval_driver(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    driver_index: DriverIndex,
    cell_index: CellIndex,
) f64 {
    const stack = &scratchpad.driver_stack;
    assert(stack.items.len == 0);
    const driver_cell_count = spreadsheet.driver_cell_count;
    for (spreadsheet.driver_formulas[driver_index]) |expr| {
        switch (expr) {
            .constant => |constant| {
                stack.appendAssumeCapacity(constant);
            },
            .cell => |cell| {
                if (eval_cell_index(scratchpad, driver_cell_count, cell.cell_index_formula, cell_index)) |expr_cell_index| {
                    stack.appendAssumeCapacity(scratchpad.cells[to_flat_index(driver_cell_count, cell.driver_index, expr_cell_index)]);
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
            .sum_column => |sum_column| {
                const table = &spreadsheet.tables[sum_column.table_index];
                eval_filters(sum_column.filters, table, &scratchpad.row_bitset);
                var sum: f64 = 0;
                switch (table.columns[sum_column.column_index]) {
                    .vectors => |vectors| {
                        const vector = vectors[cell_index * table.row_count ..][0..table.row_count];
                        // TODO This would benefit from simd, or at least inlining the isSet math.
                        for (vector, 0..) |float, row_index| {
                            if (scratchpad.row_bitset.isSet(row_index)) sum += float;
                        }
                    },
                    .dimension_string => {},
                }
                stack.appendAssumeCapacity(sum);
            },
        }
    }
    return stack.pop().?;
}

fn eval_cell_index(
    scratchpad: *Scratchpad,
    driver_cell_count: u32,
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
    if (result >= 0 and @as(u32, @intCast(result)) < driver_cell_count) {
        return @intCast(result);
    } else {
        return null;
    }
}
