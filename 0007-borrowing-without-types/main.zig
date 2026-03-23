const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const panic = std.debug.panic;

const allocator = std.heap.c_allocator;

fn oom() noreturn {
    panic("OOM", .{});
}

fn assert(cond: bool) void {
    if (!cond) panic("Assert failed", .{});
}

fn pp(args: anytype) void {
    std.debug.print("{any}\n", .{args});
}

fn pf(args: anytype) void {
    std.debug.print("{f}\n", .{args});
}

const debug = true;

// Big 'ol production-quality global.
var c: Compiler = undefined;

const Compiler = struct {
    source: []const u8,

    // tokenize
    tokens: ArrayList(Token),
    token_to_range: ArrayList([2]usize),

    // parse
    expr_len: ?ExprId,
    exprs: ArrayList(Expr),
    expr_to_tokens: ArrayList([2]TokenId),
    token_next: TokenId,

    // analyze
    fns: ArrayList(Fn),
    expr_to_fn: std.AutoHashMap(ExprId, FnId),
    scope: Stack(ScopeItem),
    fn_id_current: ?FnId,

    // eval
    stack: Stack(StackItem),
    stack_top: usize,
    stack_data: []u64,
    stack_provenance: []Provenance,
    types: ArrayList(Type),
    type_to_ref_indexes: ArrayList([]RefIndex),
    type_number: ?TypeId,
    type_tuple_empty: ?TypeId,
    type_tuple: std.HashMap([]TypeId, TypeId, TypeIdsHashContext, std.hash_map.default_max_load_percentage),
    type_ref: std.AutoHashMap(TypeId, TypeId),
    type_closure: std.AutoHashMap(FnId, TypeId),

    error_message: ?[]u8,

    pub fn init(source: []const u8) Compiler {
        return .{
            .source = source,

            .tokens = .{},
            .token_to_range = .{},

            .expr_len = null,
            .exprs = .{},
            .expr_to_tokens = .{},
            .token_next = .{ .id = 0 },

            .fns = .{},
            .expr_to_fn = .init(allocator),
            .scope = .init(1024),
            .fn_id_current = null,

            .stack = .init(stack_size),
            .stack_top = 0,
            .stack_data = allocator.alloc(u64, stack_size) catch oom(),
            .stack_provenance = allocator.alloc(Provenance, stack_size) catch oom(),
            .types = .{},
            .type_to_ref_indexes = .{},
            .type_number = null,
            .type_tuple_empty = null,
            .type_tuple = .init(allocator),
            .type_ref = .init(allocator),
            .type_closure = .init(allocator),

            .error_message = null,
        };
    }

    pub fn deinit(compiler: *Compiler) void {
        compiler.tokens.deinit(allocator);
        compiler.token_to_range.deinit(allocator);

        for (compiler.exprs.items) |expr| expr.deinit();
        compiler.exprs.deinit(allocator);
        compiler.expr_to_tokens.deinit(allocator);

        compiler.fns.deinit(allocator);
        compiler.expr_to_fn.deinit();
        compiler.scope.deinit();

        while (compiler.stack.len > 0) compiler.stack.pop().deinit();
        compiler.stack.deinit();
        allocator.free(compiler.stack_data);
        allocator.free(compiler.stack_provenance);
        for (compiler.types.items) |@"type"| @"type".deinit();
        compiler.types.deinit(allocator);
        for (compiler.type_to_ref_indexes.items) |ref_indexes| allocator.free(ref_indexes);
        compiler.type_to_ref_indexes.deinit(allocator);
        compiler.type_tuple.deinit();
        compiler.type_ref.deinit();
        compiler.type_closure.deinit();

        if (compiler.error_message) |err| allocator.free(err);
    }
};

const TypeIdsHashContext = struct {
    pub fn eql(_: @This(), type_ids_a: []TypeId, type_ids_b: []TypeId) bool {
        return std.mem.eql(TypeId, type_ids_a, type_ids_b);
    }

    pub fn hash(_: @This(), type_ids: []TypeId) u64 {
        var hasher = std.hash.Wyhash.init(0);
        for (type_ids) |type_id|
            std.hash.autoHash(&hasher, type_id);
        return hasher.final();
    }
};

const StackItemsHashContext = struct {
    pub fn eql(_: @This(), items: []StackItem, type_ids: []TypeId) bool {
        if (items.len != type_ids.len) return false;
        for (items, type_ids) |item, type_id|
            if (item.value.type_id != type_id) return false;
        return true;
    }

    pub fn hash(_: @This(), items: []StackItem) u64 {
        var hasher = std.hash.Wyhash.init(0);
        for (items) |item|
            std.hash.autoHash(&hasher, item.value.type_id);
        return hasher.final();
    }
};

const stack_size = 1024 * 1024;

const StackIndex = std.math.IntFittingRange(0, stack_size);

fn Stack(comptime Item: type) type {
    return struct {
        items: []Item,
        len: usize,

        const Self = @This();

        fn init(count: usize) Self {
            return .{
                .items = allocator.alloc(Item, count) catch oom(),
                .len = 0,
            };
        }

        fn deinit(self: Self) void {
            allocator.free(self.items);
        }

        fn push(self: *Self, item: Item) void {
            self.items[self.len] = item;
            self.len += 1;
        }

        fn pop(self: *Self) Item {
            self.len -= 1;
            return self.items[self.len];
        }

        fn peek(self: *Self) *Item {
            return &self.items[self.len - 1];
        }
    };
}

pub fn run() ![]const u8 {
    try tokenize();
    c.expr_len = try parse();
    try analyze(c.expr_len.?);
    try eval(c.expr_len.?);
    assert(c.stack.len == 1);
    const result = c.stack.peek();
    return std.fmt.allocPrint(allocator, "{f}", .{result.value});
}

const SourceLocation = union(enum) {
    pos: usize,
    token_id: TokenId,
    expr_id: ExprId,
};

fn fail(source_location: SourceLocation, comptime fmt: []const u8, args: anytype) error{Error} {
    if (debug) assert(c.error_message == null);
    const line_col = lineColFromSourceLocation(source_location);
    c.error_message = std.fmt.allocPrint(allocator, "Error at {}:{}\n" ++ fmt, .{ line_col[0], line_col[1] } ++ args) catch oom();
    return error.Error;
}

fn lineColFromSourceLocation(source_location_orig: SourceLocation) [2]usize {
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
    // Punctuation.
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
    @"^",
    @"!",
    @"&",
    @"*",

    // Keywords.
    let,
    @"if",
    @"else",
    @"while",
    @"fn",
    ref,

    // Tokens whose text matters.
    name,
    number,

    // End of file.
    eof,
};

pub fn tokenize() !void {
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
            '^' => .@"^",
            '!' => .@"!",
            '&' => .@"&",
            '*' => .@"*",
            '/' => {
                if (pos < source.len and source[pos] == '/') {
                    while (pos < source.len and source[pos] != '\n') {
                        pos += 1;
                    }
                    continue :next_token;
                } else {
                    return failBadToken(start);
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
                    .ref,
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
            else => return failBadToken(start),
        };
        _ = c.tokens.append(allocator, token) catch oom();
        _ = c.token_to_range.append(allocator, .{ start, pos }) catch oom();
    }

    _ = c.tokens.append(allocator, .eof) catch oom();
    _ = c.token_to_range.append(allocator, .{ pos, pos }) catch oom();
}

fn failBadToken(pos: usize) error{Error} {
    return fail(
        .{ .pos = pos },
        "Bad token",
        .{},
    );
}

// --- PARSE ---

const ExprId = packed struct { id: usize };

const Expr = union(enum) {
    number: i64,
    tuple: []ExprId,
    get: struct {
        name: []const u8,
        stack_reverse_index: StackIndex,
        allow_moved: bool,
    },
    move: ExprId,
    borrow: ExprId,
    share: ExprId,
    deref: ExprId,
    let: struct {
        pattern: ExprId,
        value: ExprId,
    },
    block: struct {
        statements: []ExprId, // non-empty
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
        captures: []ExprId,
        capture_mode: CaptureMode,
        params: []ExprId,
        body: ExprId,
    },
    capture: struct {
        name: []const u8,
        mode: CaptureMode,
    },
    param: struct {
        name: []const u8,
    },
    call: struct {
        closure: ExprId,
        args: []ExprId,
    },
    call_builtin: struct {
        builtin: Builtin,
        args: []ExprId,
    },
    tuple_get: struct {
        tuple: ExprId,
        index: ExprId,
    },

    fn deinit(expr: Expr) void {
        switch (expr) {
            .tuple => |exprs| allocator.free(exprs),
            .block => |block| allocator.free(block.statements),
            .@"fn" => |@"fn"| allocator.free(@"fn".params),
            .call => |call| allocator.free(call.args),
            .call_builtin => |call_builtin| allocator.free(call_builtin.args),
            .number, .get, .move, .borrow, .share, .deref, .let, .@"if", .@"while", .capture, .param, .tuple_get => {},
        }
    }
};

const CaptureMode = enum {
    move,
    borrow,
    share,
    copy,
};

const Builtin = enum {
    @"=",
    @"+",
    @"<",
    ref,
};

fn parse() error{Error}!ExprId {
    const start = c.token_next;
    const root = try parseBlockInner(start, .eof);
    try expect(.eof);
    return root;
}

fn parseExprLoose() error{Error}!ExprId {
    const start = c.token_next;
    var expr = try parseExprTight();
    var last_op: ?Builtin = null;
    while (true) {
        switch (peek()) {
            .@"=", .@"+", .@"<" => |token| {
                const op: Builtin = switch (token) {
                    .@"=" => .@"=",
                    .@"+" => .@"+",
                    .@"<" => .@"<",
                    else => unreachable,
                };
                if (last_op != null and last_op.? != op) {
                    return fail(
                        .{ .token_id = c.token_next },
                        "Ambiguous precedence: `{s}` vs `{s}`",
                        .{
                            @tagName(last_op.?),
                            @tagName(op),
                        },
                    );
                }
                last_op = op;
                _ = take();

                const right = try parseExprTight();
                expr = pushExpr(start, .{
                    .call_builtin = .{
                        .builtin = op,
                        .args = allocator.dupe(ExprId, &.{ expr, right }) catch oom(),
                    },
                });
            },
            else => break,
        }
    }
    return expr;
}

fn parseExprTight() error{Error}!ExprId {
    var expr = try parseExprBase();
    while (true) {
        switch (peek()) {
            .@"(" => expr = try parseCall(expr),
            .@"[" => expr = try parseTupleGet(expr),
            .@"^" => expr = try parseMove(expr),
            .@"!" => expr = try parseBorrow(expr),
            .@"&" => expr = try parseShare(expr),
            .@"*" => expr = try parseDeref(expr),
            else => break,
        }
    }
    return expr;
}

fn parseCall(closure: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[closure.id][0];
    const args = try parseArgs();
    return pushExpr(start, .{
        .call = .{
            .closure = closure,
            .args = args,
        },
    });
}

fn parseArgs() error{Error}![]ExprId {
    try expect(.@"(");

    var args: ArrayList(ExprId) = .{};
    defer args.deinit(allocator);

    while (true) {
        if (peek() == .@")") break;
        const arg = try parseExprLoose();
        args.append(allocator, arg) catch oom();
        if (!takeIf(.@",")) break;
    }

    try expect(.@")");

    return args.toOwnedSlice(allocator) catch oom();
}

fn parseTupleGet(tuple: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[tuple.id][0];
    try expect(.@"[");
    const index = try parseExprLoose();
    try expect(.@"]");
    return pushExpr(start, .{
        .tuple_get = .{
            .tuple = tuple,
            .index = index,
        },
    });
}

fn parseMove(path: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[path.id][0];
    try expect(.@"^");
    return pushExpr(start, .{ .move = path });
}

fn parseBorrow(path: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[path.id][0];
    try expect(.@"!");
    return pushExpr(start, .{ .borrow = path });
}

fn parseShare(path: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[path.id][0];
    try expect(.@"&");
    return pushExpr(start, .{ .share = path });
}

fn parseDeref(ref: ExprId) error{Error}!ExprId {
    const start = c.expr_to_tokens.items[ref.id][0];
    try expect(.@"*");
    return pushExpr(start, .{ .deref = ref });
}

fn parseExprBase() error{Error}!ExprId {
    return switch (peek()) {
        .number => parseNumber(),
        .@"[" => parseList(),
        .name => parseGet(),
        .@"{" => parseBlock(),
        .@"if" => parseIf(),
        .@"while" => parseWhile(),
        .@"fn" => parseFn(),
        .ref => parseCallBuiltin(),
        else => failExpected("an expression"),
    };
}

fn parseNumber() error{Error}!ExprId {
    const start = c.token_next;
    const source = peekSource();
    const number = std.fmt.parseInt(i64, source, 10) catch |err| {
        const reason: []const u8 = switch (err) {
            error.Overflow => "overflow",
            error.InvalidCharacter => "invalid character",
        };
        return fail(
            .{ .token_id = c.token_next },
            "Failed to parse integer due to {s}",
            .{reason},
        );
    };
    try expect(.number);
    return pushExpr(start, .{ .number = number });
}

fn parseList() error{Error}!ExprId {
    const start = c.token_next;

    try expect(.@"[");

    var elems: ArrayList(ExprId) = .{};
    defer elems.deinit(allocator);

    while (true) {
        if (peek() == .@"]") break;
        const elem = try parseExprLoose();
        elems.append(allocator, elem) catch oom();
        if (!takeIf(.@",")) break;
    }

    try expect(.@"]");

    return pushExpr(start, .{ .tuple = elems.toOwnedSlice(allocator) catch oom() });
}

fn parseGet() error{Error}!ExprId {
    const start = c.token_next;
    const name = try expectName();
    return pushExpr(start, .{
        .get = .{
            .name = name,
            // These are filled in later by `analyze`.
            .stack_reverse_index = 0,
            .allow_moved = false,
        },
    });
}

fn parseBlock() error{Error}!ExprId {
    const start = c.token_next;
    try expect(.@"{");
    const block = try parseBlockInner(start, .@"}");
    try expect(.@"}");
    return block;
}

fn parseBlockInner(start: TokenId, end: Token) error{Error}!ExprId {
    var statements: ArrayList(ExprId) = .{};
    defer statements.deinit(allocator);

    const return_last = while (true) {
        if (peek() == end) break false;
        const statement = if (peek() == .let) try parseLet() else try parseExprLoose();
        statements.append(allocator, statement) catch oom();
        if (!takeIf(.@";")) break true;
    };

    if (!return_last or statements.items.len == 0) {
        const statement = pushExpr(c.token_next, .{ .tuple = &.{} });
        statements.append(allocator, statement) catch oom();
    }

    if (statements.items.len == 1 and c.exprs.items[statements.items[0].id] != .let) {
        // This looks like `{ x }` - we don't need to create a block.
        return statements.items[0];
    } else {
        return pushExpr(start, .{
            .block = .{
                .statements = statements.toOwnedSlice(allocator) catch oom(),
            },
        });
    }
}

fn parseLet() error{Error}!ExprId {
    const start = c.token_next;
    try expect(.let);
    const pattern = try parseExprTight();
    try expect(.@"=");
    const value = try parseExprLoose();
    return pushExpr(start, .{ .let = .{ .pattern = pattern, .value = value } });
}

fn parseIf() error{Error}!ExprId {
    const start = c.token_next;
    try expect(.@"if");
    const cond = try parseExprLoose();
    const then = try parseBlock();
    try expect(.@"else");
    const @"else" = try parseBlock();
    return pushExpr(start, .{ .@"if" = .{ .cond = cond, .then = then, .@"else" = @"else" } });
}

fn parseWhile() error{Error}!ExprId {
    const start = c.token_next;
    try expect(.@"while");
    const cond = try parseExprLoose();
    const body = try parseBlock();
    return pushExpr(start, .{ .@"while" = .{ .cond = cond, .body = body } });
}

fn parseFn() error{Error}!ExprId {
    const start = c.token_next;
    try expect(.@"fn");

    var captures: ArrayList(ExprId) = .{};
    defer captures.deinit(allocator);

    var capture_mode = CaptureMode.copy;

    if (takeIf(.@"[")) {
        while (true) {
            if (peek() == .@"]") break;
            const capture = try parseCapture();
            captures.append(allocator, capture) catch oom();
            if (!takeIf(.@",")) break;
        }
        try expect(.@"]");
        capture_mode = parseCaptureMode();
    }

    try expect(.@"(");

    var params: ArrayList(ExprId) = .{};
    defer params.deinit(allocator);

    while (true) {
        if (peek() == .@")") break;
        const param = try parseParam();
        params.append(allocator, param) catch oom();
        if (!takeIf(.@",")) break;
    }

    try expect(.@")");
    const body = try parseBlock();

    return pushExpr(start, .{
        .@"fn" = .{
            .captures = captures.toOwnedSlice(allocator) catch oom(),
            .capture_mode = capture_mode,
            .params = params.toOwnedSlice(allocator) catch oom(),
            .body = body,
        },
    });
}

fn parseCapture() error{Error}!ExprId {
    const start = c.token_next;
    const name = try expectName();
    const mode = parseCaptureMode();
    return pushExpr(start, .{ .capture = .{ .name = name, .mode = mode } });
}

fn parseCaptureMode() CaptureMode {
    return if (takeIf(.@"^"))
        .move
    else if (takeIf(.@"!"))
        .borrow
    else if (takeIf(.@"&"))
        .share
    else
        .copy;
}

fn parseParam() error{Error}!ExprId {
    const start = c.token_next;
    const name = try expectName();
    return pushExpr(start, .{ .param = .{ .name = name } });
}

fn parseCallBuiltin() error{Error}!ExprId {
    const start = c.token_next;

    const builtin: Builtin = switch (peek()) {
        .ref => .ref,
        else => return failExpected("a builtin function"),
    };
    _ = take();

    const args = try parseArgs();
    const expr_id = pushExpr(start, .{ .call_builtin = .{ .builtin = builtin, .args = args } });
    return expr_id;
}

fn expect(expected: Token) error{Error}!void {
    const actual = peek();
    if (expected != actual) {
        return fail(
            .{ .token_id = c.token_next },
            "Expected a `{s}` but found a `{s}`",
            .{ @tagName(expected), @tagName(actual) },
        );
    }
    _ = take();
}

fn expectName() error{Error}![]const u8 {
    const name = peekSource();
    try expect(.name);
    return name;
}

fn peek() Token {
    return c.tokens.items[c.token_next.id];
}

fn peekSource() []const u8 {
    const range = c.token_to_range.items[c.token_next.id];
    return c.source[range[0]..range[1]];
}

fn take() Token {
    const token = peek();
    c.token_next.id += 1;
    return token;
}

fn takeIf(expected: Token) bool {
    const token = peek();
    if (token == expected) c.token_next.id += 1;
    return token == expected;
}

fn pushExpr(start: TokenId, expr: Expr) ExprId {
    const expr_id = ExprId{ .id = c.exprs.items.len };
    c.exprs.append(allocator, expr) catch oom();
    c.expr_to_tokens.append(allocator, .{ start, c.token_next }) catch oom();
    return expr_id;
}

fn failExpected(expected: []const u8) error{Error} {
    const actual = c.tokens.items[c.token_next.id];
    return fail(
        .{ .token_id = c.token_next },
        "Expected {s} but found a `{s}`",
        .{ expected, @tagName(actual) },
    );
}

// --- ANALYZE ---

const FnId = packed struct { id: usize };

const Fn = struct {
    parent: ?FnId,
    fn_expr_id: ExprId,
    scope_start: usize,
};

const ScopeItem = struct {
    name: ?[]const u8,
};

fn resolve(name: []const u8) ?usize {
    const items = c.scope.items[0..c.scope.len];
    var i = items.len;
    while (i > 0) : (i -= 1) {
        const index = i - 1;
        const item = items[index];
        if (item.name) |item_name|
            if (std.mem.eql(u8, item_name, name))
                return index;
    }
    return null;
}

fn analyzePath(expr_id: ExprId) error{Error}!void {
    switch (c.exprs.items[expr_id.id]) {
        .get => |*get| {
            const scope_index = resolve(get.name) orelse
                return failNotDefined(expr_id, get.name);

            if (c.fn_id_current) |fn_id| {
                const @"fn" = &c.fns.items[fn_id.id];
                if (scope_index < @"fn".scope_start) {
                    return fail(
                        .{ .expr_id = expr_id },
                        "Can't refer to `{s}` here because it is defined outside this function - try using an explicit capture instead.",
                        .{get.name},
                    );
                }
            }

            get.stack_reverse_index = @intCast(c.scope.len - scope_index);
        },
        .deref => |path| {
            try analyzePath(path);
        },
        .tuple_get => |tuple_get| {
            try analyzePath(tuple_get.tuple);

            try analyze(tuple_get.index);
            _ = c.scope.pop();
        },
        else => |other| {
            return fail(.{ .expr_id = expr_id }, "Not a valid path: {s}", .{@tagName(other)});
        },
    }
}

fn analyzePattern(expr_id: ExprId) error{Error}!void {
    switch (c.exprs.items[expr_id.id]) {
        .get => |get| {
            c.scope.push(.{ .name = get.name });
        },
        .tuple => |elems| {
            for (elems) |elem|
                try analyzePattern(elem);
        },
        else => |other| {
            return fail(.{ .expr_id = expr_id }, "Not a valid pattern: {s}", .{@tagName(other)});
        },
    }
}

fn analyze(expr_id: ExprId) error{Error}!void {
    switch (c.exprs.items[expr_id.id]) {
        .get, .deref, .tuple_get => {
            try analyzePath(expr_id);
        },
        .move, .borrow, .share => |child| {
            try analyzePath(child);
        },
        .number => {},
        .tuple => |tuple| {
            for (tuple) |elem|
                try analyze(elem);

            for (tuple) |_|
                _ = c.scope.pop();
        },
        .let => |let| {
            try analyze(let.value);
            _ = c.scope.pop();
            try analyzePattern(let.pattern);
        },
        .block => |block| {
            const scope_start = c.scope.len;
            defer c.scope.len = scope_start;

            for (block.statements) |statement| {
                try analyze(statement);
                _ = c.scope.pop();
            }
        },
        .@"if" => |@"if"| {
            try analyze(@"if".cond);
            _ = c.scope.pop();

            try analyze(@"if".then);
            _ = c.scope.pop();

            try analyze(@"if".@"else");
            _ = c.scope.pop();
        },
        .@"while" => |@"while"| {
            try analyze(@"while".cond);
            _ = c.scope.pop();

            try analyze(@"while".body);
            _ = c.scope.pop();
        },
        .@"fn" => |@"fn"| {
            const scope_start = c.scope.len;
            defer c.scope.len = scope_start;

            const fn_id = FnId{ .id = c.fns.items.len };

            const parent = c.fn_id_current;
            c.fn_id_current = fn_id;
            defer c.fn_id_current = parent;

            c.fns.append(allocator, .{
                .parent = parent,
                .fn_expr_id = expr_id,
                .scope_start = scope_start,
            }) catch oom();
            c.expr_to_fn.put(expr_id, fn_id) catch oom();

            for (@"fn".params) |param_id| {
                const param = c.exprs.items[param_id.id].param;
                c.scope.push(.{ .name = param.name });
            }

            try analyze(@"fn".body);
        },
        .capture, .param => {
            // Handled directly in @"fn" above.
            unreachable;
        },
        .call => |*call| {
            try analyze(call.closure);
            for (call.args) |arg|
                try analyze(arg);

            _ = c.scope.pop();
            for (call.args) |_|
                _ = c.scope.pop();
        },
        .call_builtin => |call_builtin| {
            const scope_start = c.scope.len;
            defer c.scope.len = scope_start;

            try checkArgCount(expr_id, .{
                .expected = switch (call_builtin.builtin) {
                    .ref => 1,
                    .@"=", .@"+", .@"<" => 2,
                },
                .actual = call_builtin.args.len,
            });

            switch (call_builtin.builtin) {
                .@"=" => {
                    const arg0 = &c.exprs.items[call_builtin.args[0].id];
                    if (arg0.* == .get)
                        arg0.get.allow_moved = true;
                    try analyzePath(call_builtin.args[0]);
                    try analyze(call_builtin.args[1]);
                },
                .ref, .@"+", .@"<" => {
                    for (call_builtin.args) |arg|
                        try analyze(arg);

                    for (call_builtin.args) |_|
                        _ = c.scope.pop();
                },
            }
        },
    }

    c.scope.push(.{ .name = null });
}

fn failNotDefined(expr_id: ExprId, name: []const u8) error{Error} {
    return fail(
        .{ .expr_id = expr_id },
        "Name `{s}` is not defined at this point",
        .{name},
    );
}

// --- EVAL ---

const TypeId = packed struct {
    id: usize,

    fn getRefIndexes(type_id: TypeId) []RefIndex {
        return c.type_to_ref_indexes.items[type_id.id];
    }

    fn wordSize(type_id: TypeId) usize {
        // TODO precompute this
        switch (c.types.items[type_id.id]) {
            .number => return 1,
            .tuple => |tuple| {
                var size: usize = 0;
                for (tuple.elems) |elem| {
                    size += elem.wordSize();
                }
                return size;
            },
            .ref => |ref| {
                return switch (ref.elem) {
                    .known => 1,
                    .any => 2,
                };
            },
            .closure => return 0,
        }
    }

    fn order(a_id: TypeId, b_id: TypeId) std.math.Order {
        if (a_id == b_id) return .eq;
        const a = c.types.items[a_id.id];
        const b = c.types.items[b_id.id];
        switch (std.math.order(@intFromEnum(a), @intFromEnum(b))) {
            .lt => return .lt,
            .gt => return .gt,
            .eq => {},
        }
        switch (a) {
            .number => return .eq,
            .tuple => {
                for (0..@min(a.tuple.elems.len, b.tuple.elems.len)) |i| {
                    switch (TypeId.order(a.tuple.elems[i], b.tuple.elems[i])) {
                        .lt => return .lt,
                        .gt => return .gt,
                        .eq => {},
                    }
                }
                return std.math.order(a.tuple.elems.len, b.tuple.elems.len);
            },
            .ref => {
                switch (std.math.order(@intFromEnum(a.ref.elem), @intFromEnum(b.ref.elem))) {
                    .lt => return .lt,
                    .gt => return .gt,
                    .eq => {},
                }
                switch (a.ref.elem) {
                    .any => return .eq,
                    .known => return TypeId.order(a.ref.elem.known, b.ref.elem.known),
                }
            },
            .closure => return .eq,
        }
    }

    pub fn format(type_id: TypeId, writer: *std.io.Writer) std.io.Writer.Error!void {
        try c.types.items[type_id.id].format(writer);
    }
};

const Type = union(enum) {
    number,
    tuple: TypeTuple,
    ref: TypeRef,
    closure: TypeClosure,

    fn deinit(@"type": Type) void {
        switch (@"type") {
            .number => {},
            .tuple => |tuple| tuple.deinit(),
            .ref => |ref| ref.deinit(),
            .closure => |closure| closure.deinit(),
        }
    }

    fn makeRefIndexes(@"type": Type, type_id: TypeId) []RefIndex {
        var indexes: ArrayList(RefIndex) = .{};
        switch (@"type") {
            .number => {},
            .tuple => |tuple| {
                var word_offset: usize = 0;
                for (tuple.elems) |elem| {
                    for (elem.getRefIndexes()) |ref_index| {
                        indexes.append(allocator, .{
                            .word_offset = word_offset + ref_index.word_offset,
                            .type_id = ref_index.type_id,
                        }) catch oom();
                    }
                    word_offset += elem.wordSize();
                }
            },
            .ref => {
                indexes.append(allocator, .{
                    .word_offset = 0,
                    .type_id = type_id,
                }) catch oom();
            },
            .closure => {},
        }
        return indexes.toOwnedSlice(allocator) catch oom();
    }

    pub fn format(@"type": Type, writer: *std.io.Writer) std.io.Writer.Error!void {
        switch (@"type") {
            .number => {
                try writer.print("number", .{});
            },
            .tuple => |tuple| {
                try writer.print("[", .{});
                for (0..tuple.elems.len) |i| {
                    if (i != 0)
                        try writer.print(", ", .{});
                    try writer.print("{f}", .{tuple.elems[i]});
                }
                try writer.print("]", .{});
            },
            .ref => |ref| {
                switch (ref.elem) {
                    .known => |known| try writer.print("ref({f})", .{known}),
                    .any => try writer.print("ref(any)", .{}),
                }
            },
            .closure => |closure| {
                try writer.print("fn({})", .{closure.fn_id});
            },
        }
    }
};

const TypeTuple = struct {
    elems: []TypeId,

    fn deinit(tuple: TypeTuple) void {
        allocator.free(tuple.elems);
    }

    fn wordOffset(tuple: TypeTuple, index: usize) usize {
        var offset: usize = 0;
        for (tuple.elems[0..index]) |elem| {
            offset += elem.wordSize();
        }
        return offset;
    }
};

const TypeRef = struct {
    elem: union(enum) {
        known: TypeId,
        any,
    },

    fn deinit(_: TypeRef) void {}
};

const TypeClosure = struct {
    fn_id: FnId,

    fn deinit(_: TypeClosure) void {}
};

const RefIndex = struct {
    word_offset: usize,
    type_id: TypeId,
};

const Value = struct {
    ptr: [*]u64,
    type_id: TypeId,

    fn getNumber(value: Value) i64 {
        _ = c.types.items[value.type_id.id].number;
        return @bitCast(value.ptr[0]);
    }

    fn getBool(value: Value) bool {
        // Zero is falsey. Everything else is truthy.
        if (c.types.items[value.type_id.id] != .number) return true;
        return value.getNumber() != 0;
    }

    fn setNumber(value: Value, number: i64) void {
        _ = c.types.items[value.type_id.id].number;
        value.ptr[0] = @bitCast(number);
    }

    fn getTupleElem(value: Value, index: usize) Value {
        const tuple = c.types.items[value.type_id.id].tuple;
        return .{
            .ptr = value.ptr + tuple.wordOffset(index),
            .type_id = tuple.elems[index],
        };
    }

    fn getRefElem(value: Value) Value {
        const ref = c.types.items[value.type_id.id].ref;
        return .{
            .ptr = @ptrFromInt(value.ptr[0]),
            .type_id = switch (ref.elem) {
                .known => |known| known,
                .any => @bitCast(value.ptr[1]),
            },
        };
    }

    fn setRefElem(value: Value, elem: Value) void {
        const ref = c.types.items[value.type_id.id].ref;
        if (debug) switch (ref.elem) {
            .known => |known| assert(known == elem.type_id),
            .any => {},
        };
        value.ptr[0] = @intFromPtr(elem.ptr);
    }

    fn allocStackWithoutInit(type_id: TypeId) Value {
        const size = type_id.wordSize();
        const ptr = &c.stack_data[c.stack_top];
        c.stack_top += size;
        return .{
            .ptr = @ptrCast(ptr),
            .type_id = type_id,
        };
    }

    fn allocStack(type_id: TypeId) Value {
        const value = allocStackWithoutInit(type_id);
        if (debug) {
            @memset(getDataSlice(value), 0xCC);
            @memset(getProvenanceSlice(value).?, .not_a_ref);
        }
        return value;
    }

    fn allocHeap(type_id: TypeId) Value {
        return .{
            .ptr = @ptrCast(allocator.alloc(u64, type_id.wordSize()) catch oom()),
            .type_id = type_id,
        };
    }

    // Returns null if `value.ptr` does not point to `stack_data`.
    fn getStackIndex(value: Value) ?StackIndex {
        if (@intFromPtr(value.ptr) < @intFromPtr(c.stack_data.ptr)) return null;
        const index = @intFromPtr(value.ptr) - @intFromPtr(c.stack_data.ptr);
        if (index >= c.stack_data.len) return null;
        return @intCast(@divExact(index, 8));
    }

    fn getDataSlice(value: Value) []u64 {
        const size = value.type_id.wordSize();
        return value.ptr[0..size];
    }

    fn copyData(args: struct { to: Value, from: Value }) void {
        if (debug) assert(args.to.type_id == args.from.type_id);
        @memcpy(getDataSlice(args.to), getDataSlice(args.from));
    }

    // Returns null if `ref.ptr` does not point to `stack_data`.
    fn getProvenance(ref: Value) ?*Provenance {
        if (debug) assert(c.types.items[ref.type_id.id] == .ref);
        const index = getStackIndex(ref) orelse return null;
        return &c.stack_provenance[index];
    }

    // Returns null if `value.ptr` does not point to `stack_data`.
    fn getProvenanceSlice(value: Value) ?[]Provenance {
        const index = getStackIndex(value) orelse return null;
        const size = value.type_id.wordSize();
        return c.stack_provenance[index..][0..size];
    }

    fn copyProvenance(args: struct { to: Value, from: Value }) void {
        if (debug) assert(args.to.type_id == args.from.type_id);
        if (getProvenanceSlice(args.to)) |to_provenance_slice| {
            if (getProvenanceSlice(args.from)) |from_provenance_slice| {
                @memcpy(to_provenance_slice, from_provenance_slice);
            } else {
                for (args.to.type_id.getRefIndexes()) |ref_index| {
                    to_provenance_slice[ref_index.word_offset] = .{
                        .lease = .owned,
                        .owner = 0,
                        .lender = 0,
                    };
                }
            }
        }
    }

    fn order(a: Value, b: Value) std.math.Order {
        switch (TypeId.order(a.type_id, b.type_id)) {
            .lt => return .lt,
            .gt => return .gt,
            .eq => {},
        }
        switch (c.types.items[a.type_id.id]) {
            .number => return std.math.order(a.getNumber(), b.getNumber()),
            .tuple => |tuple| {
                for (0..tuple.elems.len) |i| {
                    switch (Value.order(a.getTupleElem(i), b.getTupleElem(i))) {
                        .lt => return .lt,
                        .gt => return .gt,
                        .eq => {},
                    }
                }
                return .eq;
            },
            .ref => {
                return Value.order(a.getRefElem(), b.getRefElem());
            },
            .closure => {
                return .eq;
            },
        }
    }

    fn getRefAtIndex(value: Value, ref_index: RefIndex) Value {
        return .{
            .ptr = value.ptr + ref_index.word_offset,
            .type_id = ref_index.type_id,
        };
    }

    fn freeRefs(value: Value) void {
        for (value.type_id.getRefIndexes()) |ref_index| {
            if (value.ptr[ref_index.word_offset] != 0) {
                const ref = value.getRefAtIndex(ref_index);
                const provenance_maybe = getProvenance(ref);
                const lease = if (provenance_maybe) |provenance| provenance.lease else .owned;
                switch (lease) {
                    .not_a_ref => unreachable,
                    .owned => {
                        const elem = ref.getRefElem();
                        elem.freeRefs();
                        allocator.free(getDataSlice(elem));
                    },
                    .borrowed => {
                        const lender = provenance_maybe.?.lender;
                        c.stack.items[lender].ref_count.dropBorrow();
                    },
                    .shared => {
                        const lender = provenance_maybe.?.lender;
                        c.stack.items[lender].ref_count.dropShare();
                    },
                }
                value.ptr[ref_index.word_offset] = 0;
            }
        }
    }

    fn setRefsToNull(value: Value) void {
        for (value.type_id.getRefIndexes()) |ref_index| {
            value.ptr[ref_index.word_offset] = 0;
        }
    }

    pub fn format(value: Value, writer: *std.io.Writer) std.io.Writer.Error!void {
        switch (c.types.items[value.type_id.id]) {
            .number => {
                try writer.print("{}", .{value.getNumber()});
            },
            .tuple => |tuple| {
                try writer.print("[", .{});
                for (0..tuple.elems.len) |i| {
                    if (i != 0)
                        try writer.print(", ", .{});
                    try writer.print("{f}", .{value.getTupleElem(i)});
                }
                try writer.print("]", .{});
            },
            .ref => {
                if (value.ptr[0] == 0) {
                    // This isn't reachable in valid programs, but it's useful when debugging.
                    try writer.print("null", .{});
                } else {
                    try writer.print("ref({f})", .{value.getRefElem()});
                }
            },
            .closure => |closure| {
                try writer.print("fn({})", .{closure.fn_id});
            },
        }
    }
};

const StackItem = struct {
    name: ?[]const u8,
    value: Value,
    ref_count: RefCount = .{ .count = RefCount.available },

    fn deinit(
        stack_item: StackItem,
    ) void {
        if (debug) assert(switch (stack_item.ref_count.state()) {
            .available, .moved => true,
            .borrowed, .shared => false,
        });
        stack_item.value.freeRefs();
    }
};

const RefCount = packed struct {
    count: Count,

    const Count = std.math.IntFittingRange(-stack_size, stack_size);

    const available = 0;
    const moved = std.math.minInt(Count);

    const State = enum { moved, borrowed, available, shared };

    fn state(ref_count: RefCount) State {
        if (ref_count.count == moved) return .moved;
        if (ref_count.count < available) return .borrowed;
        if (ref_count.count == available) return .available;
        if (ref_count.count > available) return .shared;
        unreachable;
    }

    fn setAvailable(ref_count: *RefCount) void {
        if (debug) assert(ref_count.count == moved);
        ref_count.count = available;
    }

    fn isMoved(ref_count: RefCount) bool {
        return ref_count.count == moved;
    }

    fn canMove(ref_count: *RefCount) bool {
        return ref_count.count == available;
    }

    fn move(ref_count: *RefCount) void {
        if (debug) assert(ref_count.canMove());
        ref_count.count = moved;
    }

    fn canBorrow(ref_count: *RefCount) bool {
        return ref_count.count == available;
    }

    fn borrow(ref_count: *RefCount) void {
        if (debug) assert(ref_count.canBorrow());
        ref_count.count -= 1;
    }

    fn canShare(ref_count: *RefCount) bool {
        return ref_count.count >= available;
    }

    fn share(ref_count: *RefCount) void {
        if (debug) assert(ref_count.canShare());
        ref_count.count += 1;
    }

    fn dropBorrow(ref_count: *RefCount) void {
        if (debug) assert(ref_count.state() == .borrowed);
        ref_count.count += 1;
    }

    fn dropShare(ref_count: *RefCount) void {
        if (debug) assert(ref_count.state() == .shared);
        ref_count.count -= 1;
    }

    fn splitBorrow(ref_count: *RefCount) void {
        if (debug) assert(ref_count.state() == .borrowed);
        ref_count.count -= 1;
    }

    fn splitShare(ref_count: *RefCount) void {
        if (debug) assert(ref_count.state() == .shared);
        ref_count.count += 1;
    }
};

const Provenance = packed struct {
    lease: Lease,
    // `owner` and `lender` are only meaningful if `lease == .borrowed` or `lease == .shared`.
    owner: StackIndex,
    lender: StackIndex,

    const not_a_ref = Provenance{
        .lease = .not_a_ref,
        .owner = 0,
        .lender = 0,
    };
};

const Lease = enum(u2) {
    not_a_ref = 0,
    owned = 1,
    borrowed = 2,
    shared = 3,

    fn weakest(a: Lease, b: Lease) Lease {
        return @enumFromInt(@max(@intFromEnum(a), @intFromEnum(b)));
    }
};

fn stackPushEmptyTuple() void {
    c.stack.push(.{
        .name = null,
        .value = .{
            .ptr = c.stack_data.ptr,
            .type_id = makeTypeTupleEmpty(),
        },
    });
}

fn stackCompact(expr_id: ExprId, stack_start: usize, stack_data_start: usize) error{Error}!void {
    const stack_top = c.stack_top;

    var result = c.stack.pop();
    errdefer result.deinit();

    if (debug) {
        assert(result.name == null);
        assert(result.ref_count.state() == .available);
    }

    for (result.value.type_id.getRefIndexes()) |ref_index| {
        const provenance = result.value.getRefAtIndex(ref_index).getProvenance().?;
        switch (provenance.lease) {
            .not_a_ref => unreachable,
            .owned => {},
            .borrowed, .shared => {
                if (provenance.lender >= stack_start) {
                    const item = &c.stack.items[provenance.lender];
                    return fail(
                        .{ .expr_id = expr_id },
                        "This value shares/borrows from `{s}`, but `{s}` will be destroyed at the end of this block",
                        .{ item.name.?, item.name.? },
                    );
                }
            },
        }
    }

    while (c.stack.len > stack_start) c.stack.pop().deinit();
    c.stack_top = stack_data_start;

    const result_moved = Value.allocStackWithoutInit(result.value.type_id);
    // Can't use Value.copyData/Provenance here because the slices might overlap.
    std.mem.copyBackwards(
        u64,
        result_moved.getDataSlice(),
        result.value.getDataSlice(),
    );
    std.mem.copyBackwards(
        Provenance,
        result_moved.getProvenanceSlice().?,
        result.value.getProvenanceSlice().?,
    );

    if (debug) {
        @memset(c.stack_data[c.stack_top..stack_top], 0xCC);
        @memset(c.stack_provenance[c.stack_top..stack_top], .not_a_ref);
    }

    c.stack.push(.{ .name = null, .value = result_moved });
}

fn makeType(@"type": Type) TypeId {
    const type_id = TypeId{ .id = c.types.items.len };
    c.types.append(allocator, @"type") catch oom();
    c.type_to_ref_indexes.append(allocator, @"type".makeRefIndexes(type_id)) catch oom();
    return type_id;
}

fn makeTypeNumber() TypeId {
    if (c.type_number == null)
        c.type_number = makeType(.number);
    return c.type_number.?;
}

fn makeTypeTupleEmpty() TypeId {
    if (c.type_tuple_empty == null)
        c.type_tuple_empty = makeType(.{ .tuple = .{ .elems = &.{} } });
    return c.type_tuple_empty.?;
}

fn makeTypeTuple(items: []StackItem) TypeId {
    if (items.len == 0) return makeTypeTupleEmpty();
    if (c.type_tuple.getAdapted(items, StackItemsHashContext{})) |type_id| return type_id;
    const elems = allocator.alloc(TypeId, items.len) catch oom();
    for (elems, items) |*elem, item| elem.* = item.value.type_id;
    const type_id = makeType(.{ .tuple = .{ .elems = elems } });
    c.type_tuple.putNoClobber(elems, type_id) catch oom();
    return type_id;
}

fn makeTypeRef(elem: TypeId) TypeId {
    if (c.type_ref.get(elem)) |type_id| return type_id;
    const type_id = makeType(.{ .ref = .{ .elem = .{ .known = elem } } });
    c.type_ref.putNoClobber(elem, type_id) catch oom();
    return type_id;
}

fn makeTypeClosure(fn_id: FnId) TypeId {
    if (c.type_closure.get(fn_id)) |type_id| return type_id;
    const type_id = makeType(.{ .closure = .{ .fn_id = fn_id } });
    c.type_closure.putNoClobber(fn_id, type_id) catch oom();
    return type_id;
}

fn evalPopBool(expr_id: ExprId) error{Error}!bool {
    const stack_data_start = c.stack_top;
    try eval(expr_id);

    errdefer comptime unreachable;

    const item = c.stack.pop();
    const cond = item.value.getBool();
    item.deinit();
    c.stack_top = stack_data_start;
    return cond;
}

fn evalPopNumber(expr_id: ExprId) error{Error}!i64 {
    const stack_data_start = c.stack_top;
    try eval(expr_id);

    const item = c.stack.pop();
    errdefer item.deinit();

    try checkKind(expr_id, .{ .expected = .number, .actual = item.value.type_id });
    const number = item.value.getNumber();
    item.deinit();
    c.stack_top = stack_data_start;
    return number;
}

fn evalPath(expr_id: ExprId) error{Error}!struct { value: Value, provenance: Provenance } {
    switch (c.exprs.items[expr_id.id]) {
        .get => |get| {
            const stack_index: StackIndex = @intCast(c.stack.len - get.stack_reverse_index);
            const item = &c.stack.items[stack_index];
            if (debug) assert(std.mem.eql(u8, item.name.?, get.name));
            if (!get.allow_moved and item.ref_count.isMoved()) {
                return fail(
                    .{ .expr_id = expr_id },
                    "Can't refer to `{s}` because it has been moved",
                    .{item.name.?},
                );
            }
            return .{
                .value = item.value,
                .provenance = .{
                    .lease = .owned,
                    .owner = stack_index,
                    .lender = stack_index,
                },
            };
        },
        .deref => |deref| {
            const path = try evalPath(deref);

            try checkKind(deref, .{ .expected = .ref, .actual = path.value.type_id });

            const ref_provenance = if (path.value.getProvenance()) |provenance|
                provenance.*
            else
                // If ref is not on the stack then it must be owned by `path.owner`.
                Provenance{
                    .lease = .owned,
                    .owner = path.provenance.owner,
                    .lender = path.provenance.lender,
                };
            const lender = if (ref_provenance.lease == .borrowed)
                // We don't have exclusive access to this location, so we need to acquire it from the ref that does have exclusive access.
                path.provenance.lender
            else
                ref_provenance.owner;
            return .{
                .value = path.value.getRefElem(),
                .provenance = .{
                    .lease = Lease.weakest(path.provenance.lease, ref_provenance.lease),
                    .owner = ref_provenance.owner,
                    .lender = lender,
                },
            };
        },
        .tuple_get => |tuple_get| {
            const tuple = try evalPath(tuple_get.tuple);
            const index = try evalPopNumber(tuple_get.index);

            try checkKind(tuple_get.tuple, .{ .expected = .tuple, .actual = tuple.value.type_id });

            if (index < 0 or index >= c.types.items[tuple.value.type_id.id].tuple.elems.len)
                return fail(
                    .{ .expr_id = expr_id },
                    "Index {} is out of bounds for tuple {f}",
                    .{ index, tuple.value },
                );

            return .{
                .value = tuple.value.getTupleElem(@intCast(index)),
                .provenance = tuple.provenance,
            };
        },
        else => unreachable,
    }
}

fn evalPattern(expr_id: ExprId) error{Error}!void {
    switch (c.exprs.items[expr_id.id]) {
        // Optimize the most common case.
        .get => |get| {
            c.stack.peek().name = get.name;
        },
        else => {
            const item = c.stack.pop();
            switch (c.types.items[item.value.type_id.id]) {
                .ref => {
                    defer item.deinit(); // If succesful, we make new refs and the original ref still needs to be cleaned up.
                    try evalPatternRef(expr_id, item.value.getRefElem(), item.value.getProvenance().?.*);
                },
                else => {
                    errdefer item.deinit(); // If succesful, value is totally consumed.
                    try evalPatternOwned(expr_id, item.value);
                },
            }
        },
    }
}

fn evalPatternRef(expr_id: ExprId, value: Value, provenance: Provenance) error{Error}!void {
    switch (c.exprs.items[expr_id.id]) {
        .get => |get| {
            const lender = &c.stack.items[provenance.lender];
            switch (provenance.lease) {
                .not_a_ref => unreachable,
                .owned => return fail(.{ .expr_id = expr_id }, "Can't destructure an owned ref", .{}),
                .borrowed => lender.ref_count.splitBorrow(),
                .shared => lender.ref_count.splitShare(),
            }
            const ref = Value.allocStack(makeTypeRef(value.type_id));
            ref.setRefElem(value);
            ref.getProvenance().?.* = provenance;
            c.stack.push(.{ .name = get.name, .value = ref });
        },
        .tuple => |elems| {
            try checkKind(expr_id, .{ .expected = .tuple, .actual = value.type_id });
            if (elems.len != c.types.items[value.type_id.id].tuple.elems.len)
                return fail(
                    .{ .expr_id = expr_id },
                    "Expected a tuple of length {} but found {f}",
                    .{ elems.len, value },
                );
            for (elems, 0..) |elem, i| {
                try evalPatternRef(elem, value.getTupleElem(i), provenance);
            }
        },
        else => unreachable,
    }
}

fn evalPatternOwned(expr_id: ExprId, value: Value) error{Error}!void {
    switch (c.exprs.items[expr_id.id]) {
        .get => |get| {
            c.stack.push(.{
                .name = get.name,
                .value = value,
            });
        },
        .tuple => |elems| {
            try checkKind(expr_id, .{ .expected = .tuple, .actual = value.type_id });
            if (elems.len != c.types.items[value.type_id.id].tuple.elems.len)
                return fail(
                    .{ .expr_id = expr_id },
                    "Expected a tuple of length {} but found {f}",
                    .{ elems.len, value },
                );
            for (elems, 0..) |elem, i| {
                try evalPatternOwned(elem, value.getTupleElem(i));
            }
        },
        else => unreachable,
    }
}

fn eval(expr_id: ExprId) error{Error}!void {
    switch (c.exprs.items[expr_id.id]) {
        .get, .deref, .tuple_get => {
            const path = try evalPath(expr_id);
            for (path.value.type_id.getRefIndexes()) |ref_index| {
                const ref = path.value.getRefAtIndex(ref_index);
                const lease = if (ref.getProvenance()) |provenance| provenance.lease else .owned;
                switch (lease) {
                    .not_a_ref => unreachable,
                    .shared => {},
                    .owned => {
                        return fail(
                            .{ .expr_id = expr_id },
                            "Can't copy an owned reference",
                            .{},
                        );
                    },
                    .borrowed => {
                        return fail(
                            .{ .expr_id = expr_id },
                            "Can't copy a borrowed reference",
                            .{},
                        );
                    },
                }
            }

            errdefer comptime unreachable;

            const result = Value.allocStack(path.value.type_id);
            Value.copyData(.{ .to = result, .from = path.value });
            Value.copyProvenance(.{ .to = result, .from = path.value });

            for (result.type_id.getRefIndexes()) |ref_index| {
                const provenance = result.getRefAtIndex(ref_index).getProvenance().?;
                if (provenance.lease == .shared)
                    c.stack.items[provenance.lender].ref_count.share();
            }

            c.stack.push(.{ .name = null, .value = result });
        },
        .move => |move| {
            const path = try evalPath(move);
            if (path.provenance.lease != .owned) {
                return fail(
                    .{ .expr_id = expr_id },
                    "Can't move out of a borrowed/shared reference",
                    .{},
                );
            }
            const owner = &c.stack.items[path.provenance.owner];
            if (!owner.ref_count.canMove()) {
                switch (owner.ref_count.state()) {
                    .moved => return fail(
                        .{ .expr_id = expr_id },
                        "Can't move out of `{s}` because it has already been moved",
                        .{owner.name.?},
                    ),
                    .borrowed => return fail(
                        .{ .expr_id = expr_id },
                        "Can't move out of `{s}` because it is borrowed by TODO",
                        .{owner.name.?},
                    ),
                    .shared => return fail(
                        .{ .expr_id = expr_id },
                        "Can't move out of `{s}` because it is shared by TODO",
                        .{owner.name.?},
                    ),
                    .available => unreachable,
                }
            }

            errdefer comptime unreachable;

            owner.ref_count.move();

            const result = Value.allocStack(path.value.type_id);
            Value.copyData(.{ .to = result, .from = path.value });
            Value.copyProvenance(.{ .to = result, .from = path.value });
            path.value.setRefsToNull(); // Avoid freeing this value twice.

            c.stack.push(.{ .name = null, .value = result });
        },
        .borrow => |borrow| {
            const path = try evalPath(borrow);
            if (path.provenance.lease == .shared) {
                return fail(
                    .{ .expr_id = expr_id },
                    "Can't borrow through a shared reference",
                    .{},
                );
            }
            const lender = &c.stack.items[path.provenance.lender];
            if (!lender.ref_count.canBorrow()) {
                switch (lender.ref_count.state()) {
                    .moved => return fail(
                        .{ .expr_id = expr_id },
                        "Can't borrow `{s}` because it has been moved",
                        .{lender.name.?},
                    ),
                    .borrowed => return fail(
                        .{ .expr_id = expr_id },
                        "Can't borrow `{s}` because it is already borrowed by TODO",
                        .{lender.name.?},
                    ),
                    .shared => return fail(
                        .{ .expr_id = expr_id },
                        "Can't borrow `{s}` because it is shared by TODO",
                        .{lender.name.?},
                    ),
                    .available => unreachable,
                }
            }

            errdefer comptime unreachable;

            lender.ref_count.borrow();
            const ref = Value.allocStack(makeTypeRef(path.value.type_id));
            ref.setRefElem(path.value);
            ref.getProvenance().?.* = .{
                .lease = .borrowed,
                .owner = path.provenance.owner,
                .lender = path.provenance.lender,
            };
            c.stack.push(.{ .name = null, .value = ref });
        },
        .share => |share| {
            const path = try evalPath(share);
            const lender = &c.stack.items[path.provenance.lender];
            if (!lender.ref_count.canShare()) {
                switch (lender.ref_count.state()) {
                    .moved => return fail(
                        .{ .expr_id = expr_id },
                        "Can't share `{s}` because it has been moved",
                        .{lender.name.?},
                    ),
                    .borrowed => return fail(
                        .{ .expr_id = expr_id },
                        "Can't share `{s}` because it is borrowed by TODO",
                        .{lender.name.?},
                    ),
                    .shared, .available => unreachable,
                }
            }

            errdefer comptime unreachable;

            lender.ref_count.share();
            const ref = Value.allocStack(makeTypeRef(path.value.type_id));
            ref.setRefElem(path.value);
            ref.getProvenance().?.* = .{
                .lease = .shared,
                .owner = path.provenance.owner,
                .lender = path.provenance.lender,
            };
            c.stack.push(.{ .name = null, .value = ref });
        },
        .number => |number| {
            errdefer comptime unreachable;

            const value = Value.allocStack(makeTypeNumber());
            value.setNumber(number);
            c.stack.push(.{ .name = null, .value = value });
        },
        .tuple => |exprs| {
            if (exprs.len == 0) {
                stackPushEmptyTuple();
                return;
            }

            const stack_start = c.stack.len;

            for (exprs) |expr|
                try eval(expr);

            errdefer comptime unreachable;

            const type_tuple = makeTypeTuple(c.stack.items[c.stack.len - exprs.len .. c.stack.len]);

            // All the elems are now contiguous on the stack so we can just point at the first elem.
            c.stack.len = stack_start + 1;
            const result = c.stack.peek();
            result.value.type_id = type_tuple;
        },
        .let => |let| {
            try eval(let.value);
            try evalPattern(let.pattern);
            stackPushEmptyTuple();
        },
        .block => |block| {
            const stack_start = c.stack.len;
            const stack_data_start = c.stack_top;

            for (block.statements[0 .. block.statements.len - 1]) |statement| {
                try eval(statement);
                c.stack.pop().deinit();
            }

            try eval(block.statements[block.statements.len - 1]);
            try stackCompact(expr_id, stack_start, stack_data_start);
        },
        .@"if" => |@"if"| {
            const cond = try evalPopBool(@"if".cond);
            try eval(if (cond) @"if".then else @"if".@"else");
        },
        .@"while" => |@"while"| {
            while (true) {
                const cond = try evalPopBool(@"while".cond);
                if (!cond) break;

                try eval(@"while".body);
                c.stack.pop().deinit();
            }
            stackPushEmptyTuple();
        },
        .@"fn" => {
            errdefer comptime unreachable;

            const fn_id = c.expr_to_fn.get(expr_id).?;
            c.stack.push(.{
                .name = null,
                .value = .{
                    .ptr = c.stack_data.ptr,
                    .type_id = makeTypeClosure(fn_id),
                },
            });
        },
        .capture, .param => {
            // Handled directly in .call below.
            unreachable;
        },
        .call => |call| {
            try eval(call.closure);
            const closure = c.stack.peek();

            try checkKind(call.closure, .{ .expected = .closure, .actual = closure.value.type_id });
            const @"fn" = &c.fns.items[c.types.items[closure.value.type_id.id].closure.fn_id.id];

            const fn_expr = c.exprs.items[@"fn".fn_expr_id.id].@"fn";

            const stack_start = c.stack.len;
            const stack_data_start = c.stack_top;

            for (call.args) |arg_expr|
                try eval(arg_expr);

            for (fn_expr.params, 0..) |param_id, i| {
                const param = c.exprs.items[param_id.id].param;
                const item = &c.stack.items[c.stack.len - 1 - i];
                item.name = param.name;
            }

            try eval(fn_expr.body);
            // TODO We could avoid this extra compaction by passing stack_start/stack_data_start to the block in `fn_expr.body`.
            try stackCompact(expr_id, stack_start, stack_data_start);
        },
        .call_builtin => |call_builtin| {
            const stack_start = c.stack.len;
            const stack_data_start = c.stack_top;

            // Arg count was already checked in analyze.

            switch (call_builtin.builtin) {
                .@"=" => {
                    const path = try evalPath(call_builtin.args[0]);
                    try eval(call_builtin.args[1]);

                    const arg1 = c.stack.pop();
                    errdefer arg1.deinit();

                    switch (path.provenance.lease) {
                        .not_a_ref => unreachable,
                        .owned, .borrowed => {},
                        .shared => return fail(
                            .{ .expr_id = expr_id },
                            "Can't assign through a shared reference",
                            .{},
                        ),
                    }

                    const lender = &c.stack.items[path.provenance.lender];
                    const lender_state = lender.ref_count.state();
                    switch (lender_state) {
                        .moved, .available => {},
                        .shared => return fail(
                            .{ .expr_id = expr_id },
                            "Can't assign to `{s}` because it is shared with TODO",
                            .{lender.name.?},
                        ),
                        .borrowed => return fail(
                            .{ .expr_id = expr_id },
                            "Can't assign to `{s}` because it is borrowed by TODO",
                            .{lender.name.?},
                        ),
                    }

                    if (path.value.type_id != arg1.value.type_id) {
                        return fail(
                            .{ .expr_id = expr_id },
                            "Can't assign a value of type `{f}` to a reference with elem type `{f}`",
                            .{ arg1.value.type_id, path.value.type_id },
                        );
                    }

                    for (arg1.value.type_id.getRefIndexes()) |ref_index| {
                        const elem_provenance = arg1.value.getRefAtIndex(ref_index).getProvenance().?;
                        switch (elem_provenance.lease) {
                            .not_a_ref, .owned => {},
                            .borrowed, .shared => {
                                if (path.value.getStackIndex() == null) {
                                    return fail(
                                        .{ .expr_id = expr_id },
                                        "Can't write a borrowed/shared reference to an owned ref",
                                        .{},
                                    );
                                }
                                if (elem_provenance.lender > path.provenance.owner) {
                                    const ref_item = &c.stack.items[path.provenance.owner];
                                    const elem_item = &c.stack.items[elem_provenance.lender];
                                    return fail(
                                        .{ .expr_id = expr_id },
                                        "This value shares/borrows from `{s}`, which will be destroyed before `{s}` and so can't be owned by `{s}`",
                                        .{ elem_item.name.?, ref_item.name.?, ref_item.name.? },
                                    );
                                }
                            },
                        }
                    }

                    errdefer comptime unreachable;

                    switch (lender_state) {
                        .moved => lender.ref_count.setAvailable(),
                        .available => path.value.freeRefs(),
                        .shared, .borrowed => unreachable,
                    }

                    Value.copyData(.{ .to = path.value, .from = arg1.value });
                    Value.copyProvenance(.{ .to = path.value, .from = arg1.value });

                    stackPushEmptyTuple();
                },
                .@"+" => {
                    try eval(call_builtin.args[0]);
                    try eval(call_builtin.args[1]);

                    const arg1 = c.stack.pop();
                    defer arg1.deinit();

                    const arg0 = c.stack.pop();
                    defer arg0.deinit();

                    try checkKind(call_builtin.args[0], .{ .expected = .number, .actual = arg0.value.type_id });
                    try checkKind(call_builtin.args[1], .{ .expected = .number, .actual = arg1.value.type_id });

                    errdefer comptime unreachable;

                    const result = Value.allocStack(makeTypeNumber());
                    result.setNumber(arg0.value.getNumber() +% arg1.value.getNumber());
                    c.stack.push(.{ .name = null, .value = result });
                },
                .@"<" => {
                    try eval(call_builtin.args[0]);
                    try eval(call_builtin.args[1]);

                    const arg1 = c.stack.pop();
                    defer arg1.deinit();

                    const arg0 = c.stack.pop();
                    defer arg0.deinit();

                    errdefer comptime unreachable;

                    const result = Value.allocStack(makeTypeNumber());
                    result.setNumber(if (Value.order(arg0.value, arg1.value) == .lt) 1 else 0);
                    c.stack.push(.{ .name = null, .value = result });
                },
                .ref => {
                    try eval(call_builtin.args[0]);

                    const arg0 = c.stack.pop();
                    errdefer arg0.deinit();

                    for (arg0.value.type_id.getRefIndexes()) |ref_index| {
                        const lease = arg0.value.getRefAtIndex(ref_index).getProvenance().?.lease;
                        switch (lease) {
                            .not_a_ref, .owned => {},
                            .borrowed, .shared => {
                                return fail(
                                    .{ .expr_id = expr_id },
                                    "Can't create an owned ref containing a borrowed/shared ref",
                                    .{},
                                );
                            },
                        }
                    }

                    errdefer comptime unreachable;

                    const target = Value.allocHeap(arg0.value.type_id);
                    Value.copyData(.{ .from = arg0.value, .to = target });

                    const ref = Value.allocStack(makeTypeRef(arg0.value.type_id));
                    ref.setRefElem(target);
                    ref.getProvenance().?.* = .{
                        .lease = .owned,
                        .owner = 0,
                        .lender = 0,
                    };

                    c.stack.push(.{ .name = null, .value = ref });
                },
            }

            try stackCompact(expr_id, stack_start, stack_data_start);
        },
    }

    //pp(.{ c.exprs.items[expr_id.id], getProvenanceSlice(c.stack.peek().value) });
}

fn checkArgCount(expr_id: ExprId, opts: struct { expected: usize, actual: usize }) error{Error}!void {
    if (opts.expected != opts.actual)
        return fail(
            .{ .expr_id = expr_id },
            "Expected {} arguments but found {} arguments",
            .{ opts.expected, opts.actual },
        );
}

fn checkKind(expr_id: ExprId, opts: struct { expected: std.meta.Tag(Type), actual: TypeId }) error{Error}!void {
    const actual_type = c.types.items[opts.actual.id];
    if (opts.expected != actual_type)
        return fail(
            .{ .expr_id = expr_id },
            "Expected a {s} but found a {s}",
            .{ @tagName(opts.expected), @tagName(actual_type) },
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

            //std.debug.print("{s}\n\n", .{source});

            c = .init(source);
            defer c.deinit();

            const actual = run() catch c.error_message.?;

            //std.debug.print("{s}\n\n", .{actual});

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
