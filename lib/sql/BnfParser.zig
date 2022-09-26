const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;

const Self = @This();
const source = @embedFile("../../deps/sql-2016.bnf");
allocator: u.Allocator,
nodes: u.ArrayList(BnfNode),
name_to_node: u.DeepHashMap([]const u8, BnfNodeId),
pos: usize,

pub const BnfNodeId = usize;
pub const BnfNode = union(enum) {
    def_name: struct {
        name: []const u8,
        body: BnfNodeId,
    },
    ref_name: []const u8,
    literal: []const u8,
    either: [2]BnfNodeId,
    both: [2]BnfNodeId,
    optional: BnfNodeId,
    one_or_more: BnfNodeId,
    special,
};
pub const Error = error{OutOfMemory};

pub fn init(allocator: u.Allocator) Self {
    return Self{
        .allocator = allocator,
        .nodes = u.ArrayList(BnfNode).init(allocator),
        .name_to_node = u.DeepHashMap([]const u8, BnfNodeId).init(allocator),
        .pos = 0,
    };
}

pub fn assert(self: *Self, cond: bool) void {
    u.assert(cond, .{ self.nodes.items[if (self.nodes.items.len > 100) self.nodes.items.len - 100 else 0..], source[self.pos..] });
}

pub fn splitAt(self: *Self, needle: []const u8) ?[]const u8 {
    if (std.mem.indexOf(u8, source[self.pos..], needle)) |offset| {
        const result = source[self.pos .. self.pos + offset];
        self.pos += offset + needle.len;
        return result;
    } else return null;
}

pub fn consume(self: *Self, needle: []const u8) void {
    self.assert(self.tryConsume(needle));
}

pub fn tryConsume(self: *Self, needle: []const u8) bool {
    if (std.mem.startsWith(u8, source[self.pos..], needle)) {
        self.pos += needle.len;
        return true;
    } else {
        return false;
    }
}

pub fn discardSpace(self: *Self) void {
    while (self.pos <= source.len) {
        switch (source[self.pos]) {
            ' ' => self.pos += 1,
            else => break,
        }
    }
}

pub fn discardSpaceAndNewline(self: *Self) void {
    while (self.pos <= source.len) {
        switch (source[self.pos]) {
            ' ', '\n' => self.pos += 1,
            else => break,
        }
    }
}

pub fn pushNode(self: *Self, node: BnfNode) Error!BnfNodeId {
    const id = self.nodes.items.len;
    try self.nodes.append(node);
    if (node == .def_name)
        try self.name_to_node.put(node.def_name.name, id);
    return id;
}

pub fn parseDefs(self: *Self) Error!void {
    while (self.pos < source.len) {
        self.discardSpaceAndNewline();
        if (self.pos == source.len) return;
        switch (source[self.pos]) {
            '0'...'9' => {
                // Skip comments
                _ = self.splitAt("Format\n");
            },
            else => {},
        }
        _ = try self.parseDef();
    }
}

fn parseDef(self: *Self) Error!BnfNodeId {
    const name = self.parseName();
    _ = self.splitAt("::=");
    self.discardSpaceAndNewline();
    const body = try self.parseDefBody(name);
    return self.pushNode(.{ .def_name = .{ .name = name, .body = body } });
}

fn parseName(self: *Self) []const u8 {
    self.consume("<");
    return self.splitAt(">").?;
}

fn parseDefBody(self: *Self, name: []const u8) Error!BnfNodeId {
    // We have to special case a bunch of unescaped literals
    if (u.deepEqual(name, "left bracket")) {
        self.consume("[");
        return self.pushNode(.{ .literal = "[" });
    } else if (u.deepEqual(name, "right bracket")) {
        self.consume("]");
        return self.pushNode(.{ .literal = "]" });
    } else if (u.deepEqual(name, "less than operator")) {
        self.consume("<");
        return self.pushNode(.{ .literal = "<" });
    } else if (u.deepEqual(name, "less than or equals operator")) {
        self.consume("<=");
        return self.pushNode(.{ .literal = "<=" });
    } else {
        return self.parseExpr();
    }
}

fn parseExpr(self: *Self) Error!BnfNodeId {
    if (std.mem.startsWith(u8, source[self.pos..], "!!")) {
        _ = self.splitAt("\n") orelse "";
        return self.pushNode(.special);
    }

    var node = try self.parseAtom();

    while (true) {
        self.discardSpace();
        if (self.tryConsume("\n")) {
            if (self.pos < source.len and source[self.pos] == '<')
                // This is the start of a new def (because it isn't indendent)
                break;
        } else if (self.tryConsume("...")) {
            node = try self.pushNode(.{ .one_or_more = node });
        } else if (self.tryConsume("|")) {
            self.discardSpaceAndNewline();
            const right = try self.parseAtom();
            node = try self.pushNode(.{ .either = .{ node, right } });
        } else if (self.tryConsume("!!")) {
            // Discard comment
            _ = self.splitAt("\n") orelse "";
        } else if (self.pos >= source.len or source[self.pos] == ']') {
            break;
        } else {
            const right = try self.parseAtom();
            node = try self.pushNode(.{ .both = .{ node, right } });
        }
    }

    return node;
}

fn parseAtom(self: *Self) Error!BnfNodeId {
    return switch (source[self.pos]) {
        '<' => try self.parseRefName(),
        '[' => try self.parseOptional(),
        else => try self.parseLiteral(),
    };
}

fn parseRefName(self: *Self) Error!BnfNodeId {
    const name = self.parseName();
    return self.pushNode(.{ .ref_name = name });
}

fn parseLiteral(self: *Self) Error!BnfNodeId {
    const start = self.pos;
    while (self.pos < source.len) {
        switch (source[self.pos]) {
            ' ', '\n' => break,
            else => self.pos += 1,
        }
    }
    return self.pushNode(.{ .literal = source[start..self.pos] });
}

fn parseOptional(self: *Self) Error!BnfNodeId {
    self.consume("[");
    self.discardSpaceAndNewline();
    const body = try self.parseExpr();
    self.discardSpaceAndNewline();
    self.consume("]");
    return self.pushNode(.{ .optional = body });
}
