const std = @import("std");
const sql = @import("../lib/sql.zig");
const u = sql.util;

const allocator = std.heap.c_allocator;

pub fn ReturnError(f: anytype) type {
    const Return = @typeInfo(@TypeOf(f)).Fn.return_type.?;
    return @typeInfo(Return).ErrorUnion.error_set;
}

const SqlError = ReturnError(runStatement) || ReturnError(sql.Database.runQuery);

pub fn main() !void {
    var args = std.process.args();
    _ = args.next(); // discard executable name

    var passes: usize = 0;
    var errors = u.DeepHashMap(SqlError, usize).init(allocator);
    defer errors.deinit();

    file: while (args.next()) |slt_path| {
        std.debug.print("Running {}\n", .{std.zig.fmtEscapes(slt_path)});

        var database = sql.Database.init(allocator);
        defer database.deinit();

        var bytes = u.ArrayList(u8).init(allocator);
        defer bytes.deinit();

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
                    if (!std.mem.eql(u8, words.next().?, "sqlite"))
                        break :header;
                } else if (std.mem.eql(u8, kind, "onlyif")) {
                    if (std.mem.eql(u8, words.next().?, "sqlite"))
                        break :header;
                } else if (std.mem.eql(u8, kind, "statement")) {
                    const expected_bytes = words.next() orelse return error.UnexpectedInput;
                    const expected = if (std.mem.eql(u8, expected_bytes, "ok"))
                        StatementExpected.Ok
                    else if (std.mem.eql(u8, expected_bytes, "error"))
                        StatementExpected.Error
                    else
                        return error.UnexpectedInput;
                    const statement = std.mem.trim(u8, case[lines.index.?..], "\n");
                    if (runStatement(&database, statement, expected)) |_|
                        passes += 1
                    else |err|
                        try incCount(&errors, err);
                    break :header;
                } else if (std.mem.eql(u8, kind, "query")) {
                    break :header;
                } else return error.UnexpectedInput;
            }
        }
    }

    u.dump(errors);
    std.debug.print("passes => {}", .{passes});
}

fn incCount(hash_map: anytype, key: anytype) !void {
    const entry = try hash_map.getOrPut(key);
    if (!entry.found_existing)
        entry.value_ptr.* = 0;
    entry.value_ptr.* += 1;
}

const StatementExpected = enum {
    Ok,
    Error,
};

fn runStatement(database: *sql.Database, statement: []const u8, expected: StatementExpected) !void {
    if (database.runStatement(statement)) |_| {
        switch (expected) {
            .Ok => return,
            .Error => return error.StatementShouldError,
        }
    } else |err| {
        switch (expected) {
            .Ok => return err,
            .Error => return,
        }
    }
}
