const std = @import("std");
const panic = std.debug.panic;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Parser = @import("./Parser.zig");
const ExprId = Parser.ExprId;
const Expr = Parser.Expr;

const runtime = @import("./runtime.zig");
const Kind = runtime.Kind;

const c = @cImport({
    @cInclude("binaryen-c.h");
});

const Self = @This();
allocator: Allocator,
parser: Parser,
module: ?c.BinaryenModuleRef,
strings: ArrayList(u8),
fns: std.AutoHashMap(ExprId, c.BinaryenFunctionRef),
error_message: ?[]const u8,

// Memory layout:
// 0:1048576 = zig stack
// 1048576:? = zig data
// ?:(2*1048576) = mvs stack
// (2 * 1048576):? = mvs data
const data_start = 2 * 1048576;

pub const Scope = struct {
    wasm_var_next: usize,
    stack_offset_next: u32,
    stack_offset_max: u32,
    bindings: ArrayList(Binding),
};
pub const Binding = struct {
    mut: bool,
    name: []const u8,
    wasm_var: ?usize,
};

pub fn init(allocator: Allocator, parser: Parser) Self {
    return .{
        .allocator = allocator,
        .parser = parser,
        .module = null,
        .strings = ArrayList(u8).init(allocator),
        .fns = std.AutoHashMap(ExprId, c.BinaryenFunctionRef).init(allocator),
        .error_message = null,
    };
}

pub fn compile(self: *Self) error{CompileError}![]const u8 {
    // TODO Once stable, use:
    //const runtime_bytes = @embedFile("../runtime.wasm");

    //const runtime_file = std.fs.cwd().openFile("runtime.wasm", .{}) catch |err|
    //    panic("Error opening runtime.wasm: {}", .{err});
    //defer runtime_file.close();

    //const runtime_bytes = runtime_file.reader().readAllAlloc(self.allocator, std.math.maxInt(usize)) catch |err|
    //    panic("Error reading runtime.wasm: {}", .{err});
    //defer self.allocator.free(runtime_bytes);

    //self.module = c.BinaryenModuleRead(@as([*c]u8, @ptrCast(runtime_bytes)), runtime_bytes.len);

    self.module = c.BinaryenModuleCreate();
    defer {
        c.BinaryenModuleDispose(self.module.?);
        self.module = null;
    }

    c.BinaryenModuleSetFeatures(
        self.module.?,
        c.BinaryenFeatureBulkMemory(),
    );

    // Import runtime functions.
    {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "runtime_start",
            "runtime",
            "start",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeNone(),
        );
    }
    {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
            c.BinaryenTypeFloat64(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "createNumber",
            "runtime",
            "createNumber",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeNone(),
        );
    }
    {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
            c.BinaryenTypeInt32(),
            c.BinaryenTypeInt32(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "createString",
            "runtime",
            "createString",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeNone(),
        );
    }
    {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "createMap",
            "runtime",
            "createMap",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeNone(),
        );
    }
    {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
            c.BinaryenTypeInt32(),
            c.BinaryenTypeInt32(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "mapSet",
            "runtime",
            "mapSet",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeNone(),
        );
    }
    {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
            c.BinaryenTypeInt32(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "copy",
            "runtime",
            "copy",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeNone(),
        );
    }
    {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "print",
            "runtime",
            "print",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeNone(),
        );
    }
    {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
            c.BinaryenTypeInt32(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "set_byte",
            "runtime",
            "set_byte",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeNone(),
        );
    }

    // We have to strip debug info from the runtime because binaryen crashes on unrecognized dwarf.
    // But that removes the name of the '__stack_pointer' variable, and binaryen can only reference globals by name.
    // Binaryen also doesn't provide an api to set the name of a global.
    // So we have to make our own separate shadow stack :(
    _ = c.BinaryenAddGlobal(self.module.?, "__yet_another_stack_pointer", c.BinaryenTypeInt32(), true, c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(data_start)));

    _ = try self.compileMain(self.parser.exprs.items.len - 1);
    _ = c.BinaryenAddFunctionExport(self.module.?, "main", "main");

    // Start function.
    {
        const block = self.allocator.alloc(c.BinaryenExpressionRef, self.strings.items.len + 1) catch oom();
        defer self.allocator.free(block);

        // We have to grow memory to support that second stack, by calling `runtime.start`.
        block[0] = self.runtimeCall(
            "runtime_start",
            &.{
                c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(
                    std.math.divCeil(
                        usize,
                        data_start + self.strings.items.len,
                        16 * 1024,
                    ) catch unreachable,
                ))))),
            },
        );

        // Binaryen doesn't expose any way to create a passive data segment without also creating a memory.
        // So we'll init string data in the grossest fashion.
        for (block[1..], self.strings.items, 0..) |*expr, char, i| {
            // Without being able to define or import a memory, we can't use `store`!
            // Instead, we're stuck with this hack.
            expr.* = self.runtimeCall(
                "set_byte",
                &.{
                    c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(data_start + i))))),
                    c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(char)),
                },
            );
        }

        c.BinaryenSetStart(
            self.module.?,
            c.BinaryenAddFunction(
                self.module.?,
                "start",
                c.BinaryenTypeNone(),
                c.BinaryenTypeNone(),
                null,
                0,
                c.BinaryenBlock(self.module.?, null, block.ptr, @intCast(block.len), c.BinaryenTypeNone()),
            ),
        );
    }

    if (!c.BinaryenModuleValidate(self.module.?))
        return self.fail("Produced an invalid wasm module", .{});

    const result = c.BinaryenModuleAllocateAndWrite(self.module.?, null);
    defer std.c.free(result.binary);

    const result_bytes = @as([*c]u8, @ptrCast(result.binary))[0..result.binaryBytes];
    return self.allocator.dupe(u8, result_bytes) catch oom();
}

fn compileMain(self: *Self, body: ExprId) error{CompileError}!c.BinaryenFunctionRef {
    var scope = Scope{
        .wasm_var_next = 0,
        .stack_offset_next = 0,
        .stack_offset_max = 0,
        .bindings = ArrayList(Binding).init(self.allocator),
    };
    defer scope.bindings.deinit();

    const shadow_offset = shadowPush(&scope);
    const result_location = self.shadowPtr(shadow_offset);
    const body_inner_ref = try self.compileExpr(&scope, result_location, body);
    shadowPop(&scope, shadow_offset);

    var block = [_]c.BinaryenExpressionRef{
        self.framePush(scope.stack_offset_max),
        body_inner_ref,
        self.runtimeCall("print", &.{result_location}),
        self.framePop(scope.stack_offset_max),
    };
    const body_ref = c.BinaryenBlock(self.module.?, null, &block, @intCast(block.len), c.BinaryenTypeNone());

    const wasm_params = c.BinaryenTypeCreate(null, 0);
    const wasm_results = c.BinaryenTypeCreate(null, 0);

    const wasm_vars_types = self.allocator.alloc(
        c.BinaryenType,
        // Count any variables needed.
        scope.wasm_var_next,
    ) catch oom();
    defer self.allocator.free(wasm_vars_types);

    for (wasm_vars_types) |*wasm_var_type| wasm_var_type.* = c.BinaryenTypeInt32();

    // TODO Need to mangle names for closures?
    const fn_ref = c.BinaryenAddFunction(
        self.module.?,
        // TODO Mangle main?
        "main",
        wasm_params,
        wasm_results,
        wasm_vars_types.ptr,
        @intCast(wasm_vars_types.len),
        body_ref,
    );

    return fn_ref;
}

fn compileFn(self: *Self, name: [:0]const u8, params: []const Binding, body: ExprId) error{CompileError}!c.BinaryenFunctionRef {
    if (self.fns.get(body)) |fn_ref| return fn_ref;

    // TODO How to retrieve closure environment?
    var scope = Scope{
        .wasm_var_next = 1, // Reserve param 0 for result_location.
        .stack_offset = 0,
        .stack_offset_max = 0,
        .bindings = ArrayList(Binding).initCapacity(self.allocator, params.len) catch oom(),
    };
    defer scope.bindings.deinit();

    for (params) |param| {
        bindingPush(&scope, param.mut, param.name);
    }
    scope.stack_offset = 0;
    scope.stack_offset_max = 0;

    const result_location = c.BinaryenLocalGet(self.module.?, 0, c.BinaryenTypeInt32());
    const body_inner_ref = try self.compileExpr(&scope, result_location, body);

    var block = [_]c.BinaryenExpressionRef{
        self.framePush(scope.stack_offset_max),
        body_inner_ref,
        self.framePop(scope.stack_offset_max),
    };
    const body_ref = c.BinaryenBlock(self.module.?, null, &block, @intCast(block.len), c.BinaryenTypeNone());

    const wasm_params_types = self.allocator.alloc(
        c.BinaryenType,
        // Reserve param 0 for result_location.
        params.len + 1,
    ) catch oom();
    defer self.allocator.free(wasm_params_types);

    for (wasm_params_types) |*wasm_param| wasm_param.* = c.BinaryenTypeInt32();
    const wasm_params = c.BinaryenTypeCreate(wasm_params_types.ptr, @intCast(wasm_params_types.len));

    const wasm_results = c.BinaryenTypeCreate(null, 0);

    const wasm_vars_types = self.allocator.alloc(
        c.BinaryenType,
        // Count any variables needed beyond params and result_location.
        scope.wasm_var_next - 1 - params.len,
    ) catch oom();
    defer self.allocator.free(wasm_vars_types);

    for (wasm_vars_types) |*wasm_var_type| wasm_var_type.* = c.BinaryenTypeInt32();

    // TODO Need to mangle names for closures?
    const fn_ref = c.BinaryenAddFunction(
        self.module.?,
        name,
        wasm_params,
        wasm_results,
        wasm_vars_types.ptr,
        @intCast(wasm_vars_types.len),
        body_ref,
    );

    self.fns.put(body, fn_ref) catch oom();
    return fn_ref;
}

fn compileExpr(self: *Self, scope: *Scope, result_location: c.BinaryenExpressionRef, expr_id: ExprId) error{CompileError}!c.BinaryenExpressionRef {
    const expr = self.parser.exprs.items[expr_id];
    switch (expr) {
        .number => |number| {
            return self.createNumber(result_location, number);
        },
        .string => |string| {
            return self.createString(result_location, string);
        },
        .map => |map| {
            const block = self.allocator.alloc(c.BinaryenExpressionRef, map.keys.len + 1) catch oom();
            block[0] = self.createMap(result_location);
            for (block[1..], map.keys, map.values) |*set_expr, key_expr_id, value_expr_id| {
                const key_offset = shadowPush(scope);
                const value_offset = shadowPush(scope);
                const key_location = self.shadowPtr(key_offset);
                const value_location = self.shadowPtr(value_offset);
                var set_block = [_]c.BinaryenExpressionRef{
                    try self.compileExpr(scope, self.shadowPtr(key_offset), key_expr_id),
                    try self.compileExpr(scope, self.shadowPtr(value_offset), value_expr_id),
                    self.mapSet(result_location, key_location, value_location),
                };
                set_expr.* = c.BinaryenBlock(self.module.?, null, &set_block, @intCast(set_block.len), c.BinaryenTypeNone());
                shadowPop(scope, value_offset);
                shadowPop(scope, key_offset);
            }
            return c.BinaryenBlock(self.module.?, null, block.ptr, @intCast(block.len), c.BinaryenTypeNone());
        },
        .exprs => |child_expr_ids| {
            if (child_expr_ids.len == 0) {
                // Empty block returns falsey.
                return self.createNumber(result_location, 0);
            } else {
                const block = self.allocator.alloc(c.BinaryenExpressionRef, child_expr_ids.len) catch oom();
                for (block, child_expr_ids, 0..) |*expr_ref, child_expr_id, child_ix| {
                    if (child_ix < child_expr_ids.len - 1) {
                        const shadow_offset = shadowPush(scope);
                        expr_ref.* = try self.compileExpr(scope, self.shadowPtr(shadow_offset), child_expr_id);
                        shadowPop(scope, shadow_offset);
                    } else {
                        expr_ref.* = try self.compileExpr(scope, result_location, child_expr_id);
                    }
                }
                return c.BinaryenBlock(self.module.?, null, block.ptr, @intCast(block.len), c.BinaryenTypeNone());
            }
        },
        else => return self.fail("Unsupported expr: {}", .{expr}),
    }
}

fn createNumber(self: *Self, result_location: c.BinaryenExpressionRef, number: f64) c.BinaryenExpressionRef {
    return self.runtimeCall(
        "createNumber",
        &.{
            result_location,
            c.BinaryenConst(self.module.?, c.BinaryenLiteralFloat64(number)),
        },
    );
}

fn createString(self: *Self, result_location: c.BinaryenExpressionRef, string: []const u8) c.BinaryenExpressionRef {
    const ptr = data_start + self.strings.items.len;
    self.strings.appendSlice(string) catch oom();
    return self.runtimeCall(
        "createString",
        &.{
            result_location,
            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(ptr))))),
            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(string.len))))),
        },
    );
}

fn createMap(self: *Self, result_location: c.BinaryenExpressionRef) c.BinaryenExpressionRef {
    return self.runtimeCall(
        "createMap",
        &.{
            result_location,
        },
    );
}

fn mapSet(self: *Self, map_location: c.BinaryenExpressionRef, key_location: c.BinaryenExpressionRef, value_location: c.BinaryenExpressionRef) c.BinaryenExpressionRef {
    return self.runtimeCall(
        "mapSet",
        &.{
            map_location,
            key_location,
            value_location,
        },
    );
}

fn bindingPush(scope: *Scope, mut: bool, name: []const u8) void {
    const wasm_var = scope.wasm_var_next;
    scope.wasm_var_next += 1;

    const shadow_offset = shadowPush(scope);

    scope.bindings.append(.{
        .mut = mut,
        .name = name,
        .wasm_var = wasm_var,
        .shadow_offset = shadow_offset,
    }) catch oom();
}

fn bindingPop(scope: *Scope, mut: bool, name: []const u8) void {
    const binding = scope.bindings.pop();
    assert(binding.mut == mut);
    assert(std.mem.eql(u8, binding.name, name));
    shadowPop(scope, binding.offset);
}

fn shadowPush(scope: *Scope) u32 {
    const stack_offset = scope.stack_offset_next;
    scope.stack_offset_next += 1;
    scope.stack_offset_max = @max(scope.stack_offset_max, scope.stack_offset_next);
    return stack_offset;
}

fn shadowPop(scope: *Scope, offset: u32) void {
    scope.stack_offset_next -= 1;
    assert(scope.stack_offset_next == offset);
}

fn framePush(self: *Self, offset: u32) c.BinaryenExpressionRef {
    return c.BinaryenGlobalSet(
        self.module.?,
        "__yet_another_stack_pointer",
        c.BinaryenBinary(
            self.module.?,
            c.BinaryenSubInt32(),
            c.BinaryenGlobalGet(self.module.?, "__yet_another_stack_pointer", c.BinaryenTypeInt32()),
            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(offset * runtime.Value.wasmSizeOf))),
        ),
    );
}

fn framePop(self: *Self, offset: u32) c.BinaryenExpressionRef {
    return c.BinaryenGlobalSet(
        self.module.?,
        "__yet_another_stack_pointer",
        c.BinaryenBinary(
            self.module.?,
            c.BinaryenAddInt32(),
            c.BinaryenGlobalGet(self.module.?, "__yet_another_stack_pointer", c.BinaryenTypeInt32()),
            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(offset * runtime.Value.wasmSizeOf))),
        ),
    );
}

fn shadowPtr(self: *Self, offset: u32) c.BinaryenExpressionRef {
    // TODO How to trap before hitting the runtime's constant data?
    return c.BinaryenBinary(
        self.module.?,
        c.BinaryenAddInt32(),
        c.BinaryenGlobalGet(self.module.?, "__yet_another_stack_pointer", c.BinaryenTypeInt32()),
        c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(offset * runtime.Value.wasmSizeOf))),
    );
}

fn runtimeCall(self: *Self, fn_name: [*c]const u8, args: []const c.BinaryenExpressionRef) c.BinaryenExpressionRef {
    return c.BinaryenCall(
        self.module.?,
        fn_name,
        @constCast(args.ptr),
        @intCast(args.len),
        c.BinaryenTypeNone(),
    );
}

fn fail(self: *Self, comptime message: []const u8, args: anytype) error{CompileError} {
    self.error_message = std.fmt.allocPrint(self.allocator, message, args) catch oom();
    return error.CompileError;
}

fn oom() noreturn {
    panic("OOM", .{});
}
