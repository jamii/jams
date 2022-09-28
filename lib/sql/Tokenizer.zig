const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;
const Token = sql.grammar.Token;
const keywords = sql.grammar.keywords;

const Self = @This();
source: []const u8,
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
    while (true) {
        const char = self.source[self.pos];
        self.pos += 1;
        switch (state) {
            .start => switch (char) {
                0 => {
                    self.pos -= 1;
                    return Token.eof;
                },
                '"' => {
                    string_start = '"';
                    state = .string;
                },
                '\'' => {
                    string_start = '\'';
                    state = .comment;
                },
                'a'...'z', 'A'...'Z' => state = .name,
                '0'...'9' => state = .number,
                '-' => state = .minus,
                ' ', '\r', '\t', '\n' => state = .whitespace,
                else => return error.TokenizerError,
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
                    return self.next();
                },
                else => {},
            },
            .whitespace => switch (char) {
                ' ', '\r', '\t', '\n' => {},
                else => {
                    self.pos -= 1;
                    return self.next();
                },
            },
            .number => switch (char) {
                '0'...'9', '.' => {},
                0, ' ', '\r', '\t', '\n', ')', ']', '}' => {
                    self.pos -= 1;
                    return Token.number;
                },
                else => return error.TokenizerError,
            },
            .name => switch (char) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => {},
                else => {
                    self.pos -= 1;
                    return Token.name;
                },
            },
            .minus => switch (char) {
                '0'...'9' => state = .number,
                '-' => state = .comment,
                else => return error.TokenizerError,
            },
        }
    }
}

pub fn tokenize(self: *Self, allocator: u.Allocator) ![]const Token {
    var tokens = u.ArrayList(Token).init(allocator);
    while (true) {
        const token = try self.next();
        try tokens.append(token);
        if (token == .eof) break;
    }
    return tokens.toOwnedSlice();
}
