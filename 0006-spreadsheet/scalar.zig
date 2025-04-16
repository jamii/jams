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
    driver_stack: ArrayList(f64),
    cell_index_stack: ArrayList(i32),

    pub fn init(spreadsheet: Spreadsheet) Scratchpad {
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

pub const Schedule = []FlatIndex;

pub fn create_schedule(spreadsheet: Spreadsheet, scratchpad: *Scratchpad) Schedule {
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

pub fn eval_spreadsheet(
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
