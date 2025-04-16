const std = @import("std");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const DynamicBitSet = std.DynamicBitSet;
const allocator = std.heap.c_allocator;

pub fn oom() noreturn {
    std.debug.panic("OOM", .{});
}

pub const Spreadsheet = struct {
    // Assume that every driver has the same number of cells.
    driver_cell_count: u32,
    driver_formula_ranges: []const u32,
    driver_formula_exprs: []const DriverFormulaExpr,
    cell_index_formula_exprs: []const CellIndexFormulaExpr,
    // TODO Add source data.
};

pub const DriverIndex = u32;
pub const CellIndex = u32;

pub const DriverFormula = []const DriverFormulaExpr;
pub const DriverFormulaExpr = union(enum) {
    constant: f64,
    cell: struct {
        driver_index: DriverIndex,
        cell_index_formula_range: u32,
    },
    add, // Pop two results off stack.
    end,
    // TODO Add aggregates over drivers.
    // TODO Add aggregates and filters over source data.

    //pub fn format(self: DriverFormulaExpr, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    //    _ = fmt;
    //    _ = options;
    //    switch (self) {
    //        .constant => |constant| try writer.print("{}", .{constant}),
    //        .cell => |cell| try writer.print("driver{}{any}", .{ cell.driver_index, cell.cell_index_formula }),
    //        .add => try writer.print("+", .{}),
    //    }
    //}
};

pub const CellIndexFormula = []const CellIndexFormulaExpr;
pub const CellIndexFormulaExpr = union(enum) {
    this,
    constant: i32,
    add, // Pop two results off stack.
    end,

    pub fn format(self: CellIndexFormulaExpr, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .this => try writer.print("this", .{}),
            .constant => |constant| try writer.print("{}", .{constant}),
            .add => try writer.print("+", .{}),
        }
    }
};

const Order = enum {
    linear,
    shuffled,
};

fn generate_spreadsheet(random: std.Random, order: Order) Spreadsheet {
    const driver_count: u32 = 1000000;
    const driver_cell_count: u32 = 20;

    const schedule = allocator.alloc(DriverIndex, driver_count) catch oom();
    defer allocator.free(schedule);

    for (schedule, 0..) |*p, i| p.* = @intCast(i);
    if (order == .shuffled) {
        // We want to generate an acylic spreadsheet, but still require non-trivial scheduling.
        // So generate a random schedule and only allow drivers to refer to other drivers eariler in the schedule.
        random.shuffle(DriverIndex, schedule);
    }

    const driver_formula_ranges = allocator.alloc(u32, driver_count) catch oom();
    // Always returned.

    var driver_formula_exprs = ArrayList(DriverFormulaExpr).init(allocator);
    defer driver_formula_exprs.deinit();

    var cell_index_formula_exprs = ArrayList(CellIndexFormulaExpr).init(allocator);
    defer cell_index_formula_exprs.deinit();

    for (schedule, 0..) |driver_index, schedule_index| {
        driver_formula_ranges[driver_index] = @intCast(driver_formula_exprs.items.len);
        generate_driver_formula(random, schedule[0..schedule_index], &driver_formula_exprs, &cell_index_formula_exprs);
    }

    return .{
        .driver_cell_count = driver_cell_count,
        .driver_formula_ranges = driver_formula_ranges,
        .driver_formula_exprs = driver_formula_exprs.toOwnedSlice() catch oom(),
        .cell_index_formula_exprs = cell_index_formula_exprs.toOwnedSlice() catch oom(),
    };
}

fn generate_driver_formula(
    random: std.Random,
    schedule: []const DriverIndex,
    driver_formula_exprs: *ArrayList(DriverFormulaExpr),
    cell_index_formula_exprs: *ArrayList(CellIndexFormulaExpr),
) void {
    const start = driver_formula_exprs.items.len;
    var remaining: usize = 1;
    while (remaining > 0) {
        switch (random.enumValue(std.meta.Tag(DriverFormulaExpr))) {
            .constant => {
                driver_formula_exprs.append(.{ .constant = random.float(f64) }) catch oom();
                remaining -= 1;
            },
            .cell => {
                if (schedule.len == 0) {
                    driver_formula_exprs.append(.{ .constant = random.float(f64) }) catch oom();
                    remaining -= 1;
                } else {
                    const driver_index = schedule[random.uintLessThan(usize, schedule.len)];
                    driver_formula_exprs.append(.{ .cell = .{
                        .driver_index = driver_index,
                        .cell_index_formula_range = @intCast(cell_index_formula_exprs.items.len),
                    } }) catch oom();
                    remaining -= 1;
                    generate_cell_index_formula(random, cell_index_formula_exprs);
                }
            },
            .add => {
                driver_formula_exprs.append(.add) catch oom();
                remaining += 1;
            },
            .end => {},
        }
    }
    std.mem.reverse(DriverFormulaExpr, driver_formula_exprs.items[start..]);
    driver_formula_exprs.append(.end) catch oom();
}

fn generate_cell_index_formula(
    random: std.Random,
    cell_index_formula_exprs: *ArrayList(CellIndexFormulaExpr),
) void {
    const start = cell_index_formula_exprs.items.len;
    var remaining: usize = 1;
    while (remaining > 0) {
        switch (random.enumValue(std.meta.Tag(CellIndexFormulaExpr))) {
            .this => {
                cell_index_formula_exprs.append(.this) catch oom();
                remaining -= 1;
            },
            .constant => {
                cell_index_formula_exprs.append(.{ .constant = random.intRangeLessThan(i32, -3, 3) }) catch oom();
                remaining -= 1;
            },
            .add => {
                cell_index_formula_exprs.append(.add) catch oom();
                remaining += 1;
            },
            .end => {},
        }
    }
    std.mem.reverse(CellIndexFormulaExpr, cell_index_formula_exprs.items[start..]);
    cell_index_formula_exprs.append(.end) catch oom();
}

pub fn main() void {
    for ([2]Order{ .linear, .shuffled }) |order| {
        var rng = std.Random.DefaultPrng.init(42);
        const random = rng.random();

        const spreadsheet = generate_spreadsheet(random, order);
        // Leaked.

        inline for (.{
            @import("./scalar.zig"),
            //@import("./scalar_fused.zig"),
            //@import("./vector.zig"),
        }) |engine| {
            std.debug.print("{} {}\n", .{ order, engine });

            var scratchpad = engine.Scratchpad.init(spreadsheet);
            // Leaked.

            const before_create_schedule = std.time.nanoTimestamp();

            const schedule = engine.create_schedule(spreadsheet, &scratchpad);
            // Leaked.

            std.debug.print("create_schedule: {d:.2} seconds for {} drivers\n", .{
                @as(f64, @floatFromInt(std.time.nanoTimestamp() - before_create_schedule)) / 1e9,
                spreadsheet.driver_formula_ranges.len,
            });

            const before_eval_spreadsheet = std.time.nanoTimestamp();
            engine.eval_spreadsheet(spreadsheet, &scratchpad, schedule);
            std.debug.print("eval_spreadsheet: {d:.2} seconds for {} drivers\n", .{
                @as(f64, @floatFromInt(std.time.nanoTimestamp() - before_eval_spreadsheet)) / 1e9,
                spreadsheet.driver_formula_ranges.len,
            });

            std.debug.print("{} {}\n", .{ scratchpad.cells[0], scratchpad.cells[scratchpad.cells.len - 1] });
            //std.debug.print("{any} {any}\n", .{ schedule[0..10], schedule[schedule.len - 10] });
            //std.debug.print("{any}\n{any}\n", .{ spreadsheet.driver_formulas[0..10], spreadsheet.driver_formulas[spreadsheet.driver_formula_rangs.len - 10] });

            std.debug.print("\n---\n\n", .{});
        }
    }
}
