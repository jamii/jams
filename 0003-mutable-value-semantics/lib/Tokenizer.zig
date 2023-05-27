const std = @import("std");
const panic = std.debug.panic;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const startsWith = std.mem.startsWith;

const Self = @This();
allocator: Allocator,
source: []const u8,
tokens: ArrayList(Token),
ranges: ArrayList([2]usize),
error_message: ?[]const u8,

pub const Token = enum {
    comma,
    colon,
    semicolon,
    open_paren,
    close_paren,
    open_bracket,
    close_bracket,
    open_brace,
    close_brace,
    ampersand,
    question,
    exclamation,
    greater_than,
    less_than,
    period,
    multiply,
    divide,
    plus_equals,
    plus,
    double_equals,
    equals,
    comment,
    arrow,
    minus_equals,
    minus,
    let,
    in,
    @"var",
    @"struct",
    as,
    @"if",
    fun,
    inout,
    @"while",
    Any,
    Int,
    Float,
    identifier,
    Identifier,
    number,
    whitespace,
    eof,
};

pub fn init(allocator: Allocator, source: []const u8) Self {
    return Self{
        .allocator = allocator,
        .source = source,
        .tokens = ArrayList(Token).init(allocator),
        .ranges = ArrayList([2]usize).init(allocator),
        .error_message = null,
    };
}

pub fn tokenize(self: *Self) !void {
    const source = self.source;
    var i: usize = 0;
    while (i < source.len) {
        const start = i;
        const char = source[i];
        i += 1;
        const token: Token = switch (char) {
            ',' => .comma,
            ':' => .colon,
            ';' => .semicolon,
            '(' => .open_paren,
            ')' => .close_paren,
            '[' => .open_bracket,
            ']' => .close_bracket,
            '{' => .open_brace,
            '}' => .close_brace,
            '&' => .ampersand,
            '?' => .question,
            '!' => .exclamation,
            '>' => .greater_than,
            '<' => .less_than,
            '.' => .period,
            '*' => .multiply,
            '+' => token: {
                const next_char = if (i < source.len) source[i] else 0;
                i += 1;
                switch (next_char) {
                    '=' => break :token Token.plus_equals,
                    else => {
                        i -= 1;
                        break :token Token.plus;
                    },
                }
            },
            '=' => token: {
                const next_char = if (i < source.len) source[i] else 0;
                i += 1;
                switch (next_char) {
                    '=' => break :token Token.double_equals,
                    else => {
                        i -= 1;
                        break :token Token.equals;
                    },
                }
            },
            '/' => token: {
                const next_char = if (i < source.len) source[i] else 0;
                i += 1;
                switch (next_char) {
                    '/' => {
                        while (i < source.len and source[i] != '\n') : (i += 1) {}
                        break :token Token.comment;
                    },
                    else => {
                        i -= 1;
                        break :token Token.divide;
                    },
                }
            },
            '-' => token: {
                const next_char = if (i < source.len) source[i] else 0;
                i += 1;
                switch (next_char) {
                    '>' => break :token Token.arrow,
                    '=' => break :token Token.minus_equals,
                    else => {
                        i -= 1;
                        break :token Token.minus;
                    },
                }
            },
            'a'...'z' => token: {
                i -= 1;
                while (i < source.len) {
                    switch (source[i]) {
                        'a'...'z', 'A'...'Z', '0'...'9' => i += 1,
                        else => break,
                    }
                }
                const name = source[start..i];
                const keywords = [_]Token{
                    .let,
                    .in,
                    .@"var",
                    .@"let",
                    .@"struct",
                    .as,
                    .@"if",
                    .fun,
                    .inout,
                    .@"while",
                };
                break :token match(name, &keywords) orelse Token.identifier;
            },
            'A'...'Z' => token: {
                i -= 1;
                while (i < source.len) {
                    switch (source[i]) {
                        'a'...'z', 'A'...'Z', '0'...'9' => i += 1,
                        else => break,
                    }
                }
                const name = source[start..i];
                const types = [_]Token{
                    .Any,
                    .Int,
                    .Float,
                };
                break :token match(name, &types) orelse Token.Identifier;
            },
            '0'...'9' => token: {
                while (i < source.len) {
                    switch (source[i]) {
                        '0'...'9', '.' => i += 1,
                        else => break,
                    }
                }
                break :token Token.number;
            },
            ' ', '\n' => token: {
                while (i < source.len) {
                    switch (source[i]) {
                        ' ', '\n' => i += 1,
                        else => break,
                    }
                }
                break :token Token.whitespace;
            },
            else => return self.fail(start),
        };
        self.tokens.append(token) catch panic("OOM", .{});
        self.ranges.append(.{ start, i }) catch panic("OOM", .{});
    }

    self.tokens.append(.eof) catch panic("OOM", .{});
    self.ranges.append(.{ i, i }) catch panic("OOM", .{});
}

fn match(name: []const u8, comptime tokens: []const Token) ?Token {
    inline for (tokens) |token| {
        if (std.mem.eql(u8, name, @tagName(token)))
            return token;
    }
    return null;
}

fn fail(self: *Self, pos: usize) error{TokenizeError} {
    self.error_message = std.fmt.allocPrint(self.allocator, "Tokenizer error at {}: {s}", .{
        pos,
        self.source[pos..@min(pos + 100, self.source.len)],
    }) catch panic("OOM", .{});
    return error.TokenizeError;
}
