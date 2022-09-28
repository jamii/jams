const std = @import("std");
const sql = @import("../sql.zig");
const u = sql.util;

const Self = @This();
allocator: u.Allocator,
arena: u.ArenaAllocator,
bnf: *const sql.BnfParser,
source: []const u8,
may_contain_whitespace: bool,
nodes: u.ArrayList(Node),
memo: u.DeepHashMap(MemoKey, MemoValue),

pub const NodeId = usize;
pub const Node = struct {
    bnf_node_id: sql.BnfParser.NodeId,
    range: [2]usize,
    children: [2]?NodeId,
    hash: u128,
};

pub const MemoKey = struct {
    start_pos: usize,
    bnf_node_id: sql.BnfParser.NodeId,
};

pub const MemoValue = struct {
    was_used: bool,
    node_ids: u.DeepHashMap(u128, NodeId),
};

const Error = error{
    OutOfMemory,
};

pub fn init(allocator: u.Allocator, bnf: *const sql.BnfParser, source: []const u8) Self {
    return Self{
        .allocator = allocator,
        .arena = u.ArenaAllocator.init(allocator),
        .bnf = bnf,
        .source = source,
        .may_contain_whitespace = true,
        .nodes = u.ArrayList(Node).init(allocator),
        .memo = u.DeepHashMap(MemoKey, MemoValue).init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.memo.deinit();
    self.nodes.deinit();
    self.arena.deinit();
    self.* = undefined;
}

pub fn parse(self: *Self, bnf_node_id: sql.BnfParser.NodeId) !NodeId {
    const node_ids = try self.parseNode(0, bnf_node_id);

    //for (node_ids) |node_id| {
    //    u.dump(DumpNode{ .self = self.*, .node_id = node_id });
    //}

    var return_node_id: ?NodeId = null;
    for (node_ids) |node_id| {
        const node = self.nodes.items[node_id];
        if (node.range[1] == self.source.len) {
            if (return_node_id != null)
                return error.AmbiguousParse
            else
                return_node_id = node_id;
        }
    }

    return if (return_node_id) |node_id|
        node_id
    else
        error.NoParse;
}

fn parseNode(self: *Self, start_pos: usize, bnf_node_id: sql.BnfParser.NodeId) Error![]const NodeId {
    var result = u.ArrayList(NodeId).init(self.arena.allocator());
    switch (self.bnf.nodes.items[bnf_node_id]) {
        .def_name => |def_name| {
            const old_may_contain_whitespace = self.may_contain_whitespace;
            self.may_contain_whitespace = self.may_contain_whitespace and def_name.may_contain_whitespace;
            defer self.may_contain_whitespace = old_may_contain_whitespace;
            const node_ids =
                if (bnf_node_id == self.bnf.regular_identifier.?)
                try self.parseRegularIdentifier(start_pos, def_name.body)
            else
                try self.parseMemo(start_pos, def_name.body);
            for (node_ids) |node_id|
                try result.append(try self.pushNode(bnf_node_id, self.getRange(node_id), node_id, null));
        },
        .ref_name => |ref_name| {
            for (try self.parseNode(start_pos, ref_name.id.?)) |node_id|
                try result.append(try self.pushNode(bnf_node_id, self.getRange(node_id), node_id, null));
        },
        .literal => |literal| {
            if (start_pos + literal.len <= self.source.len) {
                const candidate = try std.ascii.allocLowerString(self.allocator, self.source[start_pos .. start_pos + literal.len]);
                defer self.allocator.free(candidate);
                if (std.mem.eql(u8, candidate, literal)) {
                    try result.append(try self.pushNode(bnf_node_id, .{ start_pos, start_pos + literal.len }, null, null));
                }
            }
        },
        .either => |either| {
            for (try self.parseNode(start_pos, either[0])) |node_id|
                try result.append(try self.pushNode(bnf_node_id, self.getRange(node_id), node_id, null));
            for (try self.parseNode(start_pos, either[1])) |node_id|
                try result.append(try self.pushNode(bnf_node_id, self.getRange(node_id), node_id, null));
        },
        .both => |both| {
            for (try self.parseNode(start_pos, both[0])) |left_child| {
                const mid_pos = if (self.may_contain_whitespace)
                    self.discardSpaceAndNewline(self.getEndPos(left_child))
                else
                    self.getEndPos(left_child);
                for (try self.parseNode(mid_pos, both[1])) |right_child| {
                    try result.append(try self.pushNode(
                        bnf_node_id,
                        .{ start_pos, self.getEndPos(right_child) },
                        left_child,
                        right_child,
                    ));
                }
            }
        },
        .optional => |optional| {
            for (try self.parseNode(start_pos, optional)) |node_id|
                try result.append(try self.pushNode(bnf_node_id, self.getRange(node_id), node_id, null));
            try result.append(try self.pushNode(bnf_node_id, .{ start_pos, start_pos }, null, null));
        },
        .identifier_start => {
            // > An <identifier start> is any character in the Unicode General Category classes "Lu", "Ll", "Lt", "Lm", "Lo", or "Nl".
            if (start_pos < self.source.len)
                switch (self.source[start_pos]) {
                    'a'...'z', 'A'...'Z' => {
                        try result.append(try self.pushNode(bnf_node_id, .{ start_pos, start_pos + 1 }, null, null));
                    },
                    else => {},
                };
        },
        .identifier_extend => {
            // > An <identifier extend> is U+00B7, "Middle Dot", or any character in the Unicode General Category classes "Mn", "Mc", "Nd", "Pc", or "Cf".
            if (start_pos < self.source.len)
                switch (self.source[start_pos]) {
                    '0'...'9', '-', '_' => {
                        try result.append(try self.pushNode(bnf_node_id, .{ start_pos, start_pos + 1 }, null, null));
                    },
                    else => {},
                };
        },
        .space => {
            if (start_pos < self.source.len)
                switch (self.source[start_pos]) {
                    ' ' => {
                        try result.append(try self.pushNode(bnf_node_id, .{ start_pos, start_pos + 1 }, null, null));
                    },
                    else => {},
                };
        },
        .fail => {},

        else => |node| u.panic("TODO {}", .{node}),
    }
    return result.toOwnedSlice();
}

fn parseMemo(self: *Self, start_pos: usize, bnf_node_id: sql.BnfParser.NodeId) Error![]const NodeId {
    var result = u.ArrayList(NodeId).init(self.arena.allocator());
    const memo_key = MemoKey{ .start_pos = start_pos, .bnf_node_id = bnf_node_id };
    if (self.memo.getPtr(memo_key)) |memo_value| {
        memo_value.was_used = true;
        {
            var iter = memo_value.node_ids.valueIterator();
            while (iter.next()) |node_id| try result.append(node_id.*);
        }
    } else {
        var old_node_ids = u.DeepHashMap(u128, NodeId).init(self.allocator);
        defer old_node_ids.deinit();
        try self.memo.put(memo_key, MemoValue{
            .was_used = false,
            .node_ids = u.DeepHashMap(u128, NodeId).init(self.arena.allocator()),
        });
        while (true) {
            const node_ids = try self.parseNode(start_pos, bnf_node_id);
            const memo_value = self.memo.getPtr(memo_key).?;

            var new_node_ids = u.DeepHashMap(u128, NodeId).init(self.arena.allocator());
            for (node_ids) |node_id| {
                const hash = self.getHash(node_id);
                const entry = try old_node_ids.getOrPut(hash);
                if (!entry.found_existing) {
                    entry.value_ptr.* = node_id;
                    try new_node_ids.put(hash, node_id);
                }
            }
            if (new_node_ids.count() == 0 or
                !memo_value.was_used)
            {
                // No further improvement to be had
                var iter = old_node_ids.valueIterator();
                while (iter.next()) |node_id| try result.append(node_id.*);
                break;
            } else {
                try self.memo.put(memo_key, MemoValue{
                    .was_used = false,
                    .node_ids = new_node_ids,
                });
            }
        }
    }
    //if (result.items.len > 0) {
    //    u.dump(.{ .start_pos = start_pos, .bnf_node_id = bnf_node_id, .bnf_node = self.bnf.nodes.items[bnf_node_id], .result = result.items });
    //} else {
    //    u.dump(.{ .start_pos = start_pos, .bnf_node_id = bnf_node_id, .bnf_node = self.bnf.nodes.items[bnf_node_id] });
    //}
    return result.toOwnedSlice();
}

fn parseRegularIdentifier(self: *Self, start_pos: usize, bnf_node_id: sql.BnfParser.NodeId) Error![]const NodeId {
    var result = u.ArrayList(NodeId).init(self.arena.allocator());
    const node_ids = try self.parseMemo(start_pos, bnf_node_id);
    for (node_ids) |node_id| {
        const node = self.nodes.items[node_id];
        const token = self.source[node.range[0]..node.range[1]];
        if (self.bnf.reserved_words.get(token) == null)
            try result.append(node_id);
    }
    return result.toOwnedSlice();
}

pub fn discardSpaceAndNewline(self: *Self, start_pos: usize) usize {
    var pos = start_pos;
    while (pos < self.source.len) {
        switch (self.source[pos]) {
            ' ', '\n' => pos += 1,
            else => break,
        }
    }
    return pos;
}

fn pushNode(self: *Self, bnf_node_id: sql.BnfParser.NodeId, range: [2]usize, left_child_id: ?NodeId, right_child_id: ?NodeId) Error!NodeId {
    var hasher = std.crypto.hash.Blake3.init(.{});
    hasher.update(&@bitCast([8]u8, bnf_node_id));
    hasher.update(&@bitCast([16]u8, range));
    if (left_child_id != null)
        hasher.update(&@bitCast([16]u8, self.nodes.items[left_child_id.?].hash));
    if (right_child_id != null)
        hasher.update(&@bitCast([16]u8, self.nodes.items[right_child_id.?].hash));
    var hash: [16]u8 = undefined;
    hasher.final(&hash);

    const id = self.nodes.items.len;
    try self.nodes.append(.{
        .hash = @bitCast(u128, hash),
        .bnf_node_id = bnf_node_id,
        .range = range,
        .children = .{ left_child_id, right_child_id },
    });
    return id;
}

fn getHash(self: *Self, node_id: NodeId) u128 {
    return self.nodes.items[node_id].hash;
}

fn getRange(self: *Self, node_id: NodeId) [2]usize {
    return self.nodes.items[node_id].range;
}

fn getEndPos(self: *Self, node_id: NodeId) usize {
    return self.nodes.items[node_id].range[1];
}

pub fn dumpInto(writer: anytype, indent: u32, self: Self) anyerror!void {
    if (self.nodes.items.len == 0)
        try writer.writeAll("<empty>\n")
    else
        try u.dumpInto(writer, indent, DumpNode{ .self = self, .node_id = self.nodes.items.len - 1 });
}

pub const DumpNode = struct {
    self: Self,
    node_id: NodeId,

    pub fn dumpInto(writer: anytype, indent: u32, self: DumpNode) anyerror!void {
        const node = self.self.nodes.items[self.node_id];
        const bnf_node = self.self.bnf.nodes.items[node.bnf_node_id];
        if (bnf_node == .def_name) {
            try writer.writeByteNTimes(' ', indent);
            try std.fmt.format(writer, "{s}: {}\n", .{ bnf_node.def_name.name, std.zig.fmtEscapes(self.self.source[node.range[0]..node.range[1]]) });
        }
        for (node.children) |child_id_maybe|
            if (child_id_maybe) |child_id|
                try u.dumpInto(writer, indent + 2, DumpNode{ .self = self.self, .node_id = child_id });
    }
};
