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

    // tokenize
    tokens: ArrayList(Token),
    token_to_range: ArrayList([2]usize),

    // parse
    expr_top: ?ExprId,
    exprs: ArrayList(Expr),
    expr_to_tokens: ArrayList([2]TokenId),
    token_next: TokenId,

    // analyze
    fns: ArrayList(Fn),
    scope: ArrayList(ScopeItem),
    fn_id_current: ?FnId,

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

            .fns = .{},
            .scope = .{},
            .fn_id_current = null,

            .error_message = null,
        };
    }

    pub fn deinit(c: *Compiler) void {
        if (c.error_message) |err| allocator.free(err);

        c.scope.deinit(allocator);
        for (c.fns.items) |*@"fn"| @"fn".deinit();
        c.fns.deinit(allocator);

        c.expr_to_tokens.deinit(allocator);
        for (c.exprs.items) |expr| expr.deinit();
        c.exprs.deinit(allocator);

        c.token_to_range.deinit(allocator);
        c.tokens.deinit(allocator);
    }

    pub fn run(c: *Compiler) ![]const u8 {
        try tokenize(c);
        c.expr_top = try parse(c);
        try analyze(c, c.expr_top.?);
        return "dummy";
    }
};

fn fail(c: *Compiler, line_col: [2]usize, comptime fmt: []const u8, args: anytype) error{Error} {
    assert(c.error_message == null);
    c.error_message = std.fmt.allocPrint(allocator, "Error at {}:{}\n" ++ fmt, .{ line_col[0], line_col[1] } ++ args) catch oom();
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
    @"!",

    let,
    @"if",
    @"else",
    @"while",
    @"fn",
    null,

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
            '!' => .@"!",
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
                    .let,
                    .@"if",
                    .@"else",
                    .@"while",
                    .@"fn",
                    .null,
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
    return fail(
        c,
        lineColFromPos(c, pos),
        "Bad token",
        .{},
    );
}

fn lineColFromTokenId(c: *Compiler, token_id: TokenId) [2]usize {
    return lineColFromPos(c, c.token_to_range.items[token_id.id][0]);
}

// --- PARSE ---

const ExprId = struct { id: usize };

const Expr = union(enum) {
    null,
    number: i64,
    list: []ExprId,
    list_get: struct {
        list: ExprId,
        index: ExprId,
    },
    get: struct {
        name: []const u8,
        is_unique: bool,
    },
    let: struct {
        name: []const u8,
        value: ExprId,
    },
    set: struct {
        ref: ExprId,
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
            .null, .number, .list_get, .get, .let, .set, .@"if", .@"while", .builtin => {},
        }
    }
};

const Builtin = enum {
    @"+",
    @"<",
};

fn parse(c: *Compiler) error{Error}!ExprId {
    const top = try parseExprLoose(c);
    try expect(c, .eof);
    return top;
}

fn parseExprLoose(c: *Compiler) error{Error}!ExprId {
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
                    return fail(
                        c,
                        lineColFromTokenId(c, c.token_next),
                        "Ambigous precedence: `{s}` vs `{s}`",
                        .{
                            @tagName(last_builtin.?),
                            @tagName(builtin),
                        },
                    );
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
            else => break,
        }
    }
    return expr;
}

fn parseListGet(c: *Compiler, list: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[list.id][0];
    try expect(c, .@"[");
    const index = try parseExprLoose(c);
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
        const arg = try parseExprLoose(c);
        args.append(allocator, arg) catch oom();
        if (!takeIf(c, .@",")) break;
    }

    try expect(c, .@")");
    return pushExpr(c, start, .{ .call = .{ .@"fn" = @"fn", .args = args.toOwnedSlice(allocator) catch oom() } });
}

fn parseExprBase(c: *Compiler) error{Error}!ExprId {
    return switch (peek(c)) {
        .null => parseNull(c),
        .number => parseNumber(c),
        .@"[" => parseList(c),
        .name => parseGet(c),
        .@"{" => parseBlock(c),
        .@"if" => parseIf(c),
        .@"while" => parseWhile(c),
        .@"fn" => parseFn(c),
        else => failExpected(c, "expr"),
    };
}

fn parseNull(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    try expect(c, .null);
    return pushExpr(c, start, .null);
}

fn parseNumber(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    const source = peekSource(c);
    const number = std.fmt.parseInt(i64, source, 10) catch |err| {
        const reason: []const u8 = switch (err) {
            error.Overflow => "overflow",
            error.InvalidCharacter => "invalid character",
        };
        return fail(
            c,
            lineColFromTokenId(c, c.token_next),
            "Failed to parse integer due to {s}",
            .{reason},
        );
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
        const elem = try parseExprLoose(c);
        elems.append(allocator, elem) catch oom();
        if (!takeIf(c, .@",")) break;
    }

    try expect(c, .@"]");

    return pushExpr(c, start, .{ .list = elems.toOwnedSlice(allocator) catch oom() });
}

fn parseGet(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    const name = try expectName(c);
    const is_unique = takeIf(c, .@"!");
    return pushExpr(c, start, .{ .get = .{ .name = name, .is_unique = is_unique } });
}

fn parseBlock(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;

    try expect(c, .@"{");

    var items: ArrayList(ExprId) = .{};
    defer items.deinit(allocator);

    while (true) {
        var item: ?ExprId = null;
        switch (peek(c)) {
            .@"}" => break,
            .let => {
                item = try parseLet(c);
            },
            else => {
                item = try parseExprLoose(c);
                if (peek(c) == .@"=")
                    item = try parseSet(c, item.?);
            },
        }
        items.append(allocator, item.?) catch oom();
        if (!takeIf(c, .@";")) break;
    }

    try expect(c, .@"}");

    return pushExpr(c, start, .{ .block = items.toOwnedSlice(allocator) catch oom() });
}

fn parseLet(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    try expect(c, .let);
    const name = try expectName(c);
    try expect(c, .@"=");
    const value = try parseExprLoose(c);
    return pushExpr(c, start, .{ .let = .{ .name = name, .value = value } });
}

fn parseSet(c: *Compiler, ref: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[ref.id][0];
    try expect(c, .@"=");
    const value = try parseExprLoose(c);
    return pushExpr(c, start, .{ .set = .{ .ref = ref, .value = value } });
}

fn parseIf(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    try expect(c, .@"if");
    const cond = try parseExprLoose(c);
    const then = try parseBlock(c);
    try expect(c, .@"else");
    const @"else" = try parseBlock(c);
    return pushExpr(c, start, .{ .@"if" = .{ .cond = cond, .then = then, .@"else" = @"else" } });
}

fn parseWhile(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    try expect(c, .@"while");
    const cond = try parseExprLoose(c);
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
        const param = try expectName(c);
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

fn expectName(c: *Compiler) error{Error}![]const u8 {
    const name = peekSource(c);
    try expect(c, .name);
    return name;
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
    return fail(
        c,
        lineColFromTokenId(c, c.token_next),
        "Expected {s} but found {}",
        .{ expected, actual },
    );
}

fn lineColFromExprId(c: *Compiler, expr_id: ExprId) [2]usize {
    const token_id = c.expr_to_tokens.items[expr_id.id][0];
    return lineColFromTokenId(c, token_id);
}

// --- ANALYZE ---

const FnId = struct { id: usize };

const Fn = struct {
    parent: ?FnId,
    closure: ArrayList([]const u8),
    closure_index: std.hash_map.StringHashMap(usize),
    scope_start: usize,

    fn deinit(@"fn": *Fn) void {
        @"fn".closure_index.deinit();
        @"fn".closure.deinit(allocator);
    }
};

const ScopeItem = struct {
    name: []const u8,
    let_id: ExprId,
};

fn resolve(c: *Compiler, name: []const u8) ?usize {
    var scope_index = c.scope.items.len;
    while (scope_index > 0) : (scope_index -= 1) {
        const scope_item = c.scope.items[scope_index - 1];
        if (std.mem.eql(u8, scope_item.name, name)) return scope_index - 1;
    }
    return null;
}

fn analyze(c: *Compiler, expr_id: ExprId) !void {
    switch (c.exprs.items[expr_id.id]) {
        .null, .number => {},
        .list => |list| {
            for (list) |item| {
                try analyze(c, item);
            }
        },
        .list_get => |list_get| {
            try analyze(c, list_get.list);
            try analyze(c, list_get.index);
        },
        .get => |get| {
            if (resolve(c, get.name)) |scope_index| {
                var fn_id_next = c.fn_id_current;
                while (fn_id_next) |fn_id| {
                    const @"fn" = &c.fns.items[fn_id.id];
                    if (@"fn".scope_start <= scope_index and
                        !@"fn".closure_index.contains(get.name))
                    {
                        @"fn".closure_index.put(get.name, @"fn".closure.items.len) catch oom();
                        @"fn".closure.append(allocator, get.name) catch oom();
                    }
                    fn_id_next = @"fn".parent;
                }
            } else {
                return failNotDefined(c, expr_id, get.name);
            }
        },
        .let => |let| {
            if (resolve(c, let.name)) |scope_index| {
                return failAlreadyDefined(c, expr_id, c.scope.items[scope_index].let_id, let.name);
            }
            try analyze(c, let.value);
            c.scope.append(allocator, .{ .name = let.name, .let_id = expr_id }) catch oom();
        },
        .set => |set| {
            try analyze(c, set.ref);
            try analyze(c, set.value);
        },
        .block => |block| {
            const scope_start = c.scope.items.len;
            defer c.scope.shrinkRetainingCapacity(scope_start);

            for (block) |statement| {
                try analyze(c, statement);
            }
        },
        .@"if" => |@"if"| {
            try analyze(c, @"if".cond);
            try analyze(c, @"if".then);
            try analyze(c, @"if".@"else");
        },
        .@"while" => |@"while"| {
            try analyze(c, @"while".cond);
            try analyze(c, @"while".body);
        },
        .@"fn" => |@"fn"| {
            const parent = c.fn_id_current;
            c.fn_id_current = .{ .id = c.fns.items.len };
            defer c.fn_id_current = parent;

            c.fns.append(allocator, .{
                .parent = parent,
                .closure = .{},
                .closure_index = .init(allocator),
                .scope_start = c.scope.items.len,
            }) catch oom();

            try analyze(c, @"fn".body);
        },
        else => panic("TODO", .{}),
    }
}

fn failNotDefined(c: *Compiler, expr_id: ExprId, name: []const u8) error{Error} {
    return fail(
        c,
        lineColFromExprId(c, expr_id),
        "Name `{s}` is not defined at this point",
        .{name},
    );
}

fn failAlreadyDefined(c: *Compiler, expr_id: ExprId, let_id: ExprId, name: []const u8) error{Error} {
    const line_col = lineColFromExprId(c, let_id);
    return fail(
        c,
        lineColFromExprId(c, expr_id),
        "Name `{s}` is already defined at {}:{}",
        .{ name, line_col[0], line_col[1] },
    );
}

// --- EVAL ---

const Kind = enum(u64) {
    null = 0,
    i64 = 1,
    tuple = 2,
    @"fn" = 3,
};

const ValueFn = struct {
    fn_id: FnId,
    closure: []Value,
};

const Value = struct {
    ptr: ?[*]u64,

    fn kind(value: Value) Kind {
        return if (value.ptr) |ptr|
            @enumFromInt(ptr[0])
        else
            .null;
    }

    fn as_i64(value: Value) ?*i64 {
        if (value.kind() != .i64) return null;
        return @ptrCast(value.ptr.?[1]);
    }

    fn as_tuple(value: Value) ?[]Value {
        if (value.kind() != .tuple) return null;
        const len = value.ptr.?[1].*;
        return @ptrCast(value.ptr.?[2..][0..len]);
    }

    fn as_fn(value: Value) ?Fn {
        if (value.kind() != .@"fn") return null;
        const body = ExprId{ .id = value.ptr.?[1].* };
        const closure_len = value.ptr.?[2].*;
        const closure: []Value = @ptrCast(value.ptr.?[3..][0..closure_len]);
        return .{ .body = body, .closure = closure };
    }

    fn from_i64(i: i64) Value {
        const ptr = allocator.alloc(u64, 2);
        ptr.?[0] = @intFromEnum(Kind.i64);
        ptr.?[1] = @bitCast(i);
        return .{ .ptr = ptr };
    }

    fn from_tuple(len: u64) Value {
        const ptr = allocator.alloc(u64, 2 + len);
        ptr.?[0] = @intFromEnum(Kind.tuple);
        ptr.?[1] = len;
        @memset(ptr.?[2..][0..len], @bitCast(Value{ .ptr = null }));
        return .{ .ptr = ptr };
    }

    fn from_fn(@"fn": FnId, closure_len: u64) Value {
        const ptr = allocator.alloc(u64, 3 + closure_len);
        ptr.?[0] = @intFromEnum(Kind.@"fn");
        ptr.?[1] = @bitCast(@"fn");
        ptr.?[2] = closure_len;
        @memset(ptr.?[3][0..closure_len], @bitCast(Value{ .ptr = null }));
        return .{ .ptr = ptr };
    }
};

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
