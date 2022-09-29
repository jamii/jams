const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;
const rules = sql.grammar.rules;
const types = sql.grammar.types;
const Node = sql.grammar.Node;

const Self = @This();
arena: *u.ArenaAllocator,
allocator: u.Allocator,
// Last token is .eof. We don't use a sentinel type because I could lazy when trying to figure out the correct casts.
tokens: []const sql.Tokenizer.TokenAndRange,
debug: bool,
pos: usize,
nodes: u.ArrayList(Node),
// debug only
rule_name_stack: u.ArrayList([]const u8),
failures: u.ArrayList(Failure),

pub const Failure = struct {
    rule_names: []const []const u8,
    pos: usize,
    remaining_tokens: []const sql.Tokenizer.TokenAndRange,
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
    tokens: []const sql.Tokenizer.TokenAndRange,
    debug: bool,
) Self {
    //u.dump(tokens);
    return Self{
        .arena = arena,
        .allocator = arena.allocator(),
        .tokens = tokens,
        .debug = debug,
        .pos = 0,
        .nodes = u.ArrayList(Node).init(arena.allocator()),
        .rule_name_stack = u.ArrayList([]const u8).init(arena.allocator()),
        .failures = u.ArrayList(Failure).init(arena.allocator()),
    };
}

// TODO memoize for left-recursion where needed

pub fn push(self: *Self, comptime rule_name: []const u8, node: @field(types, rule_name)) !NodeId(rule_name) {
    const id = self.nodes.items.len;
    try self.nodes.append(@unionInit(Node, rule_name, node));
    return .{ .id = id };
}

pub fn get(self: *Self, node_id: anytype) @TypeOf(node_id).T {
    return @field(self.nodes.items[node_id.id], @TypeOf(node_id).rule_name);
}

pub fn parse(self: *Self, comptime rule_name: []const u8) Error!?NodeId(rule_name) {
    if (try self.parseNode(rule_name)) |node|
        return try self.push(rule_name, node)
    else
        return null;
}

pub fn parseNode(self: *Self, comptime rule_name: []const u8) Error!?@field(types, rule_name) {
    if (self.debug) try self.rule_name_stack.append(rule_name);
    defer if (self.debug) {
        _ = self.rule_name_stack.pop();
    };
    const ResultType = @field(types, rule_name);
    if (self.debug)
        u.dump(.{ rule_name, self.pos, self.tokens[self.pos].token });
    switch (@field(rules, rule_name)) {
        .token => |token| {
            const self_token = self.tokens[self.pos];
            if (self_token.token == token) {
                self.pos += 1;
                return self_token.range;
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
                            return initChoice(ResultType, rule_ref, result);
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
                                return initChoice(ResultType, rule_refs[1], result);
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
                    if (all_of.field_name) |field_name| {
                        @field(result, field_name) = field_result;
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
            .rule_names = try self.allocator.dupe([]const u8, self.rule_name_stack.items),
            .pos = self.pos,
            .remaining_tokens = self.tokens[self.pos..],
        });
    return null;
}

fn initChoice(comptime ChoiceType: type, comptime rule_ref: sql.grammar.RuleRef, result: anytype) ChoiceType {
    return switch (@typeInfo(ChoiceType)) {
        .Union => @unionInit(ChoiceType, rule_ref.field_name.?, result),
        .Enum => @field(ChoiceType, rule_ref.rule_name),
        else => unreachable,
    };
}
