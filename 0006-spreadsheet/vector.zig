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

pub const Scratchpad = struct {
    cells: []f64,
    driver_stack: []f64,
    cell_index_stack: []i32,

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
            .driver_stack = allocator.alloc(f64, driver_stack_size_max * spreadsheet.driver_cell_count) catch oom(),
            .cell_index_stack = allocator.alloc(i32, cell_index_stack_size_max * spreadsheet.driver_cell_count) catch oom(),
        };
    }
};

pub const Schedule = []DriverIndex;

pub fn create_schedule(spreadsheet: Spreadsheet, scratchpad: *Scratchpad) Schedule {
    _ = scratchpad;

    const schedule_len = spreadsheet.driver_formulas.len;

    var schedule = ArrayList(DriverIndex).initCapacity(allocator, schedule_len) catch oom();
    defer schedule.deinit();

    var scheduled = DynamicBitSet.initEmpty(allocator, schedule_len) catch oom();
    defer scheduled.deinit();

    const StackItem = struct {
        driver_index: DriverIndex,
        formula_index: usize,
    };
    var stack = ArrayList(StackItem).initCapacity(allocator, schedule_len) catch oom();
    defer stack.deinit();

    for (0..spreadsheet.driver_formulas.len) |driver_index| {
        if (!scheduled.isSet(driver_index)) {
            scheduled.set(driver_index);
            var next: StackItem = .{ .driver_index = @intCast(driver_index), .formula_index = 0 };
            next: while (true) {
                const formula = spreadsheet.driver_formulas[next.driver_index];
                for (formula[next.formula_index..], next.formula_index..) |expr, formula_index_new| {
                    switch (expr) {
                        .constant, .add => {},
                        .cell => |cell| {
                            if (!scheduled.isSet(cell.driver_index)) {
                                stack.appendAssumeCapacity(.{ .driver_index = next.driver_index, .formula_index = formula_index_new + 1 });
                                scheduled.set(cell.driver_index);
                                next = .{ .driver_index = cell.driver_index, .formula_index = 0 };
                                continue :next;
                            }
                        },
                    }
                }
                schedule.appendAssumeCapacity(next.driver_index);
                next = stack.pop() orelse break :next;
            }
        }
    }

    assert(schedule.items.len == schedule_len);
    return schedule.toOwnedSlice() catch oom();
}

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
