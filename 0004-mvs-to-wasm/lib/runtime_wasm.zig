const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const runtime = @import("./runtime.zig");
const Value = runtime.Value;
const Map = runtime.Map;
const Fn = runtime.Fn;

const global_allocator = std.heap.wasm_allocator;

fn oom() noreturn {
    std.debug.panic("OOM", .{});
}

export fn start(pages: usize) void {
    assert(@wasmMemoryGrow(0, pages - @wasmMemorySize(0)) >= 0);
}

export fn createNumber(ptr: *Value, number: f64) void {
    ptr.* = .{ .number = number };
}

export fn createString(ptr: *Value, string_ptr: [*]const u8, string_len: usize) void {
    ptr.* = .{ .string = global_allocator.dupe(u8, string_ptr[0..string_len]) catch oom() };
}

export fn createMap(ptr: *Value) void {
    ptr.* = .{ .map = Map.init(global_allocator) };
}

export fn createFn(ptr: *Value, fn_ix: u32, mut_count: u32, capture_count: u32) void {
    ptr.* = .{ .@"fn" = .{
        .ix = fn_ix,
        .muts = global_allocator.alloc(bool, mut_count) catch oom(),
        .captures = global_allocator.alloc(Value, capture_count) catch oom(),
    } };
}

export fn boolGet(ptr: *Value) u32 {
    if (ptr.* == .number) {
        const number = ptr.*.number;
        if (number == 0)
            return 0
        else if (number == 1)
            return 1;
    }
    std.debug.panic("Expected boolean (0 or 1). Found {}", .{ptr.*});
}

export fn fnGetIx(ptr: *Value) u32 {
    return ptr.*.@"fn".ix;
}

export fn fnAssertMutCount(ptr: *Value, mut_count_found: u32) void {
    const mut_count_expected = ptr.*.@"fn".muts.len;
    if (mut_count_expected != mut_count_found)
        std.debug.panic("Expected {} args, found {} args", .{
            mut_count_expected,
            mut_count_found,
        });
}

export fn fnAssertMut(ptr: *Value, mut_ix: u32, mut: u32) void {
    const mut_expected = ptr.*.@"fn".muts[mut_ix];
    const mut_found = switch (mut) {
        0 => false,
        1 => true,
        else => unreachable,
    };
    if (mut_expected != mut_found)
        std.debug.panic("Expected {s} arg, found {s} arg", .{
            if (mut_expected) "mut" else "const",
            if (mut_found) "mut" else "const",
        });
}

export fn fnSetMut(ptr: *Value, mut_ix: u32, mut: u32) void {
    ptr.*.@"fn".muts[mut_ix] = switch (mut) {
        0 => false,
        1 => true,
        else => unreachable,
    };
}

export fn fnGetCapture(ptr: *Value, capture_ix: u32) *Value {
    return &ptr.*.@"fn".captures[capture_ix];
}

export fn mapSet(map: *Value, key: *Value, value: *Value) void {
    map.*.map.put(key.*, value.*) catch oom();
}

export fn mapGet(map: *Value, key: *Value) *Value {
    const result = map.*.map.getOrPut(key.*) catch oom();
    // Ensure compiled code can't see uninitialized memory.
    if (!result.found_existing) result.value_ptr.* = .{ .number = 0 };
    return result.value_ptr;
}

export fn move(ptr_a: *Value, ptr_b: *const Value) void {
    ptr_a.* = ptr_b.*;
}

export fn copy(ptr_a: *Value, ptr_b: *const Value) void {
    ptr_a.* = ptr_b.copy(global_allocator);
}

export fn copyInPlace(ptr_a: *Value) void {
    ptr_a.copyInPlace(global_allocator);
}

extern fn print_string(ptr: [*]const u8, len: usize) void;
export fn print(ptr: *Value) void {
    const string = std.fmt.allocPrint(global_allocator, "{}", .{ptr.*}) catch oom();
    defer global_allocator.free(string);

    print_string(string.ptr, string.len);
}

export fn set_byte(ptr: *u8, byte: u8) void {
    ptr.* = byte;
}

export fn equal(result: *Value, a: *Value, b: *Value) void {
    result.* = Value.fromBool(Value.equal(a.*, b.*));
}

export fn less_than(result: *Value, a: *Value, b: *Value) void {
    _ = result;
    _ = a;
    _ = b;
    std.debug.panic("Unimplemented", .{});
}

export fn less_than_or_equal(result: *Value, a: *Value, b: *Value) void {
    _ = result;
    _ = a;
    _ = b;
    std.debug.panic("Unimplemented", .{});
}

export fn more_than(result: *Value, a: *Value, b: *Value) void {
    _ = result;
    _ = a;
    _ = b;
    std.debug.panic("Unimplemented", .{});
}

export fn more_than_or_equal(result: *Value, a: *Value, b: *Value) void {
    _ = result;
    _ = a;
    _ = b;
    std.debug.panic("Unimplemented", .{});
}

export fn add(result: *Value, a: *Value, b: *Value) void {
    result.* = .{ .number = a.*.number + b.*.number };
}

export fn subtract(result: *Value, a: *Value, b: *Value) void {
    result.* = .{ .number = a.*.number - b.*.number };
}

export fn multiply(result: *Value, a: *Value, b: *Value) void {
    result.* = .{ .number = a.*.number * b.*.number };
}

export fn divide(result: *Value, a: *Value, b: *Value) void {
    result.* = .{ .number = a.*.number / b.*.number };
}

pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    @setCold(true);
    print_string(msg.ptr, msg.len);
    std.builtin.default_panic(msg, error_return_trace, ret_addr);
}
comptime {
    assert(@hasDecl(@import("root"), "panic"));
}
