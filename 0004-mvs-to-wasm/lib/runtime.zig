const std = @import("std");
const panic = std.debug.panic;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const Kind = enum(u32) {
    number = 0,
    string = 1,
    map = 2,
    @"fn" = 3,
};

pub const Value = union(Kind) {
    number: f64,
    string: []u8,
    map: Map,
    @"fn": Fn,

    // TODO
    pub const wasmSizeOf = 32;

    pub fn kind(self: Value) Kind {
        return std.meta.activeTag(self);
    }

    pub fn hash(self: Value) u64 {
        var hasher = std.hash.Wyhash.init(42);
        self.update(&hasher);
        return hasher.final();
    }

    pub fn update(self: Value, hasher: anytype) void {
        switch (self) {
            // TODO NaN
            .number => |number| hasher.update(std.mem.asBytes(&number)),
            .string => |string| hasher.update(string),
            .map => |map| {
                // TODO Does seed/ordering matter?
                var iter = map.iterator();
                while (iter.next()) |entry| {
                    entry.key_ptr.update(hasher);
                    entry.value_ptr.update(hasher);
                }
            },
            .@"fn" => |@"fn"| {
                hasher.update(std.mem.asBytes(&@"fn".ix));
                for (@"fn".captures) |capture| capture.update(hasher);
            },
        }
    }

    pub fn equal(self: Value, other: Value) bool {
        if (self.kind() != other.kind()) return false;
        switch (self) {
            // TODO NaN
            .number => return self.number == other.number,
            .string => return std.mem.eql(u8, self.string, other.string),
            .map => {
                const self_map = self.map;
                const other_map = other.map;
                if (self_map.count() != other_map.count()) return false;
                var iter = self_map.iterator();
                while (iter.next()) |entry| {
                    const self_key = entry.key_ptr.*;
                    const other_key = other_map.get(self_key) orelse return false;
                    if (!self_key.equal(other_key)) return false;
                }
                return true;
            },
            .@"fn" => {
                const self_fn = self.@"fn";
                const other_fn = other.@"fn";
                if (self_fn.ix == other_fn.ix) return false;
                for (self_fn.captures, other_fn.captures) |self_capture, other_capture| {
                    if (!self_capture.equal(other_capture.*)) return false;
                }
                return true;
            },
        }
    }

    pub fn format(self: Value, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .number => |number| try writer.print("{d}", .{number}),
            .string => |string| {
                try writer.writeByte('\'');
                for (string) |char| {
                    switch (char) {
                        '\n' => try writer.writeAll("\\n"),
                        '\'' => try writer.writeAll("\\'"),
                        '\\' => try writer.writeAll("\\\\"),
                        else => try writer.writeByte(char),
                    }
                }
                try writer.writeByte('\'');
            },
            .map => |map| {
                try writer.writeAll("[");

                var first = true;

                var ix: f64 = 0;
                while (true) : (ix += 1) {
                    if (map.get(.{ .number = ix })) |value| {
                        if (!first) try writer.writeAll(", ");
                        try writer.print("{}", .{value});
                        first = false;
                    } else {
                        break;
                    }
                }

                var iter = map.iterator();
                while (iter.next()) |entry| {
                    const key = entry.key_ptr.*;
                    if (key == .number and
                        key.number == @trunc(key.number) and
                        @trunc(key.number) >= 0 and
                        @trunc(key.number) < ix)
                        // Already printed this one.
                        continue;
                    if (!first) try writer.writeAll(", ");
                    try writer.print("{} = {}", .{ entry.key_ptr.*, entry.value_ptr.* });
                    first = false;
                }

                try writer.writeAll("]");
            },
            .@"fn" => |@"fn"| {
                try writer.print("fn<{}", .{@"fn".ix});
                for (@"fn".captures) |capture| {
                    try writer.print(", {}", .{capture});
                }
                try writer.writeAll(">");
            },
        }
    }

    pub fn copy(self: Value, allocator: Allocator) Value {
        switch (self) {
            .number => |number| return .{ .number = number },
            .string => |string| return .{ .string = allocator.dupe(u8, string) catch panic("OOM", .{}) },
            .map => |map| {
                var map_copy = map.cloneWithAllocator(allocator) catch panic("OOM", .{});
                var iter = map_copy.iterator();
                while (iter.next()) |entry| {
                    entry.key_ptr.copyInPlace(allocator);
                    entry.value_ptr.copyInPlace(allocator);
                }
                return .{ .map = map_copy };
            },
            .@"fn" => |@"fn"| {
                const muts = allocator.dupe(bool, @"fn".muts) catch panic("OOM", .{});
                const captures = allocator.dupe(*Value, @"fn".captures) catch panic("OOM", .{});
                for (captures) |capture| capture.copyInPlace(allocator);
                return .{ .@"fn" = .{
                    .ix = @"fn".ix,
                    .muts = muts,
                    .captures = captures,
                } };
            },
        }
    }

    pub fn copyInPlace(self: *Value, allocator: Allocator) void {
        const value = self.copy(allocator);
        self.* = value;
    }

    pub fn fromBool(b: bool) Value {
        return if (b) .{ .number = 1 } else .{ .number = 0 };
    }
};

pub const Map = std.HashMap(
    Value,
    Value,
    struct {
        pub fn hash(_: @This(), key: Value) u64 {
            return key.hash();
        }
        pub fn eql(_: @This(), key1: Value, key2: Value) bool {
            return key1.equal(key2);
        }
    },
    std.hash_map.default_max_load_percentage,
);

pub const Fn = struct {
    ix: u32,
    muts: []bool,
    captures: []*Value,
};
