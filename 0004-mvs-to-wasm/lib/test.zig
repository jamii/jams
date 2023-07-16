const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const panic = std.debug.panic;
const assert = std.debug.assert;

const Tokenizer = @import("./Tokenizer.zig");
const Parser = @import("./Parser.zig");
const Semantalyzer = @import("./Semantalyzer.zig");

const Baton = struct {
    tokenizer: ?Tokenizer = null,
    parser: ?Parser = null,
    semantalyzer: ?Semantalyzer = null,
};

fn eval(
    allocator: Allocator,
    source: []const u8,
    baton: *Baton,
) ![]const u8 {
    baton.tokenizer = Tokenizer.init(allocator, source);
    try baton.tokenizer.?.tokenize();
    baton.parser = Parser.init(allocator, baton.tokenizer.?);
    try baton.parser.?.parse();
    baton.semantalyzer = Semantalyzer.init(allocator, baton.parser.?);
    const value = try baton.semantalyzer.?.semantalyze();
    return std.fmt.allocPrint(allocator, "{}", .{value});
}

fn run(
    allocator: Allocator,
    source: []const u8,
) []const u8 {
    var baton = Baton{};
    if (eval(allocator, source, &baton)) |result| {
        return result;
    } else |err| {
        //if (baton.tokenizer) |tokenizer|
        //    std.debug.print("{any}\n\n", .{tokenizer.tokens.items});
        //if (baton.parser) |parser|
        //    std.debug.print("{any}\n\n", .{parser.exprs.items});
        if (@errorReturnTrace()) |trace|
            std.debug.dumpStackTrace(trace.*);
        return switch (err) {
            error.TokenizeError => baton.tokenizer.?.error_message.?,
            error.ParseError => baton.parser.?.error_message.?,
            error.SemantalyzeError => baton.semantalyzer.?.error_message.?,
            error.OutOfMemory => panic("OOM", .{}),
        };
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const cwd = std.fs.cwd();
    var args = try std.process.argsAlloc(allocator);
    args = args[1..];

    var rewrite = false;
    var failures: usize = 0;

    if (std.mem.eql(u8, args[0], "--rewrite")) {
        rewrite = true;
        args = args[1..];
    }

    for (args) |path| {
        std.debug.print("Opening {s}\n", .{path});

        const file = try cwd.openFile(path, .{ .mode = .read_write });
        defer file.close();

        var rewritten = ArrayList(u8).init(allocator);
        const writer = rewritten.writer();

        const text = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

        var cases = std.mem.split(u8, std.mem.trim(u8, text, "\n"), "\n\n");
        while (cases.next()) |case| {
            var parts = std.mem.split(u8, case, "---");
            const source = std.mem.trim(u8, parts.next().?, "\n");
            const expected = std.mem.trim(u8, parts.next().?, "\n");
            assert(parts.next() == null);
            const actual = run(allocator, source);
            if (!std.mem.eql(u8, expected, actual)) {
                std.debug.print(
                    \\{s}
                    \\---
                    \\{s}
                    \\---
                    \\{s}
                    \\
                    \\
                , .{ source, expected, actual });
                failures += 1;
            }
            try writer.print(
                \\{s}
                \\---
                \\{s}
                \\
                \\
            , .{ source, actual });
        }

        if (rewrite) {
            try file.seekTo(0);
            try file.setEndPos(0);
            try file.writer().writeAll(rewritten.items);
        }
    }

    if (failures == 0) {
        std.debug.print("Ok!", .{});
    } else {
        std.debug.print("Failures: {}!", .{failures});
        std.os.exit(1);
    }
}
