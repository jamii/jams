const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;

const Self = @This();
allocator: u.Allocator,
bnf: *const sql.BnfParser,
source: []const u8,
pos: usize,
nodes: u.ArrayList(Node),
memo: u.DeepHashMap(MemoKey, ?NodeId),

pub const NodeId = usize;
pub const Node = struct {
    bnf_node_id: sql.BnfParser.NodeId,
    range: [2]usize,
    children: [2]?NodeId,
};

pub const MemoKey = struct {
    pos: usize,
    bnf_node_id: sql.BnfParser.NodeId,
};

const Error = error{
    OutOfMemory,
};

pub fn init(allocator: u.Allocator, bnf: *const sql.BnfParser, source: []const u8) Self {
    return Self{
        .allocator = allocator,
        .bnf = bnf,
        .source = source,
        .pos = 0,
        .nodes = u.ArrayList(Node).init(allocator),
        .memo = u.DeepHashMap(MemoKey, ?NodeId).init(allocator),
    };
}

pub fn parseQuery(self: *Self) !void {
    _ = (try self.parse(self.bnf.query_specification.?)) orelse return error.ParseError;
    if (self.pos < self.source.len) return error.ParseError;
}

pub fn parseStatement(self: *Self) !void {
    _ = (try self.parse(self.bnf.sql_procedure_statement.?)) orelse return error.ParseError;
    if (self.pos < self.source.len) return error.ParseError;
}

fn pushNode(self: *Self, bnf_node_id: sql.BnfParser.NodeId, start_pos: usize, left_child: ?NodeId, right_child: ?NodeId) Error!NodeId {
    const id = self.nodes.items.len;
    try self.nodes.append(.{
        .bnf_node_id = bnf_node_id,
        .range = .{ start_pos, self.pos },
        .children = .{ left_child, right_child },
    });
    return id;
}

fn parse(self: *Self, bnf_node_id: sql.BnfParser.NodeId) Error!?NodeId {
    const start_pos = self.pos;
    const entry = try self.memo.getOrPut(.{ .pos = start_pos, .bnf_node_id = bnf_node_id });
    if (entry.found_existing) {
        return entry.value_ptr.*;
    } else {
        entry.value_ptr.* = null;
        var last_node_id: ?NodeId = null;
        var last_end_pos: usize = self.pos;
        while (true) {
            self.pos = start_pos;
            const node_id = try self.parseInner(bnf_node_id);
            const end_pos = self.pos;
            if (node_id == null or end_pos < last_end_pos) break;
            last_node_id = node_id;
            if (end_pos == last_end_pos) break;
            last_end_pos = end_pos;
        }
        self.pos = last_end_pos;
        return last_node_id;
    }
}

fn parseInner(self: *Self, bnf_node_id: sql.BnfParser.NodeId) Error!?NodeId {
    const start_pos = self.pos;
    switch (self.bnf.nodes.items[bnf_node_id]) {
        .def_name => |def_name| return self.parse(def_name.body),
        .ref_name => |ref_name| return self.parse(ref_name.id.?),
        .literal => |literal| {
            if (self.pos + literal.len < self.source.len) {
                const candidate = try std.ascii.allocLowerString(self.allocator, self.source[self.pos .. self.pos + literal.len]);
                defer self.allocator.free(candidate);
                if (std.mem.eql(u8, candidate, literal)) {
                    self.pos += literal.len;
                    return @as(?usize, try self.pushNode(bnf_node_id, start_pos, null, null));
                }
            }
            return null;
        },
        .either => |either| {
            if (try self.parse(either[0])) |node_id| return @as(?usize, node_id);
            self.pos = start_pos;
            if (try self.parse(either[1])) |node_id| return @as(?usize, node_id);
            return null;
        },
        .both => |both| {
            const left_child = (try self.parse(both[0])) orelse return null;
            self.discardSpaceAndNewline();
            const right_child = (try self.parse(both[1])) orelse return null;
            return @as(?usize, try self.pushNode(bnf_node_id, start_pos, left_child, right_child));
        },
        .optional => |optional| {
            const child = try self.parse(optional);
            return @as(?usize, try self.pushNode(bnf_node_id, start_pos, child, null));
        },
        .fail => return null,

        else =>
        //TODO
        unreachable,
    }
}

pub fn discardSpaceAndNewline(self: *Self) void {
    while (self.pos <= self.source.len) {
        switch (self.source[self.pos]) {
            ' ', '\n' => self.pos += 1,
            else => break,
        }
    }
}

pub fn dumpInto(writer: anytype, indent: u32, self: Self) anyerror!void {
    if (self.nodes.items.len == 0)
        try writer.writeAll("<empty>\n")
    else
        try dumpNodeInto(writer, indent, self, self.nodes.items.len - 1);
}

pub fn dumpNodeInto(writer: anytype, indent: u32, self: Self, node_id: NodeId) anyerror!void {
    const node = self.nodes.items[node_id];
    const bnf_node = self.bnf.nodes.items[node.bnf_node_id];
    if (bnf_node == .def_name) {
        try writer.writeByteNTimes(' ', indent);
        try std.fmt.format(writer, "{s}: {}\n", .{ bnf_node.def_name.name, std.zig.fmtEscapes(self.source[node.range[0]..node.range[1]]) });
    }
    for (node.children) |child_id_maybe|
        if (child_id_maybe) |child_id|
            try dumpNodeInto(writer, indent + 2, self, child_id);
}
