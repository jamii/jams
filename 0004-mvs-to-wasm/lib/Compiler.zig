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
fns: ArrayList([:0]const u8),
error_message: ?[]const u8,

// Memory layout:
// 0:1048576 = zig stack
// 1048576:? = zig data
// ?:(2*1048576) = mvs stack
// (2 * 1048576):? = mvs data
const data_start = 2 * 1048576;

pub const Scope = struct {
    shadow_offset_next: u32,
    shadow_offset_max: u32,
    bindings: ArrayList(Binding),
};
pub const Binding = struct {
    mut: bool,
    name: []const u8,
    kind: union(enum) {
        wasm_var: u32,
        shadow_offset: u32,
        capture: u32,
    },
    visible: bool,
};

pub fn init(allocator: Allocator, parser: Parser) Self {
    return .{
        .allocator = allocator,
        .parser = parser,
        .module = null,
        .strings = ArrayList(u8).init(allocator),
        .fns = ArrayList([:0]const u8).init(allocator),
        .error_message = null,
    };
}

pub fn compile(self: *Self) error{CompileError}![]const u8 {
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
            c.BinaryenTypeInt32(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "createFn",
            "runtime",
            "createFn",
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
            "boolGet",
            "runtime",
            "boolGet",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeInt32(),
        );
    }
    {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
            c.BinaryenTypeInt32(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "fnAssertMutCount",
            "runtime",
            "fnAssertMutCount",
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
            "fnAssertMut",
            "runtime",
            "fnAssertMut",
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
            "fnSetMut",
            "runtime",
            "fnSetMut",
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
            "fnGetCapture",
            "runtime",
            "fnGetCapture",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeInt32(),
        );
    }
    {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "fnGetIx",
            "runtime",
            "fnGetIx",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeInt32(),
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
            "mapGet",
            "runtime",
            "mapGet",
            c.BinaryenTypeCreate(&params, params.len),
            c.BinaryenTypeInt32(),
        );
    }
    {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
            c.BinaryenTypeInt32(),
        };
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            "move",
            "runtime",
            "move",
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
            "copyInPlace",
            "runtime",
            "copyInPlace",
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
    inline for (@typeInfo(Parser.Builtin).Enum.fields) |field_info| {
        var params = [_]c.BinaryenType{
            c.BinaryenTypeInt32(),
            c.BinaryenTypeInt32(),
            c.BinaryenTypeInt32(),
        };
        const name = self.allocator.dupeZ(u8, field_info.name) catch oom();
        _ = c.BinaryenAddFunctionImport(
            self.module.?,
            name,
            "runtime",
            name,
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
        block[0] = self.runtimeCall0(
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
            expr.* = self.runtimeCall0(
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

    // Fn table.
    {
        _ = c.BinaryenAddTable(
            self.module.?,
            "fns",
            @intCast(self.fns.items.len),
            @intCast(self.fns.items.len),
            c.BinaryenTypeFuncref(),
        );
        const fn_names = self.allocator.alloc([*c]const u8, self.fns.items.len) catch oom();
        for (fn_names, self.fns.items) |*fn_name_c, fn_name| fn_name_c.* = fn_name.ptr;
        _ = c.BinaryenAddActiveElementSegment(
            self.module.?,
            "fns",
            "fns_init",
            fn_names.ptr,
            @intCast(fn_names.len),
            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(0)),
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
        .shadow_offset_next = 0,
        .shadow_offset_max = 0,
        .bindings = ArrayList(Binding).init(self.allocator),
    };
    defer scope.bindings.deinit();

    const shadow_offset = shadowPush(&scope);
    const result_location = self.shadowPtr(shadow_offset);
    const body_inner_ref = try self.compileExpr(&scope, result_location, body);
    shadowPop(&scope, shadow_offset);

    var block = [_]c.BinaryenExpressionRef{
        self.framePush(scope.shadow_offset_max),
        body_inner_ref,
        self.runtimeCall0("print", &.{result_location}),
        self.framePop(scope.shadow_offset_max),
    };
    const body_ref = c.BinaryenBlock(self.module.?, null, &block, @intCast(block.len), c.BinaryenTypeNone());

    const fn_ref = c.BinaryenAddFunction(
        self.module.?,
        "main",
        c.BinaryenTypeNone(),
        c.BinaryenTypeNone(),
        null,
        0,
        body_ref,
    );

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
        .name => {
            return self.move(
                result_location,
                try self.compilePath(scope, expr_id, false),
            );
        },
        .let => |let| {
            const binding = try self.bindingFind(scope, let.name, false);
            const let_location = self.shadowPtr(binding.kind.shadow_offset);
            var block = [_]c.BinaryenExpressionRef{
                try self.compileExpr(scope, let_location, let.value),
                self.runtimeCall0("copyInPlace", &.{let_location}),
            };
            binding.visible = true;
            return c.BinaryenBlock(self.module.?, null, &block, @intCast(block.len), c.BinaryenTypeNone());
        },
        .set => |set| {
            const shadow_offset = shadowPush(scope);
            const value_location = self.shadowPtr(shadow_offset);
            const value = try self.compileExpr(scope, value_location, set.value);
            const path = try self.compilePath(scope, set.path, true);
            shadowPop(scope, shadow_offset);
            var block = [_]c.BinaryenExpressionRef{
                value,
                // TODO Drop previous value.
                self.copy(
                    path,
                    value_location,
                ),
            };
            return c.BinaryenBlock(self.module.?, null, &block, @intCast(block.len), c.BinaryenTypeNone());
        },
        .@"if" => |@"if"| {
            const shadow_offset = shadowPush(scope);
            const cond_location = self.shadowPtr(shadow_offset);
            var block = [_]c.BinaryenExpressionRef{
                try self.compileExpr(scope, cond_location, @"if".cond),
                c.BinaryenIf(
                    self.module.?,
                    self.boolGet(cond_location),
                    try self.compileExpr(scope, result_location, @"if".if_true),
                    try self.compileExpr(scope, result_location, @"if".if_false),
                ),
            };
            shadowPop(scope, shadow_offset);
            return c.BinaryenBlock(self.module.?, null, &block, @intCast(block.len), c.BinaryenTypeNone());
        },
        .@"while" => |@"while"| {
            const shadow_offset = shadowPush(scope);
            const cond_location = self.shadowPtr(shadow_offset);
            const loop_name = std.fmt.allocPrintZ(self.allocator, "{}", .{expr_id}) catch oom();
            var block_cond = [_]c.BinaryenExpressionRef{
                try self.compileExpr(scope, cond_location, @"while".cond),
                self.boolGet(cond_location),
            };
            var block_body = [_]c.BinaryenExpressionRef{
                // Reusing `cond_location`.
                try self.compileExpr(scope, cond_location, @"while".body),
                // Confusingly break is actually continue.
                c.BinaryenBreak(
                    self.module.?,
                    loop_name,
                    null,
                    null,
                ),
            };
            shadowPop(scope, shadow_offset);
            return c.BinaryenLoop(
                self.module.?,
                loop_name,
                c.BinaryenIf(
                    self.module.?,
                    c.BinaryenBlock(self.module.?, null, &block_cond, @intCast(block_cond.len), c.BinaryenTypeInt32()),
                    c.BinaryenBlock(self.module.?, null, &block_body, @intCast(block_body.len), c.BinaryenTypeNone()),
                    c.BinaryenNop(self.module.?),
                ),
            );
        },
        .@"fn" => |@"fn"| {
            var captures = ArrayList([]const u8).init(self.allocator);
            {
                var locals = ArrayList([]const u8).init(self.allocator);
                try self.collectCaptures(expr_id, scope, &captures, &locals);
            }

            const fn_name = std.fmt.allocPrintZ(self.allocator, "{}", .{expr_id}) catch oom();
            self.fns.append(fn_name) catch oom();

            var fn_scope = Scope{
                .shadow_offset_next = 0,
                .shadow_offset_max = 0,
                .bindings = ArrayList(Binding).initCapacity(self.allocator, @"fn".params.len) catch oom(),
            };
            defer fn_scope.bindings.deinit();

            for (0.., captures.items) |capture_ix, capture| {
                bindingCapturePush(&fn_scope, @intCast(capture_ix), capture);
            }
            for (2.., @"fn".muts, @"fn".params) |wasm_var, mut, param| {
                bindingParamPush(&fn_scope, @intCast(wasm_var), mut, param);
            }

            const fn_result_location = c.BinaryenLocalGet(self.module.?, 0, c.BinaryenTypeInt32());
            const body_inner_ref = try self.compileExpr(&fn_scope, fn_result_location, @"fn".body);

            var fn_block = [_]c.BinaryenExpressionRef{
                self.framePush(fn_scope.shadow_offset_max),
                body_inner_ref,
                self.framePop(fn_scope.shadow_offset_max),
            };
            const body_ref = c.BinaryenBlock(self.module.?, null, &fn_block, @intCast(fn_block.len), c.BinaryenTypeNone());

            const wasm_params_types = self.allocator.alloc(
                c.BinaryenType,
                // Reserve:
                //   param 0 for fn_result_location
                //   param 1 for fn
                @"fn".params.len + 2,
            ) catch oom();
            for (wasm_params_types) |*wasm_param| wasm_param.* = c.BinaryenTypeInt32();

            _ = c.BinaryenAddFunction(
                self.module.?,
                fn_name,
                c.BinaryenTypeCreate(wasm_params_types.ptr, @intCast(wasm_params_types.len)),
                c.BinaryenTypeNone(),
                null,
                0,
                body_ref,
            );

            const block = self.allocator.alloc(c.BinaryenExpressionRef, 1 + @"fn".muts.len + captures.items.len) catch oom();
            block[0] = self.runtimeCall0(
                "createFn",
                &.{
                    result_location,
                    c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(self.fns.items.len - 1))))),
                    c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(@"fn".muts.len))))),
                    c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(captures.items.len))))),
                },
            );
            for (block[1 .. 1 + @"fn".muts.len], 0.., @"fn".muts) |*mut_expr, mut_ix, mut| {
                mut_expr.* = self.runtimeCall0(
                    "fnSetMut",
                    &.{
                        result_location,
                        c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(mut_ix))))),
                        c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(if (mut) 1 else 0)),
                    },
                );
            }
            for (block[1 + @"fn".muts.len ..], 0.., captures.items) |*capture_expr, capture_ix, capture| {
                capture_expr.* = self.runtimeCall0(
                    "copy",
                    &.{
                        self.runtimeCall1(
                            "fnGetCapture",
                            &.{
                                result_location,
                                c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(capture_ix))))),
                            },
                        ),
                        self.bindingPtr((try self.bindingFind(scope, capture, true)).*),
                    },
                );
            }

            return c.BinaryenBlock(self.module.?, null, block.ptr, @intCast(block.len), c.BinaryenTypeNone());
        },
        .call => |call| {
            const head_expr = self.parser.exprs.items[call.head];
            if (head_expr == .builtin) {
                if (call.args.len != 2) {
                    return self.fail("Wrong number of arguments ({}) to {}", .{ call.args.len, head_expr.builtin });
                }
                const shadow_offsets = .{ shadowPush(scope), shadowPush(scope) };
                const arg_locations = .{ self.shadowPtr(shadow_offsets[0]), self.shadowPtr(shadow_offsets[1]) };
                shadowPop(scope, shadow_offsets[1]);
                shadowPop(scope, shadow_offsets[0]);
                var block = [_]c.BinaryenExpressionRef{
                    try self.compileExpr(scope, arg_locations[0], call.args[0]),
                    try self.compileExpr(scope, arg_locations[1], call.args[1]),
                    self.runtimeCall0(
                        @tagName(head_expr.builtin),
                        &.{
                            result_location,
                            arg_locations[0],
                            arg_locations[1],
                        },
                    ),
                };
                return c.BinaryenBlock(self.module.?, null, &block, @intCast(block.len), c.BinaryenTypeNone());
            } else {
                const head_shadow_offset = shadowPush(scope);
                const head_location = self.shadowPtr(head_shadow_offset);

                const arg_shadow_offsets = self.allocator.alloc(u32, call.args.len) catch oom();
                for (arg_shadow_offsets, call.muts) |*arg_shadow_offset, mut| {
                    if (!mut) {
                        arg_shadow_offset.* = shadowPush(scope);
                    }
                }

                const wasm_args = self.allocator.alloc(c.BinaryenExpressionRef, 2 + call.args.len) catch oom();
                const wasm_types = self.allocator.alloc(c.BinaryenType, 2 + call.args.len) catch oom();
                wasm_args[0] = result_location;
                wasm_types[0] = c.BinaryenTypeInt32();
                wasm_args[1] = head_location;
                wasm_types[1] = c.BinaryenTypeInt32();
                for (wasm_args[2..], wasm_types[2..], call.args, call.muts, arg_shadow_offsets) |*wasm_arg, *wasm_type, arg, mut, arg_shadow_offset| {
                    if (mut) {
                        wasm_arg.* = try self.compilePath(scope, arg, mut);
                    } else {
                        const arg_location = self.shadowPtr(arg_shadow_offset);
                        var arg_block = [_]c.BinaryenExpressionRef{
                            try self.compileExpr(scope, arg_location, arg),
                            arg_location,
                        };
                        wasm_arg.* = c.BinaryenBlock(self.module.?, null, &arg_block, @intCast(arg_block.len), c.BinaryenTypeInt32());
                    }
                    wasm_type.* = c.BinaryenTypeInt32();
                }

                const mut_block = self.allocator.alloc(c.BinaryenExpressionRef, call.muts.len) catch oom();
                for (mut_block, 0.., call.muts) |*mut_expr, mut_ix, mut| {
                    mut_expr.* = self.runtimeCall0(
                        "fnAssertMut",
                        &.{
                            head_location,
                            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(mut_ix))))),
                            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(if (mut) 1 else 0)),
                        },
                    );
                }

                var block = [_]c.BinaryenExpressionRef{
                    try self.compileExpr(scope, head_location, call.head),
                    self.runtimeCall0(
                        "fnAssertMutCount",
                        &.{
                            head_location,
                            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(call.muts.len))))),
                        },
                    ),
                    c.BinaryenBlock(self.module.?, null, mut_block.ptr, @intCast(mut_block.len), c.BinaryenTypeNone()),
                    c.BinaryenCallIndirect(
                        self.module.?,
                        "fns",
                        self.runtimeCall1("fnGetIx", &.{head_location}),
                        wasm_args.ptr,
                        @intCast(wasm_args.len),
                        c.BinaryenTypeCreate(wasm_types.ptr, @intCast(wasm_types.len)),
                        c.BinaryenTypeNone(),
                    ),
                };

                {
                    var i: usize = arg_shadow_offsets.len;
                    while (i > 0) : (i -= 1) {
                        if (!call.muts[i - 1]) {
                            shadowPop(scope, arg_shadow_offsets[i - 1]);
                        }
                    }
                }
                shadowPop(scope, head_shadow_offset);

                return c.BinaryenBlock(self.module.?, null, &block, @intCast(block.len), c.BinaryenTypeNone());
            }
        },
        .get_static => {
            return self.move(
                result_location,
                try self.compilePath(scope, expr_id, false),
            );
        },
        .exprs => |child_expr_ids| {
            if (child_expr_ids.len == 0) {
                // Empty block returns falsey.
                return self.createNumber(result_location, 0);
            } else {
                const binding_len = scope.bindings.items.len;

                // Allocate space for local variables.
                for (child_expr_ids) |child_expr_id| {
                    const child_expr = self.parser.exprs.items[child_expr_id];
                    if (child_expr == .let) {
                        bindingLocalPush(scope, child_expr.let.mut, child_expr.let.name);
                    }
                }

                // Compile child_exprs
                const block = self.allocator.alloc(c.BinaryenExpressionRef, child_expr_ids.len) catch oom();
                for (block, child_expr_ids, 0..) |*expr_ref, child_expr_id, child_ix| {
                    if (child_ix < child_expr_ids.len - 1) {
                        // TODO Might need to initialize this to 0?
                        const shadow_offset = shadowPush(scope);
                        expr_ref.* = try self.compileExpr(scope, self.shadowPtr(shadow_offset), child_expr_id);
                        shadowPop(scope, shadow_offset);
                    } else {
                        expr_ref.* = try self.compileExpr(scope, result_location, child_expr_id);
                    }
                }

                // Free locals.
                bindingPop(scope, binding_len);

                return c.BinaryenBlock(self.module.?, null, block.ptr, @intCast(block.len), c.BinaryenTypeNone());
            }
        },
        // `.builtin` only appears as `.call.head`
        .builtin => unreachable,
    }
}

fn compilePath(self: *Self, scope: *Scope, expr_id: ExprId, mut: bool) error{CompileError}!c.BinaryenExpressionRef {
    const expr = self.parser.exprs.items[expr_id];
    switch (expr) {
        .name => |name| {
            const binding = try self.bindingFind(scope, name, true);
            if (mut and !binding.mut)
                return self.fail("Cannot set a non-mut variable: {s}", .{name});
            return self.bindingPtr(binding.*);
        },
        .get_static => |get_static| {
            const shadow_offset = shadowPush(scope);
            const key_location = self.shadowPtr(shadow_offset);
            const key = switch (get_static.key) {
                .number => |number| self.createNumber(key_location, number),
                .string => |string| self.createString(key_location, string),
            };
            const map = try self.compilePath(scope, get_static.map, mut);
            shadowPop(scope, shadow_offset);
            var block = [_]c.BinaryenExpressionRef{
                key,
                self.mapGet(map, key_location),
            };
            return c.BinaryenBlock(self.module.?, null, &block, @intCast(block.len), c.BinaryenTypeInt32());
        },
        .call => |call| {
            if (call.args.len != 1)
                return self.fail("Wrong number of arguments ({}) to {}", .{ call.args.len, call.head });
            if (call.muts[0] == true)
                return self.fail("Can't pass mut arg to map", .{});
            const shadow_offset = shadowPush(scope);
            const key_location = self.shadowPtr(shadow_offset);
            const key = try self.compileExpr(scope, key_location, call.args[0]);
            const map = try self.compilePath(scope, call.head, mut);
            shadowPop(scope, shadow_offset);
            var block = [_]c.BinaryenExpressionRef{
                key,
                self.mapGet(map, key_location),
            };
            return c.BinaryenBlock(self.module.?, null, &block, @intCast(block.len), c.BinaryenTypeInt32());
        },
        else => return self.fail("Unsupported path: {}", .{expr}),
    }
}

fn createNumber(self: *Self, result_location: c.BinaryenExpressionRef, number: f64) c.BinaryenExpressionRef {
    return self.runtimeCall0(
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
    return self.runtimeCall0(
        "createString",
        &.{
            result_location,
            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(ptr))))),
            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(string.len))))),
        },
    );
}

fn createMap(self: *Self, result_location: c.BinaryenExpressionRef) c.BinaryenExpressionRef {
    return self.runtimeCall0(
        "createMap",
        &.{
            result_location,
        },
    );
}

fn boolGet(self: *Self, bool_location: c.BinaryenExpressionRef) c.BinaryenExpressionRef {
    return self.runtimeCall1(
        "boolGet",
        &.{
            bool_location,
        },
    );
}

fn mapSet(self: *Self, map_location: c.BinaryenExpressionRef, key_location: c.BinaryenExpressionRef, value_location: c.BinaryenExpressionRef) c.BinaryenExpressionRef {
    return self.runtimeCall0(
        "mapSet",
        &.{
            map_location,
            key_location,
            value_location,
        },
    );
}

fn mapGet(self: *Self, map_location: c.BinaryenExpressionRef, key_location: c.BinaryenExpressionRef) c.BinaryenExpressionRef {
    return self.runtimeCall1(
        "mapGet",
        &.{
            map_location,
            key_location,
        },
    );
}

fn move(self: *Self, result_location: c.BinaryenExpressionRef, source_location: c.BinaryenExpressionRef) c.BinaryenExpressionRef {
    return self.runtimeCall0("move", &.{
        result_location,
        source_location,
    });
}

fn copy(self: *Self, result_location: c.BinaryenExpressionRef, source_location: c.BinaryenExpressionRef) c.BinaryenExpressionRef {
    return self.runtimeCall0("copy", &.{
        result_location,
        source_location,
    });
}

fn bindingFind(self: *Self, scope: *Scope, name: []const u8, visible: bool) !*Binding {
    var i: usize = scope.bindings.items.len;
    while (i > 0) : (i -= 1) {
        const binding = &scope.bindings.items[i - 1];
        if (binding.visible == visible and std.mem.eql(u8, binding.name, name)) {
            return binding;
        }
    } else {
        return self.fail("Name not in scope: {s}", .{name});
    }
}

fn bindingPtr(self: *Self, binding: Binding) c.BinaryenExpressionRef {
    return switch (binding.kind) {
        .wasm_var => |wasm_var| c.BinaryenLocalGet(self.module.?, wasm_var, c.BinaryenTypeInt32()),
        .shadow_offset => |shadow_offset| self.shadowPtr(shadow_offset),
        .capture => |capture| self.runtimeCall1("fnGetCapture", &.{
            c.BinaryenLocalGet(self.module.?, 1, c.BinaryenTypeInt32()),
            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, @intCast(capture))))),
        }),
    };
}

fn bindingParamPush(scope: *Scope, wasm_var: u32, mut: bool, name: []const u8) void {
    scope.bindings.append(.{
        .mut = mut,
        .name = name,
        .kind = .{ .wasm_var = wasm_var },
        .visible = true,
    }) catch oom();
}

fn bindingLocalPush(scope: *Scope, mut: bool, name: []const u8) void {
    const shadow_offset = shadowPush(scope);
    scope.bindings.append(.{
        .mut = mut,
        .name = name,
        .kind = .{ .shadow_offset = shadow_offset },
        // Set to true after the `let` statement.
        .visible = false,
    }) catch oom();
}

fn bindingCapturePush(scope: *Scope, capture_ix: u32, name: []const u8) void {
    scope.bindings.append(.{
        .mut = false,
        .name = name,
        .kind = .{ .capture = capture_ix },
        .visible = true,
    }) catch oom();
}

fn bindingPop(scope: *Scope, size: usize) void {
    while (scope.bindings.items.len > size) {
        const binding = scope.bindings.pop();
        assert(binding.kind == .shadow_offset);
        shadowPop(scope, binding.kind.shadow_offset);
    }
}

fn shadowPush(scope: *Scope) u32 {
    const shadow_offset = scope.shadow_offset_next;
    scope.shadow_offset_next += 1;
    scope.shadow_offset_max = @max(scope.shadow_offset_max, scope.shadow_offset_next);
    return shadow_offset;
}

fn shadowPop(scope: *Scope, offset: u32) void {
    scope.shadow_offset_next -= 1;
    assert(scope.shadow_offset_next == offset);
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

fn runtimeCall0(self: *Self, fn_name: [*c]const u8, args: []const c.BinaryenExpressionRef) c.BinaryenExpressionRef {
    return c.BinaryenCall(
        self.module.?,
        fn_name,
        @constCast(args.ptr),
        @intCast(args.len),
        c.BinaryenTypeNone(),
    );
}

fn runtimeCall1(self: *Self, fn_name: [*c]const u8, args: []const c.BinaryenExpressionRef) c.BinaryenExpressionRef {
    return c.BinaryenCall(
        self.module.?,
        fn_name,
        @constCast(args.ptr),
        @intCast(args.len),
        c.BinaryenTypeInt32(),
    );
}

fn collectCaptures(self: *Self, expr_id: ExprId, scope: *Scope, captures: *ArrayList([]const u8), locals: *ArrayList([]const u8)) error{CompileError}!void {
    const expr = self.parser.exprs.items[expr_id];
    switch (expr) {
        .number, .string, .builtin => {},
        .map => |map| {
            for (map.keys) |key| try self.collectCaptures(key, scope, captures, locals);
            for (map.values) |value| try self.collectCaptures(value, scope, captures, locals);
        },
        .name => |name| {
            for (locals.items) |local| {
                if (std.mem.eql(u8, name, local)) {
                    return; // Not a capture - bound locally.
                }
            }
            for (captures.items) |capture| {
                if (std.mem.eql(u8, name, capture)) {
                    return; // Already captured.
                }
            }
            _ = try self.bindingFind(scope, name, true);
            captures.append(name) catch oom();
        },
        .let => |let| {
            try self.collectCaptures(let.value, scope, captures, locals);
            locals.append(let.name) catch oom();
        },
        .set => |set| {
            try self.collectCaptures(set.path, scope, captures, locals);
            try self.collectCaptures(set.value, scope, captures, locals);
        },
        .@"if" => |@"if"| {
            try self.collectCaptures(@"if".cond, scope, captures, locals);
            try self.collectCaptures(@"if".if_true, scope, captures, locals);
            try self.collectCaptures(@"if".if_false, scope, captures, locals);
        },
        .@"while" => |@"while"| {
            try self.collectCaptures(@"while".cond, scope, captures, locals);
            try self.collectCaptures(@"while".body, scope, captures, locals);
        },
        .@"fn" => |@"fn"| {
            const locals_len = locals.items.len;
            for (@"fn".params) |param| {
                locals.append(param) catch oom();
            }
            try self.collectCaptures(@"fn".body, scope, captures, locals);
            locals.shrinkRetainingCapacity(locals_len);
        },
        .call => |call| {
            try self.collectCaptures(call.head, scope, captures, locals);
            for (call.args) |arg| {
                try self.collectCaptures(arg, scope, captures, locals);
            }
        },
        .get_static => |get_static| {
            try self.collectCaptures(get_static.map, scope, captures, locals);
        },
        .exprs => |exprs| {
            const locals_len = locals.items.len;
            for (exprs) |subexpr| {
                try self.collectCaptures(subexpr, scope, captures, locals);
            }
            locals.shrinkRetainingCapacity(locals_len);
        },
    }
}

fn fail(self: *Self, comptime message: []const u8, args: anytype) error{CompileError} {
    self.error_message = std.fmt.allocPrint(self.allocator, message, args) catch oom();
    return error.CompileError;
}

fn oom() noreturn {
    panic("OOM", .{});
}
