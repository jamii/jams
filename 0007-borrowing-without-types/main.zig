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
    stack: []u64,
    stack_top: usize,
    type_number: *Type,
    type_empty_tuple: *Type,

    error_message: ?[]u8,

    pub fn init(source: []const u8) Compiler {
        const type_number = allocator.create(Type) catch oom();
        type_number.* = .number;

        const type_empty_tuple = allocator.create(Type) catch oom();
        type_empty_tuple.* = .{ .tuple = .{ .elems = &.{} } };

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
            .stack = allocator.alloc(u64, 1024 * 1024) catch oom(),
            .stack_top = 0,
            .type_number = type_number,
            .type_empty_tuple = type_empty_tuple,

            .error_message = null,
        };
    }

    pub fn deinit(c: *Compiler) void {
        c.tokens.deinit(allocator);
        c.token_to_range.deinit(allocator);

        for (c.exprs.items) |expr| expr.deinit();
        c.exprs.deinit(allocator);
        c.expr_to_tokens.deinit(allocator);

        c.fns.deinit(allocator);
        c.expr_to_fn.deinit();
        c.scope.deinit(allocator);

        for (c.bindings.items) |*binding| binding.deinit();
        c.bindings.deinit(allocator);
        allocator.free(c.stack);
        allocator.destroy(c.type_number);
        allocator.destroy(c.type_empty_tuple);

        if (c.error_message) |err| allocator.free(err);
    }

    pub fn run(c: *Compiler) ![]const u8 {
        try tokenize(c);
        c.expr_top = try parse(c);
        try analyze(c, c.expr_top.?);
        try eval(c, c.expr_top.?);
        const result = bindingsPeek(c);
        return std.fmt.allocPrint(allocator, "{f}", .{result.value});
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
    @"^",
    @"!",
    @"&",

    let,
    get,
    set,
    take,
    copy,
    @"if",
    @"else",
    @"while",
    @"fn",

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
            '^' => .@"^",
            '!' => .@"!",
            '&' => .@"&",
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
    number: i64,
    tuple: []ExprId,
    get: struct {
        name: []const u8,
        lease: Lease,
    },
    let: struct {
        name: []const u8,
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
        params: []ExprId,
        body: ExprId,
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

    fn deinit(expr: Expr) void {
        switch (expr) {
            .tuple => |exprs| allocator.free(exprs),
            .block => |block| allocator.free(block.statements),
            .@"fn" => |@"fn"| allocator.free(@"fn".params),
            .call => |call| allocator.free(call.args),
            .call_builtin => |call_builtin| allocator.free(call_builtin.args),
            .number, .get, .let, .@"if", .@"while", .param => {},
        }
    }
};

const Lease = enum(u2) {
    owned = 1,
    unique = 2,
    shared = 3,
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
        },
    });
}

const arg_count_max: usize = 31;

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
        .number => parseNumber(c),
        .@"[" => parseList(c),
        .name => parseGet(c),
        .@"{" => parseBlock(c),
        .@"if" => parseIf(c),
        .@"while" => parseWhile(c),
        .@"fn" => parseFn(c),
        .get, .set, .take, .copy => parseCallBuiltin(c),
        else => failExpected(c, "an expression"),
    };
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
    const lease = parseLease(c) orelse .shared;
    return pushExpr(c, start, .{ .get = .{ .name = name, .lease = lease } });
}

fn parseBlock(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;

    try expect(c, .@"{");

    var statements: ArrayList(ExprId) = .{};
    defer statements.deinit(allocator);

    const return_last = while (true) {
        if (peek(c) == .@"}") break false;
        const statement = if (peek(c) == .let) try parseLet(c) else try parseExprLoose(c);
        statements.append(allocator, statement) catch oom();
        if (!takeIf(c, .@";")) break true;
    };

    if (!return_last or statements.items.len == 0) {
        const statement = pushExpr(c, c.token_next, .{ .tuple = &.{} });
        statements.append(allocator, statement) catch oom();
    }

    try expect(c, .@"}");

    return pushExpr(c, start, .{
        .block = .{
            .statements = statements.toOwnedSlice(allocator) catch oom(),
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

    var params: ArrayList(ExprId) = .{};
    defer params.deinit(allocator);

    for (0..arg_count_max) |_| {
        if (peek(c) == .@")") break;
        const param = try parseParam(c);
        params.append(allocator, param) catch oom();
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

    return pushExpr(c, start, .{
        .@"fn" = .{
            .params = params.toOwnedSlice(allocator) catch oom(),
            .body = body,
        },
    });
}

fn parseParam(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;
    const name = try expectName(c);
    return pushExpr(c, start, .{ .param = .{ .name = name } });
}

fn parseCallBuiltin(c: *Compiler) error{Error}!ExprId {
    const start = c.token_next;

    const builtin: Builtin = switch (peek(c)) {
        //.get => .get,
        //.set => .set,
        //.take => .take,
        //.copy => .copy,
        else => return failExpected(c, "a builtin function"),
    };
    _ = take(c);

    const args = try parseArgs(c);
    const expr_id = pushExpr(c, start, .{ .call_builtin = .{ .builtin = builtin, .args = args } });
    return expr_id;
}

fn parseLease(c: *Compiler) ?Lease {
    return if (takeIf(c, .@"^"))
        .owned
    else if (takeIf(c, .@"!"))
        .unique
    else if (takeIf(c, .@"&"))
        .shared
    else
        null;
}

fn expect(c: *Compiler, expected: Token) error{Error}!void {
    const actual = peek(c);
    if (expected != actual) {
        return fail(
            c,
            .{ .token_id = c.token_next },
            "Expected a `{s}` but found a `{s}`",
            .{ @tagName(expected), @tagName(actual) },
        );
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
    name: []const u8,
};

fn resolve(list: anytype, name: []const u8) ?usize {
    var i = list.items.len;
    while (i > 0) : (i -= 1) {
        const index = i - 1;
        const item = list.items[index];
        const item_name = switch (@TypeOf(item.name)) {
            ?[]const u8 => item.name orelse "",
            []const u8 => item.name,
            else => unreachable,
        };
        if (std.mem.eql(u8, item_name, name))
            return index;
    }
    return null;
}

fn analyze(c: *Compiler, expr_id: ExprId) error{Error}!void {
    switch (c.exprs.items[expr_id.id]) {
        .number => {},
        .tuple => |tuple| {
            for (tuple) |elem|
                try analyze(c, elem);
        },
        .get => |get| {
            const scope_index = resolve(c.scope, get.name) orelse
                return failNotDefined(c, expr_id, get.name);

            if (c.fn_id_current) |fn_id| {
                const @"fn" = &c.fns.items[fn_id.id];
                if (scope_index < @"fn".scope_start) {
                    return fail(c, .{ .expr_id = expr_id }, "Sorry, no closures in part 1.", .{});
                }
            }
        },
        .let => |let| {
            try analyze(c, let.value);
            c.scope.append(allocator, .{ .name = let.name }) catch oom();
        },
        .block => |block| {
            const scope_start = c.scope.items.len;
            defer c.scope.shrinkRetainingCapacity(scope_start);

            for (block.statements) |statement|
                try analyze(c, statement);
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
            const scope_start = c.scope.items.len;
            defer c.scope.shrinkRetainingCapacity(scope_start);

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
                c.scope.append(allocator, .{ .name = param.name }) catch oom();
            }

            try analyze(c, @"fn".body);
        },
        .param => {
            // Handled directly in @"fn" above.
            unreachable;
        },
        .call => |*call| {
            try analyze(c, call.closure);
            for (call.args) |arg|
                try analyze(c, arg);
        },
        .call_builtin => |call_builtin| {
            for (call_builtin.args) |arg|
                try analyze(c, arg);
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

// --- EVAL ---

const Type = union(enum) {
    number,
    tuple: TypeTuple,
    ref: TypeRef,
    closure: TypeClosure,

    fn wordSize(@"type": Type) usize {
        switch (@"type") {
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

    fn order(a: *Type, b: *Type) std.math.Order {
        switch (std.math.order(@intFromEnum(a.*), @intFromEnum(b.*))) {
            .lt => return .lt,
            .gt => return .gt,
            .eq => {},
        }
        switch (a.*) {
            .number => return .eq,
            .tuple => {
                for (0..@min(a.tuple.elems.len, b.tuple.elems.len)) |i| {
                    switch (Type.order(a.tuple.elems[i], b.tuple.elems[i])) {
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
                    .known => return Type.order(a.ref.elem.known, b.ref.elem.known),
                }
            },
            .closure => return .eq,
        }
    }
};

const TypeTuple = struct {
    elems: []*Type,

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
        known: *Type,
        any,
    },
};

const TypeClosure = struct {
    fn_id: FnId,
};

const Value = struct {
    // `ptr` can only be null for zero-size types.
    ptr: ?[*]u64,
    type: *Type,

    fn getNumber(value: Value) i64 {
        _ = value.type.number;
        return @bitCast(value.ptr.?[0]);
    }

    fn getBool(value: Value) bool {
        // Zero is falsey. Everything else is truthy.
        if (value.type.* != .number) return true;
        return value.getNumber() != 0;
    }

    fn setNumber(value: Value, number: i64) void {
        _ = value.type.number;
        value.ptr.?[0] = @bitCast(number);
    }

    fn getTupleElem(value: Value, index: usize) Value {
        const tuple = value.type.tuple;
        return .{
            .ptr = value.ptr.? + tuple.wordOffset(index),
            .type = tuple.elems[index],
        };
    }

    fn getRefElem(value: Value) Value {
        const ref = value.type.ref;
        return .{ .ptr = @ptrFromInt(value.ptr.?[0]), .type = switch (ref.elem) {
            .known => |known| known,
            .any => @ptrFromInt(value.ptr.?[1]),
        } };
    }

    fn setRefElem(value: Value, elem: Value) Value {
        const ref = value.type.ref;
        switch (ref.type) {
            .known => |known| assert(Type.order(known, elem.type) == .eq),
            .any => {},
        }
        value.ptr.?[0] = @intFromPtr(elem.ptr);
    }

    fn allocHeap(@"type": Type) Value {
        return .{
            .ptr = allocator.alloc(u8, @"type".sizeOf()) catch oom(),
            .type = @"type",
        };
    }

    fn copyShallow(args: struct { from: Value, to: Value }) void {
        assert(Type.order(args.to.type, args.from.type) == .eq);
        const size = args.from.type.sizeOf();
        if (size != 0)
            @memcpy(args.to.ptr[0..], args.from.ptr[0..]);
    }

    fn copyDeep(args: struct { from: Value, to: Value }) void {
        assert(Type.order(args.to.type, args.from.type) == .eq);
        copyShallow(.{ .from = args.from, .to = args.to });
        cloneRefs(args.to);
    }

    fn cloneRefs(value: Value) void {
        switch (value.type) {
            .number => {},
            .tuple => |tuple| {
                for (0..tuple.elems.len) |i| {
                    cloneRefs(value.getTupleElem(i));
                }
            },
            .ref => {
                setRefElem(value, getRefElem(value).clone());
            },
            .closure => {},
        }
    }

    fn clone(value: Value) Value {
        const cloned = allocHeap(value.type);
        copyDeep(.{ .from = value, .to = cloned });
        return cloned;
    }

    fn order(a: Value, b: Value) std.math.Order {
        switch (Type.order(a.type, b.type)) {
            .lt => return .lt,
            .gt => return .gt,
            .eq => {},
        }
        switch (a.type.*) {
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

    fn free(value: Value) void {
        value.freeRefs();
        allocator.free(value.ptr.?[0..value.type.wordSize()]);
    }

    fn freeRefs(value: Value) void {
        switch (value.type.*) {
            .number => {},
            .tuple => |tuple| {
                for (0..tuple.elems.len) |i| {
                    freeRefs(value.getTupleElem(i));
                }
            },
            .ref => {
                getRefElem(value).free();
            },
            .closure => {},
        }
    }

    pub fn format(value: Value, writer: *std.io.Writer) std.io.Writer.Error!void {
        switch (value.type.*) {
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
                try writer.print("ref({f})", .{value.getRefElem()});
            },
            .closure => |closure| {
                try writer.print("fn({})", .{closure.fn_id});
            },
        }
    }
};

const Binding = struct {
    name: ?[]const u8,
    // This value always points to `c.stack`.
    value: Value,
    lease: Lease,

    fn deinit(binding: Binding) void {
        if (binding.lease == .owned)
            // If this value is owned on the stack, then any refs contained in it must be owned heap refs.
            binding.value.freeRefs();
    }
};

fn bindingsPushEmptyTuple(c: *Compiler) void {
    c.bindings.append(allocator, .{
        .name = null,
        .value = .{
            .ptr = null,
            .type = c.type_empty_tuple,
        },
        .lease = .owned,
    }) catch oom();
}

fn bindingsPeek(c: *Compiler) *Binding {
    return &c.bindings.items[c.bindings.items.len - 1];
}

fn compactStack(c: *Compiler, bindings_start: usize, stack_start: usize) void {
    var result = c.bindings.pop().?;

    for (c.bindings.items[bindings_start..]) |binding| binding.deinit();
    c.bindings.shrinkRetainingCapacity(bindings_start);

    const size = result.value.type.wordSize();
    if (size > 0) {
        const ptr = c.stack[stack_start..][0..size];
        std.mem.copyBackwards(u64, ptr, result.value.ptr.?[0..size]);
        c.stack_top = stack_start;
        result.value.ptr = @ptrCast(ptr);
    }

    c.bindings.append(allocator, result) catch oom();
}

fn stackPush(c: *Compiler, @"type": *Type) Value {
    const ptr = &c.stack[c.stack_top];
    c.stack_top += @"type".wordSize();
    return .{
        .ptr = @ptrCast(ptr),
        .type = @"type",
    };
}

// TODO Memoize this.
fn makeTypeTuple(c: *Compiler, bindings: []Binding) *Type {
    _ = c;
    const result = allocator.create(Type) catch oom();
    const elems = allocator.alloc(*Type, bindings.len) catch oom();
    for (elems, bindings) |*elem, binding| elem.* = binding.value.type;
    result.* = .{ .tuple = .{ .elems = elems } };
    return result;
}

// TODO Memoize this.
fn makeTypeClosure(c: *Compiler, fn_id: FnId) *Type {
    _ = c;
    const result = allocator.create(Type) catch oom();
    result.* = .{ .closure = .{ .fn_id = fn_id } };
    return result;
}

fn eval(c: *Compiler, expr_id: ExprId) error{Error}!void {
    switch (c.exprs.items[expr_id.id]) {
        .number => |number| {
            const value = stackPush(c, c.type_number);
            value.setNumber(number);
            c.bindings.append(allocator, .{
                .name = null,
                .value = value,
                .lease = .owned,
            }) catch oom();
        },
        .tuple => |exprs| {
            if (exprs.len == 0) {
                bindingsPushEmptyTuple(c);
                return;
            }

            const bindings_start = c.bindings.items.len;

            for (exprs) |expr| {
                try eval(c, expr);
            }

            const @"type" = makeTypeTuple(c, c.bindings.items[c.bindings.items.len - exprs.len ..]);

            // All the elems are now contiguous on the stack so we can just point at the first elem.
            c.bindings.shrinkRetainingCapacity(bindings_start + 1);
            const result = bindingsPeek(c);
            result.value.type = @"type";
            result.lease = .owned;
        },
        .get => |get| {
            const binding_index = resolve(c.bindings, get.name).?;
            const value = c.bindings.items[binding_index].value;
            // TODO If we don't copy on the stack then values for tuple will not be contiguous.
            c.bindings.append(allocator, .{
                .name = null,
                .value = value,
                .lease = get.lease,
            }) catch oom();
        },
        .let => |let| {
            try eval(c, let.value);
            const binding = c.bindings.pop().?;
            c.bindings.append(allocator, .{
                .name = let.name,
                .value = binding.value,
                .lease = binding.lease,
            }) catch oom();
            bindingsPushEmptyTuple(c);
        },
        .block => |block| {
            const bindings_start = c.bindings.items.len;
            const stack_start = c.stack_top;

            for (block.statements[0 .. block.statements.len - 1]) |statement| {
                try eval(c, statement);
                c.bindings.pop().?.deinit();
            }

            try eval(c, block.statements[block.statements.len - 1]);
            compactStack(c, bindings_start, stack_start);
        },
        .@"if" => |@"if"| {
            const stack_start = c.stack_top;
            try eval(c, @"if".cond);
            const binding = c.bindings.pop().?;
            const cond = binding.value.getBool();
            binding.deinit();
            c.stack_top = stack_start;

            try eval(c, if (cond) @"if".then else @"if".@"else");
        },
        .@"while" => |@"while"| {
            while (true) {
                const stack_start = c.stack_top;
                try eval(c, @"while".cond);
                const binding = c.bindings.pop().?;
                const cond = binding.value.getBool();
                binding.deinit();
                c.stack_top = stack_start;

                if (!cond) break;

                try eval(c, @"while".body);
                c.bindings.pop().?.deinit();
            }
            bindingsPushEmptyTuple(c);
        },
        .@"fn" => {
            const fn_id = c.expr_to_fn.get(expr_id).?;
            c.bindings.append(allocator, .{
                .name = null,
                .value = .{
                    .ptr = null,
                    .type = makeTypeClosure(c, fn_id),
                },
                .lease = .owned,
            }) catch oom();
        },
        .param => {
            // Handled directly in .call below.
            unreachable;
        },
        .call => |call| {
            try eval(c, call.closure);
            const closure = bindingsPeek(c);

            try checkKind(c, call.closure, .{ .expected = .closure, .actual = closure.value.type });
            const @"fn" = &c.fns.items[closure.value.type.closure.fn_id.id];

            const fn_expr = c.exprs.items[@"fn".fn_expr_id.id].@"fn";

            const bindings_start = c.bindings.items.len;
            const stack_start = c.stack_top;

            for (call.args) |arg_expr|
                try eval(c, arg_expr);

            for (fn_expr.params, 0..) |param_id, i| {
                const param = c.exprs.items[param_id.id].param;
                const binding = &c.bindings.items[c.bindings.items.len - 1 - i];
                binding.name = param.name;
            }

            try eval(c, fn_expr.body);
            // TODO We could avoid this extra compaction by passing bindings_start/stack_start to the block in `fn_expr.body`.
            compactStack(c, bindings_start, stack_start);
        },
        .call_builtin => |call_builtin| {
            const bindings_start = c.bindings.items.len;
            const stack_start = c.stack_top;

            try checkArgCount(c, expr_id, .{
                .expected = switch (call_builtin.builtin) {
                    .@"+", .@"<" => 2,
                },
                .actual = call_builtin.args.len,
            });

            for (call_builtin.args) |expr|
                try eval(c, expr);

            switch (call_builtin.builtin) {
                .@"+" => {
                    const arg1 = c.bindings.pop().?;
                    defer arg1.deinit();

                    const arg0 = c.bindings.pop().?;
                    defer arg0.deinit();

                    try checkKind(c, call_builtin.args[0], .{ .expected = .number, .actual = arg0.value.type });
                    try checkKind(c, call_builtin.args[1], .{ .expected = .number, .actual = arg1.value.type });

                    const result = stackPush(c, c.type_number);
                    result.setNumber(arg0.value.getNumber() +% arg1.value.getNumber());
                    c.bindings.append(allocator, .{
                        .name = null,
                        .value = result,
                        .lease = .owned,
                    }) catch oom();
                },
                .@"<" => {
                    const arg1 = c.bindings.pop().?;
                    defer arg1.deinit();

                    const arg0 = c.bindings.pop().?;
                    defer arg0.deinit();

                    const result = stackPush(c, c.type_number);
                    result.setNumber(if (Value.order(arg0.value, arg1.value) == .lt) 1 else 0);
                    c.bindings.append(allocator, .{
                        .name = null,
                        .value = result,
                        .lease = .owned,
                    }) catch oom();
                },
            }

            compactStack(c, bindings_start, stack_start);
        },
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

fn checkKind(c: *Compiler, expr_id: ExprId, opts: struct { expected: std.meta.Tag(Type), actual: *Type }) error{Error}!void {
    if (opts.expected != opts.actual.*)
        return fail(
            c,
            .{ .expr_id = expr_id },
            "Expected a {s} but found a {s}",
            .{ @tagName(opts.expected), @tagName(opts.actual.*) },
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
