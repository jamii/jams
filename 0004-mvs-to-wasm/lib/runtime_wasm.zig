const std = @import("std");
const panic = std.debug.panic;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const runtime = @import("./runtime.zig");
const Value = runtime.Value;
const Map = runtime.Map;
const Fn = runtime.Fn;

// TODO Need to reserve space for both stacks.
const global_allocator = std.heap.wasm_allocator;

fn oom() noreturn {
    panic("OOM", .{});
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

export fn move(ptr_a: *Value, ptr_b: *const Value) void {
    ptr_a.* = ptr_b.*;
}

export fn copy(ptr_a: *Value, ptr_b: *const Value) void {
    ptr_a.* = ptr_b.copy(global_allocator);
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
