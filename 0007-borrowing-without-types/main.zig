const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const panic = std.debug.panic;
const assert = std.debug.assert;

const allocator = std.heap.c_allocator;

fn oom() noreturn {
    std.debug.panic("OOM", .{});
}

const Compiler = struct {
    source: []const u8,

    tokens: ArrayList(Token),
    token_to_range: ArrayList([2]usize),

    expr_top: ?ExprId,
    exprs: ArrayList(Expr),
    expr_to_tokens: ArrayList([2]TokenId),
    token_next: TokenId,

    error_message: ?[]u8,

    pub fn init(source: []const u8) Compiler {
        return .{
            .source = source,

            .tokens = .{},
            .token_to_range = .{},

            .expr_top = null,
            .exprs = .{},
            .expr_to_tokens = .{},
            .token_next = .{ .id = 0 },

            .error_message = null,
        };
    }

    pub fn deinit(c: *Compiler) void {
        if (c.error_message) |err| allocator.free(err);

        c.expr_to_tokens.deinit(allocator);
        for (c.exprs.items) |expr| expr.deinit();
        c.exprs.deinit(allocator);

        c.token_to_range.deinit(allocator);
        c.tokens.deinit(allocator);
    }

    pub fn run(c: *Compiler) ![]const u8 {
        try tokenize(c);
        c.expr_top = try parse(c);
        return "dummy";
    }
};

fn fail(c: *Compiler, comptime fmt: []const u8, args: anytype) error{Error} {
    assert(c.error_message == null);
    c.error_message = std.fmt.allocPrint(allocator, fmt, args) catch oom();
    return error.Error;
}

fn lineColFromPos(c: *Compiler, pos: usize) [2]usize {
    var line: usize = 1;
    var col = pos + 1;
    for (c.source[0..pos], 0..) |char, char_pos| {
        if (char == '\n') {
            line += 1;
            col = pos - char_pos;
        }
    }
    return .{ line, col };
}

// --- TOKENIZE ---

const TokenId = struct { id: usize };

const Token = enum {
    @"(",
    @")",
    @"[",
    @"]",
    @"}",
    @"{",
    @",",
    @".",
    @";",
    @"=",
    @"<",
    @"+",
    @"@",

    @"if",
    @"else",
    @"while",
    @"fn",

    name,
    number,
    comment,
    eof,
};

pub fn tokenize(c: *Compiler) !void {
    const source = c.source;
    var pos: usize = 0;
    next_token: while (pos < source.len) {
        const start = pos;
        const char = source[pos];
        pos += 1;
        const token: Token = switch (char) {
            '(' => .@"(",
            ')' => .@")",
            '[' => .@"[",
            ']' => .@"]",
            '}' => .@"}",
            '{' => .@"{",
            ',' => .@",",
            '.' => .@".",
            ';' => .@";",
            '=' => .@"=",
            '<' => .@"<",
            '+' => .@"+",
            '@' => .@"@",
            '/' => token: {
                if (pos < source.len and source[pos] == '/') {
                    while (pos < source.len and source[pos] != '\n') {
                        pos += 1;
                    }
                    break :token .comment;
                } else {
                    return failBadToken(c, start);
                }
            },
            'a'...'z' => token: {
                while (pos < source.len) {
                    switch (source[pos]) {
                        'a'...'z' => pos += 1,
                        else => break,
                    }
                }
                const name = source[start..pos];
                const keywords = [_]Token{
                    .@"if",
                    .@"else",
                    .@"while",
                    .@"fn",
                };
                inline for (keywords) |keyword| {
                    if (std.mem.eql(u8, name, @tagName(keyword)))
                        break :token keyword;
                }
                break :token .name;
            },
            '0'...'9' => token: {
                while (pos < source.len) {
                    switch (source[pos]) {
                        '0'...'9' => pos += 1,
                        else => break,
                    }
                }
                break :token .number;
            },
            ' ' => {
                while (pos < source.len and source[pos] == ' ') {
                    pos += 1;
                }
                continue :next_token;
            },
            '\n' => {
                continue :next_token;
            },
            else => return failBadToken(c, start),
        };
        _ = c.tokens.append(allocator, token) catch oom();
        _ = c.token_to_range.append(allocator, .{ start, pos }) catch oom();
    }

    _ = c.tokens.append(allocator, .eof) catch oom();
    _ = c.token_to_range.append(allocator, .{ pos, pos }) catch oom();
}

fn failBadToken(c: *Compiler, pos: usize) error{Error} {
    const line_col = lineColFromPos(c, pos);
    return fail(c, "Bad token at {}:{}", .{ line_col[0], line_col[1] });
}

fn lineColFromTokenId(c: *Compiler, token_id: TokenId) [2]usize {
    return lineColFromPos(c, c.token_to_range.items[token_id.id][0]);
}

// --- PARSE ---

const ExprId = struct { id: usize };

const Expr = union(enum) {
    number: i64,
    list: []ExprId,
    list_get: struct {
        list: ExprId,
        index: ExprId,
    },
    ptr: ExprId,
    name: []const u8,
    let: struct {
        name: []const u8,
        value: ExprId,
    },
    set: struct {
        ptr: ExprId,
        value: ExprId,
    },
    block: []ExprId,
    @"if": struct {
        cond: ExprId,
        then: ExprId,
        @"else": ExprId,
    },
    @"while": struct {
        cond: ExprId,
        body: ExprId,
    },
    @"fn": struct {
        params: [][]const u8,
        body: ExprId,
    },
    call: struct {
        @"fn": ExprId,
        args: []ExprId,
    },
    builtin: Builtin,

    fn deinit(expr: Expr) void {
        switch (expr) {
            .list, .block => |exprs| allocator.free(exprs),
            .@"fn" => |@"fn"| allocator.free(@"fn".params),
            .call => |call| allocator.free(call.args),
            .number, .list_get, .ptr, .name, .let, .set, .@"if", .@"while", .builtin => {},
        }
    }
};

const Builtin = enum {
    @"+",
    @"<",
};

fn parse(c: *Compiler) error{Error}!ExprId {
    const top = try parseExpr(c);
    try expect(c, .eof);
    return top;
}

fn parseExpr(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    var expr = try parseExprTight(c);
    var last_builtin: ?Builtin = null;
    while (true) {
        switch (peek(c)) {
            .@"+", .@"<" => {
                const builtin_start = c.token_next;
                const builtin: Builtin = switch (peek(c)) {
                    .@"+" => .@"+",
                    .@"<" => .@"<",
                    else => unreachable,
                };
                if (last_builtin != null and last_builtin.? != builtin) {
                    const line_col = lineColFromTokenId(c, c.token_next);
                    return fail(c, "Ambigous precedence: {s} vs {s} at {}:{}", .{ @tagName(last_builtin.?), @tagName(builtin), line_col[0], line_col[1] });
                }
                _ = take(c);
                last_builtin = builtin;

                const right = try parseExprTight(c);
                expr = pushExpr(c, start, .{ .call = .{
                    .@"fn" = pushExpr(c, builtin_start, .{ .builtin = builtin }),
                    .args = allocator.dupe(ExprId, &.{ expr, right }) catch oom(),
                } });
            },
            else => break,
        }
    }
    return expr;
}

fn parseExprTight(c: *Compiler) error{Error}!ExprId {
    var expr = try parseExprBase(c);
    while (true) {
        switch (peek(c)) {
            .@"[" => expr = try parseListGet(c, expr),
            .@"(" => expr = try parseCall(c, expr),
            .@"@" => expr = try parsePtr(c, expr),
            else => break,
        }
    }
    return expr;
}

fn parseListGet(c: *Compiler, list: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[list.id][0];
    try expect(c, .@"[");
    const index = try parseExpr(c);
    try expect(c, .@"]");
    return pushExpr(c, start, .{ .list_get = .{ .list = list, .index = index } });
}

fn parseCall(c: *Compiler, @"fn": ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[@"fn".id][0];
    try expect(c, .@"(");

    var args: ArrayList(ExprId) = .{};
    defer args.deinit(allocator);

    while (true) {
        if (peek(c) == .@")") break;
        const arg = try parseExpr(c);
        args.append(allocator, arg) catch oom();
        if (!takeIf(c, .@",")) break;
    }

    try expect(c, .@")");
    return pushExpr(c, start, .{ .call = .{ .@"fn" = @"fn", .args = args.toOwnedSlice(allocator) catch oom() } });
}

fn parsePtr(c: *Compiler, lvalue: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[lvalue.id][0];
    try expect(c, .@"@");
    return pushExpr(c, start, .{ .ptr = lvalue });
}

fn parseExprBase(c: *Compiler) error{Error}!ExprId {
    return switch (peek(c)) {
        .number => parseNumber(c),
        .@"[" => parseList(c),
        .name => parseName(c),
        .@"{" => parseBlock(c),
        .@"if" => parseIf(c),
        .@"while" => parseWhile(c),
        .@"fn" => parseFn(c),
        else => failExpected(c, "expr"),
    };
}

fn parseNumber(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    const source = peekSource(c);
    const number = std.fmt.parseInt(i64, source, 10) catch |err| {
        const line_col = lineColFromTokenId(c, c.token_next);
        const reason: []const u8 = switch (err) {
            error.Overflow => "overflow",
            error.InvalidCharacter => "invalid character",
        };
        return fail(c, "Failed to parse integer at {}:{} due to {s}", .{ line_col[0], line_col[1], reason });
    };
    try expect(c, .number);
    return pushExpr(c, start, .{ .number = number });
}

fn parseList(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;

    try expect(c, .@"[");

    var elems: ArrayList(ExprId) = .{};
    defer elems.deinit(allocator);

    while (true) {
        if (peek(c) == .@"]") break;
        const elem = try parseExpr(c);
        elems.append(allocator, elem) catch oom();
        if (!takeIf(c, .@",")) break;
    }

    try expect(c, .@"]");

    return pushExpr(c, start, .{ .list = elems.toOwnedSlice(allocator) catch oom() });
}

fn parseName(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    const name = peekSource(c);
    try expect(c, .name);
    return pushExpr(c, start, .{ .name = name });
}

fn parseBlock(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;

    try expect(c, .@"{");

    var items: ArrayList(ExprId) = .{};
    defer items.deinit(allocator);

    while (true) {
        if (peek(c) == .@"}") break;
        var item = try parseExpr(c);
        if (peek(c) == .@"=") item = try parseLetOrSet(c, item);
        items.append(allocator, item) catch oom();
        if (!takeIf(c, .@";")) break;
    }

    try expect(c, .@"}");

    return pushExpr(c, start, .{ .block = items.toOwnedSlice(allocator) catch oom() });
}

fn parseLetOrSet(c: *Compiler, lvalue: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[lvalue.id][0];
    try expect(c, .@"=");
    switch (c.exprs.items[lvalue.id]) {
        .name => |name| {
            const value = try parseExpr(c);
            return pushExpr(c, start, .{ .let = .{ .name = name, .value = value } });
        },
        .ptr => |ptr| {
            const value = try parseExpr(c);
            return pushExpr(c, start, .{ .set = .{ .ptr = ptr, .value = value } });
        },
        else => |other| {
            const line_col = lineColFromTokenId(c, c.token_next);
            return fail(c, "Cannot assign to {s} expr at {}:{}", .{ @tagName(other), line_col[0], line_col[1] });
        },
    }
}

fn parseIf(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    try expect(c, .@"if");
    const cond = try parseExpr(c);
    const then = try parseBlock(c);
    try expect(c, .@"else");
    const @"else" = try parseBlock(c);
    return pushExpr(c, start, .{ .@"if" = .{ .cond = cond, .then = then, .@"else" = @"else" } });
}

fn parseWhile(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    try expect(c, .@"while");
    const cond = try parseExpr(c);
    const body = try parseBlock(c);
    return pushExpr(c, start, .{ .@"while" = .{ .cond = cond, .body = body } });
}

fn parseFn(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    try expect(c, .@"fn");
    try expect(c, .@"(");

    var params: ArrayList([]const u8) = .{};
    defer params.deinit(allocator);

    while (true) {
        if (peek(c) == .@")") break;
        const param = peekSource(c);
        try expect(c, .name);
        params.append(allocator, param) catch oom();
        if (!takeIf(c, .@",")) break;
    }

    try expect(c, .@")");

    const body = try parseBlock(c);

    return pushExpr(c, start, .{ .@"fn" = .{ .params = params.toOwnedSlice(allocator) catch oom(), .body = body } });
}

fn expect(c: *Compiler, expected: Token) error{Error}!void {
    const actual = peek(c);
    if (expected != actual) {
        return failExpected(c, @tagName(expected));
    }
    _ = take(c);
}

fn peek(c: *Compiler) Token {
    return c.tokens.items[c.token_next.id];
}

fn peekSource(c: *Compiler) []const u8 {
    const range = c.token_to_range.items[c.token_next.id];
    return c.source[range[0]..range[1]];
}

fn take(c: *Compiler) Token {
    const token = peek(c);
    c.token_next.id += 1;
    return token;
}

fn takeIf(c: *Compiler, expected: Token) bool {
    const token = peek(c);
    if (token == expected) c.token_next.id += 1;
    return token == expected;
}

fn pushExpr(c: *Compiler, start: TokenId, expr: Expr) ExprId {
    const expr_id = ExprId{ .id = c.exprs.items.len };
    c.exprs.append(allocator, expr) catch oom();
    c.expr_to_tokens.append(allocator, .{ start, c.token_next }) catch oom();
    return expr_id;
}

fn failExpected(c: *Compiler, expected: []const u8) error{Error} {
    const actual = c.tokens.items[c.token_next.id];
    const line_col = lineColFromTokenId(c, c.token_next);
    return fail(
        c,
        "Expected {s} but found {} at {}:{}",
        .{ expected, actual, line_col[0], line_col[1] },
    );
}

fn lineColFromExprId(c: *Compiler, expr_id: ExprId) [2]usize {
    const token_id = c.expr_to_tokens.items[expr_id.id][0];
    return lineColFromTokenId(c, token_id);
}

// ---

pub fn main() !void {
    const cwd = std.fs.cwd();
    var args = try std.process.argsAlloc(allocator);
    args = args[1..];

    var rewrite = false;
    var failures: usize = 0;

    if (args.len > 0 and std.mem.eql(u8, args[0], "--rewrite")) {
        rewrite = true;
        args = args[1..];
    }

    for (args) |path| {
        std.debug.print("Opening {s}\n", .{path});

        const file = try cwd.openFile(path, .{ .mode = .read_write });
        defer file.close();

        var rewritten: ArrayList(u8) = .{};

        const text = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

        var cases = std.mem.splitSequence(u8, text, "```");
        while (true) {
            const not_case = cases.next().?;
            try rewritten.appendSlice(allocator, not_case);
            const case = cases.next() orelse break;
            if (!std.mem.startsWith(u8, case, "test")) {
                try rewritten.print(allocator,
                    \\```{s}```
                , .{case});
                continue;
            }
            var parts = std.mem.splitSequence(u8, std.mem.trim(u8, case, "test"), "\n\n");
            const source = std.mem.trim(u8, parts.next().?, "\n");
            const expected = std.mem.trim(u8, parts.next() orelse "", "\n");
            assert(parts.next() == null);

            var compiler = Compiler.init(source);
            defer compiler.deinit();

            const actual = compiler.run() catch compiler.error_message.?;

            if (!std.mem.eql(u8, expected, actual)) {
                std.debug.print(
                    \\=== source ===
                    \\{s}
                    \\--- expected ---
                    \\{s}
                    \\--- actual ---
                    \\{s}
                    \\
                    \\
                , .{ source, expected, actual });
                failures += 1;
            }
            try rewritten.print(allocator,
                \\```test
                \\{s}
                \\
                \\{s}
                \\```
            , .{ source, actual });
        }

        if (rewrite) {
            try file.seekTo(0);
            try file.setEndPos(0);
            var buffer: [64]u8 = undefined;
            var writer = file.writer(&buffer);
            try writer.interface.writeAll(rewritten.items);
            try writer.interface.flush();
        }
    }

    if (failures == 0) {
        std.debug.print("Ok!", .{});
    } else {
        std.debug.print("Failures: {}!", .{failures});
        std.process.exit(1);
    }
}
