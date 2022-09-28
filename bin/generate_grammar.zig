const std = @import("std");
const sql = @import("../lib/sql.zig");
const u = sql.util;

pub fn main() !void {
    var arena = u.ArenaAllocator.init(std.heap.page_allocator);

    var parser = sql.GrammarParser.init(&arena);
    try parser.parseRules();
    u.dump(parser.rules.items);

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
    } else {
        // Source is invalid, but write it anyway for debugging
        try file.writeAll(bytes.items);
        u.dump(tree.errors);
        return error.ZigParseError;
    }
}
