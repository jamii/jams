const std = @import("std");

pub const Allocator = std.mem.Allocator;
pub const ArenaAllocator = std.heap.ArenaAllocator;
pub const ArrayList = std.ArrayList;
pub const HashMap = std.HashMap;

// TODO should probably preallocate memory for panic message
pub fn panic(comptime fmt: []const u8, args: anytype) noreturn {
    var buf = ArrayList(u8).init(std.heap.page_allocator);
    var writer = buf.writer();
    const message: []const u8 = message: {
        std.fmt.format(writer, fmt, args) catch |err| {
            switch (err) {
                error.OutOfMemory => break :message "OOM inside panic",
            }
        };
        break :message buf.toOwnedSlice();
    };
    @panic(message);
}

pub fn assert(b: bool) void {
    if (!b)
        panic("Assert failed", .{});
}

pub fn oom() noreturn {
    @panic("Out of memory");
}

pub fn dump(thing: anytype) void {
    std.debug.getStderrMutex().lock();
    defer std.debug.getStderrMutex().unlock();
    const my_stderr = std.io.getStdErr();
    const writer = my_stderr.writer();
    dumpInto(writer, 0, thing) catch return;
    writer.writeAll("\n") catch return;
}

pub fn dumpInto(writer: anytype, indent: u32, thing: anytype) anyerror!void {
    const T = @TypeOf(thing);
    if (T == Allocator) {
        try writer.writeAll("Allocator{}");
    } else if (T == ArenaAllocator) {
        try writer.writeAll("ArenaAllocator{}");
    } else if (comptime std.mem.startsWith(u8, @typeName(T), "std.array_list.ArrayList")) {
        try dumpInto(writer, indent, thing.items);
    } else if (comptime std.mem.startsWith(u8, @typeName(T), "std.hash_map.HashMap")) {
        var iter = thing.iterator();
        const is_set = @TypeOf(iter.next().?.value_ptr.*) == void;
        try writer.writeAll(if (is_set) "HashSet(\n" else "HashMap(\n");
        while (iter.next()) |entry| {
            try writer.writeByteNTimes(' ', indent + 4);
            try dumpInto(writer, indent + 4, entry.key_ptr.*);
            if (!is_set) {
                try writer.writeAll(" => ");
                try dumpInto(writer, indent + 4, entry.value_ptr.*);
            }
            try writer.writeAll(",\n");
        }
        try writer.writeByteNTimes(' ', indent);
        try writer.writeAll(")");
    } else switch (@typeInfo(T)) {
        .Pointer => |pti| {
            switch (pti.size) {
                .One => {
                    try writer.writeAll("&");
                    try dumpInto(writer, indent, thing.*);
                },
                .Many => {
                    // bail
                    try std.fmt.format(writer, "{any}", .{thing});
                },
                .Slice => {
                    if (pti.child == u8) {
                        try std.fmt.format(writer, "\"{s}\"", .{thing});
                    } else {
                        try std.fmt.format(writer, "[]{}[\n", .{pti.child});
                        for (thing) |elem| {
                            try writer.writeByteNTimes(' ', indent + 4);
                            try dumpInto(writer, indent + 4, elem);
                            try writer.writeAll(",\n");
                        }
                        try writer.writeByteNTimes(' ', indent);
                        try writer.writeAll("]");
                    }
                },
                .C => {
                    // bail
                    try std.fmt.format(writer, "{}", .{thing});
                },
            }
        },
        .Array => |ati| {
            if (ati.child == u8) {
                try std.fmt.format(writer, "\"{s}\"", .{thing});
            } else {
                try std.fmt.format(writer, "[{}]{s}[\n", .{ ati.len, ati.child });
                for (thing) |elem| {
                    try writer.writeByteNTimes(' ', indent + 4);
                    try dumpInto(writer, indent + 4, elem);
                    try writer.writeAll(",\n");
                }
                try writer.writeByteNTimes(' ', indent);
                try writer.writeAll("]");
            }
        },
        .Struct => |sti| {
            try writer.writeAll(@typeName(@TypeOf(thing)));
            try writer.writeAll("{\n");
            inline for (sti.fields) |field| {
                try writer.writeByteNTimes(' ', indent + 4);
                try std.fmt.format(writer, ".{s} = ", .{field.name});
                try dumpInto(writer, indent + 4, @field(thing, field.name));
                try writer.writeAll(",\n");
            }
            try writer.writeByteNTimes(' ', indent);
            try writer.writeAll("}");
        },
        .Union => |uti| {
            if (uti.tag_type) |tag_type| {
                try writer.writeAll(@typeName(@TypeOf(thing)));
                try writer.writeAll("{\n");
                inline for (@typeInfo(tag_type).Enum.fields) |fti| {
                    if (@enumToInt(std.meta.activeTag(thing)) == fti.value) {
                        try writer.writeByteNTimes(' ', indent + 4);
                        try std.fmt.format(writer, ".{s} = ", .{fti.name});
                        try dumpInto(writer, indent + 4, @field(thing, fti.name));
                        try writer.writeAll("\n");
                        try writer.writeByteNTimes(' ', indent);
                        try writer.writeAll("}");
                    }
                }
            } else {
                // bail
                try std.fmt.format(writer, "{}", .{thing});
            }
        },
        .Optional => {
            if (thing == null) {
                try writer.writeAll("null");
            } else {
                try dumpInto(writer, indent, thing.?);
            }
        },
        .Opaque => {
            try writer.writeAll("opaque");
        },
        .Float => {
            try std.fmt.format(writer, "{d}", .{thing});
        },
        else => {
            // bail
            try std.fmt.format(writer, "{any}", .{thing});
        },
    }
}

pub fn deepClone(thing: anytype, allocator: Allocator) error{OutOfMemory}!@TypeOf(thing) {
    const T = @TypeOf(thing);
    const ti = @typeInfo(T);

    if (T == std.mem.Allocator)
        return allocator;

    if (comptime std.mem.startsWith(u8, @typeName(T), "std.array_list.ArrayList")) {
        var cloned = try ArrayList(@TypeOf(thing.items[0])).initCapacity(allocator, thing.items.len);
        cloned.appendSliceAssumeCapacity(thing.items);
        for (cloned.items) |*item| item.* = try deepClone(item.*, allocator);
        return cloned;
    }

    if (comptime std.mem.startsWith(u8, @typeName(T), "std.hash_map.HashMap")) {
        var cloned = try thing.cloneWithAllocator(allocator);
        var iter = cloned.iterator();
        while (iter.next()) |entry| {
            entry.key_ptr.* = try deepClone(entry.key_ptr.*, allocator);
            entry.value_ptr.* = try deepClone(entry.value_ptr.*, allocator);
        }
        return cloned;
    }

    switch (ti) {
        .Bool, .Int, .Float, .Enum, .Void, .Fn => return thing,
        .Pointer => |pti| {
            switch (pti.size) {
                .One => {
                    const cloned = try allocator.create(pti.child);
                    cloned.* = try deepClone(thing.*, allocator);
                    return cloned;
                },
                .Slice => {
                    const cloned = try allocator.alloc(pti.child, thing.len);
                    for (thing) |item, i| cloned[i] = try deepClone(item, allocator);
                    return cloned;
                },
                .Many, .C => compileError("Cannot deepClone {}", .{T}),
            }
        },
        .Array => {
            var cloned = thing;
            for (cloned) |*item| item.* = try deepClone(item.*, allocator);
            return cloned;
        },
        .Optional => {
            return if (thing == null) null else try deepClone(thing.?, allocator);
        },
        .Struct => |sti| {
            var cloned: T = undefined;
            inline for (sti.fields) |fti| {
                @field(cloned, fti.name) = try deepClone(@field(thing, fti.name), allocator);
            }
            return cloned;
        },
        .Union => |uti| {
            if (uti.tag_type) |tag_type| {
                const tag = @enumToInt(std.meta.activeTag(thing));
                inline for (@typeInfo(tag_type).Enum.fields) |fti| {
                    if (tag == fti.value) {
                        return @unionInit(T, fti.name, try deepClone(@field(thing, fti.name), allocator));
                    }
                }
                unreachable;
            } else {
                compileError("Cannot deepClone {}", .{T});
            }
        },
        else => compileError("Cannot deepClone {}", .{T}),
    }
}

pub fn format(allocator: Allocator, comptime fmt: []const u8, args: anytype) []const u8 {
    var buf = ArrayList(u8).init(allocator);
    var writer = buf.writer();
    std.fmt.format(writer, fmt, args) catch oom();
    return buf.items;
}

pub fn formatZ(allocator: Allocator, comptime fmt: []const u8, args: anytype) [:0]const u8 {
    var buf = ArrayList(u8).init(allocator);
    var writer = buf.writer();
    std.fmt.format(writer, fmt, args) catch oom();
    buf.append(0) catch oom();
    return buf.items[0 .. buf.items.len - 1 :0];
}

pub fn deepEqual(a: anytype, b: @TypeOf(a)) bool {
    return deepCompare(a, b) == .eq;
}

pub fn deepCompare(a: anytype, b: @TypeOf(a)) std.math.Order {
    const T = @TypeOf(a);
    const ti = @typeInfo(T);
    switch (ti) {
        .Struct, .Enum, .Union => {
            if (@hasDecl(T, "deepCompare")) {
                return T.deepCompare(a, b);
            }
        },
        else => {},
    }
    switch (ti) {
        .Bool => {
            if (a == b) return .eq;
            if (a) return .gt;
            return .lt;
        },
        .Int, .Float => {
            if (a < b) {
                return .lt;
            }
            if (a > b) {
                return .gt;
            }
            return .eq;
        },
        .Enum => {
            return deepCompare(@enumToInt(a), @enumToInt(b));
        },
        .Pointer => |pti| {
            switch (pti.size) {
                .One => {
                    return if (a == b)
                        .eq
                    else
                        deepCompare(a.*, b.*);
                },
                .Slice => {
                    const len = std.math.min(a.len, b.len);
                    var i: usize = 0;
                    while (i < len) : (i += 1) {
                        const ordering = deepCompare(a[i], b[i]);
                        if (ordering != .eq) {
                            return ordering;
                        }
                    }
                    return std.math.order(a.len, b.len);
                },
                .Many, .C => @compileError("cannot deepCompare " ++ @typeName(T)),
            }
        },
        .Optional => {
            if (a) |a_val| {
                if (b) |b_val| {
                    return deepCompare(a_val, b_val);
                } else {
                    return .gt;
                }
            } else {
                if (b) |_| {
                    return .lt;
                } else {
                    return .eq;
                }
            }
        },
        .Array => {
            for (a) |a_elem, a_ix| {
                const ordering = deepCompare(a_elem, b[a_ix]);
                if (ordering != .eq) {
                    return ordering;
                }
            }
            return .eq;
        },
        .Struct => |sti| {
            inline for (sti.fields) |fti| {
                const ordering = deepCompare(@field(a, fti.name), @field(b, fti.name));
                if (ordering != .eq) {
                    return ordering;
                }
            }
            return .eq;
        },
        .Union => |uti| {
            if (uti.tag_type) |tag_type| {
                const enum_info = @typeInfo(tag_type).Enum;
                const a_tag = @enumToInt(@as(tag_type, a));
                const b_tag = @enumToInt(@as(tag_type, b));
                if (a_tag < b_tag) {
                    return .lt;
                }
                if (a_tag > b_tag) {
                    return .gt;
                }
                inline for (enum_info.fields) |fti| {
                    if (a_tag == fti.value) {
                        return deepCompare(
                            @field(a, fti.name),
                            @field(b, fti.name),
                        );
                    }
                }
                unreachable;
            } else {
                @compileError("cannot deepCompare " ++ @typeName(T));
            }
        },
        .Void => return .eq,
        .ErrorUnion => {
            if (a) |a_ok| {
                if (b) |b_ok| {
                    return deepCompare(a_ok, b_ok);
                } else |_| {
                    return .lt;
                }
            } else |a_err| {
                if (b) |_| {
                    return .gt;
                } else |b_err| {
                    return deepCompare(a_err, b_err);
                }
            }
        },
        .ErrorSet => return deepCompare(@errorToInt(a), @errorToInt(b)),
        else => @compileError("cannot deepCompare " ++ @typeName(T)),
    }
}

pub fn deepHash(key: anytype) u64 {
    var hasher = std.hash.Wyhash.init(0);
    deepHashInto(&hasher, key);
    return hasher.final();
}

pub fn deepHashInto(hasher: anytype, key: anytype) void {
    const T = @TypeOf(key);
    const ti = @typeInfo(T);
    switch (ti) {
        .Struct, .Enum, .Union => {
            if (@hasDecl(T, "deepHashInto")) {
                return T.deepHashInto(hasher, key);
            }
        },
        else => {},
    }
    switch (ti) {
        .Int => @call(.{ .modifier = .always_inline }, hasher.update, .{std.mem.asBytes(&key)}),
        .Float => |info| deepHashInto(hasher, @bitCast(std.meta.Int(.unsigned, info.bits), key)),
        .Bool => deepHashInto(hasher, @boolToInt(key)),
        .Enum => deepHashInto(hasher, @enumToInt(key)),
        .Pointer => |pti| {
            switch (pti.size) {
                .One => deepHashInto(hasher, key.*),
                .Slice => {
                    for (key) |element| {
                        deepHashInto(hasher, element);
                    }
                },
                .Many, .C => @compileError("cannot deepHash " ++ @typeName(T)),
            }
        },
        .Optional => if (key) |k| deepHashInto(hasher, k),
        .Array => {
            for (key) |element| {
                deepHashInto(hasher, element);
            }
        },
        .Struct => |info| {
            inline for (info.fields) |field| {
                deepHashInto(hasher, @field(key, field.name));
            }
        },
        .Union => |info| {
            if (info.tag_type) |tag_type| {
                const enum_info = @typeInfo(tag_type).Enum;
                const tag = std.meta.activeTag(key);
                deepHashInto(hasher, tag);
                inline for (enum_info.fields) |enum_field| {
                    if (enum_field.value == @enumToInt(tag)) {
                        deepHashInto(hasher, @field(key, enum_field.name));
                        return;
                    }
                }
                unreachable;
            } else @compileError("cannot deepHash " ++ @typeName(T));
        },
        .Void => {},
        else => @compileError("cannot deepHash " ++ @typeName(T)),
    }
}

pub fn DeepHashContext(comptime K: type) type {
    return struct {
        const Self = @This();
        pub fn hash(_: Self, pseudo_key: K) u64 {
            return deepHash(pseudo_key);
        }
        pub fn eql(_: Self, pseudo_key: K, key: K) bool {
            return deepEqual(pseudo_key, key);
        }
    };
}

pub fn DeepHashMap(comptime K: type, comptime V: type) type {
    return std.HashMap(K, V, DeepHashContext(K), std.hash_map.default_max_load_percentage);
}

pub fn DeepHashSet(comptime K: type) type {
    return DeepHashMap(K, void);
}

pub fn deepSort(slice: anytype) void {
    const T = @typeInfo(@TypeOf(slice)).Pointer.child;
    std.sort.sort(T, slice, {}, struct {
        fn lessThan(_: void, a: T, b: T) bool {
            return deepCompare(a, b) == .lt;
        }
    }.lessThan);
}

pub fn box(allocator: Allocator, value: anytype) error{OutOfMemory}!*@TypeOf(value) {
    var boxed = try allocator.create(@TypeOf(value));
    boxed.* = value;
    return boxed;
}

pub const BinarySearchResult = union(enum) {
    Found: usize,
    NotFound: usize,

    pub fn position(self: BinarySearchResult) usize {
        return switch (self) {
            .Found => |found| found,
            .NotFound => |not_found| not_found,
        };
    }
};

pub fn binarySearch(
    comptime T: type,
    key: anytype,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (context: @TypeOf(context), lhs: @TypeOf(key), rhs: T) std.math.Order,
) BinarySearchResult {
    var left: usize = 0;
    var right: usize = items.len;

    while (left < right) {
        // Avoid overflowing in the midpoint calculation
        const mid = left + (right - left) / 2;
        // Compare the key with the midpoint element
        switch (compareFn(context, key, items[mid])) {
            .eq => return .{ .Found = mid },
            .gt => left = mid + 1,
            .lt => right = mid,
        }
    }

    return .{ .NotFound = left };
}

pub fn compileError(comptime message: []const u8, comptime args: anytype) void {
    @compileError(comptime std.fmt.comptimePrint(message, args));
}
