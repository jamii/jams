const std = @import("std");
const assert = std.debug.assert;

const c = @cImport({
    @cInclude("binaryen-c.h");
});

usingnamespace c;

pub fn main() !void {
    const module = c.BinaryenModuleCreate();
    defer c.BinaryenModuleDispose(module);

    // Create a function type for  i32 (i32, i32)
    var ii = [_:0]c.BinaryenType{ c.BinaryenTypeInt32(), c.BinaryenTypeInt32() };
    const params = c.BinaryenTypeCreate(&ii, 2);
    const results = c.BinaryenTypeInt32();

    const x = c.BinaryenLocalGet(module, 0, c.BinaryenTypeInt32());
    const y = c.BinaryenLocalGet(module, 1, c.BinaryenTypeInt32());
    const add = c.BinaryenBinary(module, c.BinaryenAddInt32(), x, y);

    const adder = c.BinaryenAddFunction(module, "adder", params, results, null, 0, add);
    _ = adder;

    assert(c.BinaryenModuleValidate(module));

    c.BinaryenModulePrint(module);

    const result = c.BinaryenModuleAllocateAndWrite(module, null);
    defer std.c.free(result.binary);

    const file = try std.fs.cwd().createFile("hello.wasm", .{ .truncate = true });
    defer file.close();

    const bytes = @ptrCast([*c]u8, result.binary)[0..result.binaryBytes];
    try file.writeAll(bytes);
}
