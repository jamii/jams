const std = @import("std");
const assert = std.debug.assert;

const c = @cImport({
    @cInclude("binaryen-c.h");
});

usingnamespace c;

pub fn main() !void {
    const runtime_file = try std.fs.cwd().openFile("runtime.wasm", .{});
    defer runtime_file.close();

    const runtime_bytes = runtime_file.reader().readAllAlloc(std.heap.c_allocator, std.math.maxInt(usize)) catch unreachable;

    const module = c.BinaryenModuleRead(@ptrCast([*c]u8, runtime_bytes), runtime_bytes.len);
    defer c.BinaryenModuleDispose(module);

    // Don't export runtime functions.
    {
        c.BinaryenRemoveExport(module, "add");
    }

    // Define add_inc = fn [x, y] add(x + y)
    {
        var ii = [_]c.BinaryenType{ c.BinaryenTypeInt32(), c.BinaryenTypeInt32() };
        const params = c.BinaryenTypeCreate(&ii, ii.len);
        const results = c.BinaryenTypeInt32();

        const x = c.BinaryenLocalGet(module, 0, c.BinaryenTypeInt32());
        const y = c.BinaryenLocalGet(module, 1, c.BinaryenTypeInt32());
        const add = c.BinaryenBinary(module, c.BinaryenAddInt32(), x, y);
        var operands = [_]c.BinaryenExpressionRef{add};
        const inc = c.BinaryenCall(module, "add", &operands, operands.len, c.BinaryenTypeInt32());

        _ = c.BinaryenAddFunction(module, "add_inc", params, results, null, 0, inc);
    }

    // Export add_inc.
    {
        _ = c.BinaryenAddFunctionExport(module, "add_inc", "add_inc");
    }

    assert(c.BinaryenModuleValidate(module));

    c.BinaryenModulePrint(module);

    const result = c.BinaryenModuleAllocateAndWrite(module, null);
    defer std.c.free(result.binary);

    const file = try std.fs.cwd().createFile("hello.wasm", .{ .truncate = true });
    defer file.close();

    const bytes = @ptrCast([*c]u8, result.binary)[0..result.binaryBytes];
    try file.writeAll(bytes);
}
