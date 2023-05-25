const std = @import("std");
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Tokenizer = @import("./Tokenizer.zig");
const Token = Tokenizer.Token;

const Self = @This();
allocator: Allocator,
tokenizer: Tokenizer,
token_ix: usize,
nodes: ArrayList(Node),
error_message: ?[]const u8,

pub const NodeId = usize;
pub const Node = union(enum) {
    decl: struct {
        name: []const u8,
        fields: []NodeId,
    },
    field: struct {
        mutability: Mutability,
        name: []const u8,
        typ: NodeId,
    },
    typ: Type,
    param: struct {
        mutability: Mutability,
        typ: NodeId,
    },
    expr: Expr,
};

pub const Mutability = enum {
    @"var",
    @"let",
};

pub const Type = union(enum) {
    any,
    int,
    float,
    unit,
    identifier: []const u8,
    list: NodeId,
    fun: struct {
        params: []NodeId,
        return_typ: NodeId,
    },
};

pub const Expr = union(enum) {
    seq: [2]NodeId,
    call: struct {
        fun: NodeId,
        mutabilities: []Mutability,
        args: []NodeId,
    },
    op: struct {
        op: Op,
        args: [2]NodeId,
    },
    @"if": struct {
        cond: NodeId,
        true_branch: NodeId,
        false_branch: NodeId,
    },
    as: struct {
        value: NodeId,
        typ: NodeId,
    },
    field: struct {
        value: NodeId,
        field: []const u8,
    },
    elem: struct {
        value: NodeId,
        elem: NodeId,
    },
    define: struct {
        mutability: Mutability,
        name: []const u8,
        typ: NodeId,
        value: NodeId,
        tail: NodeId,
    },
    list: []NodeId,
    struct_init: struct {
        name: []const u8,
        args: []NodeId,
    },
    define_fun: struct {
        name: []const u8,
        fun: NodeId,
        tail: NodeId,
    },
    fun: struct {
        names: [][]const u8,
        params: []NodeId,
        return_typ: NodeId,
        body: NodeId,
    },
    integer: i64,
    float: f64,
    name: []const u8,
};

pub const Op = enum {
    plus,
    minus,
    multiply,
    divide,
};

pub fn init(allocator: Allocator, tokenizer: Tokenizer) Self {
    return Self{
        .allocator = allocator,
        .tokenizer = tokenizer,
        .token_ix = 0,
        .nodes = ArrayList(Node).init(allocator),
        .error_message = null,
    };
}

pub fn parse(self: *Self) !void {
    while (true) {
        if (self.peek() != .@"struct") break;
        _ = try self.parseDecl();
    }
    _ = try self.parseExpr0();
    try self.expect(.eof);
}

fn parseDecl(self: *Self) !NodeId {
    std.debug.print("decl {}\n", .{self.token_ix});
    try self.expect(.@"struct");
    try self.expect(.Identifier);
    const name = self.lastTokenText();
    try self.expect(.open_brace);
    var fields = ArrayList(NodeId).init(self.allocator);
    while (true) {
        if (self.takeIf(.close_brace)) break;
        fields.append(try self.parseField()) catch panic("OOM", .{});
    }
    return self.node(.{ .decl = .{
        .name = name,
        .fields = fields.toOwnedSlice() catch panic("OOM", .{}),
    } });
}

fn parseField(self: *Self) !NodeId {
    const token = self.take();
    const mutability = switch (token) {
        .@"var" => Mutability.@"var",
        .@"let" => Mutability.@"let",
        else => return self.fail("Expected var/const, found {}", .{token}),
    };
    try self.expect(.identifier);
    const name = self.lastTokenText();
    try self.expect(.colon);
    const type_id = try self.parseType();
    return self.node(.{ .field = .{
        .mutability = mutability,
        .name = name,
        .typ = type_id,
    } });
}

fn parseType(self: *Self) error{ParseError}!NodeId {
    const token = self.take();
    const typ = switch (token) {
        .Any => Type.any,
        .Int => Type.int,
        .Float => Type.float,
        .Identifier => Type{ .identifier = self.lastTokenText() },
        .open_brace => typ: {
            const typ_inner = try self.parseType();
            try self.expect(.close_brace);
            break :typ Type{ .list = typ_inner };
        },
        .open_paren => typ: {
            var params = ArrayList(NodeId).init(self.allocator);
            while (true) {
                if (self.peek() == .close_paren) break;
                params.append(try self.parseParam()) catch panic("OOM", .{});
                if (!self.takeIf(.comma)) break;
            }
            try self.expect(.close_paren);
            try self.expect(.arrow);
            const return_typ = try self.parseType();
            break :typ Type{ .fun = .{
                .params = params.toOwnedSlice() catch panic("OOM", .{}),
                .return_typ = return_typ,
            } };
        },
        else => return self.fail("Expected type, found {}", .{token}),
    };
    return self.node(.{ .typ = typ });
}

fn parseExpr0(self: *Self) !NodeId {
    var expr = try self.parseExpr1();
    while (true) {
        if (!self.takeIf(.semicolon)) break;
        const tail = try self.parseExpr1();
        expr = self.node(.{ .expr = .{ .seq = .{ expr, tail } } });
    }
    return expr;
}

fn parseExpr1(self: *Self) !NodeId {
    const expr = try self.parseExpr2();
    const token = self.take();
    std.debug.print("expr1: {} {s}\n", .{ token, self.lastTokenText() });
    switch (token) {
        .open_paren => {
            var args = ArrayList(NodeId).init(self.allocator);
            var mutabilities = ArrayList(Mutability).init(self.allocator);
            while (true) {
                if (self.peek() == .close_paren) break;
                mutabilities.append(if (self.takeIf(.ampersand)) .@"var" else .let) catch panic("OOM", .{});
                args.append(try self.parseExpr1()) catch panic("OOM", .{});
                if (!self.takeIf(.comma)) break;
            }
            try self.expect(.close_paren);
            return self.node(.{ .expr = .{ .call = .{
                .fun = expr,
                .mutabilities = mutabilities.toOwnedSlice() catch panic("OOM", .{}),
                .args = args.toOwnedSlice() catch panic("OOM", .{}),
            } } });
        },
        .question => {
            const true_branch = try self.parseExpr1();
            try self.expect(.colon);
            const false_branch = try self.parseExpr1();
            return self.node(.{ .expr = .{ .@"if" = .{
                .cond = expr,
                .true_branch = true_branch,
                .false_branch = false_branch,
            } } });
        },
        .as => {
            const typ = try self.parseType();
            return self.node(.{ .expr = .{ .as = .{
                .value = expr,
                .typ = typ,
            } } });
        },
        .period => {
            try self.expect(.identifier);
            const field = self.lastTokenText();
            return self.node(.{ .expr = .{ .field = .{
                .value = expr,
                .field = field,
            } } });
        },
        .open_bracket => {
            const elem = try self.parseExpr1();
            try self.expect(.close_bracket);
            return self.node(.{ .expr = .{ .elem = .{
                .value = expr,
                .elem = elem,
            } } });
        },
        .plus, .minus, .multiply, .divide => {
            const op = switch (token) {
                .plus => Op.plus,
                .minus => Op.minus,
                .multiply => Op.multiply,
                .divide => Op.divide,
                else => unreachable,
            };
            const right = try self.parseExpr1();
            return self.node(.{ .expr = .{ .op = .{ .op = op, .args = .{ expr, right } } } });
        },
        else => {
            self.token_ix -= 1;
            return expr;
        },
    }
}

fn parseExpr2(self: *Self) error{ParseError}!NodeId {
    const token = self.take();
    std.debug.print("expr2: {} {s}\n", .{ token, self.lastTokenText() });
    switch (token) {
        .@"let", .@"var" => {
            const mutability = switch (token) {
                .@"let" => Mutability.@"let",
                .@"var" => Mutability.@"var",
                else => unreachable,
            };
            try self.expect(.identifier);
            const name = self.lastTokenText();
            try self.expect(.colon);
            const typ = try self.parseType();
            try self.expect(.equals);
            const value = try self.parseExpr1();
            try self.expect(.in);
            const tail = try self.parseExpr0();
            return self.node(.{ .expr = .{ .define = .{
                .mutability = mutability,
                .name = name,
                .typ = typ,
                .value = value,
                .tail = tail,
            } } });
        },
        .open_bracket => {
            var exprs = ArrayList(NodeId).init(self.allocator);
            while (true) {
                if (self.peek() == .close_bracket) break;
                exprs.append(try self.parseExpr1()) catch panic("OOM", .{});
                if (!self.takeIf(.comma)) break;
            }
            try self.expect(.close_bracket);
            return self.node(.{ .expr = .{
                .list = exprs.toOwnedSlice() catch panic("OOM", .{}),
            } });
        },
        .Identifier => {
            const name = self.lastTokenText();
            try self.expect(.open_paren);
            var args = ArrayList(NodeId).init(self.allocator);
            while (true) {
                if (self.peek() == .close_paren) break;
                args.append(try self.parseExpr1()) catch panic("OOM", .{});
                if (!self.takeIf(.comma)) break;
            }
            try self.expect(.close_paren);
            return self.node(.{ .expr = .{ .struct_init = .{
                .name = name,
                .args = args.toOwnedSlice() catch panic("OOM", .{}),
            } } });
        },
        .fun => {
            try self.expect(.identifier);
            const name = self.lastTokenText();
            const fun = try self.parseFun();
            try self.expect(.in);
            const tail = try self.parseExpr0();
            return self.node(.{ .expr = .{ .define_fun = .{
                .name = name,
                .fun = fun,
                .tail = tail,
            } } });
        },
        .open_paren => {
            self.token_ix -= 1;
            if (self.parseFun()) |fun| {
                return fun;
            } else |_| {
                try self.expect(.open_paren);
                const expr = self.parseExpr0();
                try self.expect(.close_paren);
                return expr;
            }
        },
        .number => {
            const text = self.lastTokenText();
            if (std.mem.indexOfScalar(u8, text, '.') == null) {
                if (std.fmt.parseInt(i64, text, 10)) |integer| {
                    return self.node(.{ .expr = .{ .integer = integer } });
                } else |_| {
                    return self.fail("Can't parse integer: {s}", .{text});
                }
            } else {
                if (std.fmt.parseFloat(f64, text)) |float| {
                    return self.node(.{ .expr = .{ .float = float } });
                } else |_| {
                    return self.fail("Can't parse float: {s}", .{text});
                }
            }
        },
        .identifier => {
            const name = self.lastTokenText();
            return self.node(.{ .expr = .{ .name = name } });
        },
        else => {
            return self.fail("Expected start of expression, found {}", .{token});
        },
    }
}

fn parseFun(self: *Self) !NodeId {
    try self.expect(.open_paren);
    var names = ArrayList([]const u8).init(self.allocator);
    var params = ArrayList(NodeId).init(self.allocator);
    while (true) {
        if (self.peek() == .close_paren) break;
        try self.expect(.identifier);
        names.append(self.lastTokenText()) catch panic("OOM", .{});
        params.append(try self.parseParam()) catch panic("OOM", .{});
        if (!self.takeIf(.comma)) break;
    }
    try self.expect(.close_paren);
    try self.expect(.arrow);
    const return_typ = try self.parseType();
    try self.expect(.open_brace);
    // TODO not used in mvs tests?
    //var closes = ArrayList([]const u8).init(self.allocator);
    //{
    //    try self.expect(.open_bracket);
    //    while (true) {
    //        if (self.peek() == .close_bracket) break;
    //        try self.expect(.identifier);
    //        closes.append(self.lastTokenText()) catch panic("OOM", .{});
    //        if (!self.takeIf(.comma)) break;
    //    }
    //    try self.expect(.close_bracket);
    //}
    //try self.expect(.in);
    const body = try self.parseExpr0();
    return self.node(.{ .expr = .{ .fun = .{
        .names = names.toOwnedSlice() catch panic("OOM", .{}),
        .params = params.toOwnedSlice() catch panic("OOM", .{}),
        .return_typ = return_typ,
        .body = body,
    } } });
}

fn parseParam(self: *Self) !NodeId {
    try self.expect(.colon);
    const mutability = if (self.takeIf(.inout)) Mutability.@"var" else Mutability.let;
    const typ = try self.parseType();
    return self.node(.{ .param = .{
        .mutability = mutability,
        .typ = typ,
    } });
}

fn peek(self: *Self) Token {
    while (true) {
        const tokens = self.tokenizer.tokens.items;
        const token = if (self.token_ix > tokens.len) .eof else tokens[self.token_ix];
        switch (token) {
            .whitespace, .comment => self.token_ix += 1,
            else => return token,
        }
    }
}

fn take(self: *Self) Token {
    const token = self.peek();
    self.token_ix += 1;
    return token;
}

fn expect(self: *Self, expected: Token) !void {
    const found = self.take();
    if (found != expected) {
        return self.fail("Expected {}, found {}", .{ expected, found });
    }
}

fn takeIf(self: *Self, wanted: Token) bool {
    const found = self.take();
    if (found != wanted) {
        self.token_ix -= 1;
    }
    return found == wanted;
}

fn fail(self: *Self, comptime message: []const u8, args: anytype) error{ParseError} {
    const source_ix = self.tokenizer.ranges.items[self.token_ix - 1][0];
    self.error_message = std.fmt.allocPrint(
        self.allocator,
        "At {}. " ++ message,
        .{source_ix} ++ args,
    ) catch panic("OOM", .{});
    return error.ParseError;
}

fn lastTokenText(self: *Self) []const u8 {
    const range = self.tokenizer.ranges.items[self.token_ix - 1];
    return self.tokenizer.source[range[0]..range[1]];
}

fn node(self: *Self, node_value: Node) NodeId {
    const id = self.nodes.items.len;
    self.nodes.append(node_value) catch panic("OOM", .{});
    return id;
}
