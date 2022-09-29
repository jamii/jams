const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;
const Token = sql.grammar.Token;
const keywords = sql.grammar.keywords;

const Self = @This();
source: [:0]const u8,
pos: usize,

const State = enum {
    start,
    name,
    string,
    string_maybe_end,
    number,
    comment,
    whitespace,
    minus,
    less_than,
    greater_than,
    equal,
    not,
    bitwise_or,
};

pub fn init(source: [:0]const u8) Self {
    return .{
        .source = source,
        .pos = 0,
    };
}

pub fn next(self: *Self) !Token {
    var state = State.start;
    var string_start: u8 = 0;
    const start_pos = self.pos;
    while (true) {
        //u.dump(.{ self.pos, state, self.source[self.pos..] });
        const char = self.source[self.pos];
        self.pos += 1;
        switch (state) {
            .start => switch (char) {
                0 => {
                    self.pos -= 1;
                    return Token.eof;
                },
                ',' => return Token.comma,
                '(' => return Token.open_paren,
                ')' => return Token.close_paren,
                '>' => state = .less_than,
                '<' => state = .greater_than,
                '+' => return Token.plus,
                '*' => return Token.star,
                '/' => return Token.forward_slash,
                '=' => state = .equal,
                '.' => return Token.dot,
                '%' => return Token.modulus,
                '!' => state = .not,
                '|' => state = .bitwise_or,
                '&' => return Token.bitwise_and,
                '~' => return Token.bitwise_not,
                '"' => {
                    string_start = '"';
                    state = .string;
                },
                '\'' => {
                    string_start = '\'';
                    state = .comment;
                },
                ';' => return Token.semicolon,
                'a'...'z', 'A'...'Z' => state = .name,
                '0'...'9' => state = .number,
                '-' => state = .minus,
                ' ', '\r', '\t', '\n' => state = .whitespace,
                else => return error.TokenizerError,
            },
            .less_than => switch (char) {
                '=' => return Token.less_than_or_equal,
                '>' => return Token.not_equal,
                '<' => return Token.shift_left,
                else => {
                    self.pos -= 1;
                    return Token.less_than;
                },
            },
            .greater_than => switch (char) {
                '=' => return Token.greater_than_or_equal,
                '>' => return Token.shift_right,
                else => {
                    self.pos -= 1;
                    return Token.greater_than;
                },
            },
            .equal => switch (char) {
                '=' => return Token.double_equal,
                else => {
                    self.pos -= 1;
                    return Token.equal;
                },
            },
            .not => switch (char) {
                '=' => return Token.not_equal,
                '<' => return Token.not_less_than,
                '>' => return Token.not_greater_than,
                else => {
                    self.pos -= 1;
                    return error.TokenizerError;
                },
            },
            .bitwise_or => switch (char) {
                '|' => return Token.string_concat,
                else => {
                    self.pos -= 1;
                    return Token.bitwise_or;
                },
            },
            .string => switch (char) {
                0 => return error.TokenizerError,
                '\'', '"' => {
                    if (char == string_start) {
                        state = .string_maybe_end;
                    } else {
                        return Token.string;
                    }
                },
                else => {},
            },
            .string_maybe_end => switch (char) {
                0 => {
                    self.pos -= 1;
                    return Token.string;
                },
                '\'', '"' => {
                    if (char == string_start) {
                        state = .string;
                    } else {
                        self.pos -= 1;
                        return Token.string;
                    }
                },
                else => state = .string,
            },
            .comment => switch (char) {
                0, '\r', '\n' => {
                    self.pos -= 1;
                    state = .start;
                    return self.next();
                },
                else => {},
            },
            .whitespace => switch (char) {
                ' ', '\r', '\t', '\n' => {},
                else => {
                    self.pos -= 1;
                    state = .start;
                    return self.next();
                },
            },
            .number => switch (char) {
                '0'...'9', '.' => {},
                // This looks too much like a name
                'a'...'z', 'A'...'Z' => return error.TokenizerError,
                else => {
                    self.pos -= 1;
                    return Token.number;
                },
            },
            .name => switch (char) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => {},
                else => {
                    self.pos -= 1;
                    const name = self.source[start_pos..self.pos];
                    return if (sql.grammar.keywords.get(name)) |token|
                        token
                    else
                        Token.name;
                },
            },
            .minus => switch (char) {
                '-' => state = .comment,
                else => {
                    self.pos -= 1;
                    return Token.minus;
                },
            },
        }
    }
}

pub const TokensAndRanges = struct {
    tokens: []const Token,
    ranges: []const [2]usize,
};

pub fn tokenize(self: *Self, allocator: u.Allocator) !TokensAndRanges {
    var tokens = u.ArrayList(Token).init(allocator);
    var ranges = u.ArrayList([2]usize).init(allocator);
    while (true) {
        const start_pos = self.pos;
        const token = try self.next();
        try tokens.append(token);
        try ranges.append(.{ start_pos, self.pos });
        if (token == .eof) break;
    }
    return TokensAndRanges{
        .tokens = tokens.toOwnedSlice(),
        .ranges = ranges.toOwnedSlice(),
    };
}
