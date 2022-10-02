const std = @import("std");
const sql = @import("../lib/sql.zig");
const u = sql.util;

const global_allocator = std.heap.c_allocator;

pub fn ReturnError(comptime f: anytype) type {
    const Return = @typeInfo(@TypeOf(f)).Fn.return_type.?;
    return @typeInfo(Return).ErrorUnion.error_set;
}

const TestError = ReturnError(runStatement) || ReturnError(runQuery);

pub fn main() !void {
    //defer _ = gpa.detectLeaks();
    try real_main();
}

pub fn real_main() !void {
    var args = std.process.args();
    _ = args.next(); // discard executable name

    var total: usize = 0;
    var passes: usize = 0;
    var skips: usize = 0;
    var errors = u.DeepHashMap(TestError, usize).init(global_allocator);
    defer errors.deinit();

    file: while (args.next()) |slt_path| {
        std.debug.print("Running {}\n", .{std.zig.fmtEscapes(slt_path)});
        var skip = false;

        var gpa = std.heap.GeneralPurposeAllocator(.{
            .safety = false,
        }){
            .backing_allocator = global_allocator,
        };
        defer _ = gpa.deinit();

        var database = try sql.Database.init(gpa.allocator());

        var bytes = u.ArrayList(u8).init(gpa.allocator());

        {
            const file = try std.fs.cwd().openFile(slt_path, .{});
            defer file.close();

            try file.reader().readAllArrayList(&bytes, std.math.maxInt(usize));
        }

        var cases = std.mem.split(u8, bytes.items, "\n\n");
        while (cases.next()) |case_untrimmed| {
            const case = std.mem.trim(u8, case_untrimmed, " \n");
            if (case.len == 0) continue;

            errdefer std.debug.print("Case:\n{}\n\n", .{std.zig.fmtEscapes(case)});
            var lines = std.mem.split(u8, case, "\n");

            // might have to loop a few times to get to the actual header
            header: while (lines.next()) |header| {
                errdefer std.debug.print("Header:\n{}\n\n", .{std.zig.fmtEscapes(header)});

                if (std.mem.startsWith(u8, header, "#")) continue :header;
                var words = std.mem.split(u8, header, " ");
                const kind = words.next() orelse return error.UnexpectedInput;
                if (std.mem.eql(u8, kind, "hash-threshold")) {
                    // TODO
                    break :header;
                } else if (std.mem.eql(u8, kind, "halt")) {
                    continue :file;
                } else if (std.mem.eql(u8, kind, "skipif")) {
                    const db = words.next().?;
                    if (std.mem.eql(u8, db, "sqlite"))
                        break :header;
                } else if (std.mem.eql(u8, kind, "onlyif")) {
                    const db = words.next().?;
                    if (!std.mem.eql(u8, db, "sqlite"))
                        break :header;
                } else if (std.mem.eql(u8, kind, "statement")) {
                    // Statements look like:
                    // statement ok/error
                    // ...sql...
                    const expected_bytes = words.next() orelse return error.UnexpectedInput;
                    const expected = if (std.mem.eql(u8, expected_bytes, "ok"))
                        StatementExpected.ok
                    else if (std.mem.eql(u8, expected_bytes, "error"))
                        StatementExpected.err
                    else
                        return error.UnexpectedInput;
                    const statement = std.mem.trim(u8, case[lines.index.?..], "\n");
                    total += 1;
                    if (runStatement(&database, statement, expected)) |_|
                        passes += 1
                    else |err| {
                        if (skip)
                            skips += 1
                        else {
                            u.dump(.{ .err = err, .statement = statement, .file = slt_path });
                            try incCount(&errors, err);
                        }
                        // Once we fail on one statement, the rest of the file is unlikely to pass anyway
                        skip = true;
                    }
                    break :header;
                } else if (std.mem.eql(u8, kind, "query")) {
                    // Queries look like
                    // query types sort_mode? label?
                    // ...sql...
                    // ----
                    // ...expected...
                    const types_bytes = words.next().?;

                    const types = try gpa.allocator().alloc(sql.Type, types_bytes.len);

                    for (types) |*typ, i|
                        typ.* = switch (types_bytes[i]) {
                            'T' => sql.Type.text,
                            'I' => sql.Type.integer,
                            'R' => sql.Type.real,
                            else => return error.UnexpectedInput,
                        };
                    const sort_mode_bytes = words.next() orelse "nosort";
                    const sort_mode = if (std.mem.eql(u8, sort_mode_bytes, "nosort"))
                        SortMode.no_sort
                    else if (std.mem.eql(u8, sort_mode_bytes, "rowsort"))
                        SortMode.row_sort
                    else if (std.mem.eql(u8, sort_mode_bytes, "valuesort"))
                        SortMode.value_sort
                    else
                        return error.UnexpectedInput;
                    const label = words.next();
                    var query_and_expected_iter = std.mem.split(u8, case[lines.index.?..], "----");
                    const query = std.mem.trim(u8, query_and_expected_iter.next().?, "\n");
                    const expected = std.mem.trim(u8, query_and_expected_iter.next() orelse "", "\n");
                    total += 1;
                    if (runQuery(&database, query, types, sort_mode, label, expected)) |_|
                        passes += 1
                    else |err| if (skip)
                        skips += 1
                    else {
                        u.dump(.{ .err = err, .query = query, .file = slt_path });
                        try incCount(&errors, err);
                    }

                    break :header;
                } else return error.UnexpectedInput;
            }
        }
    }

    std.debug.print("total => {}\n", .{total});
    u.dump(errors);
    std.debug.print("skips => {}\n", .{skips});
    std.debug.print("passes => {} (= {d:.2}%)\n", .{ passes, 100 * @intToFloat(f64, total) / @intToFloat(f64, passes) });
    //try sql.dumpRuleUsage();
}

fn incCount(hash_map: anytype, key: anytype) !void {
    const entry = try hash_map.getOrPut(key);
    if (!entry.found_existing)
        entry.value_ptr.* = 0;
    entry.value_ptr.* += 1;
}

const StatementExpected = enum {
    ok,
    err,
};

const SortMode = enum {
    no_sort,
    row_sort,
    value_sort,
};

fn runStatement(database: *sql.Database, statement: []const u8, expected: StatementExpected) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = false,
        .enable_memory_limit = true,
    }){
        .requested_memory_limit = 1024 * 1024 * 1024 * 1,
        .backing_allocator = global_allocator,
    };
    defer _ = gpa.deinit();
    if (database.run(gpa.allocator(), statement)) |_| {
        switch (expected) {
            .ok => return,
            .err => return error.StatementShouldError,
        }
    } else |err| {
        switch (expected) {
            .ok => return err,
            .err => switch (err) {
                error.AbortPlan, error.AbortEval => return,
                else => return err,
            },
        }
    }
}

fn runQuery(database: *sql.Database, query: []const u8, types: []const sql.Type, sort_mode: SortMode, label: ?[]const u8, expected_output: []const u8) !void {
    _ = label; // TODO handle labels
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .safety = false,
        .enable_memory_limit = true,
    }){
        .requested_memory_limit = 1024 * 1024 * 1024 * 1,
        .backing_allocator = global_allocator,
    };
    defer _ = gpa.deinit();

    const rows = try database.run(gpa.allocator(), query);

    for (rows.items) |row|
        if (row.items.len != types.len)
            return error.WrongNumberOfColumnsReturned;

    const should_hash = std.mem.containsAtLeast(u8, expected_output, 1, "values hashing to");
    const actual_output = try produceQueryOutput(gpa.allocator(), rows, types, sort_mode, should_hash);
    return std.testing.expectEqualStrings(expected_output, actual_output);
}

fn produceQueryOutput(allocator: u.Allocator, rows: sql.Evaluator.Relation, types: []const sql.Type, sort_mode: SortMode, should_hash: bool) ![]const u8 {
    var actual_outputs = u.ArrayList([]const u8).init(allocator);
    for (rows.items) |row| {
        switch (sort_mode) {
            .no_sort, .value_sort => {
                for (types) |typ, i|
                    try actual_outputs.append(try formatValue(allocator, typ, row.items[i]));
            },
            .row_sort => {
                var row_output = u.ArrayList([]const u8).init(allocator);
                for (types) |typ, i|
                    try row_output.append(try formatValue(allocator, typ, row.items[i]));
                try actual_outputs.append(try std.mem.join(allocator, "\n", row_output.items));
            },
        }
    }

    switch (sort_mode) {
        .no_sort => {},
        .value_sort, .row_sort => std.sort.sort(
            []const u8,
            actual_outputs.items,
            {},
            (struct {
                fn lessThan(_: void, a: []const u8, b: []const u8) bool {
                    return std.mem.order(u8, a, b) == .lt;
                }
            }).lessThan,
        ),
    }

    const actual_output = try std.mem.join(allocator, "\n", actual_outputs.items);

    if (should_hash) {
        var hasher = std.crypto.hash.Md5.init(.{});
        hasher.update(actual_output);
        hasher.update("\n");
        var hash: [std.crypto.hash.Md5.digest_length]u8 = undefined;
        hasher.final(&hash);
        return std.fmt.allocPrint(allocator, "{} values hashing to {s}", .{ rows.items.len * types.len, std.fmt.fmtSliceHexLower(&hash) });
    } else {
        return actual_output;
    }
}

fn formatValue(allocator: u.Allocator, typ: sql.Type, value: sql.Value) ![]const u8 {
    return switch (value) {
        .nul => "NULL",
        .integer => |integer| switch (typ) {
            .integer, .text => std.fmt.allocPrint(allocator, "{}", .{integer}),
            .real => std.fmt.allocPrint(allocator, "{d:.3}", .{@intToFloat(f64, integer)}),
            .nul, .blob => unreachable, // tests only contain I T R
        },
        .real => |real| switch (typ) {
            .integer => error.UnexpectedFormatComboRealinteger,
            .text => error.UnexpectedFormatComboRealText,
            .real => std.fmt.allocPrint(allocator, "{d:.3}", .{real}),
            .nul, .blob => unreachable, // tests only contain I T R
        },
        .text => |text| switch (typ) {
            .text => text,
            .integer => "0", // sqlite, why?
            .real => error.UnexpectedFormatComboTextReal,
            .nul, .blob => unreachable, // tests only contain I T R
        },
        .blob => return error.UnexpectedFormatComboBlob,
    };
}

fn testProduceQueryOutput(rows: []const []const sql.Value, types: []const sql.Type, sort_mode: SortMode, should_hash: bool, expected: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){
        .safety = false,
        .backing_allocator = global_allocator,
    };
    defer _ = gpa.deinit();
    const actual = try produceQueryOutput(gpa.allocator(), rows, types, sort_mode, should_hash);
    return std.testing.expectEqualStrings(expected, actual);
}

test {
    try testProduceQueryOutput(
        &.{
            &.{
                .{ .integer = 222 },
                .{ .integer = 117 },
                .{ .integer = -3 },
                .{ .integer = 1180 },
                .{ .integer = 117 },
                .{ .integer = 1 },
            },
            &.{
                .{ .integer = 222 },
                .{ .integer = 120 },
                .{ .integer = -3 },
                .{ .integer = 1240 },
                .{ .integer = 122 },
                .{ .integer = 1 },
            },
            &.{
                .{ .integer = 444 },
                .{ .integer = 103 },
                .{ .integer = 4 },
                .{ .integer = 1000 },
                .{ .integer = 102 },
                .{ .integer = 2 },
            },
        },
        &.{
            sql.Type.integer,
            sql.Type.integer,
            sql.Type.integer,
            sql.Type.integer,
            sql.Type.integer,
            sql.Type.integer,
        },
        SortMode.no_sort,
        true,
        "18 values hashing to 195ca5c056027e19b7098549fb30a259",
    );

    try testProduceQueryOutput(
        &.{
            &.{.{ .integer = 9 }},
            &.{.{ .integer = 31 }},
            &.{.{ .integer = 116 }},
            &.{.{ .integer = 240 }},
            &.{.{ .integer = 300 }},
            &.{.{ .integer = 386 }},
            &.{.{ .integer = 799 }},
            &.{.{ .integer = 863 }},
            &.{.{ .integer = 973 }},
        },
        &.{
            sql.Type.integer,
        },
        SortMode.value_sort,
        true,
        "9 values hashing to 0242ff524f6efe4a8115ad23f4d8659a",
    );
}
