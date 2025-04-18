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

pub const Scratchpad = struct {
    cells: []f64,
    evalled: DynamicBitSet,
    driver_stack: ArrayList(f64),
    cell_index_stack: ArrayList(i32),

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
        return .{
            .cells = allocator.alloc(f64, spreadsheet.driver_formulas.len * spreadsheet.driver_cell_count) catch oom(),
            .evalled = DynamicBitSet.initEmpty(allocator, spreadsheet.driver_cell_count * spreadsheet.driver_formulas.len) catch oom(),
            .driver_stack = ArrayList(f64).initCapacity(allocator, spreadsheet.driver_formulas.len * driver_stack_size_max) catch oom(),
            .cell_index_stack = ArrayList(i32).initCapacity(allocator, spreadsheet.driver_formulas.len * cell_index_stack_size_max) catch oom(),
        };
    }

    pub fn deinit(scratchpad: *Scratchpad) void {
        allocator.free(scratchpad.cells);
        scratchpad.evalled.deinit();
        scratchpad.driver_stack.deinit();
        scratchpad.cell_index_stack.deinit();
    }
};

pub const Schedule = void;

pub fn create_schedule(spreadsheet: Spreadsheet, scratchpad: *Scratchpad) Schedule {
    _ = spreadsheet;
    _ = scratchpad;
}

pub fn eval_spreadsheet(spreadsheet: Spreadsheet, scratchpad: *Scratchpad, schedule: Schedule) void {
    _ = schedule;

    scratchpad.evalled.unmanaged.unsetAll();

    for (0..spreadsheet.driver_formulas.len) |driver_index| {
        for (0..spreadsheet.driver_cell_count) |cell_index| {
            if (!scratchpad.evalled.isSet(to_flat_index(spreadsheet.driver_cell_count, @intCast(driver_index), @intCast(cell_index))))
                eval_cell(spreadsheet, scratchpad, @intCast(driver_index), @intCast(cell_index));
        }
    }
}

fn eval_cell(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    driver_index: DriverIndex,
    cell_index: CellIndex,
) void {
    const stack = &scratchpad.driver_stack;
    const driver_cell_count = spreadsheet.driver_cell_count;
    for (spreadsheet.driver_formulas[driver_index]) |expr| {
        switch (expr) {
            .constant => |constant| {
                stack.appendAssumeCapacity(constant);
            },
            .cell => |cell| {
                const expr_cell_index = eval_cell_index(spreadsheet, scratchpad, cell.cell_index_formula, cell_index);
                if (expr_cell_index >= 0 and @as(u32, @intCast(expr_cell_index)) < driver_cell_count) {
                    const expr_flat_index = to_flat_index(driver_cell_count, cell.driver_index, @intCast(expr_cell_index));
                    if (!scratchpad.evalled.isSet(expr_flat_index))
                        eval_cell(spreadsheet, scratchpad, cell.driver_index, @intCast(expr_cell_index));
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
                eval_filters(sum_column.filters, table);
                var sum: f64 = 0;
                switch (table.columns[sum_column.column_index]) {
                    .vectors => |vectors| {
                        const vector = vectors[cell_index * table.row_count ..][0..table.row_count];
                        for (vector, 0..) |float, row_index| {
                            if (table.bitset.isSet(row_index)) sum += float;
                        }
                    },
                    .dimension_string => {},
                }
                stack.appendAssumeCapacity(sum);
            },
        }
    }
    const flat_index = to_flat_index(driver_cell_count, driver_index, cell_index);
    scratchpad.evalled.set(flat_index);
    scratchpad.cells[flat_index] = stack.pop().?;
}

fn eval_cell_index(
    spreadsheet: Spreadsheet,
    scratchpad: *Scratchpad,
    formula: CellIndexFormula,
    this_cell_index: CellIndex,
) i32 {
    _ = spreadsheet;

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
