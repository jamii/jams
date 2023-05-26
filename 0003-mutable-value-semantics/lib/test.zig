const std = @import("std");
const Allocator = std.mem.Allocator;
const panic = std.debug.panic;

const Tokenizer = @import("./Tokenizer.zig");
const Parser = @import("./Parser.zig");

const Baton = struct {
    tokenizer: ?Tokenizer = null,
    parser: ?Parser = null,
};

fn run(
    allocator: Allocator,
    source: []const u8,
    baton: *Baton,
) !void {
    baton.tokenizer = Tokenizer.init(allocator, source);
    try baton.tokenizer.?.tokenize();
    baton.parser = Parser.init(allocator, baton.tokenizer.?);
    try baton.parser.?.parse();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const cwd = std.fs.cwd();
    const args = try std.process.argsAlloc(allocator);
    for (args[1..]) |path| {
        std.debug.print("Opening {s}\n", .{path});

        const file = try cwd.openFile(path, .{});
        defer file.close();

        const source = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        var baton = Baton{};
        run(allocator, source, &baton) catch |err| {
            if (baton.tokenizer) |tokenizer|
                std.debug.print("{any}", .{tokenizer.tokens.items});
            if (baton.parser) |parser|
                std.debug.print("{any}", .{parser.nodes.items});
            const message = switch (err) {
                error.TokenizeError => baton.tokenizer.?.error_message.?,
                error.ParseError => baton.parser.?.error_message.?,
            };
            panic("{s}", .{message});
        };
    }
}
