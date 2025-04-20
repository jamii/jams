//! Like ./scalar.zig, but the scheduling and evaluation are fused together for better memory locality and to avoid recalculating `CellIndexFormula`s.

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

    // A cell index is in `evaluating` when it is in the process of being evaluated, but its dependencies haven't been evaluated yet.
    evaluating: DynamicBitSet,

    // A cell index is in `evaluted` when its result has been stored in `cells`.
    evaluated: DynamicBitSet,

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
            .evaluating = DynamicBitSet.initEmpty(allocator, spreadsheet.driver_cell_count * spreadsheet.driver_formulas.len) catch oom(),
            .evaluated = DynamicBitSet.initEmpty(allocator, spreadsheet.driver_cell_count * spreadsheet.driver_formulas.len) catch oom(),
            // Note: `driver_stack` needs to be much bigger than in ./scalar.zig because more than one driver can be in the middle of being evaluated at a time.
            .driver_stack = ArrayList(f64).initCapacity(allocator, spreadsheet.driver_formulas.len * driver_stack_size_max) catch oom(),
            .cell_index_stack = ArrayList(i32).initCapacity(allocator, cell_index_stack_size_max) catch oom(),
            .row_bitset = DynamicBitSet.initEmpty(allocator, max_row_count) catch oom(),
        };
    }

    pub fn deinit(scratchpad: *Scratchpad) void {
        allocator.free(scratchpad.cells);
        scratchpad.evaluating.deinit();
        scratchpad.evaluated.deinit();
        scratchpad.driver_stack.deinit();
        scratchpad.cell_index_stack.deinit();
        scratchpad.row_bitset.deinit();
    }
};

pub const Schedule = void;

// Dummy function to match the api of ./scalar.zig
pub fn create_schedule(spreadsheet: Spreadsheet, scratchpad: *Scratchpad) Schedule {
    _ = spreadsheet;
    _ = scratchpad;
}

// Evaluate `spreadsheet`, storing the results in `scratchpad.cells`.
pub fn eval_spreadsheet(spreadsheet: Spreadsheet, scratchpad: *Scratchpad, schedule: Schedule) void {
    _ = schedule;

    scratchpad.evaluating.unmanaged.unsetAll();
    scratchpad.evaluated.unmanaged.unsetAll();

    for (0..spreadsheet.driver_formulas.len) |driver_index| {
        for (0..spreadsheet.driver_cell_count) |cell_index| {
            if (!scratchpad.evaluated.isSet(to_flat_index(spreadsheet.driver_cell_count, @intCast(driver_index), @intCast(cell_index))))
                eval_driver(spreadsheet, scratchpad, @intCast(driver_index), @intCast(cell_index));
        }
    }
}

fn eval_driver(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    driver_index: DriverIndex,
    cell_index: CellIndex,
) void {
    const stack = &scratchpad.driver_stack;
    const driver_cell_count = spreadsheet.driver_cell_count;
    const flat_index = to_flat_index(driver_cell_count, driver_index, cell_index);
    scratchpad.evaluating.set(flat_index);
    for (spreadsheet.driver_formulas[driver_index]) |expr| {
        switch (expr) {
            .constant => |constant| {
                stack.appendAssumeCapacity(constant);
            },
            .cell => |cell| {
                const expr_cell_index = eval_cell_index(scratchpad, cell.cell_index_formula, cell_index);
                if (expr_cell_index >= 0 and @as(u32, @intCast(expr_cell_index)) < driver_cell_count) {
                    const expr_flat_index = to_flat_index(driver_cell_count, cell.driver_index, @intCast(expr_cell_index));
                    if (!scratchpad.evaluated.isSet(expr_flat_index)) {
                        if (scratchpad.evaluating.isSet(expr_flat_index))
                            std.debug.panic("Cycle detected!", .{});
                        // Note: This is the main difference from ./scalar.zig - we may have to recursively evaluate another cell before finishing the current cell.
                        eval_driver(spreadsheet, scratchpad, cell.driver_index, @intCast(expr_cell_index));
                    }
                    stack.appendAssumeCapacity(scratchpad.cells[expr_flat_index]);
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
    scratchpad.evaluating.unset(flat_index);
    scratchpad.evaluated.set(flat_index);
    scratchpad.cells[flat_index] = stack.pop().?;
}

fn eval_cell_index(
    scratchpad: *Scratchpad,
    formula: CellIndexFormula,
    this_cell_index: CellIndex,
) i32 {
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
    return stack.pop().?;
}
