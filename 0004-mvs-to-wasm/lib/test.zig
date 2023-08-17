const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const panic = std.debug.panic;
const assert = std.debug.assert;

const Tokenizer = @import("./Tokenizer.zig");
const Parser = @import("./Parser.zig");
const Semantalyzer = @import("./Semantalyzer.zig");
const Compiler = @import("./Compiler.zig");

const Baton = struct {
    tokenizer: ?Tokenizer = null,
    parser: ?Parser = null,
    semantalyzer: ?Semantalyzer = null,
    compiler: ?Compiler = null,
};

fn eval_wasm(
    allocator: Allocator,
    wasm: []const u8,
) []const u8 {
    const file = std.fs.cwd().createFile("test-without-runtime.wasm", .{ .truncate = true }) catch |err|
        panic("Error opening test-without-runtime.wasm: {}", .{err});
    defer file.close();

    file.writeAll(wasm) catch |err|
        panic("Error writing test-without-runtime.wasm: {}", .{err});

    if (std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{
            "./deps/binaryen/bin/wasm-merge", "runtime_wasm.wasm", "runtime", "test-without-runtime.wasm", "test", "-o", "test.wasm",
        },
        .max_output_bytes = std.math.maxInt(usize),
    })) |result| {
        assert(std.meta.eql(result.term, .{ .Exited = 0 }));
    } else |err| {
        panic("Error running wasm-merge: {}", .{err});
    }

    if (std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{ "deno", "run", "--allow-read", "test.js" },
        .max_output_bytes = std.math.maxInt(usize),
    })) |result| {
        assert(std.meta.eql(result.term, .{ .Exited = 0 }));
        return result.stdout;
    } else |err| {
        panic("Error running test.js: {}", .{err});
    }
}

fn eval(
    allocator: Allocator,
    source: []const u8,
    baton: *Baton,
) ![]const u8 {
    baton.tokenizer = Tokenizer.init(allocator, source);
    try baton.tokenizer.?.tokenize();
    baton.parser = Parser.init(allocator, baton.tokenizer.?);
    try baton.parser.?.parse();
    baton.compiler = Compiler.init(allocator, baton.parser.?);
    const wasm = try baton.compiler.?.compile();
    const value_compiled = eval_wasm(allocator, wasm);
    // TODO Assert error messages are the same.
    //baton.semantalyzer = Semantalyzer.init(allocator, baton.parser.?);
    //const value_interpreted = try baton.semantalyzer.?.semantalyze();
    //try std.testing.expectEqualStrings(
    //    std.fmt.allocPrint(allocator, "{}", .{value_interpreted}) catch panic("OOM", .{}),
    //    std.mem.trim(u8, value_compiled, "\n"),
    //);
    return value_compiled;
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
        //if (@errorReturnTrace()) |trace|
        //    std.debug.dumpStackTrace(trace.*);
        return switch (err) {
            error.TokenizeError => baton.tokenizer.?.error_message.?,
            error.ParseError => baton.parser.?.error_message.?,
            //error.SemantalyzeError => baton.semantalyzer.?.error_message.?,
            error.CompileError => baton.compiler.?.error_message.?,
            //error.TestExpectedEqual => "Semantalyzer and Compiler produced different results",
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
            if (!std.mem.eql(
                u8,
                expected,
                std.mem.trim(u8, actual, "\n"),
            )) {
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
