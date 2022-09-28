const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;

const Self = @This();
const source = @embedFile("./grammar.txt");
arena: *u.ArenaAllocator,
allocator: u.Allocator,
rules: u.ArrayList(NamedRule),
pos: usize,

const Error = error{OutOfMemory};

pub const NamedRule = struct {
    name: []const u8,
    rule: sql.grammar_support.Rule,
};

pub fn init(arena: *u.ArenaAllocator) Self {
    return Self{
        .arena = arena,
        .allocator = arena.allocator(),
        .rules = u.ArrayList(NamedRule).init(arena.allocator()),
        .pos = 0,
    };
}

pub fn parseRules(self: *Self) Error!void {
    while (true) {
        self.discardWhitespace();
        if (source[self.pos] == 0) break;
        _ = try self.parseNamedRule();
    }
}

fn parseNamedRule(self: *Self) Error!void {
    const name = self.parseName();
    self.discardWhitespace();
    self.consume("=");
    self.discardWhitespace();
    const rule = switch (source[self.pos]) {
        '|' => try self.parseOneOf(),
        else => try self.parseAllOf(),
    };
    self.consume(";");
    try self.rules.append(.{ .name = name, .rule = rule });
}

fn parseOneOf(self: *Self) Error!sql.grammar_support.Rule {
    var one_ofs = u.ArrayList(sql.grammar_support.OneOf).init(self.allocator);
    while (true) {
        if (!self.tryConsume("|")) break;
        self.discardWhitespace();
        const rule_ref_0 = try self.parseRuleRef();
        self.discardWhitespace();
        if (self.tryConsume("=>")) {
            self.discardWhitespace();
            const rule_ref_1 = try self.parseRuleRef();
            try one_ofs.append(.{ .committed_choice = .{ rule_ref_0, rule_ref_1 } });
        } else {
            try one_ofs.append(.{ .choice = rule_ref_0 });
        }
        self.discardWhitespace();
    }
    self.assert(one_ofs.items.len > 0);
    return sql.grammar_support.Rule{ .one_of = one_ofs.toOwnedSlice() };
}

fn parseAllOf(self: *Self) Error!sql.grammar_support.Rule {
    var all_ofs = u.ArrayList(sql.grammar_support.RuleRef).init(self.allocator);
    while (true) {
        self.discardWhitespace();
        var rule_ref = (try self.tryParseRuleRef()) orelse break;
        try self.tryParseModifier(&rule_ref);
        try all_ofs.append(rule_ref);
    }
    self.assert(all_ofs.items.len > 0);
    return sql.grammar_support.Rule{ .all_of = all_ofs.toOwnedSlice() };
}

fn tryParseModifier(self: *Self, rule_ref: *sql.grammar_support.RuleRef) Error!void {
    switch (source[self.pos]) {
        '*' => {
            self.consume("*");
            try self.parseRepeat(0, rule_ref);
        },
        '+' => {
            self.consume("+");
            try self.parseRepeat(1, rule_ref);
        },
        '?' => {
            self.consume("?");
            const optional = sql.grammar_support.Rule{ .optional = rule_ref.* };
            rule_ref.rule_name = try self.makeAnonRule(optional);
        },
        '=' => {
            self.consume("=");
            const name = self.parseName();
            rule_ref.field_name = name;
        },
        else => {},
    }
}

fn parseRepeat(self: *Self, min_count: usize, rule_ref: *sql.grammar_support.RuleRef) Error!void {
    const separator = if (self.tryParseName()) |name|
        sql.grammar_support.RuleRef{
            .field_name = null,
            .rule_name = name,
        }
    else
        null;
    const repeat = sql.grammar_support.Rule{ .repeat = .{
        .min_count = min_count,
        .element = rule_ref.*,
        .separator = separator,
    } };
    rule_ref.rule_name = try self.makeAnonRule(repeat);
}

fn makeAnonRule(self: *Self, rule: sql.grammar_support.Rule) Error![]const u8 {
    const name = try self.makeAnonRuleName();
    try self.rules.append(.{ .name = name, .rule = rule });
    return name;
}

fn makeAnonRuleName(self: *Self) Error![]const u8 {
    return std.fmt.allocPrint(self.allocator, "anon_{}", .{self.rules.items.len});
}

fn parseRuleRef(self: *Self) Error!sql.grammar_support.RuleRef {
    const rule_ref = try self.tryParseRuleRef();
    self.assert(rule_ref != null);
    return rule_ref.?;
}

fn tryParseRuleRef(self: *Self) Error!?sql.grammar_support.RuleRef {
    if (source[self.pos] == '(') {
        self.consume("(");
        const all_of = try self.parseAllOf();
        self.consume(")");
        const name = try self.makeAnonRule(all_of);
        return sql.grammar_support.RuleRef{
            .field_name = null,
            .rule_name = name,
        };
    } else {
        const name = self.tryParseName() orelse return null;
        return sql.grammar_support.RuleRef{
            .field_name = name,
            .rule_name = name,
        };
    }
}

fn parseName(self: *Self) []const u8 {
    const name = self.tryParseName();
    self.assert(name != null);
    return name.?;
}

fn tryParseName(self: *Self) ?[]const u8 {
    const start_pos = self.pos;
    while (true) {
        switch (source[self.pos]) {
            'a'...'z', 'A'...'Z', '_' => self.pos += 1,
            else => break,
        }
    }
    return if (self.pos == start_pos)
        null
    else
        source[start_pos..self.pos];
}

pub fn assert(self: *Self, cond: bool) void {
    u.assert(cond, .{source[self.pos..]});
}

pub fn consume(self: *Self, needle: []const u8) void {
    self.assert(self.tryConsume(needle));
}

pub fn tryConsume(self: *Self, needle: []const u8) bool {
    if (std.mem.startsWith(u8, source[self.pos..], needle)) {
        self.pos += needle.len;
        return true;
    } else {
        return false;
    }
}

pub fn discardWhitespace(self: *Self) void {
    while (true) {
        switch (source[self.pos]) {
            ' ', '\n' => self.pos += 1,
            else => break,
        }
    }
}

pub fn writeRules(self: *Self, writer: anytype) anyerror!void {
    _ = self;
    _ = writer;
}
