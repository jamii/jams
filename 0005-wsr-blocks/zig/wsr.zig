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
    original_kind: Kind,
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

const VectorCompressed = union(Compression) {
    dict: VectorDict,
    size: VectorSize,
    bias: VectorBias,
};

const Vector = union(enum) {
    uncompressed: VectorUncompressed,
    compressed: VectorCompressed,
};

fn tagByType(comptime T: type, payload: anytype) T {
    comptime var field_name: ?[]const u8 = null;
    inline for (std.meta.fields(T)) |field| {
        if (field.type == @TypeOf(payload)) {
            if (field_name != null)
                @compileError("Can't make a " ++ @typeName(T) ++ " from " ++ @typeName(@TypeOf(payload)));
            field_name = field.name;
        }
    }
    if (field_name == null)
        @compileError("Can't make a " ++ @typeName(T) ++ " from " ++ @typeName(@TypeOf(payload)));
    return @unionInit(T, field_name.?, payload);
}

fn boxedVectorFromValues(allocator: Allocator, values: anytype) *Vector {
    const vector = allocator.create(Vector) catch oom();
    vector.* = .{ .uncompressed = tagByType(VectorUncompressed, values) };
    return vector;
}

fn dupeValue(allocator: Allocator, value: anytype) @TypeOf(value) {
    if (@typeInfo(@TypeOf(value)) == .Int) return value;
    if (@TypeOf(value) == []u8) return allocator.dupe(u8, value) catch oom();
    @compileError("Can't dupe " ++ @typeName(@TypeOf(value)));
}

fn equalValue(a: anytype, b: @TypeOf(a)) bool {
    if (@typeInfo(@TypeOf(a)) == .Int) return a == b;
    if (@TypeOf(a) == []u8) return std.mem.eql(u8, a, b);
    @compileError("Can't equal " ++ @typeName(@TypeOf(a)));
}

fn Dict(comptime kind: Kind, comptime V: type) type {
    const Elem = std.meta.fieldInfo(Value, kind).type;
    return switch (kind) {
        .uint8, .uint16, .uint32, .uint64 => std.AutoHashMap(Elem, V),
        // TODO Make a hashmap that takes []u8 instead of []const u8 to avoid @constCast below.
        .string => std.StringHashMap(V),
    };
}

fn compressed(allocator: Allocator, vector: VectorUncompressed, compression: Compression) ?VectorCompressed {
    switch (vector) {
        inline else => |values, kind| {
            const Elem = std.meta.Elem(@TypeOf(values));
            switch (compression) {
                .dict => {
                    var codes = std.ArrayList(u64).initCapacity(allocator, values.len) catch oom();
                    var unique_values = std.ArrayList(Elem).init(allocator);

                    var dict = Dict(kind, u64).init(allocator);
                    defer dict.deinit();

                    for (values) |value| {
                        const entry = dict.getOrPut(value) catch oom();
                        if (!entry.found_existing) {
                            entry.value_ptr.* = unique_values.items.len;
                            unique_values.append(dupeValue(allocator, value)) catch oom();
                        }
                        codes.append(entry.value_ptr.*) catch oom();
                    }

                    return .{ .dict = .{
                        .codes = boxedVectorFromValues(allocator, codes.toOwnedSlice() catch oom()),
                        .unique_values = boxedVectorFromValues(allocator, unique_values.toOwnedSlice() catch oom()),
                    } };
                },
                .size => {
                    if (kind == .string) return null;
                    if (values.len == 0) return null;

                    const max = std.mem.max(Elem, values);
                    inline for (.{ u8, u16, u32 }) |ElemCompressed| {
                        if (@typeInfo(ElemCompressed).Int.bits < @typeInfo(Elem).Int.bits) {
                            if (max < std.math.maxInt(ElemCompressed)) {
                                {
                                    const values_compressed = allocator.alloc(ElemCompressed, values.len) catch oom();
                                    for (values, values_compressed) |value, *value_compressed| {
                                        value_compressed.* = @intCast(value);
                                    }
                                    return .{ .size = .{
                                        .original_kind = kind,
                                        .values = boxedVectorFromValues(allocator, values_compressed),
                                    } };
                                }
                            }
                        }
                    } else return null;
                },
                .bias => {
                    var counts = Dict(kind, usize).init(allocator);
                    defer counts.deinit();

                    for (values) |value| {
                        const entry = counts.getOrPut(value) catch oom();
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

                    var presence = std.bit_set.DynamicBitSet.initEmpty(allocator, values.len) catch oom();
                    var remainder = std.ArrayList(Elem).initCapacity(allocator, values.len - common_count) catch oom();

                    for (values, 0..) |value, i| {
                        if (equalValue(value, common_value)) {
                            presence.set(i);
                        } else {
                            remainder.append(dupeValue(allocator, value)) catch oom();
                        }
                    }

                    return .{ .bias = .{
                        .count = values.len,
                        .value = tagByType(Value, dupeValue(allocator, common_value)),
                        .presence = presence,
                        .remainder = boxedVectorFromValues(allocator, remainder.toOwnedSlice() catch oom()),
                    } };
                },
            }
        },
    }
}

// Assumes arena allocation.
fn ensureDecompressed(allocator: Allocator, vector: Vector) VectorUncompressed {
    return switch (vector) {
        .compressed => |vector_compressed| decompressed(allocator, vector_compressed),
        .uncompressed => |vector_uncompressed| vector_uncompressed,
    };
}

// Assumes arena allocation.
fn decompressed(allocator: Allocator, vector: VectorCompressed) VectorUncompressed {
    switch (vector) {
        .dict => |dict| {
            const codes = ensureDecompressed(allocator, dict.codes.*).uint64;
            switch (ensureDecompressed(allocator, dict.unique_values.*)) {
                inline else => |unique_values| {
                    const Elem = std.meta.Elem(@TypeOf(unique_values));
                    const values = allocator.alloc(Elem, codes.len) catch oom();
                    for (values, codes) |*value, code| {
                        value.* = dupeValue(allocator, unique_values[code]);
                    }
                    return tagByType(VectorUncompressed, values);
                },
            }
        },
        .size => |size| {
            switch (size.original_kind) {
                inline .uint8, .uint16, .uint32, .uint64 => |kind| {
                    switch (ensureDecompressed(allocator, size.values.*)) {
                        inline .uint8, .uint16, .uint32, .uint64 => |values_compressed| {
                            const Elem = std.meta.fieldInfo(Value, kind).type;
                            const ElemCompressed = std.meta.Elem(@TypeOf(values_compressed));
                            if (@typeInfo(ElemCompressed).Int.bits >= @typeInfo(Elem).Int.bits) {
                                unreachable;
                            }
                            const values = allocator.alloc(Elem, values_compressed.len) catch oom();
                            for (values, values_compressed) |*value, value_compressed| {
                                value.* = @as(Elem, value_compressed);
                            }
                            return tagByType(VectorUncompressed, values);
                        },
                        .string => unreachable,
                    }
                },
                .string => unreachable,
            }
        },
        .bias => |bias| {
            switch (ensureDecompressed(allocator, bias.remainder.*)) {
                inline else => |remainder, kind| {
                    const Elem = std.meta.Elem(@TypeOf(remainder));
                    const bias_value = @field(bias.value, @tagName(kind));
                    var values = allocator.alloc(Elem, bias.count) catch oom();
                    var remainder_ix: usize = 0;
                    for (values, 0..) |*value, value_ix| {
                        if (bias.presence.isSet(value_ix)) {
                            value.* = dupeValue(allocator, bias_value);
                        } else {
                            value.* = dupeValue(allocator, remainder[remainder_ix]);
                            remainder_ix += 1;
                        }
                    }
                    return tagByType(VectorUncompressed, values);
                },
            }
        },
    }
}

fn oom() noreturn {
    std.debug.panic("OutOfMemory", .{});
}

// Only needed for tests.
fn vectorFromLiteral(allocator: Allocator, comptime Elem: type, literal: anytype) !VectorUncompressed {
    const values = allocator.alloc(Elem, literal.len) catch oom();
    for (values, literal) |*value, lit| {
        value.* = if (Elem == []u8)
            allocator.dupe(u8, lit) catch oom()
        else
            lit;
    }
    return tagByType(VectorUncompressed, values);
}

test {
    const testing = std.testing;

    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const vectors = [_]VectorUncompressed{
        try vectorFromLiteral(allocator, u64, &[_]u64{}),
        try vectorFromLiteral(allocator, u64, &[_]u64{ 42, 102, 42, 42, 87, 1 << 11 }),
        try vectorFromLiteral(allocator, []u8, &[_][]const u8{ "foo", "bar", "bar", "quux" }),
    };
    for (vectors) |vector| {
        errdefer std.debug.print("vector={}\n", .{vector});
        for (std.meta.tags(Compression)) |compression| {
            errdefer std.debug.print("compression={}\n", .{compression});
            if (compressed(allocator, vector, compression)) |vector_compressed| {
                const vector_decompressed = decompressed(allocator, vector_compressed);
                try testing.expectEqualDeep(vector, vector_decompressed);
            }
        }
    }
}
