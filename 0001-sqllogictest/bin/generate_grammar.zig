const std = @import("std");
const GrammarParser = @import("../lib/sql/GrammarParser.zig");
const u = @import("../lib/sql/util.zig");

pub fn main() !void {
    var arena = u.ArenaAllocator.init(std.heap.page_allocator);

    var parser = GrammarParser.init(&arena);
    try parser.parseRules();

    var bytes = u.ArrayList(u8).init(arena.allocator());
    try parser.write(bytes.writer());

    // Try to format
    const bytes_z = try arena.allocator().dupeZ(u8, bytes.items);
    var tree = try std.zig.parse(arena.allocator(), bytes_z);
    const file = try std.fs.cwd().openFile("./lib/sql/grammar.zig", .{ .mode = .write_only });
    try file.setEndPos(0);
    if (tree.errors.len == 0) {
        // Write the formatted version
        const formatted = try tree.render(arena.allocator());
        try file.writeAll(formatted);
        std.debug.print("Generated!\n", .{});
    } else {
        // Source is invalid, but write it anyway for debugging
        try file.writeAll(bytes.items);
        u.dump(tree.errors);
        return error.ZigParseError;
    }
}
