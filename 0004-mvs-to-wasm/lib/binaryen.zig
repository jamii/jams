const c = @cImport({
    @cInclude("binaryen-c.h");
});

usingnamespace c;

pub fn main() void {
    const module = c.BinaryenModuleCreate();

    // Create a function type for  i32 (i32, i32)
    var ii = [_:0]c.BinaryenType{ c.BinaryenTypeInt32(), c.BinaryenTypeInt32() };
    const params = c.BinaryenTypeCreate(&ii, 2);
    const results = c.BinaryenTypeInt32();

    // Get the 0 and 1 arguments, and add them
    const x = c.BinaryenLocalGet(module, 0, c.BinaryenTypeInt32());
    const y = c.BinaryenLocalGet(module, 1, c.BinaryenTypeInt32());
    const add = c.BinaryenBinary(module, c.BinaryenAddInt32(), x, y);

    // Create the add function
    // Note: no additional local variables
    // Note: no basic blocks here, we are an AST. The function body is just an
    // expression node.
    const adder = c.BinaryenAddFunction(module, "adder", params, results, null, 0, add);
    _ = adder;

    // Print it out
    c.BinaryenModulePrint(module);

    // Clean up the module, which owns all the objects we created above
    c.BinaryenModuleDispose(module);
}
