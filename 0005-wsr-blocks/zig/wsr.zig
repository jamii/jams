const std = @import("std");
const Allocator = std.mem.Allocator;

const Kind = enum {
    uint8,
    uint16,
    uint32,
    uint64,
    string,
};

const Value = union(Kind) {
    uint8: u8,
    uint16: u16,
    uint32: u32,
    uint64: u64,
    string: []u8,
};

const VectorUncompressed = union(Kind) {
    uint8: []u8,
    uint16: []u16,
    uint32: []u32,
    uint64: []u64,
    string: [][]u8,
};

const VectorDict = struct {
    codes: *Vector,
    unique_values: *Vector,
};

const VectorSize = struct {
    original_size_bits: u8,
    values: *Vector,
};

const VectorBias = struct {
    count: usize,
    value: Value,
    presence: std.bit_set.DynamicBitSet,
    remainder: *Vector,
};

const Compression = enum {
    dict,
    size,
    bias,
};

const compressions = compressions: {
    const fields = std.meta.fields(Compression);
    var result: [fields.len]Compression = undefined;
    for (&result, fields) |*compression, field|
        compression.* = @enumFromInt(field.value);
    break :compressions result;
};

const VectorCompressed = union(Compression) {
    dict: VectorDict,
    size: VectorSize,
    bias: VectorBias,
};

const Vector = union(enum) {
    uncompressed: VectorUncompressed,
    compressed: VectorCompressed,
};

fn valueFrom(value: anytype) Value {
    inline for (std.meta.fields(Value)) |field| {
        if (field.type == @TypeOf(value)) {
            return @unionInit(Value, field.name, value);
        }
    }
    @compileError("Can't make a value from " ++ @typeName(@TypeOf(value)));
}

fn vectorFromValues(values: anytype) VectorUncompressed {
    inline for (std.meta.fields(VectorUncompressed)) |field| {
        if (field.type == @TypeOf(values)) {
            return @unionInit(VectorUncompressed, field.name, values);
        }
    }
    @compileError("Can't make a vector from " ++ @typeName(@TypeOf(values)));
}

fn boxedVectorFromValues(allocator: Allocator, values: anytype) !*Vector {
    const vector = try allocator.create(Vector);
    vector.* = .{ .uncompressed = vectorFromValues(values) };
    return vector;
}

fn dupeValue(allocator: Allocator, value: anytype) error{OutOfMemory}!@TypeOf(value) {
    if (@typeInfo(@TypeOf(value)) == .Int) return value;
    if (@TypeOf(value) == []u8) return allocator.dupe(u8, value);
    @compileError("Can't dupe " ++ @typeName(@TypeOf(value)));
}

fn equalValue(a: anytype, b: @TypeOf(a)) bool {
    if (@typeInfo(@TypeOf(a)) == .Int) return a == b;
    if (@TypeOf(a) == []u8) return std.mem.eql(u8, a, b);
    @compileError("Can't equal " ++ @typeName(@TypeOf(a)));
}

fn compressed(allocator: Allocator, vector: VectorUncompressed, compression: Compression) !?VectorCompressed {
    switch (compression) {
        .dict => return dictCompressed(allocator, vector),
        .size => return sizeCompressed(allocator, vector),
        .bias => return biasCompressed(allocator, vector),
    }
}

fn Dict(comptime kind: Kind, comptime V: type) type {
    const Elem = std.meta.Elem(std.meta.fieldInfo(VectorUncompressed, kind).type);
    return switch (kind) {
        .uint8, .uint16, .uint32, .uint64 => std.AutoHashMap(Elem, V),
        // TODO Make a hashmap that takes []u8 instead of []const u8 to avoid @constCast below.
        .string => std.StringHashMap(V),
    };
}

fn dictCompressed(allocator: Allocator, vector: VectorUncompressed) !?VectorCompressed {
    switch (vector) {
        inline else => |values, kind| {
            const Elem = std.meta.Elem(@TypeOf(values));

            var codes = try std.ArrayList(u64).initCapacity(allocator, values.len);
            defer codes.deinit();

            var unique_values = std.ArrayList(Elem).init(allocator);
            defer unique_values.deinit();

            var dict = Dict(kind, u64).init(allocator);
            defer dict.deinit();

            for (values) |value| {
                const entry = try dict.getOrPut(value);
                if (!entry.found_existing) {
                    entry.value_ptr.* = unique_values.items.len;
                    try unique_values.append(try dupeValue(allocator, value));
                }
                try codes.append(entry.value_ptr.*);
            }

            return .{ .dict = .{
                .codes = try boxedVectorFromValues(allocator, try codes.toOwnedSlice()),
                .unique_values = try boxedVectorFromValues(allocator, try unique_values.toOwnedSlice()),
            } };
        },
    }
}

fn sizeCompressed(allocator: Allocator, vector: VectorUncompressed) !?VectorCompressed {
    switch (vector) {
        inline .uint8, .uint16, .uint32, .uint64 => |values| {
            const Elem = std.meta.Elem(@TypeOf(values));

            const max = std.mem.max(Elem, values);
            inline for (.{ u8, u16, u32 }) |ElemCompressed| {
                if (max < std.math.maxInt(ElemCompressed) and Elem != ElemCompressed) {
                    const values_compressed = try allocator.alloc(ElemCompressed, values.len);
                    for (values, values_compressed) |value, *value_compressed| {
                        value_compressed.* = @intCast(value);
                    }
                    return .{ .size = .{
                        .original_size_bits = @intCast(@typeInfo(Elem).Int.bits),
                        .values = try boxedVectorFromValues(allocator, values_compressed),
                    } };
                }
            } else return null;
        },
        .string => return null,
    }
}

fn biasCompressed(allocator: Allocator, vector: VectorUncompressed) !?VectorCompressed {
    switch (vector) {
        inline else => |values, kind| {
            const Elem = std.meta.Elem(@TypeOf(values));

            var counts = Dict(kind, usize).init(allocator);
            defer counts.deinit();

            for (values) |value| {
                const entry = try counts.getOrPut(value);
                if (!entry.found_existing) entry.value_ptr.* = 0;
                entry.value_ptr.* += 1;
            }

            if (values.len == 0) return null;
            var common_value = values[0];
            var common_count: usize = 0;
            var iter = counts.iterator();
            while (iter.next()) |entry| {
                if (entry.value_ptr.* > common_count) {
                    common_value = if (Elem == []u8) @constCast(entry.key_ptr.*) else entry.key_ptr.*;
                    common_count = entry.value_ptr.*;
                }
            }

            var presence = try std.bit_set.DynamicBitSet.initEmpty(allocator, values.len);
            errdefer presence.deinit();

            var remainder = try std.ArrayList(Elem).initCapacity(allocator, values.len - common_count);
            defer remainder.deinit();

            for (values, 0..) |value, i| {
                if (equalValue(value, common_value)) {
                    presence.set(i);
                } else {
                    try remainder.append(try dupeValue(allocator, value));
                }
            }

            return .{ .bias = .{
                .count = values.len,
                .value = valueFrom(try dupeValue(allocator, common_value)),
                .presence = presence,
                .remainder = try boxedVectorFromValues(allocator, try remainder.toOwnedSlice()),
            } };
        },
    }
}

fn decompressed(allocator: Allocator, vector: VectorCompressed) !VectorUncompressed {
    _ = vector;
    _ = allocator;
    std.debug.panic("TODO", .{});
}

fn vectorFromLiteral(allocator: Allocator, comptime Elem: type, literal: anytype) !VectorUncompressed {
    const values = try allocator.alloc(Elem, literal.len);
    for (values, literal) |*value, lit| {
        value.* = if (Elem == []u8)
            try allocator.dupe(u8, lit)
        else
            lit;
    }
    return vectorFromValues(values);
}

test {
    const testing = std.testing;
    const allocator = testing.allocator;

    const vectors = [_]VectorUncompressed{
        try vectorFromLiteral(allocator, u64, &[_]u64{}),
        try vectorFromLiteral(allocator, u64, &[_]u64{ 42, 102, 42, 42, 87, 1 << 11 }),
        try vectorFromLiteral(allocator, []u8, &[_][]const u8{ "foo", "bar", "bar", "quux" }),
    };
    for (vectors) |vector| {
        for (compressions) |compression| {
            if (try compressed(allocator, vector, compression)) |vector_compressed| {
                const vector_decompressed = try decompressed(allocator, vector_compressed);
                try testing.expectEqualDeep(vector, vector_decompressed);
            }
        }
    }
}
