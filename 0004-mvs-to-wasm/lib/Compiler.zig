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

    self.module = c.BinaryenModuleRead(@as([*c]u8, @ptrCast(runtime_bytes)), runtime_bytes.len);
    defer {
        c.BinaryenModuleDispose(self.module.?);
        self.module = null;
    }
    
    //// (memory 0) already exists, but doesn't have a name.
    //void BinaryenSetMemory(self.module.?,
    //                                16,
    //                                BinaryenIndex maximum,
    //                                const char* exportName,
    //                                const char** segments,
    //                                bool* segmentPassive,
    //                                BinaryenExpressionRef* segmentOffsets,
    //                                BinaryenIndex* segmentSizes,
    //                                BinaryenIndex numSegments,
    //                                bool shared,
    //                                bool memory64,
    //                                const char* name);

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
            return self.literalNumber(number);
        },
        .exprs => |child_expr_ids| {
            if (child_expr_ids.len == 0) {
                // Empty block returns falsey.
                return self.literalNumber(0);
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
    scope.bindings.append(binding) catch oom();
}

fn literalNumber(self: *Self, number: f64) c.BinaryenExpressionRef {
    var block = [_]c.BinaryenExpressionRef{
        // Alloc stack space.
        self.stackPush(@sizeOf(Kind) + @sizeOf(f64)),
        // Set type tag.
        c.BinaryenStore(
            self.module.?,
            @sizeOf(Kind),
            0,
            0,
            c.BinaryenGlobalGet(self.module.?, "__stack_pointer", c.BinaryenTypeInt32()),
            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@intFromEnum(Kind.number))),
            c.BinaryenTypeInt32(),
            null,
        ),
        // Set value.
        c.BinaryenStore(
            self.module.?,
            @sizeOf(f64),
            @sizeOf(Kind),
            0, // TODO Will this be misaligned? Should I do value first?
            c.BinaryenGlobalGet(self.module.?, "__stack_pointer", c.BinaryenTypeInt32()),
            c.BinaryenConst(self.module.?, c.BinaryenLiteralFloat64(number)),
            c.BinaryenTypeFloat64(),
            null,
        ),
        // Return pointer.
        c.BinaryenGlobalGet(self.module.?, "__stack_pointer", c.BinaryenTypeInt32()),
    };
    return c.BinaryenBlock(self.module.?, null, &block, block.len, c.BinaryenTypeInt32());
}

fn stackPush(self: *Self, bytes_count: u32) c.BinaryenExpressionRef {
    // TODO Will this trap on stack overflow?
    return c.BinaryenGlobalSet(
        self.module.?,
        "__stack_pointer",
        c.BinaryenBinary(
            self.module.?,
            c.BinaryenSubInt32(),
            c.BinaryenConst(self.module.?, c.BinaryenLiteralInt32(@bitCast(bytes_count))),
            c.BinaryenGlobalGet(self.module.?, "__stack_pointer", c.BinaryenTypeInt32()),
        ),
    );
}

fn fail(self: *Self, comptime message: []const u8, args: anytype) error{CompileError} {
    self.error_message = std.fmt.allocPrint(self.allocator, message, args) catch oom();
    return error.CompileError;
}

fn oom() noreturn {
    panic("OOM", .{});
}
