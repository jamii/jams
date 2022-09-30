const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;
const Token = sql.grammar.Token;
const keywords = sql.grammar.keywords;

const Self = @This();
arena: *u.ArenaAllocator,
allocator: u.Allocator,
source: [:0]const u8,
pos: usize,
tokens: u.ArrayList(Token),
token_ranges: u.ArrayList([2]usize),

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

pub fn init(arena: *u.ArenaAllocator, source: [:0]const u8) Self {
    const allocator = arena.allocator();
    return .{
        .arena = arena,
        .allocator = allocator,
        .source = source,
        .pos = 0,
        .tokens = u.ArrayList(Token).init(allocator),
        .token_ranges = u.ArrayList([2]usize).init(allocator),
    };
}

pub fn tokenize(self: *Self) !void {
    while (true) {
        const start_pos = self.pos;
        const token = (try self.next()) orelse continue;
        try self.tokens.append(token);
        try self.token_ranges.append(.{ start_pos, self.pos });
        if (token == .eof) break;
    }
}

pub fn next(self: *Self) !?Token {
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
                '<' => state = .less_than,
                '>' => state = .greater_than,
                '+' => return Token.plus,
                '*' => return Token.star,
                '/' => return Token.forward_slash,
                '=' => state = .equal,
                '.' => return Token.dot,
                '%' => return Token.percent,
                '!' => state = .not,
                '|' => state = .bitwise_or,
                '&' => return Token.bitwise_and,
                '~' => return Token.bitwise_not,
                '"', '\'' => {
                    string_start = char;
                    state = .string;
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
                '\'', '"' => {
                    if (char == string_start) {
                        state = .string;
                    } else {
                        self.pos -= 1;
                        return Token.string;
                    }
                },
                else => {
                    self.pos -= 1;
                    return Token.string;
                },
            },
            .comment => switch (char) {
                0, '\r', '\n' => {
                    self.pos -= 1;
                    state = .start;
                    return null;
                },
                else => {},
            },
            .whitespace => switch (char) {
                ' ', '\r', '\t', '\n' => {},
                else => {
                    self.pos -= 1;
                    state = .start;
                    return null;
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
                    const max_token_len = sql.grammar.keywords.kvs[sql.grammar.keywords.kvs.len - 1].key.len;
                    if (name.len <= max_token_len) {
                        var buffer: [max_token_len]u8 = undefined;
                        const upper_name = std.ascii.upperString(&buffer, name);
                        if (sql.grammar.keywords.get(upper_name)) |token|
                            return token;
                    }
                    return Token.name;
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
