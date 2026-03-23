const std = @import("std");

const lib = @import("./lib.zig");

export fn alloc(len: usize) usize {
    return @intFromPtr((lib.allocator.allocSentinel(u8, len, 0) catch lib.oom()).ptr);
}

export fn free(ptr: usize) void {
    lib.allocator.free(std.mem.span(@as([*c]u8, @ptrFromInt(ptr))));
}

export fn run(source_ptr: usize) usize {
    const source = std.mem.span(@as([*c]u8, @ptrFromInt(source_ptr)));

    lib.c = .init(source);
    defer lib.c.deinit();

    const result = lib.run() catch (lib.allocator.dupeZ(u8, lib.c.error_message.?) catch lib.oom());
    return @intFromPtr(result.ptr);
}
