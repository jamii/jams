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

pub fn write(self: *Self, writer: anytype) anyerror!void {
    try writer.writeAll(
        \\const std = @import("std");
        \\const sql = @import("../lib/sql.zig");
        \\const u = sql.util;
        \\pub usingnamespace sql.grammar_support;
        \\
        \\const Token = sql.grammar_support.Token;
        \\const Rule = sql.grammar_support.Rule;
        \\const OneOf = sql.grammar_support.OneOf;
        \\const Repeat = sql.grammar_support.Repeat;
        \\const RuleRef = sql.grammar_support.RuleRef;
        \\
        \\
    );
    try self.writeRules(writer);
    try writer.writeAll("\n\n");
    try self.writeTypes(writer);
}

fn writeRules(self: *Self, writer: anytype) anyerror!void {
    try writer.writeAll("pub const rules = .{\n");
    inline for (@typeInfo(sql.grammar_support.Token).Enum.fields) |field| {
        try std.fmt.format(writer, ".{s} = ", .{field.name});
        try self.writeRule(writer, .{ .token = @intToEnum(sql.grammar_support.Token, field.value) });
        try writer.writeAll(",\n");
    }
    for (self.rules.items) |rule| {
        try std.fmt.format(writer, ".{s} = ", .{rule.name});
        try self.writeRule(writer, rule.rule);
        try writer.writeAll(",\n");
    }
    try writer.writeAll("};");
}

fn writeRule(self: *Self, writer: anytype, rule: sql.grammar_support.Rule) anyerror!void {
    switch (rule) {
        .token => |token| {
            try std.fmt.format(writer, "Rule{{.token = .{s}}}", .{std.meta.tagName(token)});
        },
        .one_of => |one_ofs| {
            try std.fmt.format(writer, "Rule{{.one_of = &[{}]OneOf{{\n", .{one_ofs.len});
            for (one_ofs) |one_of| {
                switch (one_of) {
                    .choice => |choice| {
                        try std.fmt.format(writer, ".{{.choice = ", .{});
                        try self.writeRuleRef(writer, choice);
                        try writer.writeAll("},\n");
                    },
                    .committed_choice => |committed_choice| {
                        try std.fmt.format(writer, ".{{.committed_choice = .{{\n", .{});
                        try self.writeRuleRef(writer, committed_choice[0]);
                        try writer.writeAll("\n,");
                        try self.writeRuleRef(writer, committed_choice[1]);
                        try writer.writeAll(",\n}},\n");
                    },
                }
            }
            try writer.writeAll("}}");
        },
        else => try writer.writeAll("TODO"),
    }
}

fn writeRuleRef(self: *Self, writer: anytype, rule_ref: sql.grammar_support.RuleRef) anyerror!void {
    _ = self;
    if (rule_ref.field_name) |field_name|
        try std.fmt.format(writer, "RuleRef{{.field_name = \"{}\", .rule_name = \"{}\"}}", .{
            std.zig.fmtEscapes(field_name),
            std.zig.fmtEscapes(rule_ref.rule_name),
        })
    else
        try std.fmt.format(writer, "RuleRef{{.field_name = {}, .rule_name = \"{}\"}}", .{
            null,
            std.zig.fmtEscapes(rule_ref.rule_name),
        });
}

fn writeTypes(self: *Self, writer: anytype) anyerror!void {
    try writer.writeAll("pub const types = .{\n");
    inline for (@typeInfo(sql.grammar_support.Token).Enum.fields) |field| {
        try std.fmt.format(writer, ".{s} = ", .{field.name});
        try self.writeType(writer, .{ .token = @intToEnum(sql.grammar_support.Token, field.value) });
        try writer.writeAll(",\n");
    }
    for (self.rules.items) |rule| {
        try std.fmt.format(writer, ".{s} = ", .{rule.name});
        try self.writeType(writer, rule.rule);
        try writer.writeAll(",\n");
    }
    try writer.writeAll("};");
}

fn writeType(self: *Self, writer: anytype, rule: sql.grammar_support.Rule) anyerror!void {
    _ = self;
    switch (rule) {
        .token => {
            try writer.writeAll("Token");
        },
        .one_of => |one_ofs| {
            try std.fmt.format(writer, "union(enum) {{\n", .{});
            for (one_ofs) |one_of| {
                const rule_ref = switch (one_of) {
                    .choice => |choice| choice,
                    .committed_choice => |committed_choice| committed_choice[1],
                };
                if (rule_ref.field_name) |field_name|
                    try std.fmt.format(writer, "{s}: {s},", .{ field_name, rule_ref.rule_name });
            }
            try writer.writeAll("}");
        },
        else => try writer.writeAll("TODO"),
    }
}
