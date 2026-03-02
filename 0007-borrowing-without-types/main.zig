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
        var bs = try analyze(c, c.expr_top.?);
        bs.deinit();
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
    take,
    copy,
    @"if",
    @"else",
    @"while",
    @"fn",
    null,

    name,
    number,
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
            '/' => {
                if (pos < source.len and source[pos] == '/') {
                    while (pos < source.len and source[pos] != '\n') {
                        pos += 1;
                    }
                    continue :next_token;
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
                    .take,
                    .copy,
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
    get: struct {
        name: []const u8,
        borrow_kind: BorrowKind,
    },
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
        params: []Param,
        body: ExprId,
    },
    call: struct {
        closure: ExprId,
        args: []ExprId,
        unique_bitmap: u64,
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
            .null, .number, .get, .let, .@"if", .@"while" => {},
        }
    }
};

const Param = struct {
    name: []const u8,
    borrow_kind: BorrowKind,
};

const Builtin = enum {
    get,
    set,
    take,
    copy,
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
    return pushExpr(c, start, .{
        .call = .{
            .closure = closure,
            .args = args,
            .unique_bitmap = 0, // filled in later by `analyze`
        },
    });
}

const arg_count_max: usize = 64;

fn parseArgs(c: *Compiler) error{Error}![]ExprId {
    try expect(c, .@"(");

    var args: ArrayList(ExprId) = .{};
    defer args.deinit(allocator);

    for (0..arg_count_max) |_| {
        if (peek(c) == .@")") break;
        const arg = try parseExprLoose(c);
        args.append(allocator, arg) catch oom();
        if (!takeIf(c, .@",")) break;
    } else {
        return fail(
            c,
            .{ .token_id = c.token_next },
            "Functions may take at most {} arguments",
            .{arg_count_max},
        );
    }

    try expect(c, .@")");

    return args.toOwnedSlice(allocator) catch oom();
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
        .get, .set, .take, .copy => parseCallBuiltin(c),
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

fn parseGet(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    const name = try expectName(c);
    const borrow_kind: BorrowKind = if (takeIf(c, .@"!")) .unique else .shared;
    return pushExpr(c, start, .{ .get = .{ .name = name, .borrow_kind = borrow_kind } });
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

    var params: ArrayList(Param) = .{};
    defer params.deinit(allocator);

    for (0..arg_count_max) |_| {
        if (peek(c) == .@")") break;
        const name = try expectName(c);
        const borrow_kind: BorrowKind = if (takeIf(c, .@"!")) .unique else .shared;
        params.append(allocator, .{ .name = name, .borrow_kind = borrow_kind }) catch oom();
        if (!takeIf(c, .@",")) break;
    } else {
        return fail(
            c,
            .{ .token_id = c.token_next },
            "Functions may take at most {} arguments",
            .{arg_count_max},
        );
    }

    try expect(c, .@")");

    const body = try parseBlock(c);

    return pushExpr(c, start, .{ .@"fn" = .{ .params = params.toOwnedSlice(allocator) catch oom(), .body = body } });
}

fn parseCallBuiltin(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;

    const builtin: Builtin = switch (peek(c)) {
        .get => .get,
        .set => .set,
        .take => .take,
        .copy => .copy,
        else => return failExpected(c, "a builtin function"),
    };
    _ = take(c);

    const args = try parseArgs(c);
    const expr_id = pushExpr(c, start, .{ .call_builtin = .{ .builtin = builtin, .args = args } });
    return expr_id;
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
    captures: ArrayList(Capture),
    capture_name_to_index: std.hash_map.StringHashMap(usize),
    scope_start: usize,
    unique_bitmap: u64,

    fn deinit(@"fn": *Fn) void {
        @"fn".capture_name_to_index.deinit();
        @"fn".captures.deinit(allocator);
    }
};

const Capture = struct {
    name: []const u8,
    borrow: Borrow,
};

const ScopeItem = struct {
    // Either the name from an `Expr.let`, or null if this is an anonymous expression.
    name: ?[]const u8,
    expr_id: ExprId,
    borrow_set: BorrowSet,

    fn deinit(scope_item: *ScopeItem) void {
        scope_item.borrow_set.deinit();
    }
};

fn resolve(list: anytype, name: []const u8) ?usize {
    var i = list.items.len;
    while (i > 0) : (i -= 1) {
        const index = i - 1;
        const item = list.items[index];
        if (item.name) |item_name|
            if (std.mem.eql(u8, item_name, name))
                return index;
    }
    return null;
}

const BorrowSet = std.hash_map.StringHashMap(Borrow);

const Borrow = struct {
    kind: BorrowKind,
    // The `Expr.get` where this borrow originated from.
    origin: ExprId,
};

const BorrowKind = enum {
    unique,
    shared,
};

fn addBorrowSet(bs_old: *BorrowSet, bs_new: BorrowSet) void {
    var iter = bs_new.iterator();
    while (iter.next()) |kv| {
        bs_old.put(kv.key_ptr.*, kv.value_ptr.*) catch oom();
    }
}

fn analyze(c: *Compiler, expr_id: ExprId) error{Error}!BorrowSet {
    switch (c.exprs.items[expr_id.id]) {
        .null, .number => {
            return BorrowSet.init(allocator);
        },
        .tuple => |tuple| {
            const scope_start = c.scope.items.len;
            defer resetScope(c, scope_start);

            for (tuple) |elem| {
                const bs_elem = try analyzeAndAddToScope(c, elem);
                var iter = bs_elem.iterator();
                while (iter.next()) |kv| {
                    const name = kv.key_ptr.*;
                    const borrow = kv.value_ptr.*;
                    if (borrow.kind == .unique) {
                        return fail(
                            c,
                            .{ .expr_id = elem },
                            "This value can't be stored inside a tuple because it uniquely borrows from {s}.",
                            .{name},
                        );
                    }
                }
            }

            // This tuple borrows from all the names it's elems borrow from.
            var bs = BorrowSet.init(allocator);
            for (c.scope.items[scope_start..]) |scope_item| {
                addBorrowSet(&bs, scope_item.borrow_set);
            }
            return bs;
        },
        .get => |get| {
            // Find the corresponding `let`.
            const scope_index = resolve(c.scope, get.name) orelse
                return failNotDefined(c, expr_id, get.name);

            // Update captures of any enclosing functions.
            var fn_id_next = c.fn_id_current;
            while (fn_id_next) |fn_id| {
                const @"fn" = &c.fns.items[fn_id.id];
                if (scope_index < @"fn".scope_start) {
                    if (@"fn".capture_name_to_index.get(get.name)) |capture_index| {
                        if (get.borrow_kind == .unique)
                            @"fn".captures.items[capture_index].borrow.kind = .unique;
                    } else {
                        const capture_index = @"fn".captures.items.len;
                        @"fn".capture_name_to_index.put(get.name, capture_index) catch oom();
                        @"fn".captures.append(allocator, .{
                            .name = get.name,
                            .borrow = .{ .kind = get.borrow_kind, .origin = expr_id },
                        }) catch oom();
                    }
                }
                fn_id_next = @"fn".parent;
            }

            // Check if any other names already borrow `get.name`.
            for (c.scope.items) |scope_item| {
                if (scope_item.borrow_set.get(get.name)) |borrow| {
                    if (get.borrow_kind == .unique) {
                        const line_col = lineColFromSourceLocation(c, .{ .expr_id = borrow.origin });
                        return fail(
                            c,
                            .{ .expr_id = expr_id },
                            "Can't uniquely borrow {s} here because it is already borrowed by {s} at {}:{}'",
                            .{ get.name, scope_item.name orelse "<anon>", line_col[0], line_col[1] },
                        );
                    }
                    if (borrow.kind == .unique) {
                        const line_col = lineColFromSourceLocation(c, .{ .expr_id = borrow.origin });
                        return fail(
                            c,
                            .{ .expr_id = expr_id },
                            "Can't borrow {s} here because it is already uniquely borrowed by {s} at {}:{}'",
                            .{ get.name, scope_item.name orelse "<anon>", line_col[0], line_col[1] },
                        );
                    }
                }
            }

            // Check if `get.name` borrows another name using a conflicting `BorrowKind`.
            if (get.borrow_kind == .unique) {
                var iter = c.scope.items[scope_index].borrow_set.iterator();
                while (iter.next()) |kv| {
                    const borrow_name = kv.key_ptr.*;
                    const borrow = kv.value_ptr;
                    if (borrow.kind == .shared) {
                        return fail(
                            c,
                            .{ .expr_id = expr_id },
                            "Can't uniquely borrow {s} because it borrows non-uniquely from {s}'",
                            .{ get.name, borrow_name },
                        );
                    }
                }
            }

            // This expression borrows from `get.name`.
            var bs = BorrowSet.init(allocator);
            bs.putNoClobber(get.name, .{ .kind = get.borrow_kind, .origin = expr_id }) catch oom();
            return bs;
        },
        .let => |let| {
            if (resolve(c.scope, let.name)) |scope_index| {
                return failAlreadyDefined(c, expr_id, c.scope.items[scope_index].expr_id, let.name);
            }

            const bs = try analyze(c, let.value);
            c.scope.append(allocator, .{
                .name = let.name,
                .expr_id = expr_id,
                .borrow_set = bs,
            }) catch oom();

            return BorrowSet.init(allocator);
        },
        .block => |block| {
            const scope_start = c.scope.items.len;
            defer resetScope(c, scope_start);

            var bs = BorrowSet.init(allocator);
            errdefer bs.deinit();

            for (block.statements) |statement| {
                const bs_statement = try analyze(c, statement);

                bs.deinit();
                bs = bs_statement;
            }

            if (block.return_null) {
                bs.deinit();
                bs = .init(allocator);
            }

            for (c.scope.items[scope_start..]) |scope_item| {
                if (bs.contains(scope_item.name.?)) {
                    return fail(
                        c,
                        .{ .expr_id = block.statements[block.statements.len - 1] },
                        "The value returned from this block borrows from {s}, but {s} will be destroyed at the end of this block.",
                        .{ scope_item.name.?, scope_item.name.? },
                    );
                }
            }

            return bs;
        },
        .@"if" => |@"if"| {
            var bs_cond = try analyze(c, @"if".cond);
            bs_cond.deinit();

            var bs_then = try analyze(c, @"if".then);
            defer bs_then.deinit();

            var bs_else = try analyze(c, @"if".@"else");
            defer bs_else.deinit();

            var bs = BorrowSet.init(allocator);
            errdefer bs.deinit();

            // This `if` borrows from everything borrowed in the `then` and `else` branches.
            // But the borrows in each branch must have matching kinds.
            std.mem.swap(BorrowSet, &bs, &bs_then);
            {
                var iter = bs_then.iterator();
                while (iter.next()) |kv| {
                    const name = kv.key_ptr.*;
                    const borrow_else = kv.value_ptr.*;
                    if (bs.get(name)) |borrow_then| {
                        if (borrow_then.kind == .unique and borrow_else.kind == .shared) {
                            return fail(
                                c,
                                .{ .expr_id = expr_id },
                                "The 'then' branch of this 'if' uniquely borrows {s} but the 'else' branch non-uniquely borrows {s}.",
                                .{ name, name },
                            );
                        }
                        if (borrow_then.kind == .shared and borrow_else.kind == .unique) {
                            return fail(
                                c,
                                .{ .expr_id = expr_id },
                                "The 'then' branch of this 'if' non-uniquely borrows {s} but the 'else' branch uniquely borrows {s}.",
                                .{ name, name },
                            );
                        }
                    } else {
                        bs.putNoClobber(name, borrow_else) catch oom();
                    }
                }
            }
            return bs;
        },
        .@"while" => |@"while"| {
            var bs_cond = try analyze(c, @"while".cond);
            bs_cond.deinit();

            var bs_body = try analyze(c, @"while".body);
            bs_body.deinit();

            return BorrowSet.init(allocator);
        },
        .@"fn" => |@"fn"| {
            const scope_start = c.scope.items.len;
            defer resetScope(c, scope_start);

            const fn_id = FnId{ .id = c.fns.items.len };

            const parent = c.fn_id_current;
            c.fn_id_current = fn_id;
            defer c.fn_id_current = parent;

            var unique_bitmap: u64 = 0;
            for (@"fn".params, 0..) |param, i| {
                if (param.borrow_kind == .unique)
                    unique_bitmap |= (@as(u64, 1) << @intCast(i));
            }
            c.fns.append(allocator, .{
                .parent = parent,
                .body_expr_id = @"fn".body,
                .captures = .{},
                .capture_name_to_index = .init(allocator),
                .scope_start = scope_start,
                .unique_bitmap = unique_bitmap,
            }) catch oom();
            c.expr_to_fn.put(expr_id, fn_id) catch oom();

            for (@"fn".params) |param| {
                // TODO Get decent error reporting out of this. A real name and expr_id.
                var bs_param = BorrowSet.init(allocator);
                bs_param.putNoClobber("<params>", .{ .kind = param.borrow_kind, .origin = expr_id }) catch oom();
                c.scope.append(allocator, .{ .name = param.name, .expr_id = expr_id, .borrow_set = bs_param }) catch oom();
            }

            var bs_fn = try analyze(c, @"fn".body);
            bs_fn.deinit();

            // This `fn` borrows from any name that it captures.
            var bs = BorrowSet.init(allocator);
            for (c.fns.items[fn_id.id].captures.items) |capture| {
                bs.putNoClobber(capture.name, capture.borrow) catch oom();
            }
            return bs;
        },
        .call => |*call| {
            const scope_start = c.scope.items.len;
            defer resetScope(c, scope_start);

            _ = try analyzeAndAddToScope(c, call.closure);

            for (call.args, 0..) |arg, i| {
                const bs_arg = try analyzeAndAddToScope(c, arg);

                var is_unique = false;
                var iter = bs_arg.iterator();
                while (iter.next()) |kv| is_unique |= kv.value_ptr.kind == .unique;
                if (is_unique) call.unique_bitmap |= @as(u64, 1) << @intCast(i);
            }

            return BorrowSet.init(allocator);
        },
        .call_builtin => |call_builtin| {
            const scope_start = c.scope.items.len;
            defer resetScope(c, scope_start);

            switch (call_builtin.builtin) {
                .@"+", .@"<", .copy => {
                    for (call_builtin.args) |arg|
                        _ = try analyzeAndAddToScope(c, arg);

                    return BorrowSet.init(allocator);
                },
                .get => {
                    try checkArgCount(c, expr_id, .{ .expected = 2, .actual = call_builtin.args.len });
                    const bs_tuple = try analyzeAndAddToScope(c, call_builtin.args[0]);
                    _ = try analyzeAndAddToScope(c, call_builtin.args[1]);

                    return bs_tuple.clone() catch oom();
                },
                .set => {
                    try checkArgCount(c, expr_id, .{ .expected = 3, .actual = call_builtin.args.len });
                    const bs_tuple = try analyzeAndAddToScope(c, call_builtin.args[0]);
                    _ = try analyzeAndAddToScope(c, call_builtin.args[1]);
                    const bs_elem = try analyzeAndAddToScope(c, call_builtin.args[2]);

                    // `tuple` must not contain any shared borrows.
                    {
                        var iter = bs_tuple.iterator();
                        while (iter.next()) |kv| {
                            const name = kv.key_ptr.*;
                            const borrow = kv.value_ptr.*;
                            if (borrow.kind == .shared) {
                                return fail(
                                    c,
                                    .{ .expr_id = call_builtin.args[0] },
                                    "Can't set an elem on this tuple because it borrows non-uniquely from {s}.'",
                                    .{name},
                                );
                            }
                        }
                    }

                    // 'elem' must not borrow from anything.
                    {
                        var iter = bs_elem.iterator();
                        if (iter.next()) |kv| {
                            const name = kv.key_ptr.*;
                            return fail(
                                c,
                                .{ .expr_id = call_builtin.args[2] },
                                "Can't set this elem because it borrows from {s}.",
                                .{name},
                            );
                        }
                    }

                    // The result is owned.
                    return BorrowSet.init(allocator);
                },
                .take => {
                    try checkArgCount(c, expr_id, .{ .expected = 2, .actual = call_builtin.args.len });
                    const bs_tuple = try analyzeAndAddToScope(c, call_builtin.args[0]);
                    _ = try analyzeAndAddToScope(c, call_builtin.args[1]);

                    // `tuple` must not contain any shared borrows.
                    {
                        var iter = bs_tuple.iterator();
                        while (iter.next()) |kv| {
                            const name = kv.key_ptr.*;
                            const borrow = kv.value_ptr.*;
                            if (borrow.kind == .shared) {
                                return fail(
                                    c,
                                    .{ .expr_id = call_builtin.args[0] },
                                    "Can't take an elem from this tuple because it borrows non-uniquely from {s}.'",
                                    .{name},
                                );
                            }
                        }
                    }

                    // The result is owned.
                    return BorrowSet.init(allocator);
                },
            }
        },
    }
}

fn analyzeAndAddToScope(c: *Compiler, expr_id: ExprId) error{Error}!BorrowSet {
    const bs = try analyze(c, expr_id);
    c.scope.append(allocator, .{ .name = null, .expr_id = expr_id, .borrow_set = bs }) catch oom();
    return bs;
}

fn resetScope(c: *Compiler, scope_start: usize) void {
    while (c.scope.items.len > scope_start) {
        var scope_item = c.scope.pop().?;
        scope_item.deinit();
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

    fn initBool(b: bool) Value {
        return if (b) Value.initTuple(0) else Value.initNull();
    }

    fn order(a: Value, b: Value) std.math.Order {
        switch (std.math.order(@intFromEnum(a.kind()), @intFromEnum(b.kind()))) {
            .lt => return .lt,
            .gt => return .gt,
            .eq => {},
        }
        switch (a.kind()) {
            .null => return .eq,
            .number => return std.math.order(a.asNumber().?, b.asNumber().?),
            .tuple => {
                const a_tuple = a.asTuple().?;
                const b_tuple = b.asTuple().?;
                for (0..@min(a_tuple.len, b_tuple.len)) |i| {
                    switch (Value.order(a_tuple[i], b_tuple[i])) {
                        .lt => return .lt,
                        .gt => return .gt,
                        .eq => {},
                    }
                }
                return std.math.order(a_tuple.len, b_tuple.len);
            },
            .closure => {
                const a_closure = a.asClosure().?;
                const b_closure = b.asClosure().?;
                switch (std.math.order(a_closure.fn_id.id, b_closure.fn_id.id)) {
                    .lt => return .lt,
                    .gt => return .gt,
                    .eq => {},
                }
                for (0..@min(a_closure.capture_values.len, b_closure.capture_values.len)) |i| {
                    switch (Value.order(a_closure.capture_values[i], b_closure.capture_values[i])) {
                        .lt => return .lt,
                        .gt => return .gt,
                        .eq => {},
                    }
                }
                return std.math.order(a_closure.capture_values.len, b_closure.capture_values.len);
            },
        }
    }

    pub fn copy(value: Value) Value {
        switch (value.kind()) {
            .null => {
                return value;
            },
            .number => {
                return .initNumber(value.asNumber().?);
            },
            .tuple => {
                const in = value.asTuple().?;
                const out = Value.initTuple(in.len);
                for (out.asTuple().?, in) |*out_elem, in_elem| {
                    out_elem.* = in_elem.copy();
                }
                return out;
            },
            .closure => {
                const in = value.asClosure().?;
                const out = Value.initClosure(in.fn_id, in.capture_values.len);
                for (out.asClosure().?.capture_values, in.capture_values) |*out_elem, in_elem| {
                    out_elem.* = in_elem.copy();
                }
                return out;
            },
        }
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
    name: ?[]const u8,
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
        .get => |get| {
            const binding_index = resolve(c.bindings, get.name).?;
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
            while (true) {
                var cond = try eval(c, @"while".cond);
                defer cond.deinit();

                if (cond.kind() == .null) break;

                var value = try eval(c, @"while".body);
                defer value.deinit();
            }

            return Value.initNull();
        },
        .@"fn" => {
            const fn_id = c.expr_to_fn.get(expr_id).?;
            const @"fn" = &c.fns.items[fn_id.id];

            var value = Value.initClosure(fn_id, @"fn".captures.items.len);
            defer value.deinit();

            for (@"fn".captures.items, value.asClosure().?.capture_values) |capture, *capture_value| {
                const binding_index = resolve(c.bindings, capture.name).?;
                capture_value.* = c.bindings.items[binding_index].value.borrow();
            }

            return value.take();
        },
        .call => |call| {
            var closure_value = try eval(c, call.closure);
            defer closure_value.deinit();

            try checkKind(c, call.closure, .{ .expected = .closure, .actual = closure_value.kind() });
            const closure = closure_value.asClosure().?;
            const @"fn" = &c.fns.items[closure.fn_id.id];

            const missing_unique_bitmap = @"fn".unique_bitmap & ~call.unique_bitmap;
            if (missing_unique_bitmap != 0) {
                const arg_index = @ctz(missing_unique_bitmap);
                return fail(
                    c,
                    .{ .expr_id = call.args[arg_index] },
                    "The callee expected this argument to be uniquely shared, but it was not.",
                    .{},
                );
            }

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

            for (@"fn".captures.items, closure.capture_values) |capture, capture_value| {
                c.bindings.append(allocator, .{ .name = capture.name, .value = capture_value.borrow() }) catch oom();
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
                    try checkArgCount(c, expr_id, .{ .expected = 2, .actual = args.len });
                    try checkKind(c, call_builtin.args[0], .{ .expected = .number, .actual = args[0].kind() });
                    try checkKind(c, call_builtin.args[1], .{ .expected = .number, .actual = args[1].kind() });
                    return Value.initNumber(args[0].asNumber().? +% args[1].asNumber().?);
                },
                .@"<" => {
                    try checkArgCount(c, expr_id, .{ .expected = 2, .actual = args.len });
                    return Value.initBool(Value.order(args[0], args[1]) == .lt);
                },
                .get => {
                    try checkArgCount(c, expr_id, .{ .expected = 2, .actual = args.len });
                    try checkKind(c, call_builtin.args[0], .{ .expected = .tuple, .actual = args[0].kind() });
                    try checkKind(c, call_builtin.args[1], .{ .expected = .number, .actual = args[1].kind() });
                    const value_ptr = try getPtr(c, expr_id, args[0..2]);
                    return value_ptr.borrow();
                },
                .set => {
                    try checkArgCount(c, expr_id, .{ .expected = 3, .actual = args.len });
                    try checkKind(c, call_builtin.args[0], .{ .expected = .tuple, .actual = args[0].kind() });
                    try checkKind(c, call_builtin.args[1], .{ .expected = .number, .actual = args[1].kind() });
                    const value_ptr = try getPtr(c, expr_id, args[0..2]);
                    const value_old = value_ptr.take();
                    value_ptr.* = args[2].take();
                    return value_old;
                },
                .take => {
                    try checkArgCount(c, expr_id, .{ .expected = 2, .actual = args.len });
                    try checkKind(c, call_builtin.args[0], .{ .expected = .tuple, .actual = args[0].kind() });
                    try checkKind(c, call_builtin.args[1], .{ .expected = .number, .actual = args[1].kind() });
                    const value_ptr = try getPtr(c, expr_id, args[0..2]);
                    return value_ptr.take();
                },
                .copy => {
                    try checkArgCount(c, expr_id, .{ .expected = 1, .actual = args.len });
                    return args[0].copy();
                },
            }
        },
    }
}

fn getPtr(c: *Compiler, expr_id: ExprId, args: *[2]Value) error{Error}!*Value {
    const tuple = args[0].asTuple().?;
    const index = args[1].asNumber().?;
    if (index >= 0 and index < tuple.len) {
        return &tuple[@intCast(index)];
    } else {
        return fail(
            c,
            .{ .expr_id = expr_id },
            "Index {f} is out of bounds for tuple {f}",
            .{ args[1], args[0] },
        );
    }
}

fn checkArgCount(c: *Compiler, expr_id: ExprId, opts: struct { expected: usize, actual: usize }) error{Error}!void {
    if (opts.expected != opts.actual)
        return fail(
            c,
            .{ .expr_id = expr_id },
            "Expected {} arguments but found {} arguments",
            .{ opts.expected, opts.actual },
        );
}

fn checkKind(c: *Compiler, expr_id: ExprId, opts: struct { expected: Kind, actual: Kind }) error{Error}!void {
    if (opts.expected != opts.actual)
        return fail(
            c,
            .{ .expr_id = expr_id },
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
