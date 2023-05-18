const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const startsWith = std.mem.startsWith;
const panic = std.debug.panic;

const Self = @This();
allocator: Allocator,
tokens: ArrayList(Token),
ranges: ArrayList([2]usize),

pub const Token = enum {
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
    Unit,
    identifier,
    Identifier,
    number,
    whitespace,
};

pub fn init(allocator: Allocator, source: []const u8) Self {
    var self = Self{
        .allocator = allocator,
        .tokens = ArrayList(Token).init(allocator),
        .ranges = ArrayList([2]usize).init(allocator),
    };

    var i: usize = 0;
    while (i < source.len) : (i += 1) {
        const start = i;
        const char = source[i];
        i += 1;
        const token: Token = switch (char) {
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
                    '/' => break :token Token.comment,
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
                const keywords = [_]Token{
                    .let,
                    .in,
                    .@"var",
                    .@"struct",
                    .as,
                    .@"if",
                    .fun,
                    .inout,
                    .@"while",
                };
                if (match(source, &i, &keywords)) |token| {
                    break :token token;
                } else {
                    while (i < source.len) : (i += 1) {
                        switch (source[i]) {
                            'a'...'z', 'A'...'Z', '0'...'9' => {},
                            else => {
                                i -= 1;
                                break;
                            },
                        }
                    }
                    break :token Token.identifier;
                }
            },
            'A'...'Z' => token: {
                i -= 1;
                const types = [_]Token{
                    .Any,
                    .Int,
                    .Float,
                    .Unit,
                };
                if (match(source, &i, &types)) |token| {
                    break :token token;
                } else {
                    while (i < source.len) : (i += 1) {
                        switch (source[i]) {
                            'a'...'z', 'A'...'Z', '0'...'9' => {},
                            else => {
                                i -= 1;
                                break;
                            },
                        }
                    }
                    break :token Token.Identifier;
                }
            },
            '0'...'9' => token: {
                while (i < source.len) : (i += 1) {
                    switch (source[i]) {
                        '0'...'9', '.' => {},
                        else => {
                            i -= 1;
                            break;
                        },
                    }
                }
                break :token Token.number;
            },
            ' ', '\n' => token: {
                while (i < source.len) : (i += 1) {
                    switch (source[i]) {
                        ' ', '\n' => {},
                        else => {
                            i -= 1;
                            break;
                        },
                    }
                }
                break :token Token.whitespace;
            },
            else => self.fail(start),
        };
        self.tokens.append(token) catch panic("OOM", .{});
        self.ranges.append(.{ start, i }) catch panic("OOM", .{});
    }

    return self;
}

fn match(source: []const u8, start: *usize, comptime tokens: []const Token) ?Token {
    inline for (tokens) |token| {
        if (startsWith(u8, source[start.*..], @tagName(token))) {
            start.* += @tagName(token).len;
            return token;
        }
    }
    return null;
}

fn fail(self: *Self, pos: usize) noreturn {
    // Lazy error handling.
    _ = self;
    panic("Tokenizer error at {}", .{pos});
}

pub fn main() void {
    const self = Self.init(std.testing.allocator, "foo + Any");
    std.debug.print("{any}", .{self.tokens.items});
}
