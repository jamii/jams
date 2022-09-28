const std = @import("std");
const sql = @import("../lib/sql.zig");
const u = sql.util;

pub fn main() !void {
    var arena = u.ArenaAllocator.init(std.heap.page_allocator);
    var parser = sql.GrammarParser.init(&arena);
    try parser.parseRules();
    u.dump(parser.rules.items);
}
