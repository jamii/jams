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
fns: std.AutoHashMap(ExprId, c.BinaryenFunctionRef),
error_message: ?[]const u8,

pub const Scope = struct {
    wasm_var_next: usize,
    len_max: usize,
    bindings: ArrayList(Binding),
};
pub const Binding = struct {
    mut: bool,
    name: []const u8,
    wasm_var: usize,
};

pub fn init(allocator: Allocator, parser: Parser) Self {
    return .{
        .allocator = allocator,
        .parser = parser,
        .module = null,
        .fns = std.AutoHashMap(ExprId, c.BinaryenFunctionRef).init(allocator),
        .error_message = null,
    };
}

pub fn compile(self: *Self) error{CompileError}![]const u8 {
    // TODO Once stable, use:
    //const runtime_bytes = @embedFile("../runtime.wasm");

    const runtime_file = std.fs.cwd().openFile("runtime.wasm", .{}) catch |err|
        panic("Error opening runtime.wasm: {}", .{err});
    defer runtime_file.close();

    const runtime_bytes = runtime_file.reader().readAllAlloc(self.allocator, std.math.maxInt(usize)) catch |err|
        panic("Error reading runtime.wasm: {}", .{err});
    defer self.allocator.free(runtime_bytes);

    //self.module = c.BinaryenModuleRead(@as([*c]u8, @ptrCast(runtime_bytes)), runtime_bytes.len);
    self.module = c.BinaryenModuleCreate();
    defer {
        c.BinaryenModuleDispose(self.module.?);
        self.module = null;
    }

    // We have to strip debug info from the runtime because binaryen crashes on unrecognized dwarf.
    // But that removes the name of the '__stack_pointer' variable, and binaryen can only reference globals by name.
    // Binaryen also doesn't provide an api to set the name of a global.
    // So we have to make our own separate shadow stack :(
    _ = c.BinaryenAddGlobal(self.module.?, "__yet_another_stack_pointer", c.BinaryenTypeInt32(), true, c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(2 * 1048576)));

    // We also have to grow memory to support that second stack.
    {
        c.BinaryenAddMemoryImport(
            self.module.?,
            "memory",
            "runtime",
            "memory",
            0,
        );
        c.BinaryenSetStart(
            self.module.?,
            c.BinaryenAddFunction(
                self.module.?,
                "start",
                c.BinaryenTypeNone(),
                c.BinaryenTypeNone(),
                null,
                0,
                c.BinaryenDrop(
                    self.module.?,
                    c.BinaryenMemoryGrow(
                        self.module.?,
                        c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(@as(u32, 16)))),
                        "memory",
                        false,
                    ),
                ),
            ),
        );
    }

    // Import runtime functions.
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

    // TODO Mangle main?
    _ = try self.compileFn("main", &.{}, self.parser.exprs.items.len - 1);
    _ = c.BinaryenAddFunctionExport(self.module.?, "main", "main");

    if (!c.BinaryenModuleValidate(self.module.?))
        return self.fail("Produced an invalid wasm module", .{});

    const result = c.BinaryenModuleAllocateAndWrite(self.module.?, null);
    defer std.c.free(result.binary);

    const result_bytes = @as([*c]u8, @ptrCast(result.binary))[0..result.binaryBytes];
    return self.allocator.dupe(u8, result_bytes) catch oom();
}

fn compileFn(self: *Self, name: [:0]const u8, params: []const Binding, body: ExprId) error{CompileError}!c.BinaryenFunctionRef {
    if (self.fns.get(body)) |fn_ref| return fn_ref;

    // TODO How to retrieve closure environment?
    var scope = Scope{
        .wasm_var_next = 1, // Reserve param 0 for return value.
        .len_max = 0,
        .bindings = ArrayList(Binding).initCapacity(self.allocator, params.len) catch oom(),
    };
    defer scope.bindings.deinit();

    for (params) |param| {
        scopePut(&scope, param);
    }
    const body_ref = try self.compileExpr(&scope, body);

    const wasm_params_types = self.allocator.alloc(
        c.BinaryenType,
        // Reserve param 0 for return value.
        params.len + 1,
    ) catch oom();
    defer self.allocator.free(wasm_params_types);

    for (wasm_params_types) |*wasm_param| wasm_param.* = c.BinaryenTypeInt32();
    const wasm_params = c.BinaryenTypeCreate(wasm_params_types.ptr, @intCast(wasm_params_types.len));

    const wasm_results = c.BinaryenTypeCreate(null, 0);

    const wasm_vars_types = self.allocator.alloc(
        c.BinaryenType,
        // Count any variables needed beyond params and return value.
        scope.wasm_var_next - 1 - params.len,
    ) catch oom();
    defer self.allocator.free(wasm_vars_types);

    for (wasm_vars_types) |*wasm_param| wasm_param.* = c.BinaryenTypeInt32();

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

fn compileExpr(self: *Self, scope: *Scope, expr_id: ExprId) error{CompileError}!c.BinaryenExpressionRef {
    const expr = self.parser.exprs.items[expr_id];
    switch (expr) {
        .number => |number| {
            return self.runtimeCall(
                "createNumber",
                &.{
                    self.stackPtr(0), // TODO
                    c.BinaryenConst(self.module.?, c.BinaryenLiteralFloat64(number)),
                },
            );
        },
        .exprs => |child_expr_ids| {
            if (child_expr_ids.len == 0) {
                // Empty block returns falsey.
                return self.runtimeCall(
                    "createNumber",
                    &.{
                        self.stackPtr(0), // TODO
                        c.BinaryenConst(self.module.?, c.BinaryenLiteralFloat64(0)),
                    },
                );
            } else {
                const block = self.allocator.alloc(c.BinaryenExpressionRef, child_expr_ids.len) catch oom();
                for (block, child_expr_ids) |*expr_ref, child_expr_id| {
                    expr_ref.* = try self.compileExpr(scope, child_expr_id);
                }
                return c.BinaryenBlock(self.module.?, null, block.ptr, @intCast(block.len), c.BinaryenTypeInt32());
            }
        },
        else => return self.fail("Unsupported expr: {}", .{expr}),
    }
}

fn scopePut(scope: *Scope, _binding: Binding) void {
    var binding = _binding;
    binding.wasm_var = scope.wasm_var_next;
    scope.wasm_var_next += 1;
    scope.len_max = @max(scope.len_max, scope.bindings.items.len);
    scope.bindings.append(binding) catch oom();
}

fn stackPush(self: *Self, offset: u32) c.BinaryenExpressionRef {
    return c.BinaryenGlobalSet(
        self.module.?,
        "__yet_another_stack_pointer",
        c.BinaryenBinary(
            self.module.?,
            c.BinaryenSubInt32(),
            c.BinaryenGlobalGet(self.module.?, "__yet_another_stack_pointer", c.BinaryenTypeInt32()),
            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(offset))),
        ),
    );
}

fn stackPop(self: *Self, offset: u32) c.BinaryenExpressionRef {
    return c.BinaryenGlobalSet(
        self.module.?,
        "__yet_another_stack_pointer",
        self.stackPtr(offset),
    );
}

fn stackPtr(self: *Self, offset: u32) c.BinaryenExpressionRef {
    // TODO Will this trap on stack overflow?
    return c.BinaryenBinary(
        self.module.?,
        c.BinaryenAddInt32(),
        c.BinaryenGlobalGet(self.module.?, "__yet_another_stack_pointer", c.BinaryenTypeInt32()),
        c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(offset))),
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
