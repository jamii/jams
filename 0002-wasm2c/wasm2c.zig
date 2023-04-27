const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const panic = std.debug.panic;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

fn d(x: anytype) @TypeOf(x) {
    std.debug.print("{any}\n", .{x});
    return x;
}

var EXTRA_BRACES = false;

const WasmSectionId = enum(u8) {
    type = 1,
    import = 2,
    func = 3,
    table = 4,
    mem = 5,
    global = 6,
    @"export" = 7,
    start = 8,
    elem = 9,
    code = 10,
    data = 11,
    datacount = 12,
};

const WasmValType = enum(i8) {
    i32 = -0x01,
    i64 = -0x02,
    f32 = -0x03,
    f64 = -0x04,
    v128 = -0x05,
    funcref = -0x10,
    externref = -0x11,
    empty = -0x40,

    fn toC(wasm_val_type: WasmValType) []const u8 {
        return switch (wasm_val_type) {
            .i32 => "uint32_t",
            .i64 => "uint64_t",
            .f32 => "float",
            .f64 => "double",
            .v128 => panic("vector types are unsupported", .{}),
            .funcref => "void (*)(void)",
            .externref => "void *",
            .empty => unreachable,
        };
    }
};

const WasmRefType = enum(i8) {
    funcref = -0x10,
    externref = -0x11,
};

const WasmMut = enum(u8) {
    @"const" = 0x00,
    @"var" = 0x01,

    fn toC(wasm_mut: WasmMut) []const u8 {
        return switch (wasm_mut) {
            .@"const" => "const ",
            .@"var" => "",
        };
    }
};

const WasmOpCode = enum(u8) {
    @"unreachable" = 0x00,
    nop = 0x01,
    block = 0x02,
    loop = 0x03,
    @"if" = 0x04,
    @"else" = 0x05,
    end = 0x0B,
    br = 0x0C,
    br_if = 0x0D,
    br_table = 0x0E,
    @"return" = 0x0F,
    call = 0x10,
    call_indirect = 0x11,

    drop = 0x1A,
    select = 0x1B,
    select_t = 0x1C,

    local_get = 0x20,
    local_set = 0x21,
    local_tee = 0x22,
    global_get = 0x23,
    global_set = 0x24,

    table_get = 0x25,
    table_set = 0x26,

    i32_load = 0x28,
    i64_load = 0x29,
    f32_load = 0x2A,
    f64_load = 0x2B,
    i32_load8_s = 0x2C,
    i32_load8_u = 0x2D,
    i32_load16_s = 0x2E,
    i32_load16_u = 0x2F,
    i64_load8_s = 0x30,
    i64_load8_u = 0x31,
    i64_load16_s = 0x32,
    i64_load16_u = 0x33,
    i64_load32_s = 0x34,
    i64_load32_u = 0x35,
    i32_store = 0x36,
    i64_store = 0x37,
    f32_store = 0x38,
    f64_store = 0x39,
    i32_store8 = 0x3A,
    i32_store16 = 0x3B,
    i64_store8 = 0x3C,
    i64_store16 = 0x3D,
    i64_store32 = 0x3E,
    memory_size = 0x3F,
    memory_grow = 0x40,

    i32_const = 0x41,
    i64_const = 0x42,
    f32_const = 0x43,
    f64_const = 0x44,

    i32_eqz = 0x45,
    i32_eq = 0x46,
    i32_ne = 0x47,
    i32_lt_s = 0x48,
    i32_lt_u = 0x49,
    i32_gt_s = 0x4A,
    i32_gt_u = 0x4B,
    i32_le_s = 0x4C,
    i32_le_u = 0x4D,
    i32_ge_s = 0x4E,
    i32_ge_u = 0x4F,

    i64_eqz = 0x50,
    i64_eq = 0x51,
    i64_ne = 0x52,
    i64_lt_s = 0x53,
    i64_lt_u = 0x54,
    i64_gt_s = 0x55,
    i64_gt_u = 0x56,
    i64_le_s = 0x57,
    i64_le_u = 0x58,
    i64_ge_s = 0x59,
    i64_ge_u = 0x5A,

    f32_eq = 0x5B,
    f32_ne = 0x5C,
    f32_lt = 0x5D,
    f32_gt = 0x5E,
    f32_le = 0x5F,
    f32_ge = 0x60,

    f64_eq = 0x61,
    f64_ne = 0x62,
    f64_lt = 0x63,
    f64_gt = 0x64,
    f64_le = 0x65,
    f64_ge = 0x66,

    i32_clz = 0x67,
    i32_ctz = 0x68,
    i32_popcnt = 0x69,
    i32_add = 0x6A,
    i32_sub = 0x6B,
    i32_mul = 0x6C,
    i32_div_s = 0x6D,
    i32_div_u = 0x6E,
    i32_rem_s = 0x6F,
    i32_rem_u = 0x70,
    i32_and = 0x71,
    i32_or = 0x72,
    i32_xor = 0x73,
    i32_shl = 0x74,
    i32_shr_s = 0x75,
    i32_shr_u = 0x76,
    i32_rotl = 0x77,
    i32_rotr = 0x78,

    i64_clz = 0x79,
    i64_ctz = 0x7A,
    i64_popcnt = 0x7B,
    i64_add = 0x7C,
    i64_sub = 0x7D,
    i64_mul = 0x7E,
    i64_div_s = 0x7F,
    i64_div_u = 0x80,
    i64_rem_s = 0x81,
    i64_rem_u = 0x82,
    i64_and = 0x83,
    i64_or = 0x84,
    i64_xor = 0x85,
    i64_shl = 0x86,
    i64_shr_s = 0x87,
    i64_shr_u = 0x88,
    i64_rotl = 0x89,
    i64_rotr = 0x8A,

    f32_abs = 0x8B,
    f32_neg = 0x8C,
    f32_ceil = 0x8D,
    f32_floor = 0x8E,
    f32_trunc = 0x8F,
    f32_nearest = 0x90,
    f32_sqrt = 0x91,
    f32_add = 0x92,
    f32_sub = 0x93,
    f32_mul = 0x94,
    f32_div = 0x95,
    f32_min = 0x96,
    f32_max = 0x97,
    f32_copysign = 0x98,

    f64_abs = 0x99,
    f64_neg = 0x9A,
    f64_ceil = 0x9B,
    f64_floor = 0x9C,
    f64_trunc = 0x9D,
    f64_nearest = 0x9E,
    f64_sqrt = 0x9F,
    f64_add = 0xA0,
    f64_sub = 0xA1,
    f64_mul = 0xA2,
    f64_div = 0xA3,
    f64_min = 0xA4,
    f64_max = 0xA5,
    f64_copysign = 0xA6,

    i32_wrap_i64 = 0xA7,
    i32_trunc_f32_s = 0xA8,
    i32_trunc_f32_u = 0xA9,
    i32_trunc_f64_s = 0xAA,
    i32_trunc_f64_u = 0xAB,
    i64_extend_i32_s = 0xAC,
    i64_extend_i32_u = 0xAD,
    i64_trunc_f32_s = 0xAE,
    i64_trunc_f32_u = 0xAF,
    i64_trunc_f64_s = 0xB0,
    i64_trunc_f64_u = 0xB1,
    f32_convert_i32_s = 0xB2,
    f32_convert_i32_u = 0xB3,
    f32_convert_i64_s = 0xB4,
    f32_convert_i64_u = 0xB5,
    f32_demote_f64 = 0xB6,
    f64_convert_i32_s = 0xB7,
    f64_convert_i32_u = 0xB8,
    f64_convert_i64_s = 0xB9,
    f64_convert_i64_u = 0xBA,
    f64_promote_f32 = 0xBB,
    i32_reinterpret_f32 = 0xBC,
    i64_reinterpret_f64 = 0xBD,
    f32_reinterpret_i32 = 0xBE,
    f64_reinterpret_i64 = 0xBF,

    i32_extend8_s = 0xC0,
    i32_extend16_s = 0xC1,
    i64_extend8_s = 0xC2,
    i64_extend16_s = 0xC3,
    i64_extend32_s = 0xC4,

    prefixed = 0xFC,
};

const WasmPrefixedOpCode = enum(u8) {
    i32_trunc_sat_f32_s = 0,
    i32_trunc_sat_f32_u = 1,
    i32_trunc_sat_f64_s = 2,
    i32_trunc_sat_f64_u = 3,
    i64_trunc_sat_f32_s = 4,
    i64_trunc_sat_f32_u = 5,
    i64_trunc_sat_f64_s = 6,
    i64_trunc_sat_f64_u = 7,

    memory_init = 8,
    data_drop = 9,
    memory_copy = 10,
    memory_fill = 11,

    table_init = 12,
    elem_drop = 13,
    table_copy = 14,
    table_grow = 15,
    table_size = 16,
    table_fill = 17,
};

const WasmType = WasmValType; // TODO

const WasmResultType = []const WasmType;

const WasmFuncType = struct {
    param: WasmResultType,
    result: WasmResultType,

    fn fromBlockType(types: []const WasmFuncType, block_type: i64) *const WasmFuncType {
        if (block_type >= 0) return &types[@intCast(usize, block_type)];

        const Types = struct {
            const empty = [_]WasmValType{};
            const @"i32" = [_]WasmValType{.i32};
            const @"i64" = [_]WasmValType{.i64};
            const @"f32" = [_]WasmValType{.f32};
            const @"f64" = [_]WasmValType{.f64};

            const empty_empty = WasmFuncType{ .param = &empty, .result = &empty };
            const empty_i32 = WasmFuncType{ .param = &empty, .result = &@"i32" };
            const empty_i64 = WasmFuncType{ .param = &empty, .result = &@"i64" };
            const empty_f32 = WasmFuncType{ .param = &empty, .result = &@"f32" };
            const empty_f64 = WasmFuncType{ .param = &empty, .result = &@"f64" };
        };

        switch (@intToEnum(WasmValType, block_type)) {
            .empty => return &Types.empty_empty,
            .i32 => return &Types.empty_i32,
            .i64 => return &Types.empty_i64,
            .f32 => return &Types.empty_f32,
            .f64 => return &Types.empty_f64,
            else => unreachable,
        }
    }
};

const WasmImportDesc = enum(u8) {
    typeidx = 0x0,
    tabletype = 0x1,
    memtype = 0x2,
    globaltype = 0x3,
};

const WasmImport = struct {
    mod: []const u8,
    name: []const u8,
    type_idx: u32,
};

const WasmFunc = struct {
    type_idx: u32,
};

const WasmLimitsType = enum(u8) {
    no_max = 0x00,
    max = 0x01,
};

const WasmLimits = struct {
    min: u32,
    max: ?u32,
};

const WasmTable = struct {
    typ: WasmRefType,
    limits: WasmLimits,
};

const WasmMem = struct {
    limits: WasmLimits,
};

const WasmGlobal = struct {
    mut: WasmMut,
    val_type: WasmValType,
};

const WasmExportDesc = enum(u8) {
    funcidx = 0x0,
    tableidx = 0x1,
    memidx = 0x2,
    globalidx = 0x3,
};

fn readLeb128(reader: anytype, comptime Int: type) !Int {
    const bits = @typeInfo(Int).Int.bits;
    const Uint = @Type(.{ .Int = .{ .signedness = .unsigned, .bits = bits } });
    const Shift = switch (Int) {
        u32, i32 => u5,
        u64, i64 => u6,
        else => @compileError("Unsupported Leb128 type: " ++ @typeName(Int)),
    };
    var value: Uint = 0;
    var shift: u8 = 0;
    var byte: u8 = undefined;
    while (true) {
        byte = try reader.readByte();
        value |= @as(Uint, byte & 0x7F) << @intCast(Shift, shift);
        shift += 7;
        if (byte & 0x80 == 0) break;
    }
    if (@typeInfo(Int).Int.signedness == .signed) {
        if (shift < bits) {
            const mask = @bitCast(Uint, 0 -% @bitCast(Int, @as(Uint, 1) << @intCast(Shift, shift)));
            if (byte & 0x40 != 0) {
                value |= mask;
            } else {
                value &= ~mask;
            }
        }
    }
    return @bitCast(Int, value);
}

fn testReadLeb128(comptime Int: type, bytes: []const u8, expected: Int) !void {
    var reader = std.io.FixedBufferStream([]const u8){ .buffer = bytes, .pos = 0 };
    try expectEqual(expected, try readLeb128(&reader.reader(), Int));
}
test "readLeb128" {
    // Examples from https://en.wikipedia.org/wiki/LEB128
    try testReadLeb128(u32, &.{ 0b11100101, 0b10001110, 0b00100110 }, 624485);
    try testReadLeb128(u64, &.{ 0b11100101, 0b10001110, 0b00100110 }, 624485);
    try testReadLeb128(i32, &.{ 0b11000000, 0b10111011, 0b01111000 }, -123456);
    try testReadLeb128(i64, &.{ 0b11000000, 0b10111011, 0b01111000 }, -123456);
}

fn evalExpr(reader: anytype) !u32 {
    var value: u32 = undefined;
    while (true) {
        const byte = try reader.readByte();
        const op_code = @intToEnum(WasmOpCode, byte);
        switch (op_code) {
            .end => return value,
            .i32_const => {
                value = @intCast(u32, try readLeb128(reader, i32));
            },
            else => panic("unsupported expr opcode: {}", .{op_code}),
        }
    }
}

fn renderExpr(reader: anytype, writer: anytype) !void {
    while (true) {
        const byte = try reader.readByte();
        const op_code = @intToEnum(WasmOpCode, byte);
        switch (op_code) {
            .end => return,
            .i32_const => {
                const value = @intCast(u32, try readLeb128(reader, i32));
                try writer.print("UINT32_C(0x{x})", .{value});
            },
            else => panic("unsupported expr opcode: {}", .{op_code}),
        }
    }
}

fn readBytes(reader: anytype, comptime num_bytes: usize) ![num_bytes]u8 {
    var bytes: [num_bytes]u8 = undefined;
    const len = try reader.readAll(&bytes);
    try expectEqual(num_bytes, len);
    return bytes;
}

fn skipToSection(reader_peek: anytype, reader: anytype, section_id: WasmSectionId) !bool {
    while (true) {
        const next_section_id = reader.readByte() catch |err| {
            return if (err == error.EndOfStream) false else err;
        };

        // Annoyingly, WasmSectionId.datacount has id 12 but is placed between ids 9 and 10.
        const next_section_id_order = if (next_section_id == @enumToInt(WasmSectionId.datacount))
            9.5
        else
            @intToFloat(f32, next_section_id);
        const section_id_order = if (section_id == .datacount) 9.5 else @intToFloat(f32, @enumToInt(section_id));

        switch (std.math.order(next_section_id_order, section_id_order)) {
            .lt => {
                const size = try readLeb128(reader, u32);
                try reader.skipBytes(size, .{});
            },
            .eq => {
                _ = try readLeb128(reader, u32);
                return true;
            },
            .gt => {
                try reader_peek.putBackByte(next_section_id);
                return false;
            },
        }
    }
}

fn readResultType(allocator: Allocator, reader: anytype) !WasmResultType {
    const len = try readLeb128(reader, u32);
    const types = try allocator.alloc(WasmType, len);
    for (types) |*typ| {
        typ.* = @intToEnum(WasmValType, try readLeb128(reader, i64));
        switch (typ.*) {
            .i32, .i64, .f32, .f64 => {},
            else => panic("unsupported val_type: {}", .{typ.*}),
        }
    }
    return types;
}

fn readName(allocator: Allocator, reader: anytype) ![]const u8 {
    const len = try readLeb128(reader, u32);
    const name = try allocator.alloc(u8, len);
    const read = try reader.readAll(name);
    if (read < len) panic("unexpected end of input stream", .{});
    return name;
}

fn readLimits(reader: anytype) !WasmLimits {
    const limits_type = @intToEnum(WasmLimitsType, try reader.readByte());
    const min = try readLeb128(reader, u32);
    const max = switch (limits_type) {
        .no_max => null,
        .max => try readLeb128(reader, u32),
    };
    return .{ .min = min, .max = max };
}

const Block = struct {
    typ: u32,
    label: u32,
    stack_i: u32,
    reuse_i: u32,
};

const FuncGen = struct {
    allocator: Allocator,
    type: ArrayList(i8),
    reuse: ArrayList(u32),
    stack: ArrayList(u32),
    block: ArrayList(Block),

    fn init(func_gen: *FuncGen, allocator: Allocator) void {
        func_gen.* = .{
            .allocator = allocator,
            .type = ArrayList(i8).init(allocator),
            .reuse = ArrayList(u32).init(allocator),
            .stack = ArrayList(u32).init(allocator),
            .block = ArrayList(Block).init(allocator),
        };
    }

    fn deinit(func_gen: *FuncGen) void {
        func_gen.block.deinit();
        func_gen.stack.deinit();
        func_gen.reuse.deinit();
        func_gen.type.deinit();
    }

    fn reset(func_gen: *FuncGen) void {
        func_gen.type.shrinkRetainingCapacity(0);
        func_gen.reuse.shrinkRetainingCapacity(0);
        func_gen.stack.shrinkRetainingCapacity(0);
        func_gen.block.shrinkRetainingCapacity(0);
    }

    fn outdent(func_gen: *FuncGen, writer: anytype) !void {
        for (func_gen.block.items) |_| try writer.writeByteNTimes(' ', 4);
    }

    fn indent(func_gen: *FuncGen, writer: anytype) !void {
        try func_gen.outdent(writer);
        try writer.writeByteNTimes(' ', 4);
    }

    fn cont(func_gen: *FuncGen, writer: anytype) !void {
        try func_gen.indent(writer);
        try writer.writeByteNTimes(' ', 4);
    }

    fn localAlloc(func_gen: *FuncGen, val_type: i8) !u32 {
        try func_gen.type.append(val_type);
        return @intCast(u32, func_gen.type.items.len - 1);
    }

    fn localType(func_gen: *const FuncGen, local_idx: u32) WasmValType {
        return @intToEnum(WasmValType, func_gen.type.items[local_idx]);
    }

    fn localDeclare(func_gen: *FuncGen, writer: anytype, val_type: WasmValType) !u32 {
        const local_idx = try func_gen.localAlloc(@enumToInt(val_type));
        try writer.print("{s} l{}", .{ val_type.toC(), local_idx });
        return local_idx;
    }

    fn reuseTop(func_gen: *const FuncGen) u32 {
        return if (func_gen.block.items.len > 0)
            func_gen.block.items[func_gen.block.items.len - 1].reuse_i
        else
            0;
    }

    fn reuseReset(func_gen: *FuncGen) void {
        func_gen.reuse.shrinkRetainingCapacity(func_gen.reuseTop());
    }

    fn reuseLocal(func_gen: *FuncGen, writer: anytype, val_type: WasmValType) !u32 {
        for (func_gen.reuseTop()..func_gen.reuse.items.len) |i| {
            const local_idx = func_gen.reuse.items[i];
            if (func_gen.localType(local_idx) == val_type) {
                func_gen.reuse.items[i] = func_gen.reuse.pop();
                try writer.print("l{}", .{local_idx});
                return local_idx;
            }
        }
        return func_gen.localDeclare(writer, val_type);
    }

    fn stackPush(func_gen: *FuncGen, writer: anytype, val_type: WasmValType) !void {
        try func_gen.indent(writer);
        try func_gen.stack.append(try func_gen.reuseLocal(writer, val_type));
        try writer.writeAll(" = ");
    }

    fn stackAt(func_gen: *const FuncGen, stack_idx: u32) u32 {
        return func_gen.stack.items[func_gen.stack.items.len - 1 - stack_idx];
    }

    fn stackPop(func_gen: *FuncGen) !u32 {
        const local_idx = func_gen.stack.pop();
        try func_gen.reuse.append(local_idx);
        return local_idx;
    }

    fn writeLabel(func_gen: *FuncGen, writer: anytype, label: u32) !void {
        try func_gen.indent(writer);
        try writer.print("goto l{};\n", .{label});
        try func_gen.outdent(writer);
        try writer.print("l{}:;\n", .{label});
    }

    fn blockBegin(func_gen: *FuncGen, writer: anytype, kind: WasmOpCode, typ: i64) !void {
        if (kind == .@"if") {
            try func_gen.indent(writer);
            try writer.print("if (l{}) {{\n", .{try func_gen.stackPop()});
        } else if (EXTRA_BRACES) {
            try func_gen.indent(writer);
            try writer.writeAll("{\n");
        }

        // TODO sus
        const label = try func_gen.localAlloc(if (typ < 0)
            ~@bitCast(i8, @enumToInt(kind))
        else
            @bitCast(i8, @enumToInt(kind)));
        try func_gen.block.append(.{
            .typ = @intCast(u32, if (typ < 0) ~typ else typ),
            .label = label,
            .stack_i = @intCast(u32, func_gen.stack.items.len),
            .reuse_i = @intCast(u32, func_gen.reuse.items.len),
        });
        if (kind == .loop) try func_gen.writeLabel(writer, label);

        const reuse_top = func_gen.reuseTop();
        const reuse_n = func_gen.reuse.items.len - reuse_top;
        try func_gen.reuse.ensureUnusedCapacity(reuse_n);
        func_gen.reuse.appendSliceAssumeCapacity(func_gen.reuse.items[reuse_top .. reuse_top + reuse_n]);
    }

    fn blockKind(func_gen: *const FuncGen, label_idx: u32) WasmOpCode {
        const kind = func_gen.type.items[func_gen.blockLabel(label_idx)];
        return @intToEnum(WasmOpCode, if (kind < 0) ~kind else kind);
    }

    fn blockType(func_gen: *const FuncGen, label_idx: u32) i64 {
        const block = &func_gen.block.items[func_gen.block.items.len - 1 - label_idx];
        return if (func_gen.type.items[block.label] < 0)
            ~@intCast(i64, block.typ)
        else
            @intCast(i64, block.typ);
    }

    fn blockLabel(func_gen: *const FuncGen, label_idx: u32) u32 {
        return func_gen.block.items[func_gen.block.items.len - 1 - label_idx].label;
    }

    fn blockEnd(func_gen: *FuncGen, writer: anytype) !void {
        const kind = func_gen.blockKind(0);
        const label = func_gen.blockLabel(0);
        if (kind != .loop) try func_gen.writeLabel(writer, label);
        const block = func_gen.block.pop();

        if (EXTRA_BRACES or kind == .@"if") {
            try func_gen.indent(writer);
            try writer.writeAll("}\n");
        }

        if (func_gen.stack.items.len != block.stack_i) {
            try func_gen.indent(writer);
            try writer.print("// stack mismatch {} != {}\n", .{ func_gen.stack.items.len, block.stack_i });
        }
        func_gen.stack.shrinkRetainingCapacity(block.stack_i);
        func_gen.reuse.shrinkRetainingCapacity(block.reuse_i);
    }

    fn done(func_gen: *const FuncGen) bool {
        return func_gen.block.items.len == 0;
    }
};

fn renderResultType(writer: anytype, func_type: *const WasmFuncType) !void {
    switch (func_type.result.len) {
        0 => try writer.writeAll("void"),
        1 => try writer.writeAll(func_type.result[0].toC()),
        else => panic("multiple function returns not supported", .{}),
    }
}

fn renderParamType(writer: anytype, func_type: *const WasmFuncType) !void {
    if (func_type.param.len == 0) try writer.writeAll("void");
    for (func_type.param, 0..) |typ, typ_i| {
        if (typ_i > 0) try writer.writeAll(", ");
        try writer.writeAll(typ.toC());
    }
}

pub const Mangle = struct {
    name: []const u8,

    pub fn format(value: Mangle, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        for (value.name, 0..) |byte, i| {
            switch (byte) {
                'a'...'z', 'A'...'Z', '_' => try writer.writeByte(byte),
                '0'...'9' => {
                    if (i == 0) try writer.writeAll("__");
                    try writer.writeByte(byte);
                },
                '.' => try writer.writeAll("__DOT__"),
                '-' => try writer.writeAll("__DASH__"),
                '$' => try writer.writeAll("__DOLLAR__"),
                '<' => try writer.writeAll("__LT__"),
                '>' => try writer.writeAll("__GT__"),
                else => panic("Don't know how to mangle: {s}", .{value.name}),
            }
        }
    }
};

pub fn mangle(name: []const u8) Mangle {
    return .{ .name = name };
}

fn run(allocator: Allocator, reader_peek: anytype, reader: anytype, writer_c: anytype, writer_h: anytype) !void {
    const magic = try readBytes(reader, 4);
    try expectEqual([4]u8{ 0, 'a', 's', 'm' }, magic);

    const version = try reader.readIntLittle(u32);
    if (version != 1) panic("unsupported wasm version: {}", .{version});

    assert(builtin.target.cpu.arch.endian() == .Little);

    try writer_c.writeAll(@embedFile("./preamble.c"));
    try writer_c.writeAll("\n\n");

    try writer_h.writeAll(@embedFile("./preamble.h"));
    try writer_h.writeAll("\n\n");

    var types: []WasmFuncType = &.{};
    var max_param_len: u32 = 0;
    if (try skipToSection(reader_peek, reader, .type)) {
        const len = try readLeb128(reader, u32);
        types = try allocator.alloc(WasmFuncType, len);
        for (types) |*typ| {
            const func_type_tag = try reader.readByte();
            if (func_type_tag != 0x60) panic("expected functype, found {}", .{typ});
            typ.* = .{
                .param = try readResultType(allocator, reader),
                .result = try readResultType(allocator, reader),
            };
            max_param_len = @max(max_param_len, @intCast(u32, typ.param.len));
        }
    }

    var imports: []WasmImport = &.{};
    if (try skipToSection(reader_peek, reader, .import)) {
        const len = try readLeb128(reader, u32);
        imports = try allocator.alloc(WasmImport, len);
        for (imports) |*import| {
            const mod = try readName(allocator, reader);
            const name = try readName(allocator, reader);
            const import_desc = @intToEnum(WasmImportDesc, try reader.readByte());
            const type_idx = switch (import_desc) {
                .typeidx => try readLeb128(reader, u32),
                else => panic("unsupported import_desc: {}", .{import_desc}),
            };
            import.* = .{
                .mod = mod,
                .name = name,
                .type_idx = type_idx,
            };
            const func_type = &types[import.type_idx];
            try renderResultType(writer_c, func_type);
            try writer_c.print(" {s}_{s}(", .{
                mangle(import.mod),
                mangle(import.name),
            });
            try renderParamType(writer_c, func_type);
            try writer_c.writeAll(");\n");
        }
        try writer_c.writeAll("\n");
    }

    var funcs: []WasmFunc = &.{};
    if (try skipToSection(reader_peek, reader, .func)) {
        const len = try readLeb128(reader, u32);
        funcs = try allocator.alloc(WasmFunc, len);
        for (funcs, 0..) |*func, func_i| {
            func.* = .{
                .type_idx = try readLeb128(reader, u32),
            };
            const func_type = &types[func.type_idx];
            try writer_c.writeAll("static ");
            try renderResultType(writer_c, func_type);
            try writer_c.print(" f{}(", .{func_i});
            try renderParamType(writer_c, func_type);
            try writer_c.writeAll(");\n");
        }
        try writer_c.writeAll("\n");
    }

    var tables: []WasmTable = &.{};
    if (try skipToSection(reader_peek, reader, .table)) {
        const len = try readLeb128(reader, u32);
        tables = try allocator.alloc(WasmTable, len);
        for (tables, 0..) |*table, table_i| {
            const typ = @intToEnum(WasmRefType, try readLeb128(reader, i64));
            switch (typ) {
                .funcref => {},
                else => panic("unsupported table type: {}", .{typ}),
            }
            const limits = try readLimits(reader);
            if (limits.min != limits.max) panic("growable table not supported", .{});
            table.* = .{
                .typ = typ,
                .limits = limits,
            };
            try writer_c.print("static void (*t{}[UINT32_C({})])(void);\n", .{ table_i, limits.min });
        }
        try writer_c.writeAll("\n");
    }

    var mems: []WasmMem = &.{};
    if (try skipToSection(reader_peek, reader, .mem)) {
        const len = try readLeb128(reader, u32);
        mems = try allocator.alloc(WasmMem, len);
        for (mems, 0..) |*mem, mem_i| {
            const limits = try readLimits(reader);
            mem.* = .{
                .limits = limits,
            };
            try writer_c.print(
                \\static uint8_t *m{};
                \\static uint32_t p{};
                \\static uint32_t c{};
                \\
            , .{ mem_i, mem_i, mem_i });
        }
        try writer_c.writeAll("\n");
    }

    var globals: []WasmGlobal = &.{};
    if (try skipToSection(reader_peek, reader, .global)) {
        const len = try readLeb128(reader, u32);
        globals = try allocator.alloc(WasmGlobal, len);
        for (globals, 0..) |*global, global_i| {
            const val_type = @intToEnum(WasmValType, try readLeb128(reader, i64));
            const mut = @intToEnum(WasmMut, try reader.readByte());
            global.* = .{
                .mut = mut,
                .val_type = val_type,
            };
            try writer_c.print("{s}{s} g{} = ", .{ mut.toC(), val_type.toC(), global_i });
            try renderExpr(reader, writer_c);
            try writer_c.writeAll(";\n");
        }
        try writer_c.writeAll("\n");
    }

    if (try skipToSection(reader_peek, reader, .@"export")) {
        const len = try readLeb128(reader, u32);
        for (0..len) |_| {
            const name = try readName(allocator, reader);
            const desc = @intToEnum(WasmExportDesc, try reader.readByte());
            switch (desc) {
                .funcidx => {
                    const idx = try readLeb128(reader, u32);
                    if (idx < imports.len) panic("can't export an import", .{});
                    const func_type = &types[funcs[idx - imports.len].type_idx];
                    {
                        try renderResultType(writer_c, func_type);
                        try writer_c.print(" {s}_{s}(", .{
                            "wasm",
                            mangle(name),
                        });
                        if (func_type.param.len == 0) try writer_c.writeAll("void");
                        for (func_type.param, 0..) |typ, typ_i| {
                            if (typ_i > 0) try writer_c.writeAll(", ");
                            try writer_c.print("{s} l{}", .{ typ.toC(), typ_i });
                        }
                        try writer_c.print(
                            \\) {{
                            \\    init();
                            \\    {s}f{}(
                        , .{
                            if (func_type.result.len > 0) "return " else "",
                            idx - imports.len,
                        });
                        for (func_type.param, 0..) |_, typ_i| {
                            if (typ_i > 0) try writer_c.writeAll(", ");
                            try writer_c.print("l{}", .{typ_i});
                        }
                        try writer_c.writeAll(");\n}\n");
                    }
                    {
                        try renderResultType(writer_h, func_type);
                        try writer_h.print(" {s}_{s}(", .{ "wasm", mangle(name) });
                        if (func_type.param.len == 0) try writer_h.writeAll("void");
                        for (func_type.param, 0..) |typ, typ_i| {
                            if (typ_i > 0) try writer_h.writeAll(", ");
                            try writer_h.print("{s} l{}", .{ typ.toC(), typ_i });
                        }
                        try writer_h.writeAll(");\n");
                    }
                },
                .memidx => {
                    const idx = try readLeb128(reader, u32);
                    try writer_c.print("uint8_t **const {s}_{s} = &m{};\n", .{ "wasm", mangle(name), idx });
                    try writer_h.print("uint8_t **const {s}_{s};\n", .{ "wasm", mangle(name) });
                },
                else => panic("unsupported export kind: {}", .{desc}),
            }
        }
        try writer_c.writeAll("\n");
    }

    try writer_c.writeAll("static void init_elem(void) {\n");
    if (try skipToSection(reader_peek, reader, .elem)) {
        const len = try readLeb128(reader, u32);
        for (0..len) |_| {
            var table_idx: u32 = 0;
            const elem_type = try readLeb128(reader, u32);
            if (elem_type != 0x00) panic("unsupported elem type: {}", .{elem_type});
            const offset = try evalExpr(reader);
            const segment_len = try readLeb128(reader, u32);
            for (0..segment_len) |i| {
                const func_id = try readLeb128(reader, u32);
                try writer_c.print("    t{}[UINT32_C({})] = (void (*)(void))&", .{ table_idx, offset + i });
                if (func_id < imports.len) {
                    try writer_c.print("{s}_{s}", .{
                        mangle(imports[func_id].mod),
                        mangle(imports[func_id].name),
                    });
                } else {
                    try writer_c.print("f{}", .{func_id - imports.len});
                }
                try writer_c.writeAll(";\n");
            }
        }
    }
    try writer_c.writeAll("}\n\n");

    if (try skipToSection(reader_peek, reader, .code)) {
        var fg: FuncGen = undefined;
        fg.init(allocator);
        const param_used = try allocator.alloc(bool, max_param_len);
        const param_stash = try allocator.alloc(u32, max_param_len);

        const len = try readLeb128(reader, u32);
        for (0..len) |func_i| {
            fg.reset();

            const code_len = try readLeb128(reader, u32);
            _ = code_len; // TODO

            const func_type = &types[funcs[func_i].type_idx];
            try writer_c.writeAll("static ");
            try renderResultType(writer_c, func_type);
            try writer_c.print(" f{}(", .{func_i});
            if (func_type.param.len == 0) try writer_c.writeAll("void");
            for (func_type.param, 0..) |param_type, param_i| {
                param_used[param_i] = false;
                if (param_i > 0) try writer_c.writeAll(", ");
                _ = try fg.localDeclare(writer_c, param_type);
            }
            try writer_c.writeAll(") {\n");

            var local_sets_remaining = try readLeb128(reader, u32);
            while (local_sets_remaining > 0) : (local_sets_remaining -= 1) {
                var local_set_len = try readLeb128(reader, u32);
                const val_type = @intToEnum(WasmValType, try readLeb128(reader, i64));
                while (local_set_len > 0) : (local_set_len -= 1) {
                    try fg.indent(writer_c);
                    _ = try fg.localDeclare(writer_c, val_type);
                    try writer_c.writeAll(" = 0;\n");
                }
            }

            {
                var result_i = func_type.result.len;
                while (result_i > 0) {
                    result_i -= 1;
                    try fg.indent(writer_c);
                    _ = try fg.localDeclare(writer_c, func_type.result[result_i]);
                    try writer_c.writeAll(";\n");
                }
            }

            try fg.blockBegin(writer_c, .block, funcs[func_i].type_idx);

            var unreachable_depth: u32 = 0;
            while (!fg.done()) {
                const opcode = @intToEnum(WasmOpCode, try reader.readByte());
                switch (opcode) {
                    .@"unreachable" => {
                        if (unreachable_depth == 0) {
                            try fg.indent(writer_c);
                            try writer_c.writeAll("abort();\n");
                            unreachable_depth += 1;
                        }
                    },
                    .nop => {},
                    .block, .loop, .@"if" => {
                        const block_type = try readLeb128(reader, i64);
                        if (unreachable_depth == 0) {
                            const block_func_type = WasmFuncType.fromBlockType(types, block_type);
                            {
                                var param_i = block_func_type.param.len;
                                while (param_i > 0) {
                                    param_i -= 1;
                                    try fg.indent(writer_c);
                                    param_stash[param_i] = try fg.localDeclare(writer_c, block_func_type.param[param_i]);
                                    try writer_c.print(" = l{};\n", .{try fg.stackPop()});
                                }
                            }
                            {
                                var result_i = block_func_type.result.len;
                                while (result_i > 0) {
                                    result_i -= 1;
                                    try fg.indent(writer_c);
                                    _ = try fg.localDeclare(writer_c, block_func_type.result[result_i]);
                                    try writer_c.writeAll(";\n");
                                }
                            }
                            try fg.blockBegin(writer_c, opcode, block_type);
                            for (block_func_type.param, 0..) |param_type, param_i| {
                                try fg.stackPush(writer_c, param_type);
                                try writer_c.print(" = l{};\n", .{param_stash[param_i]});
                            }
                        } else unreachable_depth += 1;
                    },
                    .@"else", .end => {
                        if (unreachable_depth <= 1) {
                            const result_type = WasmFuncType.fromBlockType(types, fg.blockType(0)).result;
                            const label = fg.blockLabel(0);
                            if (unreachable_depth == 0) {
                                var result_i = result_type.len;
                                while (result_i > 0) {
                                    result_i -= 1;
                                    try fg.indent(writer_c);
                                    try writer_c.print(
                                        "l{} = l{};\n",
                                        .{ label - result_type.len + result_i, try fg.stackPop() },
                                    );
                                }
                            } else unreachable_depth -= 1;
                            switch (opcode) {
                                .@"else" => {
                                    fg.reuseReset();
                                    try fg.outdent(writer_c);
                                    try writer_c.writeAll("} else {\n");
                                },
                                .end => {
                                    try fg.blockEnd(writer_c);
                                    var result_i = result_type.len;
                                    while (result_i > 0) {
                                        result_i -= 1;
                                        try fg.stackPush(writer_c, result_type[result_i]);
                                        try writer_c.print(
                                            "l{};\n",
                                            .{label - result_type.len + result_i},
                                        );
                                    }
                                },
                                else => unreachable,
                            }
                        } else if (opcode == .end) unreachable_depth -= 1;
                    },
                    .br, .br_if => {
                        const label_idx = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const kind = fg.blockKind(label_idx);
                            const block_func_type = WasmFuncType.fromBlockType(types, fg.blockType(label_idx));
                            const label = fg.blockLabel(label_idx);

                            if (opcode == .br_if) {
                                try fg.indent(writer_c);
                                try writer_c.print("if (l{}) {{\n", .{try fg.stackPop()});
                            } else if (EXTRA_BRACES) {
                                try fg.indent(writer_c);
                                try writer_c.writeAll("{\n");
                            }

                            var label_type: WasmResultType = undefined;
                            var lhs: u32 = undefined;
                            switch (kind) {
                                .loop => {
                                    label_type = block_func_type.param;
                                    lhs = @intCast(u32, label - block_func_type.result.len - block_func_type.param.len);
                                },
                                else => {
                                    label_type = block_func_type.result;
                                    lhs = @intCast(u32, label - block_func_type.result.len);
                                },
                            }
                            for (0..label_type.len) |stack_i| {
                                const rhs = switch (opcode) {
                                    .br => try fg.stackPop(),
                                    .br_if => fg.stackAt(@intCast(u32, stack_i)),
                                    else => unreachable,
                                };
                                try fg.cont(writer_c);
                                try writer_c.print("l{} = l{};\n", .{ lhs, rhs });
                                lhs += 1;
                            }
                            try fg.cont(writer_c);
                            try writer_c.print("goto l{};\n", .{label});
                            if (EXTRA_BRACES or opcode == .br_if) {
                                try fg.indent(writer_c);
                                try writer_c.writeAll("}\n");
                            }
                            if (opcode == .br) unreachable_depth += 1;
                        }
                    },
                    .br_table => {
                        if (unreachable_depth == 0) {
                            try fg.indent(writer_c);
                            try writer_c.print("switch (l{}) {{\n", .{try fg.stackPop()});
                        }
                        const label_len = try readLeb128(reader, u32);
                        for (0..label_len) |i| {
                            const label = try readLeb128(reader, u32);
                            if (unreachable_depth == 0) {
                                try fg.indent(writer_c);
                                try writer_c.print("case {}: goto l{};\n", .{ i, fg.blockLabel(label) });
                            }
                        }
                        const label = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            try fg.indent(writer_c);
                            try writer_c.print("default: goto l{};\n", .{fg.blockLabel(label)});
                            try fg.indent(writer_c);
                            try writer_c.writeAll("}\n");
                            unreachable_depth += 1;
                        }
                    },
                    .@"return" => {
                        if (unreachable_depth == 0) {
                            try fg.indent(writer_c);
                            try writer_c.writeAll("return");
                            switch (func_type.result.len) {
                                0 => {},
                                1 => try writer_c.print(" l{}", .{try fg.stackPop()}),
                                else => panic("multiple function returns not supported", .{}),
                            }
                            try writer_c.writeAll(";\n");
                            unreachable_depth += 1;
                        }
                    },
                    .drop => {
                        if (unreachable_depth == 0) {
                            try fg.indent(writer_c);
                            try writer_c.print("(void)l{};\n", .{try fg.stackPop()});
                        }
                    },
                    .select => {
                        if (unreachable_depth == 0) {
                            const cond = try fg.stackPop();
                            const rhs = try fg.stackPop();
                            const lhs = fg.stackAt(0);
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "l{} = l{} ? l{} : l{};\n",
                                .{ lhs, cond, lhs, rhs },
                            );
                        }
                    },
                    .call, .call_indirect => {
                        var func_id: u32 = undefined;
                        var type_idx: u32 = undefined;
                        var table_idx: u32 = undefined;
                        switch (opcode) {
                            .call => {
                                func_id = try readLeb128(reader, u32);
                                type_idx = if (func_id < imports.len)
                                    imports[func_id].type_idx
                                else
                                    funcs[func_id - imports.len].type_idx;
                            },
                            .call_indirect => {
                                type_idx = try readLeb128(reader, u32);
                                table_idx = try readLeb128(reader, u32);
                                func_id = try fg.stackPop();
                            },
                            else => unreachable,
                        }
                        if (unreachable_depth == 0) {
                            const callee_func_type = &types[type_idx];
                            {
                                var param_i = callee_func_type.param.len;
                                while (param_i > 0) {
                                    param_i -= 1;
                                    param_stash[param_i] = try fg.stackPop();
                                }
                            }
                            switch (callee_func_type.result.len) {
                                0 => try fg.indent(writer_c),
                                1 => try fg.stackPush(writer_c, callee_func_type.result[0]),
                                else => panic("multiple function returns not supported", .{}),
                            }
                            switch (opcode) {
                                .call => {
                                    if (func_id < imports.len)
                                        try writer_c.print("{s}_{s}", .{
                                            mangle(imports[func_id].mod),
                                            mangle(imports[func_id].name),
                                        })
                                    else
                                        try writer_c.print("f{}", .{func_id - imports.len});
                                },
                                .call_indirect => {
                                    try writer_c.writeAll("(*(");
                                    try renderResultType(writer_c, callee_func_type);
                                    try writer_c.writeAll(" (*)(");
                                    try renderParamType(writer_c, callee_func_type);
                                    try writer_c.print("))t{}[l{}])", .{ table_idx, func_id });
                                },
                                else => unreachable,
                            }
                            try writer_c.writeAll("(");
                            for (0..callee_func_type.param.len) |param_i| {
                                if (param_i > 0) try writer_c.writeAll(", ");
                                try writer_c.print("l{}", .{param_stash[param_i]});
                            }
                            try writer_c.writeAll(");\n");
                        }
                    },
                    .global_get => {
                        const global_idx = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            try fg.stackPush(writer_c, globals[global_idx].val_type);
                            try writer_c.print("g{};\n", .{global_idx});
                        }
                    },
                    .global_set => {
                        const global_idx = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            try fg.indent(writer_c);
                            try writer_c.print("g{} = l{};\n", .{ global_idx, try fg.stackPop() });
                        }
                    },
                    .table_get, .table_set => {
                        _ = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) panic("unimplemented opcode", .{});
                    },
                    .local_get => {
                        const local_idx = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            if (local_idx < func_type.param.len) param_used[local_idx] = true;
                            try fg.stackPush(writer_c, fg.localType(local_idx));
                            try writer_c.print("l{};\n", .{local_idx});
                        }
                    },
                    .local_set => {
                        const local_idx = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            if (local_idx < func_type.param.len) param_used[local_idx] = true;
                            try fg.indent(writer_c);
                            try writer_c.print("l{} = l{};\n", .{ local_idx, try fg.stackPop() });
                        }
                    },
                    .local_tee => {
                        const local_idx = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            if (local_idx < func_type.param.len) param_used[local_idx] = true;
                            try fg.indent(writer_c);
                            try writer_c.print("l{} = l{};\n", .{ local_idx, fg.stackAt(0) });
                        }
                    },
                    .i32_load => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print(
                                "load32_align{}((const uint{}_t *)&m{}[l{} + UINT32_C({})]);\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset },
                            );
                        }
                    },
                    .i64_load => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print(
                                "load64_align{}((const uint{}_t *)&m{}[l{} + UINT32_C({})]);\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset },
                            );
                        }
                    },
                    .f32_load => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .f32);
                            try writer_c.print(
                                "f32_reinterpret_i32(load32_align{}((const uint{}_t *)&m{}[l{} + UINT32_C({})]));\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset },
                            );
                        }
                    },
                    .f64_load => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .f64);
                            try writer_c.print(
                                "f64_reinterpret_i64(load64_align{}((const uint{}_t *)&m{}[l{} + UINT32_C({})]));\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset },
                            );
                        }
                    },
                    .i32_load8_s => {
                        _ = try readLeb128(reader, u32);
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print(
                                "(int8_t)m{}[l{} + UINT32_C({})];\n",
                                .{ 0, base, offset },
                            );
                        }
                    },
                    .i32_load8_u => {
                        _ = try readLeb128(reader, u32);
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print(
                                "m{}[l{} + UINT32_C({})];\n",
                                .{ 0, base, offset },
                            );
                        }
                    },
                    .i32_load16_s => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print(
                                "(int16_t)load16_align{}((const uint{}_t *)&m{}[l{} + UINT32_C({})]);\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset },
                            );
                        }
                    },
                    .i32_load16_u => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print(
                                "load16_align{}((const uint{}_t *)&m{}[l{} + UINT32_C({})]);\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset },
                            );
                        }
                    },
                    .i64_load8_s => {
                        _ = try readLeb128(reader, u32);
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print(
                                "(int8_t)m{}[l{} + UINT32_C({})];\n",
                                .{ 0, base, offset },
                            );
                        }
                    },
                    .i64_load8_u => {
                        _ = try readLeb128(reader, u32);
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print(
                                "m{}[l{} + UINT32_C({})];\n",
                                .{ 0, base, offset },
                            );
                        }
                    },
                    .i64_load16_s => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print(
                                "(int16_t)load16_align{}((const uint{}_t *)&m{}[l{} + UINT32_C({})]);\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset },
                            );
                        }
                    },
                    .i64_load16_u => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print(
                                "load16_align{}((const uint{}_t *)&m{}[l{} + UINT32_C({})]);\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset },
                            );
                        }
                    },
                    .i64_load32_s => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print(
                                "(int32_t)load32_align{}((const uint{}_t *)&m{}[l{} + UINT32_C({})]);\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset },
                            );
                        }
                    },
                    .i64_load32_u => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const base = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print(
                                "load32_align{}((const uint{}_t *)&m{}[l{} + UINT32_C({})]);\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset },
                            );
                        }
                    },
                    .i32_store => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const value = try fg.stackPop();
                            const base = try fg.stackPop();
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "store32_align{}((uint{}_t *)&m{}[l{} + UINT32_C({})], l{});\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset, value },
                            );
                        }
                    },
                    .i64_store => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const value = try fg.stackPop();
                            const base = try fg.stackPop();
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "store64_align{}((uint{}_t *)&m{}[l{} + UINT32_C({})], l{});\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset, value },
                            );
                        }
                    },
                    .f32_store => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const value = try fg.stackPop();
                            const base = try fg.stackPop();
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "store32_align{}((uint{}_t *)&m{}[l{} + UINT32_C({})], i32_reinterpret_f32(l{}));\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset, value },
                            );
                        }
                    },
                    .f64_store => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const value = try fg.stackPop();
                            const base = try fg.stackPop();
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "store64_align{}((uint{}_t *)&m{}[l{} + UINT32_C({})], i64_reinterpret_f64(l{}));\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset, value },
                            );
                        }
                    },
                    .i32_store8 => {
                        _ = try readLeb128(reader, u32);
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const value = try fg.stackPop();
                            const base = try fg.stackPop();
                            try fg.indent(writer_c);
                            try writer_c.print("m{}[l{} + UINT32_C({})] = (uint8_t)l{};\n", .{ 0, base, offset, value });
                        }
                    },
                    .i32_store16 => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const value = try fg.stackPop();
                            const base = try fg.stackPop();
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "store16_align{}((uint{}_t *)&m{}[l{} + UINT32_C({})], (uint16_t)l{});\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset, value },
                            );
                        }
                    },
                    .i64_store8 => {
                        _ = try readLeb128(reader, u32);
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const value = try fg.stackPop();
                            const base = try fg.stackPop();
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "m{}[l{} + UINT32_C({})] = (uint8_t)l{};\n",
                                .{ 0, base, offset, value },
                            );
                        }
                    },
                    .i64_store16 => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const value = try fg.stackPop();
                            const base = try fg.stackPop();
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "store16_align{}((uint{}_t *)&m{}[l{} + UINT32_C({})], (uint16_t)l{});\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset, value },
                            );
                        }
                    },
                    .i64_store32 => {
                        const @"align" = @intCast(u5, try readLeb128(reader, u32));
                        const offset = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const value = try fg.stackPop();
                            const base = try fg.stackPop();
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "store32_align{}((uint{}_t *)&m{}[l{} + UINT32_C({})], (uint32_t)l{});\n",
                                .{ @"align", @as(u32, 8) << @"align", 0, base, offset, value },
                            );
                        }
                    },
                    .i32_const => {
                        const value = @bitCast(u32, try readLeb128(reader, i32));
                        if (unreachable_depth == 0) {
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print("UINT32_C(0x{X});\n", .{value});
                        }
                    },
                    .i64_const => {
                        const value = @bitCast(u64, try readLeb128(reader, i64));
                        if (unreachable_depth == 0) {
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print("UINT64_C(0x{X});\n", .{value});
                        }
                    },
                    .f32_const => {
                        const value = try reader.readIntLittle(u32);
                        if (unreachable_depth == 0) {
                            try fg.stackPush(writer_c, .f32);
                            try writer_c.print("f32_reinterpret_i32(UINT32_C(0x{X}));\n", .{value});
                        }
                    },
                    .f64_const => {
                        const value = try reader.readIntLittle(u64);
                        if (unreachable_depth == 0) {
                            try fg.stackPush(writer_c, .f64);
                            try writer_c.print("f64_reinterpret_i64(UINT64_C(0x{X}));\n", .{value});
                        }
                    },
                    .i32_eqz => {
                        if (unreachable_depth == 0) {
                            const lhs = fg.stackAt(0);
                            try fg.indent(writer_c);
                            try writer_c.print("l{} = !l{};\n", .{ lhs, lhs });
                        }
                    },
                    .i32_eq,
                    .i32_ne,
                    .i32_lt_u,
                    .i32_gt_u,
                    .i32_le_u,
                    .i32_ge_u,
                    => {
                        if (unreachable_depth == 0) {
                            const rhs = try fg.stackPop();
                            const lhs = fg.stackAt(0);
                            const operator = switch (opcode) {
                                .i32_eq => "==",
                                .i32_ne => "!=",
                                .i32_lt_u => "<",
                                .i32_gt_u => ">",
                                .i32_le_u => "<=",
                                .i32_ge_u => ">=",
                                else => unreachable,
                            };
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "l{} = l{} {s} l{};\n",
                                .{ lhs, lhs, operator, rhs },
                            );
                        }
                    },
                    .i32_lt_s,
                    .i32_gt_s,
                    .i32_le_s,
                    .i32_ge_s,
                    => {
                        if (unreachable_depth == 0) {
                            const rhs = try fg.stackPop();
                            const lhs = fg.stackAt(0);
                            const operator = switch (opcode) {
                                .i32_lt_s => "<",
                                .i32_gt_s => ">",
                                .i32_le_s => "<=",
                                .i32_ge_s => ">=",
                                else => unreachable,
                            };
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "l{} = (int32_t)l{} {s} (int32_t)l{};\n",
                                .{ lhs, lhs, operator, rhs },
                            );
                        }
                    },
                    .i64_eqz => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print("!l{};\n", .{lhs});
                        }
                    },
                    .i64_eq,
                    .i64_ne,
                    .i64_lt_u,
                    .i64_gt_u,
                    .i64_le_u,
                    .i64_ge_u,
                    .f32_eq,
                    .f32_ne,
                    .f32_lt,
                    .f32_gt,
                    .f32_le,
                    .f32_ge,
                    .f64_eq,
                    .f64_ne,
                    .f64_lt,
                    .f64_gt,
                    .f64_le,
                    .f64_ge,
                    => {
                        if (unreachable_depth == 0) {
                            const rhs = try fg.stackPop();
                            const lhs = try fg.stackPop();
                            const operator = switch (opcode) {
                                .i64_eq,
                                .f32_eq,
                                .f64_eq,
                                => "==",
                                .i64_ne,
                                .f32_ne,
                                .f64_ne,
                                => "!=",
                                .i64_lt_u,
                                .f32_lt,
                                .f64_lt,
                                => "<",
                                .i64_gt_u,
                                .f32_gt,
                                .f64_gt,
                                => ">",
                                .i64_le_u,
                                .f32_le,
                                .f64_le,
                                => "<=",
                                .i64_ge_u,
                                .f32_ge,
                                .f64_ge,
                                => ">=",
                                else => unreachable,
                            };
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print(
                                "l{} = l{} {s} l{};\n",
                                .{ lhs, lhs, operator, rhs },
                            );
                        }
                    },
                    .i64_lt_s,
                    .i64_gt_s,
                    .i64_le_s,
                    .i64_ge_s,
                    => {
                        if (unreachable_depth == 0) {
                            const rhs = try fg.stackPop();
                            const lhs = try fg.stackPop();
                            const operator = switch (opcode) {
                                .i64_lt_s => "<",
                                .i64_gt_s => ">",
                                .i64_le_s => "<=",
                                .i64_ge_s => ">=",
                                else => unreachable,
                            };
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print(
                                "l{} = (int64_t)l{} {s} (int64_t)l{};\n",
                                .{ lhs, lhs, operator, rhs },
                            );
                        }
                    },
                    .i32_add,
                    .i32_sub,
                    .i32_mul,
                    .i32_div_u,
                    .i32_rem_u,
                    .i32_and,
                    .i32_or,
                    .i32_xor,
                    .i64_add,
                    .i64_sub,
                    .i64_mul,
                    .i64_div_u,
                    .i64_rem_u,
                    .i64_and,
                    .i64_or,
                    .i64_xor,
                    .f32_add,
                    .f32_sub,
                    .f32_mul,
                    .f32_div,
                    .f64_add,
                    .f64_sub,
                    .f64_mul,
                    .f64_div,
                    => {
                        if (unreachable_depth == 0) {
                            const rhs = try fg.stackPop();
                            const lhs = fg.stackAt(0);
                            const operator: u8 = switch (opcode) {
                                .i32_add, .i64_add, .f32_add, .f64_add => '+',
                                .i32_sub, .i64_sub, .f32_sub, .f64_sub => '-',
                                .i32_mul, .i64_mul, .f32_mul, .f64_mul => '*',
                                .i32_div_u, .i64_div_u, .f32_div, .f64_div => '/',
                                .i32_rem_u, .i64_rem_u => '%',
                                .i32_and, .i64_and => '&',
                                .i32_or, .i64_or => '|',
                                .i32_xor, .i64_xor => '^',
                                else => unreachable,
                            };
                            try fg.indent(writer_c);
                            try writer_c.print("l{} {c}= l{};\n", .{ lhs, operator, rhs });
                        }
                    },
                    .i32_div_s,
                    .i32_rem_s,
                    .i64_div_s,
                    .i64_rem_s,
                    => {
                        if (unreachable_depth == 0) {
                            const rhs = try fg.stackPop();
                            const lhs = fg.stackAt(0);
                            const operator: u8 = switch (opcode) {
                                .i32_div_s, .i64_div_s => '/',
                                .i32_rem_s, .i64_rem_s => '%',
                                else => unreachable,
                            };
                            const width: u8 = switch (opcode) {
                                .i32_div_s, .i32_rem_s => 32,
                                .i64_div_s, .i64_rem_s => 64,
                                else => unreachable,
                            };
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "l{} = (uint{}_t)((int{}_t)l{} {c} (int{}_t)l{});\n",
                                .{ lhs, width, width, lhs, operator, width, rhs },
                            );
                        }
                    },
                    .i32_shl, .i32_shr_u, .i64_shl, .i64_shr_u => {
                        if (unreachable_depth == 0) {
                            const rhs = try fg.stackPop();
                            const lhs = fg.stackAt(0);
                            const operator: u8 = switch (opcode) {
                                .i32_shl, .i64_shl => '<',
                                .i32_shr_u, .i64_shr_u => '>',
                                else => unreachable,
                            };
                            const width: u8 = switch (opcode) {
                                .i32_shl, .i32_shr_u => 32,
                                .i64_shl, .i64_shr_u => 64,
                                else => unreachable,
                            };
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "l{} {c}{c}= l{} & 0x{X};\n",
                                .{ lhs, operator, operator, rhs, width - 1 },
                            );
                        }
                    },
                    .i32_shr_s, .i64_shr_s => {
                        if (unreachable_depth == 0) {
                            const rhs = try fg.stackPop();
                            const lhs = fg.stackAt(0);
                            const operator: u8 = switch (opcode) {
                                .i32_shr_s, .i64_shr_s => '>',
                                else => unreachable,
                            };
                            const width: u8 = switch (opcode) {
                                .i32_shr_s => 32,
                                .i64_shr_s => 64,
                                else => unreachable,
                            };
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "l{} = (uint{}_t)((int{}_t)l{} {c}{c} (l{} & 0x{X}));\n",
                                .{ lhs, width, width, lhs, operator, operator, rhs, width - 1 },
                            );
                        }
                    },
                    .i32_rotl, .i32_rotr, .i64_rotl, .i64_rotr => {
                        if (unreachable_depth == 0) {
                            const rhs = try fg.stackPop();
                            const lhs = fg.stackAt(0);
                            const forward_operator: u8 = switch (opcode) {
                                .i32_rotl, .i64_rotl => '<',
                                .i32_rotr, .i64_rotr => '>',
                                else => unreachable,
                            };
                            const reverse_operator: u8 = switch (opcode) {
                                .i32_rotl, .i64_rotl => '>',
                                .i32_rotr, .i64_rotr => '<',
                                else => unreachable,
                            };
                            const width: u8 = switch (opcode) {
                                .i32_rotl, .i32_rotr => 32,
                                .i64_rotl, .i64_rotr => 64,
                                else => unreachable,
                            };
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "l{} = l{} {c}{c} (l{} & 0x{X}) | l{} {c}{c} (-l{} & 0x{X});\n",
                                .{
                                    lhs,
                                    lhs,
                                    forward_operator,
                                    forward_operator,
                                    rhs,
                                    width - 1,
                                    lhs,
                                    reverse_operator,
                                    reverse_operator,
                                    rhs,
                                    width - 1,
                                },
                            );
                        }
                    },
                    .f32_min, .f32_max, .f32_copysign, .f64_min, .f64_max, .f64_copysign => {
                        if (unreachable_depth == 0) {
                            const rhs = try fg.stackPop();
                            const lhs = fg.stackAt(0);
                            const function = switch (opcode) {
                                .f32_min => "fminf",
                                .f32_max => "fmaxf",
                                .f32_copysign => "copysignf",
                                .f64_min => "fmin",
                                .f64_max => "fmax",
                                .f64_copysign => "copysign",
                                else => unreachable,
                            };
                            try fg.indent(writer_c);
                            try writer_c.print(
                                "l{} = {s}(l{}, l{});\n",
                                .{ lhs, function, lhs, rhs },
                            );
                        }
                    },
                    .memory_size => {
                        const mem_idx = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print("p{};\n", .{mem_idx});
                        }
                    },
                    .memory_grow => {
                        const mem_idx = try readLeb128(reader, u32);
                        if (unreachable_depth == 0) {
                            const pages = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print(
                                "memory_grow(&m{}, &p{}, &c{}, l{});\n",
                                .{ mem_idx, mem_idx, mem_idx, pages },
                            );
                        }
                    },
                    .prefixed => {
                        const prefixed_opcode = @intToEnum(WasmPrefixedOpCode, try readLeb128(reader, u32));
                        switch (prefixed_opcode) {
                            .i32_trunc_sat_f32_s,
                            .i32_trunc_sat_f32_u,
                            .i32_trunc_sat_f64_s,
                            .i32_trunc_sat_f64_u,
                            .i64_trunc_sat_f32_s,
                            .i64_trunc_sat_f32_u,
                            .i64_trunc_sat_f64_s,
                            .i64_trunc_sat_f64_u,
                            => {
                                if (unreachable_depth == 0)
                                    panic("unimplemented opcode: {}", .{prefixed_opcode});
                            },
                            .memory_init => {
                                _ = try readLeb128(reader, u32);
                                _ = try reader.readByte();
                                if (unreachable_depth == 0)
                                    panic("unimplemented opcode: {}", .{prefixed_opcode});
                            },
                            .data_drop => {
                                _ = try readLeb128(reader, u32);
                                if (unreachable_depth == 0)
                                    panic("unimplemented opcode: {}", .{prefixed_opcode});
                            },
                            .memory_copy => {
                                const dst_mem_idx = try readLeb128(reader, u32);
                                const src_mem_idx = try readLeb128(reader, u32);
                                if (unreachable_depth == 0) {
                                    const n = try fg.stackPop();
                                    const src = try fg.stackPop();
                                    const dst = try fg.stackPop();
                                    try fg.indent(writer_c);
                                    try writer_c.print(
                                        "memmove(&m{}[l{}], &m{}[l{}], l{});\n",
                                        .{ dst_mem_idx, dst, src_mem_idx, src, n },
                                    );
                                }
                            },
                            .memory_fill => {
                                const mem_idx = try readLeb128(reader, u32);
                                if (unreachable_depth == 0) {
                                    const n = try fg.stackPop();
                                    const c = try fg.stackPop();
                                    const s = try fg.stackPop();
                                    try fg.indent(writer_c);
                                    try writer_c.print(
                                        "memset(&m{}[l{}], l{}, l{});\n",
                                        .{ mem_idx, s, c, n },
                                    );
                                }
                            },
                            .table_init => {
                                _ = try readLeb128(reader, u32);
                                _ = try readLeb128(reader, u32);
                                if (unreachable_depth == 0)
                                    panic("unimplemented opcode: {}", .{prefixed_opcode});
                            },
                            .elem_drop => {
                                _ = try readLeb128(reader, u32);
                                if (unreachable_depth == 0)
                                    panic("unimplemented opcode: {}", .{prefixed_opcode});
                            },
                            .table_copy => {
                                _ = try readLeb128(reader, u32);
                                _ = try readLeb128(reader, u32);
                                if (unreachable_depth == 0)
                                    panic("unimplemented opcode: {}", .{prefixed_opcode});
                            },
                            .table_grow => {
                                _ = try readLeb128(reader, u32);
                                if (unreachable_depth == 0)
                                    panic("unimplemented opcode: {}", .{prefixed_opcode});
                            },
                            .table_size => {
                                _ = try readLeb128(reader, u32);
                                if (unreachable_depth == 0)
                                    panic("unimplemented opcode: {}", .{prefixed_opcode});
                            },
                            .table_fill => {
                                _ = try readLeb128(reader, u32);
                                if (unreachable_depth == 0)
                                    panic("unimplemented opcode: {}", .{prefixed_opcode});
                            },
                        }
                    },
                    .i32_extend8_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print("(int8_t)l{};\n", .{lhs});
                        }
                    },
                    .i32_extend16_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print("(int16_t)l{};\n", .{lhs});
                        }
                    },
                    .i64_extend8_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print("(int8_t)l{};\n", .{lhs});
                        }
                    },
                    .i64_extend16_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print("(int16_t)l{};\n", .{lhs});
                        }
                    },
                    .i64_extend32_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print("(int32_t)l{};\n", .{lhs});
                        }
                    },
                    .i32_wrap_i64 => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print("(uint32_t)l{};\n", .{lhs});
                        }
                    },
                    .i32_trunc_f32_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print("(int32_t)l{};\n", .{lhs});
                        }
                    },
                    .i32_trunc_f32_u => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print("(uint32_t)l{};\n", .{lhs});
                        }
                    },
                    .i32_trunc_f64_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print("(int32_t)l{};\n", .{lhs});
                        }
                    },
                    .i32_trunc_f64_u => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print("(uint32_t)l{};\n", .{lhs});
                        }
                    },
                    .i64_extend_i32_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print("(int32_t)l{};\n", .{lhs});
                        }
                    },
                    .i64_extend_i32_u => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print("(uint32_t)l{};\n", .{lhs});
                        }
                    },
                    .i64_trunc_f32_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print("(int64_t)l{};\n", .{lhs});
                        }
                    },
                    .i64_trunc_f32_u => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print("(uint64_t)l{};\n", .{lhs});
                        }
                    },
                    .i64_trunc_f64_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print("(int64_t)l{};\n", .{lhs});
                        }
                    },
                    .i64_trunc_f64_u => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print("(uint64_t)l{};\n", .{lhs});
                        }
                    },
                    .f32_convert_i32_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f32);
                            try writer_c.print("(int32_t)l{};\n", .{lhs});
                        }
                    },
                    .f32_convert_i32_u => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f32);
                            try writer_c.print("(uint32_t)l{};\n", .{lhs});
                        }
                    },
                    .f32_convert_i64_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f32);
                            try writer_c.print("(int64_t)l{};\n", .{lhs});
                        }
                    },
                    .f32_convert_i64_u => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f32);
                            try writer_c.print("(uint64_t)l{};\n", .{lhs});
                        }
                    },
                    .f32_demote_f64 => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f32);
                            try writer_c.print("(float)l{};\n", .{lhs});
                        }
                    },
                    .f64_convert_i32_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f64);
                            try writer_c.print("(int32_t)l{};\n", .{lhs});
                        }
                    },
                    .f64_convert_i32_u => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f64);
                            try writer_c.print("(uint32_t)l{};\n", .{lhs});
                        }
                    },
                    .f64_convert_i64_s => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f64);
                            try writer_c.print("(int64_t)l{};\n", .{lhs});
                        }
                    },
                    .f64_convert_i64_u => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f64);
                            try writer_c.print("(uint64_t)l{};\n", .{lhs});
                        }
                    },
                    .f64_promote_f32 => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f64);
                            try writer_c.print("(double)l{};\n", .{lhs});
                        }
                    },
                    .i32_reinterpret_f32 => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i32);
                            try writer_c.print("i32_reinterpret_f32(l{});\n", .{lhs});
                        }
                    },
                    .i64_reinterpret_f64 => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .i64);
                            try writer_c.print("i64_reinterpret_f64(l{});\n", .{lhs});
                        }
                    },
                    .f32_reinterpret_i32 => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f32);
                            try writer_c.print("f32_reinterpret_i32(l{});\n", .{lhs});
                        }
                    },
                    .f64_reinterpret_i64 => {
                        if (unreachable_depth == 0) {
                            const lhs = try fg.stackPop();
                            try fg.stackPush(writer_c, .f64);
                            try writer_c.print("f64_reinterpret_i64(l{});\n", .{lhs});
                        }
                    },

                    .i32_clz,
                    .i32_ctz,
                    .i32_popcnt,
                    .i64_clz,
                    .i64_ctz,
                    .i64_popcnt,
                    .f32_abs,
                    .f32_neg,
                    .f32_ceil,
                    .f32_floor,
                    .f32_trunc,
                    .f32_nearest,
                    .f32_sqrt,
                    .f64_abs,
                    .f64_neg,
                    .f64_ceil,
                    .f64_floor,
                    .f64_trunc,
                    .f64_nearest,
                    .f64_sqrt,
                    => {
                        if (unreachable_depth == 0) {
                            const lhs = fg.stackAt(0);
                            const function = switch (opcode) {
                                .i32_clz => "i32_clz",
                                .i32_ctz => "i32_ctz",
                                .i32_popcnt => "i32_popcnt",
                                .i64_clz => "i64_clz",
                                .i64_ctz => "i64_ctz",
                                .i64_popcnt => "i64_popcnt",
                                .f32_abs => "fabsf",
                                .f32_neg, .f64_neg => "-",
                                .f32_ceil => "ceilf",
                                .f32_floor => "floorf",
                                .f32_trunc => "truncf",
                                .f32_nearest => "roundf",
                                .f32_sqrt => "sqrtf",
                                .f64_abs => "fabs",
                                .f64_ceil => "ceil",
                                .f64_floor => "floor",
                                .f64_trunc => "trunc",
                                .f64_nearest => "round",
                                .f64_sqrt => "sqrt",
                                else => unreachable,
                            };
                            try fg.indent(writer_c);
                            try writer_c.print("l{} = {s}(l{});\n", .{ lhs, function, lhs });
                        }
                    },

                    else => panic("unsupported opcode => {}", .{opcode}),
                }
            }

            for (0..func_type.param.len) |param_i| {
                if (param_used[param_i]) continue;
                try fg.indent(writer_c);
                try writer_c.print("(void)l{};\n", .{param_i});
            }
            switch (func_type.result.len) {
                0 => {},
                1 => {
                    try fg.indent(writer_c);
                    try writer_c.print("return l{};\n", .{try fg.stackPop()});
                },
                else => panic("multiple function returns not supported", .{}),
            }
            try writer_c.writeAll("}\n\n");
        }
    }

    try writer_c.writeAll("static void init_data(void) {\n");
    for (0..mems.len) |i| {
        try writer_c.print(
            \\    p{} = UINT32_C({});
            \\    c{} = p{};
            \\    m{} = calloc(c{}, UINT32_C(1) << 16);
            \\
        , .{ i, mems[i].limits.min, i, i, i, i });
    }
    if (try skipToSection(reader_peek, reader, .data)) {
        const len = try readLeb128(reader, u32);
        for (0..len) |segment_i| {
            const data_kind = try readLeb128(reader, u32);
            const mem_idx = switch (data_kind) {
                0 => 0,
                2 => try readLeb128(reader, u32),
                else => panic("unsupported data kind: {}", .{data_kind}),
            };
            const offset = try evalExpr(reader);
            const segment_len = try readLeb128(reader, u32);
            try writer_c.writeAll("\n");
            try writer_c.print(
                "    static const uint8_t s{}[UINT32_C({})] = {{",
                .{ segment_i, segment_len },
            );
            for (0..segment_len) |i| {
                if (i % 32 == 0) try writer_c.writeAll("\n       ");
                try writer_c.print(" 0x{X:0>2},", .{try reader.readByte()});
            }
            try writer_c.print(
                \\
                \\    }};
                \\    memcpy(&m{}[UINT32_C(0x{X})], s{}, UINT32_C({}));
                \\
            , .{ mem_idx, offset, segment_i, segment_len });
        }
    }
    try writer_c.writeAll("}\n");
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 3) {
        panic("Expected 2 args, found {}", .{args.len - 1});
    }

    const reader_path = std.mem.sliceTo(args[1], 0);
    const writer_path = std.mem.sliceTo(args[2], 0);

    const reader_file = try std.fs.cwd().openFile(reader_path, .{ .mode = .read_only });
    defer reader_file.close();

    const writer_path_c = try std.fmt.allocPrint(allocator, "{s}.c", .{writer_path});
    defer allocator.free(writer_path_c);

    const writer_path_h = try std.fmt.allocPrint(allocator, "{s}.h", .{writer_path});
    defer allocator.free(writer_path_h);

    const writer_file_c = try std.fs.cwd().createFile(writer_path_c, .{ .truncate = true });
    defer writer_file_c.close();

    const writer_file_h = try std.fs.cwd().createFile(writer_path_h, .{ .truncate = true });
    defer writer_file_h.close();

    var buffered_reader = std.io.bufferedReader(reader_file.reader());
    var buffered_reader_peek = std.io.peekStream(1, buffered_reader.reader());
    var buffered_writer_c = std.io.bufferedWriter(writer_file_c.writer());
    var buffered_writer_h = std.io.bufferedWriter(writer_file_h.writer());

    try run(allocator, &buffered_reader_peek, buffered_reader_peek.reader(), buffered_writer_c.writer(), buffered_writer_h.writer());

    try buffered_writer_c.flush();
    try buffered_writer_h.flush();

    std.debug.print("Ok!", .{});
}

test {
    std.testing.refAllDecls(@This());
}
