const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;
const rules = sql.grammar.rules;
const types = sql.grammar.types;
const Node = sql.grammar.Node;

const Self = @This();
arena: *u.ArenaAllocator,
allocator: u.Allocator,
tokenizer: sql.Tokenizer,
debug: bool,
pos: usize,
nodes: u.ArrayList(Node),
node_ranges: u.ArrayList([2]usize),
node_children: u.ArrayList([]const usize),
// debug only
rule_name_stack: u.ArrayList([]const u8),
failures: u.ArrayList(Failure),

pub const Failure = struct {
    rule_name_stack: []const []const u8,
    pos: usize,
    remaining_tokens: []const sql.grammar.Token,
};

pub const Error = error{
    OutOfMemory,
};

pub fn NodeId(comptime rule_name_: []const u8) type {
    return struct {
        pub const rule_name = rule_name_;
        pub const T = @field(types, rule_name);
        id: usize,
        pub fn get(self: @This(), nodes: []const Node) T {
            return @field(nodes[self.id], rule_name);
        }
    };
}

pub fn init(
    arena: *u.ArenaAllocator,
    tokenizer: sql.Tokenizer,
    debug: bool,
) Self {
    const allocator = arena.allocator();
    return Self{
        .arena = arena,
        .allocator = allocator,
        .tokenizer = tokenizer,
        .debug = debug,
        .pos = 0,
        .nodes = u.ArrayList(Node).init(allocator),
        .node_ranges = u.ArrayList([2]usize).init(allocator),
        .node_children = u.ArrayList([]const usize).init(allocator),
        .rule_name_stack = u.ArrayList([]const u8).init(allocator),
        .failures = u.ArrayList(Failure).init(allocator),
    };
}

pub fn get(self: *Self, node_id: anytype) @TypeOf(node_id).T {
    return @field(self.nodes.items[node_id.id], @TypeOf(node_id).rule_name);
}

pub fn parse(self: *Self, comptime rule_name: []const u8) Error!?NodeId(rule_name) {
    if (self.debug) try self.rule_name_stack.append(rule_name);
    defer if (self.debug) {
        _ = self.rule_name_stack.pop();
    };
    if (self.debug)
        u.dump(.{
            //self.rule_name_stack.items,
            rule_name,
            self.pos,
            self.tokenizer.tokens.items[self.pos],
        });

    const start_pos = self.pos;
    var children = u.ArrayList(usize).init(self.allocator);
    if (try self.parseNode(rule_name, &children)) |node| {
        const id = self.nodes.items.len;
        try self.nodes.append(@unionInit(Node, rule_name, node));
        try self.node_ranges.append(.{ start_pos, self.pos });
        try self.node_children.append(children.toOwnedSlice());

        if (self.debug)
            u.dump(.{
                //self.rule_name_stack.items,
                rule_name,
                self.pos,
                self.tokenizer.tokens.items[self.pos],
                .pass,
            });

        return .{ .id = id };
    } else {
        if (self.debug)
            u.dump(.{
                //self.rule_name_stack.items,
                rule_name,
                self.pos,
                self.tokenizer.tokens.items[self.pos],
                .fail,
            });

        return null;
    }
}

pub fn parseNode(self: *Self, comptime rule_name: []const u8, children: *u.ArrayList(usize)) Error!?@field(types, rule_name) {
    const ResultType = @field(types, rule_name);
    switch (@field(rules, rule_name)) {
        .token => |token| {
            const self_token = self.tokenizer.tokens.items[self.pos];
            if (self_token == token) {
                if (token != .eof) self.pos += 1;
                return {};
            } else {
                return self.fail(rule_name);
            }
        },
        .one_of => |one_ofs| {
            const start_pos = self.pos;
            inline for (one_ofs) |one_of| {
                switch (one_of) {
                    .choice => |rule_ref| {
                        if (try self.parse(rule_ref.rule_name)) |result| {
                            try children.append(result.id);
                            return @unionInit(ResultType, rule_ref.field_name, result);
                        } else {
                            // Try next one_of.
                            self.pos = start_pos;
                        }
                    },
                    .committed_choice => |rule_refs| {
                        if (try self.parse(rule_refs[0].rule_name)) |_| {
                            // Reset after lookahead
                            self.pos = start_pos;
                            if (try self.parse(rule_refs[1].rule_name)) |result| {
                                try children.append(result.id);
                                return @unionInit(ResultType, rule_refs[1].field_name, result);
                            } else {
                                // Already committed.
                                return self.fail(rule_name);
                            }
                        } else {
                            // Try next one_of.
                            self.pos = start_pos;
                        }
                    },
                }
            }
            return self.fail(rule_name);
        },
        .all_of => |all_ofs| {
            var result: ResultType = undefined;
            inline for (all_ofs) |all_of| {
                if (try self.parse(all_of.rule_name)) |field_result| {
                    if (@hasField(ResultType, all_of.field_name)) {
                        try children.append(field_result.id);
                        @field(result, all_of.field_name) = field_result;
                    }
                } else {
                    return self.fail(rule_name);
                }
            }
            return result;
        },
        .optional => |optional| {
            const start_pos = self.pos;
            if (try self.parse(optional.rule_name)) |optional_result| {
                try children.append(optional_result.id);
                return optional_result;
            } else {
                self.pos = start_pos;
                // This is a succesful null, not a failure.
                return @as(ResultType, null);
            }
        },
        .repeat => |repeat| {
            var results = u.ArrayList(NodeId(repeat.element.rule_name)).init(self.allocator);
            while (true) {
                const start_pos = self.pos;
                if (repeat.separator) |separator| {
                    if (results.items.len > 0) {
                        if (try self.parse(separator.rule_name) == null) {
                            self.pos = start_pos;
                            break;
                        }
                    }
                }
                if (try self.parse(repeat.element.rule_name)) |result| {
                    try children.append(result.id);
                    try results.append(result);
                } else {
                    self.pos = start_pos;
                    break;
                }
            }
            if (results.items.len >= repeat.min_count)
                return results.toOwnedSlice()
            else
                return self.fail(rule_name);
        },
    }
}

fn fail(self: *Self, comptime rule_name: []const u8) Error!?@field(types, rule_name) {
    if (self.debug)
        try self.failures.append(.{
            .rule_name_stack = try self.allocator.dupe([]const u8, self.rule_name_stack.items),
            .pos = self.pos,
            .remaining_tokens = self.tokenizer.tokens.items[self.pos..],
        });
    return null;
}

pub fn greatestFailure(self: Self) ?Failure {
    var result: ?Failure = null;
    for (self.failures.items) |failure| {
        if (result == null or
            result.?.pos < failure.pos or
            (result.?.pos == failure.pos and
            result.?.rule_name_stack.len <= failure.rule_name_stack.len))
            result = failure;
    }
    return result;
}

pub fn getSourceRange(self: Self, id: usize) [2]usize {
    const token_range = self.node_ranges.items[id];
    return .{
        self.tokenizer.token_ranges.items[token_range[0]][0],
        self.tokenizer.token_ranges.items[token_range[1]][0],
    };
}

pub fn dumpInto(writer: anytype, indent: u32, self: Self) anyerror!void {
    if (self.nodes.items.len == 0)
        try writer.writeAll("<empty>\n")
    else
        try u.dumpInto(writer, indent, DumpNode{ .self = self, .node_id = self.nodes.items.len - 1 });
}

pub const DumpNode = struct {
    self: Self,
    node_id: usize,

    pub fn dumpInto(writer: anytype, indent: u32, self: DumpNode) anyerror!void {
        const node = self.self.nodes.items[self.node_id];
        const source_range = self.self.getSourceRange(self.node_id);
        const source = self.self.tokenizer.source[source_range[0]..source_range[1]];
        try writer.writeByteNTimes(' ', indent);
        try std.fmt.format(writer, "{s} <= \"{}\"\n", .{
            @tagName(node),
            std.zig.fmtEscapes(source),
        });
        for (self.self.node_children.items[self.node_id]) |child_id|
            try u.dumpInto(writer, indent + 2, DumpNode{ .self = self.self, .node_id = child_id });
    }
};
