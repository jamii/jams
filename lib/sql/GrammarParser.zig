const std = @import("std");
const u = @import("./util.zig");

const Self = @This();
const source = @embedFile("./grammar.txt");
const keywords = @embedFile("./keywords.txt");
arena: *u.ArenaAllocator,
allocator: u.Allocator,
rules: u.ArrayList(NamedRule),
rule_name_defs: u.DeepHashSet([]const u8),
rule_name_refs: u.DeepHashSet([]const u8),
tokens: u.DeepHashSet([]const u8),
left_recursive_rules: u.DeepHashSet([]const u8),
pos: usize,

const Error = error{OutOfMemory};

pub const NamedRule = struct {
    name: []const u8,
    rule: Rule,
};

pub const Rule = union(enum) {
    token: []const u8,
    one_of: []const OneOf,
    all_of: []const RuleRef,
    optional: RuleRef,
    repeat: Repeat,
};

pub const OneOf = union(enum) {
    choice: RuleRef,
    committed_choice: [2]RuleRef,
};

pub const Repeat = struct {
    min_count: usize,
    element: RuleRef,
    separator: ?RuleRef,
};

pub const RuleRef = struct {
    field_name: ?[]const u8,
    rule_name: []const u8,
};

pub fn init(arena: *u.ArenaAllocator) Self {
    const allocator = arena.allocator();
    return Self{
        .arena = arena,
        .allocator = allocator,
        .rules = u.ArrayList(NamedRule).init(allocator),
        .rule_name_defs = u.DeepHashSet([]const u8).init(allocator),
        .rule_name_refs = u.DeepHashSet([]const u8).init(allocator),
        .tokens = u.DeepHashSet([]const u8).init(allocator),
        .left_recursive_rules = u.DeepHashSet([]const u8).init(allocator),
        .pos = 0,
    };
}

pub fn parseRules(self: *Self) Error!void {
    while (true) {
        self.discardWhitespace();
        if (source[self.pos] == 0) break;
        try self.parseNamedRule();
    }

    // rule_name_refs gets filled while parsing, because I'm lazy.

    // fill rule_name_defs
    for (self.rules.items) |rule|
        try self.rule_name_defs.put(rule.name, {});

    // Any name that is reffed but not deffed is assumed to be a token.
    {
        var iter = self.rule_name_refs.keyIterator();
        while (iter.next()) |name| {
            if (!self.rule_name_defs.contains(name.*))
                try self.tokens.put(name.*, {});
        }
    }

    // Add keywords to tokens list too.
    {
        var iter = std.mem.tokenize(u8, keywords, "\n");
        while (iter.next()) |keyword|
            try self.tokens.put(keyword, {});
    }

    // Generate a rule for each token.
    var iter = self.tokens.keyIterator();
    while (iter.next()) |token|
        try self.rules.append(.{
            .name = token.*,
            .rule = .{ .token = token.* },
        });

    {
        // Figure out which rules might match empty strings
        var may_be_empty = u.DeepHashSet([]const u8).init(self.allocator);
        for (self.rules.items) |rule|
            if (rule.rule == .optional or (rule.rule == .repeat and rule.rule.repeat.min_count == 0))
                try may_be_empty.put(rule.name, {});
        while (true) {
            var changed = false;
            for (self.rules.items) |rule1|
                if (!may_be_empty.contains(rule1.name)) {
                    const may_be_empty1 = b: {
                        switch (rule1.rule) {
                            .token => break :b false,
                            .one_of => |one_ofs| {
                                var b = false;
                                for (one_ofs) |one_of| {
                                    switch (one_of) {
                                        .choice => |choice| {
                                            b = b or
                                                may_be_empty.contains(choice.rule_name);
                                        },
                                        .committed_choice => |committed_choice| {
                                            b = b or
                                                (may_be_empty.contains(committed_choice[0].rule_name) and
                                                may_be_empty.contains(committed_choice[1].rule_name));
                                        },
                                    }
                                }
                                break :b b;
                            },
                            .all_of => |all_ofs| {
                                var b = true;
                                for (all_ofs) |all_of|
                                    b = b and may_be_empty.contains(all_of.rule_name);
                                break :b b;
                            },
                            .optional => break :b true,
                            .repeat => |repeat| {
                                break :b (repeat.min_count == 0) or (may_be_empty.contains(repeat.element.rule_name) and
                                    (repeat.separator == null or
                                    may_be_empty.contains(repeat.separator.?.rule_name)));
                            },
                        }
                    };
                    if (may_be_empty1) {
                        try may_be_empty.put(rule1.name, {});
                        changed = true;
                    }
                };
            if (!changed) break;
        }

        // Figure out which rules are left recursive
        var reach = u.DeepHashMap([]const u8, u.DeepHashSet([]const u8)).init(self.allocator);
        for (self.rules.items) |rule| {
            var init_reach = u.DeepHashSet([]const u8).init(self.allocator);
            switch (rule.rule) {
                .token => {},
                .one_of => |one_ofs| {
                    for (one_ofs) |one_of| {
                        switch (one_of) {
                            .choice => |choice| {
                                try init_reach.put(choice.rule_name, {});
                            },
                            .committed_choice => |committed_choice| {
                                try init_reach.put(committed_choice[0].rule_name, {});
                                try init_reach.put(committed_choice[1].rule_name, {});
                            },
                        }
                    }
                },
                .all_of => |all_ofs| {
                    for (all_ofs) |all_of| {
                        try init_reach.put(all_of.rule_name, {});
                        if (!may_be_empty.contains(all_of.rule_name)) break;
                    }
                },
                .optional => |optional| {
                    try init_reach.put(optional.rule_name, {});
                },
                .repeat => |repeat| {
                    try init_reach.put(repeat.element.rule_name, {});
                    if (!may_be_empty.contains(repeat.element.rule_name))
                        if (repeat.separator) |separator|
                            try init_reach.put(separator.rule_name, {});
                },
            }
            try reach.put(rule.name, init_reach);
        }
        while (true) {
            var changed = false;
            for (self.rules.items) |rule_1| {
                var new_reach1 = u.ArrayList([]const u8).init(self.allocator);
                const reach1 = reach.getPtr(rule_1.name).?;
                var iter1 = reach1.keyIterator();
                while (iter1.next()) |rule2_name| {
                    const reach2 = reach.getPtr(rule2_name.*).?;
                    var iter2 = reach2.keyIterator();
                    while (iter2.next()) |rule3_name| {
                        if (!reach1.contains(rule3_name.*)) {
                            // append to new_reach1 to avoid invalidating iter1
                            changed = true;
                            try new_reach1.append(rule3_name.*);
                        }
                    }
                }
                for (new_reach1.items) |rule3_name|
                    try reach1.put(rule3_name, {});
            }
            if (!changed) break;
        }
        for (self.rules.items) |rule|
            if (reach.get(rule.name).?.contains(rule.name))
                try self.left_recursive_rules.put(rule.name, {});
    }
}

fn parseNamedRule(self: *Self) Error!void {
    const name = try self.parseName();
    self.discardWhitespace();
    self.consume("=");
    self.discardWhitespace();
    const rule = try self.parseRule();
    self.consume(";");
    try self.rules.append(.{ .name = name, .rule = rule });
}

fn parseRule(self: *Self) Error!Rule {
    return switch (source[self.pos]) {
        '|' => try self.parseOneOf(),
        else => try self.parseAllOf(),
    };
}

fn parseOneOf(self: *Self) Error!Rule {
    var one_ofs = u.ArrayList(OneOf).init(self.allocator);
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
    return Rule{ .one_of = one_ofs.toOwnedSlice() };
}

fn parseAllOf(self: *Self) Error!Rule {
    var all_ofs = u.ArrayList(RuleRef).init(self.allocator);
    while (true) {
        self.discardWhitespace();
        var rule_ref = (try self.tryParseRuleRef()) orelse break;

        try all_ofs.append(rule_ref);
    }
    self.assert(all_ofs.items.len > 0);
    return Rule{ .all_of = all_ofs.toOwnedSlice() };
}

fn parseRepeat(self: *Self, min_count: usize, rule_ref: *RuleRef) Error!void {
    const separator = if (try self.tryParseName()) |name|
        RuleRef{
            .field_name = null,
            .rule_name = name,
        }
    else
        null;
    const repeat = Rule{ .repeat = .{
        .min_count = min_count,
        .element = rule_ref.*,
        .separator = separator,
    } };
    rule_ref.rule_name = try self.makeAnonRule(repeat);
}

fn makeAnonRule(self: *Self, rule: Rule) Error![]const u8 {
    const name = try self.makeAnonRuleName();
    try self.rules.append(.{ .name = name, .rule = rule });
    return name;
}

fn makeAnonRuleName(self: *Self) Error![]const u8 {
    return std.fmt.allocPrint(self.allocator, "anon_{}", .{self.rules.items.len});
}

fn parseRuleRef(self: *Self) Error!RuleRef {
    var rule_ref = try self.tryParseRuleRef();
    self.assert(rule_ref != null);
    return rule_ref.?;
}

fn tryParseRuleRef(self: *Self) Error!?RuleRef {
    var rule_ref = rule_ref: {
        if (source[self.pos] == '(') {
            self.consume("(");
            const all_of = try self.parseRule();
            self.consume(")");
            const name = try self.makeAnonRule(all_of);
            break :rule_ref RuleRef{
                .field_name = null,
                .rule_name = name,
            };
        } else {
            const name = (try self.tryParseName()) orelse return null;
            var is_token = true;
            for (name) |char|
                switch (char) {
                    'A'...'Z', '_' => {},
                    else => is_token = false,
                };
            break :rule_ref RuleRef{
                .field_name = if (is_token) null else name,
                .rule_name = name,
            };
        }
    };
    try self.tryParseModifier(&rule_ref);
    return rule_ref;
}

fn parseName(self: *Self) ![]const u8 {
    const name = try self.tryParseName();
    self.assert(name != null);
    return name.?;
}

fn tryParseName(self: *Self) !?[]const u8 {
    const start_pos = self.pos;
    while (true) {
        switch (source[self.pos]) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => self.pos += 1,
            else => break,
        }
    }

    if (self.pos == start_pos) {
        return null;
    } else {
        const name = source[start_pos..self.pos];
        try self.rule_name_refs.put(name, {});
        return name;
    }
}

fn tryParseModifier(self: *Self, rule_ref: *RuleRef) Error!void {
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
            const optional = Rule{ .optional = rule_ref.* };
            rule_ref.rule_name = try self.makeAnonRule(optional);
        },
        '=' => {
            self.consume("=");
            const name = try self.parseName();
            rule_ref.field_name = name;
        },
        else => {},
    }
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
            '#' => while (true) {
                switch (source[self.pos]) {
                    0, '\n' => break,
                    else => self.pos += 1,
                }
            },
            else => break,
        }
    }
}

pub fn write(self: *Self, writer: anytype) anyerror!void {
    try writer.writeAll(
        \\const std = @import("std");
        \\const sql = @import("../sql.zig");
        \\const u = sql.util;
        \\
        \\pub const Rule = union(enum) {
        \\    token: Token,
        \\    one_of: []const OneOf,
        \\    all_of: []const RuleRef,
        \\    optional: RuleRef,
        \\    repeat: Repeat,
        \\};
        \\pub const OneOf = sql.GrammarParser.OneOf;
        \\pub const Repeat = sql.GrammarParser.Repeat;
        \\pub const RuleRef = sql.GrammarParser.RuleRef;
        \\
        \\ 
    );
    try self.writeNode(writer);
    try writer.writeAll("\n\n");
    try self.writeRules(writer);
    try writer.writeAll("\n\n");
    try self.writeTypes(writer);
    try writer.writeAll("\n\n");
    try self.writeIsLeftRecursive(writer);
    try writer.writeAll("\n\n");
    {
        try writer.writeAll("pub const Token = enum {");
        var iter = self.tokens.keyIterator();
        while (iter.next()) |token|
            try std.fmt.format(writer, "{s},", .{token.*});
        try writer.writeAll("};");
    }
    try writer.writeAll("\n\n");
    {
        try writer.writeAll(
            \\pub const keywords = keywords: {
            \\    @setEvalBranchQuota(10000);
            \\    break :keywords std.ComptimeStringMap(Token, .{
            \\
        );
        var keywords_iter = std.mem.tokenize(u8, keywords, "\n");
        while (keywords_iter.next()) |keyword|
            try std.fmt.format(writer, ".{{\"{}\", Token.{s}}},\n", .{ std.zig.fmtEscapes(keyword), keyword });
        try writer.writeAll("});};");
    }
}

fn writeNode(self: *Self, writer: anytype) anyerror!void {
    try writer.writeAll("pub const Node = union(enum) {\n");
    for (self.rules.items) |rule| {
        try std.fmt.format(writer, "{s}: @field(types, \"{s}\"),\n", .{ rule.name, rule.name });
    }
    try writer.writeAll("};");
}

fn writeRules(self: *Self, writer: anytype) anyerror!void {
    try writer.writeAll("pub const rules = struct {\n");
    for (self.rules.items) |rule| {
        try std.fmt.format(writer, "pub const {s} = ", .{rule.name});
        try self.writeRule(writer, rule.rule);
        try writer.writeAll(";\n");
    }
    try writer.writeAll("};");
}

fn writeRule(self: *Self, writer: anytype, rule: Rule) anyerror!void {
    switch (rule) {
        .token => |token| {
            try std.fmt.format(writer, "Rule{{.token = .{s}}}", .{token});
        },
        .one_of => |one_ofs| {
            try std.fmt.format(writer, "Rule{{.one_of = &[_]OneOf{{\n", .{});
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
        .all_of => |all_ofs| {
            try std.fmt.format(writer, "Rule{{.all_of = &[_]RuleRef{{\n", .{});
            for (all_ofs) |all_of| {
                try self.writeRuleRef(writer, all_of);
                try writer.writeAll(",\n");
            }
            try writer.writeAll("}}");
        },
        .optional => |optional| {
            try std.fmt.format(writer, "Rule{{.optional = ", .{});
            try self.writeRuleRef(writer, optional);
            try writer.writeAll("}");
        },
        .repeat => |repeat| {
            try std.fmt.format(writer, "Rule{{.repeat = .{{.min_count = {}, .element =", .{repeat.min_count});
            try self.writeRuleRef(writer, repeat.element);
            try writer.writeAll(", .separator =  ");
            if (repeat.separator) |separator|
                try self.writeRuleRef(writer, separator)
            else
                try writer.writeAll("null");
            try writer.writeAll("}}");
        },
    }
}

fn writeRuleRef(self: *Self, writer: anytype, rule_ref: RuleRef) anyerror!void {
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
    try writer.writeAll("pub const types = struct {\n");
    for (self.rules.items) |rule| {
        try std.fmt.format(writer, "pub const {s} = ", .{rule.name});
        try self.writeType(writer, rule.rule);
        try writer.writeAll(";\n");
    }
    try writer.writeAll("};");
}

fn writeType(self: *Self, writer: anytype, rule: Rule) anyerror!void {
    _ = self;
    switch (rule) {
        .token => {
            try writer.writeAll("void");
        },
        .one_of => |one_ofs| {
            var is_enum = true;
            for (one_ofs) |one_of| {
                const rule_ref = switch (one_of) {
                    .choice => |choice| choice,
                    .committed_choice => |committed_choice| committed_choice[1],
                };
                if (rule_ref.field_name != null)
                    is_enum = false;
            }
            if (is_enum)
                try std.fmt.format(writer, "enum {{\n", .{})
            else
                try std.fmt.format(writer, "union(enum) {{\n", .{});
            for (one_ofs) |one_of| {
                const rule_ref = switch (one_of) {
                    .choice => |choice| choice,
                    .committed_choice => |committed_choice| committed_choice[1],
                };
                if (rule_ref.field_name) |field_name|
                    try std.fmt.format(writer, "{s}: sql.Parser.NodeId(\"{s}\"),", .{ field_name, rule_ref.rule_name })
                else
                    try std.fmt.format(writer, "{s},", .{rule_ref.rule_name});
            }
            try writer.writeAll("}");
        },
        .all_of => |all_ofs| {
            try std.fmt.format(writer, "struct {{\n", .{});
            for (all_ofs) |all_of| {
                if (all_of.field_name) |field_name| {
                    try std.fmt.format(writer, "{s}: sql.Parser.NodeId(\"{s}\"),", .{ field_name, all_of.rule_name });
                }
            }
            try writer.writeAll("}");
        },
        .optional => |optional| {
            try std.fmt.format(writer, "?sql.Parser.NodeId(\"{s}\")", .{optional.rule_name});
        },
        .repeat => |repeat| {
            try std.fmt.format(writer, "[]const sql.Parser.NodeId(\"{s}\")", .{repeat.element.rule_name});
        },
    }
}

fn writeIsLeftRecursive(self: *Self, writer: anytype) anyerror!void {
    try writer.writeAll("pub const is_left_recursive = struct {\n");
    for (self.rules.items) |rule|
        try std.fmt.format(writer, "pub const {s} = {};", .{ rule.name, self.left_recursive_rules.contains(rule.name) });
    try writer.writeAll("};");
}
