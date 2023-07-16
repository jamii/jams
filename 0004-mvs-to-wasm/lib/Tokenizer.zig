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
    number,
    string,
    name,
    let,
    mut,
    set,
    @"fn",
    @"if",
    @"else",
    @"while",
    @"(",
    @")",
    @"[",
    @"]",
    @",",
    @".",
    @";",
    @"=",
    @"==",
    @"<",
    @"<=",
    @">",
    @">=",
    @"+",
    @"-",
    @"/",
    @"*",
    comment,
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
            '(' => Token.@"(",
            ')' => Token.@")",
            '[' => Token.@"[",
            ']' => Token.@"]",
            ',' => Token.@",",
            '.' => Token.@".",
            ';' => Token.@";",
            '=' => token: {
                if (i < source.len and source[i] == '=') {
                    i += 1;
                    break :token Token.@"==";
                } else {
                    break :token Token.@"=";
                }
            },
            '<' => token: {
                if (i < source.len and source[i] == '=') {
                    i += 1;
                    break :token Token.@"<=";
                } else {
                    break :token Token.@"<";
                }
            },
            '>' => token: {
                if (i < source.len and source[i] == '=') {
                    i += 1;
                    break :token Token.@">=";
                } else {
                    break :token Token.@">";
                }
            },
            '+' => Token.@"+",
            '-' => Token.@"-",
            '/' => token: {
                if (i < source.len and source[i] == '/') {
                    while (i < source.len and source[i] != '\n') : (i += 1) {}
                    break :token Token.comment;
                } else {
                    break :token Token.@"/";
                }
            },
            '*' => Token.@"*",
            'a'...'z' => token: {
                i -= 1;
                while (i < source.len) {
                    switch (source[i]) {
                        'a'...'z', 'A'...'Z', '0'...'9', '-' => i += 1,
                        else => break,
                    }
                }
                const name = source[start..i];
                const keywords = [_]Token{
                    .let,
                    .mut,
                    .set,
                    .@"fn",
                    .@"if",
                    .@"else",
                    .@"while",
                };
                break :token match(name, &keywords) orelse Token.name;
            },
            '\'' => token: {
                var escaped = false;
                while (i < source.len) : (i += 1) {
                    switch (source[i]) {
                        '\'' => {
                            if (!escaped) {
                                i += 1;
                                break :token Token.string;
                            } else {
                                escaped = false;
                            }
                        },
                        '\\' => escaped = true,
                        else => escaped = false,
                    }
                }
                return self.fail(start);
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
