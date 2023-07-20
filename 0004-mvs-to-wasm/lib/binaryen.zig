const std = @import("std");
const assert = std.debug.assert;

const c = @cImport({
    @cInclude("binaryen-c.h");
});

usingnamespace c;

pub fn main() !void {
    const module = c.BinaryenModuleCreate();
    defer c.BinaryenModuleDispose(module);

    // Import inc = runtime.add
    {
        var i = [_]c.BinaryenType{c.BinaryenTypeInt32()};
        const params = c.BinaryenTypeCreate(&i, i.len);
        c.BinaryenAddFunctionImport(module, "inc", "runtime", "add", params, c.BinaryenTypeInt32());
    }

    // Define add_inc = fn [x, y] inc(x + y)
    {
        var ii = [_]c.BinaryenType{ c.BinaryenTypeInt32(), c.BinaryenTypeInt32() };
        const params = c.BinaryenTypeCreate(&ii, ii.len);
        const results = c.BinaryenTypeInt32();

        const x = c.BinaryenLocalGet(module, 0, c.BinaryenTypeInt32());
        const y = c.BinaryenLocalGet(module, 1, c.BinaryenTypeInt32());
        const add = c.BinaryenBinary(module, c.BinaryenAddInt32(), x, y);
        var operands = [_]c.BinaryenExpressionRef{add};
        const inc = c.BinaryenCall(module, "inc", &operands, operands.len, c.BinaryenTypeInt32());

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
