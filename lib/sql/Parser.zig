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
}

pub fn parseStatement(self: *Self) !void {
    _ = (try self.parse(self.bnf.sql_data_change_statement.?)) orelse return error.ParseError;
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
            if (node_id == null or end_pos <= last_end_pos) break;
            last_node_id = node_id;
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
            if (std.mem.startsWith(u8, self.source[self.pos..], literal)) {
                self.pos += literal.len;
                return @as(?usize, try self.pushNode(bnf_node_id, start_pos, null, null));
            } else {
                return null;
            }
        },
        .either => |either| {
            if (try self.parse(either[0])) |node_id| return @as(?usize, node_id);
            self.pos = start_pos;
            if (try self.parse(either[1])) |node_id| return @as(?usize, node_id);
            return null;
        },
        .both => |both| {
            const left_child = (try self.parse(both[0])) orelse return null;
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
