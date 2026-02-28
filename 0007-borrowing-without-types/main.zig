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
    expr_to_fn: std.AutoHashMap(ExprId, FnId),
    scope: ArrayList(ScopeItem),
    fn_id_current: ?FnId,

    // eval
    bindings: ArrayList(Binding),

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
            .expr_to_fn = .init(allocator),
            .scope = .{},
            .fn_id_current = null,

            .bindings = .{},

            .error_message = null,
        };
    }

    pub fn deinit(c: *Compiler) void {
        if (c.error_message) |err| allocator.free(err);

        for (c.bindings.items) |*binding| binding.value.deinit();
        c.bindings.deinit(allocator);

        c.scope.deinit(allocator);
        c.expr_to_fn.deinit();
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
        const value = try eval(c, c.expr_top.?);
        return std.fmt.allocPrint(allocator, "{f}", .{value});
    }
};

const SourceLocation = union(enum) {
    pos: usize,
    token_id: TokenId,
    expr_id: ExprId,
};

fn fail(c: *Compiler, source_location: SourceLocation, comptime fmt: []const u8, args: anytype) error{Error} {
    assert(c.error_message == null);
    const line_col = lineColFromSourceLocation(c, source_location);
    c.error_message = std.fmt.allocPrint(allocator, "Error at {}:{}\n" ++ fmt, .{ line_col[0], line_col[1] } ++ args) catch oom();
    return error.Error;
}

fn lineColFromSourceLocation(c: *Compiler, source_location_orig: SourceLocation) [2]usize {
    var source_location = source_location_orig;
    while (true) {
        switch (source_location) {
            .expr_id => |expr_id| {
                const token_id = c.expr_to_tokens.items[expr_id.id][0];
                source_location = .{ .token_id = token_id };
            },
            .token_id => |token_id| {
                const pos = c.token_to_range.items[token_id.id][0];
                source_location = .{ .pos = pos };
            },
            .pos => |pos| {
                var line: usize = 1;
                var col = pos + 1;
                for (c.source[0..pos], 0..) |char, char_pos| {
                    if (char == '\n') {
                        line += 1;
                        col = pos - char_pos;
                    }
                }
                return .{ line, col };
            },
        }
    }
}

// --- TOKENIZE ---

const TokenId = packed struct { id: usize };

const Token = enum {
    @"(",
    @")",
    @"[",
    @"]",
    @"}",
    @"{",
    @",",
    @";",
    @"=",
    @"<",
    @"+",
    @"!",

    let,
    get,
    set,
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
                    .get,
                    .set,
                    .@"if",
                    .@"else",
                    .@"while",
                    .@"fn",
                    .null,
                };
                for (keywords) |keyword| {
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
        .{ .pos = pos },
        "Bad token",
        .{},
    );
}

// --- PARSE ---

const ExprId = packed struct { id: usize };

const Expr = union(enum) {
    null,
    number: i64,
    tuple: []ExprId,
    name: []const u8,
    let: struct {
        name: []const u8,
        value: ExprId,
    },
    block: struct {
        statements: []ExprId,
        return_null: bool,
    },
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
        closure: ExprId,
        args: []ExprId,
    },
    call_builtin: struct {
        builtin: Builtin,
        args: []ExprId,
    },

    fn deinit(expr: Expr) void {
        switch (expr) {
            .tuple => |exprs| allocator.free(exprs),
            .block => |block| allocator.free(block.statements),
            .@"fn" => |@"fn"| allocator.free(@"fn".params),
            inline .call, .call_builtin => |call| allocator.free(call.args),
            .null, .number, .name, .let, .@"if", .@"while" => {},
        }
    }
};

const Builtin = enum {
    get,
    set,
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
                const builtin: Builtin = switch (peek(c)) {
                    .@"+" => .@"+",
                    .@"<" => .@"<",
                    else => unreachable,
                };
                if (last_builtin != null and last_builtin.? != builtin) {
                    return fail(
                        c,
                        .{ .token_id = c.token_next },
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
                expr = pushExpr(c, start, .{ .call_builtin = .{
                    .builtin = builtin,
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
            .@"(" => expr = try parseCall(c, expr),
            else => break,
        }
    }
    return expr;
}

fn parseCall(c: *Compiler, closure: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[closure.id][0];
    const args = try parseArgs(c);
    return pushExpr(c, start, .{ .call = .{ .closure = closure, .args = args } });
}

fn parseArgs(c: *Compiler) error{Error}![]ExprId {
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

    return args.toOwnedSlice(allocator) catch oom();
}

fn parseExprBase(c: *Compiler) error{Error}!ExprId {
    return switch (peek(c)) {
        .null => parseNull(c),
        .get => parseGet(c),
        .set => parseSet(c),
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

fn parseNull(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    try expect(c, .null);
    return pushExpr(c, start, .null);
}

fn parseGet(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    try expect(c, .get);
    const args = try parseArgs(c);
    const expr_id = pushExpr(c, start, .{ .call_builtin = .{ .builtin = .get, .args = args } });
    try checkArgCount(c, .{ .token_id = start }, .{ .expected = 2, .actual = args.len });
    return expr_id;
}

fn parseSet(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    try expect(c, .set);
    const args = try parseArgs(c);
    const expr_id = pushExpr(c, start, .{ .call_builtin = .{ .builtin = .set, .args = args } });
    try checkArgCount(c, .{ .token_id = start }, .{ .expected = 3, .actual = args.len });
    return expr_id;
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
            .{ .token_id = c.token_next },
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

    return pushExpr(c, start, .{ .tuple = elems.toOwnedSlice(allocator) catch oom() });
}

fn parseName(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    const name = try expectName(c);
    return pushExpr(c, start, .{ .name = name });
}

fn parseBlock(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;

    try expect(c, .@"{");

    var statements: ArrayList(ExprId) = .{};
    defer statements.deinit(allocator);

    const return_null = while (true) {
        if (peek(c) == .@"}") break true;
        const statement = if (peek(c) == .let) try parseLet(c) else try parseExprLoose(c);
        statements.append(allocator, statement) catch oom();
        if (!takeIf(c, .@";")) break false;
    };

    try expect(c, .@"}");

    return pushExpr(c, start, .{
        .block = .{
            .statements = statements.toOwnedSlice(allocator) catch oom(),
            .return_null = return_null,
        },
    });
}

fn parseLet(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    try expect(c, .let);
    const name = try expectName(c);
    try expect(c, .@"=");
    const value = try parseExprLoose(c);
    return pushExpr(c, start, .{ .let = .{ .name = name, .value = value } });
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
        .{ .token_id = c.token_next },
        "Expected {s} but found `{s}`",
        .{ expected, @tagName(actual) },
    );
}

// --- ANALYZE ---

const FnId = packed struct { id: usize };

const Fn = struct {
    parent: ?FnId,
    body_expr_id: ExprId,
    capture_names: ArrayList([]const u8),
    capture_name_to_index: std.hash_map.StringHashMap(usize),
    scope_start: usize,

    fn deinit(@"fn": *Fn) void {
        @"fn".capture_name_to_index.deinit();
        @"fn".capture_names.deinit(allocator);
    }
};

const ScopeItem = struct {
    name: []const u8,
    let_id: ExprId,
};

fn resolve(list: anytype, name: []const u8) ?usize {
    var i = list.items.len;
    while (i > 0) : (i -= 1) {
        const item = list.items[i - 1];
        if (std.mem.eql(u8, item.name, name)) return i - 1;
    }
    return null;
}

fn analyze(c: *Compiler, expr_id: ExprId) !void {
    switch (c.exprs.items[expr_id.id]) {
        .null, .number => {},
        .tuple => |tuple| {
            for (tuple) |item| {
                try analyze(c, item);
            }
        },
        .name => |name| {
            const scope_index = resolve(c.scope, name) orelse
                return failNotDefined(c, expr_id, name);

            var fn_id_next = c.fn_id_current;
            while (fn_id_next) |fn_id| {
                const @"fn" = &c.fns.items[fn_id.id];
                if (scope_index <= @"fn".scope_start and
                    !@"fn".capture_name_to_index.contains(name))
                {
                    const capture_index = @"fn".capture_names.items.len;
                    @"fn".capture_name_to_index.put(name, capture_index) catch oom();
                    @"fn".capture_names.append(allocator, name) catch oom();
                }
                fn_id_next = @"fn".parent;
            }
        },
        .let => |let| {
            if (resolve(c.scope, let.name)) |scope_index| {
                return failAlreadyDefined(c, expr_id, c.scope.items[scope_index].let_id, let.name);
            }
            try analyze(c, let.value);
            c.scope.append(allocator, .{ .name = let.name, .let_id = expr_id }) catch oom();
        },
        .block => |block| {
            const scope_start = c.scope.items.len;
            defer c.scope.shrinkRetainingCapacity(scope_start);

            for (block.statements) |statement| {
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
                .body_expr_id = @"fn".body,
                .capture_names = .{},
                .capture_name_to_index = .init(allocator),
                .scope_start = c.scope.items.len,
            }) catch oom();
            c.expr_to_fn.put(expr_id, c.fn_id_current.?) catch oom();

            try analyze(c, @"fn".body);
        },
        .call => |call| {
            try analyze(c, call.closure);
            for (call.args) |arg| {
                try analyze(c, arg);
            }
        },
        .call_builtin => |call_builtin| {
            for (call_builtin.args) |arg| {
                try analyze(c, arg);
            }
        },
    }
}

fn failNotDefined(c: *Compiler, expr_id: ExprId, name: []const u8) error{Error} {
    return fail(
        c,
        .{ .expr_id = expr_id },
        "Name `{s}` is not defined at this point",
        .{name},
    );
}

fn failAlreadyDefined(c: *Compiler, expr_id: ExprId, let_id: ExprId, name: []const u8) error{Error} {
    const line_col = lineColFromSourceLocation(c, .{ .expr_id = let_id });
    return fail(
        c,
        .{ .expr_id = expr_id },
        "Name `{s}` is already defined at {}:{}",
        .{ name, line_col[0], line_col[1] },
    );
}

// --- EVAL ---

const Ownership = enum(u1) {
    owned = 0,
    borrowed = 1,
};

const Kind = enum(u64) {
    null = 0,
    number = 1,
    tuple = 2,
    closure = 3,
};

const Closure = struct {
    fn_id: FnId,
    capture_values: []Value,
};

const Value = packed struct {
    ownership: Ownership,
    ptr: u63,

    fn asPtr(value: Value) ?[*]u64 {
        return @ptrFromInt(value.ptr);
    }

    fn initPtr(ptr: ?[*]u64) Value {
        return .{
            .ownership = .owned,
            .ptr = @intCast(@intFromPtr(ptr)),
        };
    }

    fn borrow(value: Value) Value {
        return .{
            .ownership = .borrowed,
            .ptr = value.ptr,
        };
    }

    fn take(value: *Value) Value {
        const taken = value.*;
        value.* = .initNull();
        return taken;
    }

    fn kind(value: Value) Kind {
        return if (value.asPtr()) |ptr|
            @enumFromInt(ptr[0])
        else
            .null;
    }

    fn asNumber(value: Value) ?i64 {
        if (value.kind() != .number) return null;
        return @bitCast(value.asPtr().?[1]);
    }

    fn asTuple(value: Value) ?[]Value {
        if (value.kind() != .tuple) return null;
        const len = value.asPtr().?[1];
        return @ptrCast(value.asPtr().?[2..][0..len]);
    }

    fn asClosure(value: Value) ?Closure {
        if (value.kind() != .closure) return null;
        const fn_id = FnId{ .id = value.asPtr().?[1] };
        const capture_count = value.asPtr().?[2];
        const capture_values: []Value = @ptrCast(value.asPtr().?[3..][0..capture_count]);
        return .{ .fn_id = fn_id, .capture_values = capture_values };
    }

    fn initNull() Value {
        return .initPtr(null);
    }

    fn initNumber(i: i64) Value {
        const ptr = allocator.alloc(u64, 2) catch oom();
        ptr[0] = @intFromEnum(Kind.number);
        ptr[1] = @bitCast(i);
        return .initPtr(@ptrCast(ptr));
    }

    fn initTuple(len: u64) Value {
        const ptr = allocator.alloc(u64, 2 + len) catch oom();
        ptr[0] = @intFromEnum(Kind.tuple);
        ptr[1] = len;
        @memset(ptr[2..][0..len], @bitCast(Value.initPtr(null)));
        return .initPtr(@ptrCast(ptr));
    }

    fn initClosure(fn_id: FnId, closure_len: u64) Value {
        const ptr = allocator.alloc(u64, 3 + closure_len) catch oom();
        ptr[0] = @intFromEnum(Kind.closure);
        ptr[1] = @bitCast(fn_id);
        ptr[2] = closure_len;
        @memset(ptr[3..][0..closure_len], @bitCast(Value.initPtr(null)));
        return .initPtr(@ptrCast(ptr));
    }

    fn deinit(value: *Value) void {
        if (value.ownership == .owned) {
            switch (value.kind()) {
                .null, .number => {},
                .tuple => for (value.asTuple().?) |*elem| elem.deinit(),
                .closure => for (value.asClosure().?.capture_values) |*capture_value| capture_value.deinit(),
            }
            const len = switch (value.kind()) {
                .null => return,
                .number => 2,
                .tuple => 2 + value.asTuple().?.len,
                .closure => 3 + value.asClosure().?.capture_values.len,
            };
            allocator.free(value.asPtr().?[0..len]);
        }
        value.* = .initNull();
    }

    pub fn format(value: Value, writer: *std.io.Writer) std.io.Writer.Error!void {
        switch (value.kind()) {
            .null => {
                try writer.print("null", .{});
            },
            .number => {
                try writer.print("{}", .{value.asNumber().?});
            },
            .tuple => {
                try writer.print("[", .{});
                for (value.asTuple().?, 0..) |item, i| {
                    if (i != 0)
                        try writer.print(", ", .{});
                    try writer.print("{f}", .{item});
                }
                try writer.print("]", .{});
            },
            .closure => {
                const closure = value.asClosure().?;
                try writer.print("fn<{}>[", .{closure.fn_id});
                for (closure.capture_values, 0..) |capture_value, i| {
                    if (i != 0)
                        try writer.print(", ", .{});
                    try writer.print("{f}", .{capture_value});
                }
                try writer.print("]", .{});
            },
        }
    }
};

const Binding = struct {
    name: []const u8,
    value: Value,
};

fn eval(c: *Compiler, expr_id: ExprId) error{Error}!Value {
    switch (c.exprs.items[expr_id.id]) {
        .null => {
            return .initNull();
        },
        .number => |number| {
            return .initNumber(number);
        },
        .tuple => |exprs| {
            var value = Value.initTuple(exprs.len);
            defer value.deinit();

            const tuple = value.asTuple().?;
            for (tuple, exprs) |*item, expr| {
                item.* = try eval(c, expr);
            }

            return value.take();
        },
        .name => |name| {
            const binding_index = resolve(c.bindings, name).?;
            const value = c.bindings.items[binding_index].value;
            return value.borrow();
        },
        .let => |let| {
            var value = try eval(c, let.value);
            defer value.deinit();

            c.bindings.append(allocator, .{
                .name = let.name,
                .value = value.take(),
            }) catch oom();

            return Value.initNull();
        },
        .block => |block| {
            const bindings_start = c.bindings.items.len;

            var value = Value.initNull();
            defer value.deinit();

            for (block.statements) |statement| {
                value.deinit();
                value = try eval(c, statement);
            }
            if (block.return_null) {
                value.deinit();
            }

            while (c.bindings.items.len > bindings_start) {
                var binding = c.bindings.pop().?;
                binding.value.deinit();
            }

            return value.take();
        },
        .@"if" => |@"if"| {
            var cond = try eval(c, @"if".cond);
            defer cond.deinit();

            return eval(c, if (cond.kind() != .null) @"if".then else @"if".@"else");
        },
        .@"while" => |@"while"| {
            var value = Value.initNull();
            defer value.deinit();

            while (true) {
                var cond = try eval(c, @"while".cond);
                defer cond.deinit();

                if (cond.kind() == .null) break;

                value.deinit();
                value = try eval(c, @"while".body);
            }

            return value.take();
        },
        .@"fn" => {
            const fn_id = c.expr_to_fn.get(expr_id).?;
            const @"fn" = &c.fns.items[fn_id.id];

            var value = Value.initClosure(fn_id, @"fn".capture_names.items.len);
            defer value.deinit();

            for (@"fn".capture_names.items, value.asClosure().?.capture_values) |capture_name, *capture_value| {
                const binding_index = resolve(c.bindings, capture_name).?;
                capture_value.* = c.bindings.items[binding_index].value.borrow();
            }

            return value.take();
        },
        .call => |call| {
            var closure_value = try eval(c, call.closure);
            defer closure_value.deinit();

            try checkKind(c, .{ .expr_id = call.closure }, .{ .expected = .closure, .actual = closure_value.kind() });
            const closure = closure_value.asClosure().?;
            const @"fn" = &c.fns.items[closure.fn_id.id];

            const args = allocator.alloc(Value, call.args.len) catch oom();
            for (args) |*arg| arg.* = Value.initNull();
            defer {
                for (args) |*arg| arg.deinit();
                allocator.free(args);
            }

            for (args, call.args) |*arg_value, arg_expr|
                arg_value.* = try eval(c, arg_expr);

            const bindings_start = c.bindings.items.len;
            defer {
                while (c.bindings.items.len > bindings_start) {
                    var binding = c.bindings.pop().?;
                    binding.value.deinit();
                }
            }

            for (@"fn".capture_names.items, closure.capture_values) |capture_name, capture_value| {
                c.bindings.append(allocator, .{ .name = capture_name, .value = capture_value }) catch oom();
            }

            return eval(c, @"fn".body_expr_id);
        },
        .call_builtin => |call_builtin| {
            const args = allocator.alloc(Value, call_builtin.args.len) catch oom();
            for (args) |*arg| arg.* = Value.initNull();
            defer {
                for (args) |*arg| arg.deinit();
                allocator.free(args);
            }

            for (args, call_builtin.args) |*value, expr| {
                value.* = try eval(c, expr);
            }

            switch (call_builtin.builtin) {
                .@"+" => {
                    try checkArgCount(c, .{ .expr_id = expr_id }, .{ .expected = 2, .actual = args.len });
                    try checkKind(c, .{ .expr_id = call_builtin.args[0] }, .{ .expected = .number, .actual = args[0].kind() });
                    try checkKind(c, .{ .expr_id = call_builtin.args[1] }, .{ .expected = .number, .actual = args[1].kind() });
                    return Value.initNumber(args[0].asNumber().? +% args[1].asNumber().?);
                },
                .@"<", .get, .set => |builtin| return fail(c, .{ .expr_id = expr_id }, "TODO .{}", .{builtin}),
            }
        },
    }
}

fn checkArgCount(c: *Compiler, source_location: SourceLocation, opts: struct { expected: usize, actual: usize }) error{Error}!void {
    if (opts.expected != opts.actual)
        return fail(
            c,
            source_location,
            "Expected {} arguments but found {} arguments",
            .{ opts.expected, opts.actual },
        );
}

fn checkKind(c: *Compiler, source_location: SourceLocation, opts: struct { expected: Kind, actual: Kind }) error{Error}!void {
    if (opts.expected != opts.actual)
        return fail(
            c,
            source_location,
            "Expected a {s} but found a {s}",
            .{ @tagName(opts.expected), @tagName(opts.actual) },
        );
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
