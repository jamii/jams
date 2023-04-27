const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const panic = std.debug.panic;
const expectEqual = std.testing.expectEqual;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const wasm2c = @import("./wasm2c.zig");

fn d(x: anytype) @TypeOf(x) {
    std.debug.print("{any}\n", .{x});
    return x;
}

// Test suite spec:
// https://github.com/WebAssembly/spec/blob/7f67637cd638e273f3e9b8be08a9c0e322497498/interpreter/README.md#scripts

const TestFile = struct {
    source_filename: []const u8,
    commands: []const TestCommand,
};

const TestCommand = struct {
    type: enum {
        action,
        assert_exhaustion,
        assert_invalid,
        assert_malformed,
        assert_return,
        assert_trap,
        assert_uninstantiable,
        assert_unlinkable,
        module,
        register,
    },
    line: ?usize = null,
    filename: ?[]const u8 = null,
    action: ?TestAction = null,
    expected: ?[]TestValue = null,
};

const TestAction = struct {
    type: enum {
        invoke,
        get,
    },
    field: ?[]const u8 = null,
    args: ?[]TestValue = null,
};

const TestValue = struct {
    type: []const u8,
    value: ?[]const u8 = null,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const cwd = std.fs.cwd();

    var test_files = ArrayList(TestFile).init(allocator);
    const args = try std.process.argsAlloc(allocator);
    for (args[1..]) |filename| {
        std.debug.print("Opening {s}\n", .{filename});

        const file = try cwd.openFile(filename, .{});
        defer file.close();

        const bytes = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        var token_stream = std.json.TokenStream.init(bytes);
        const options = .{
            .allocator = allocator,
            .ignore_unknown_fields = true,
        };
        const test_file = try std.json.parse(TestFile, &token_stream, options);
        try test_files.append(test_file);
    }

    // TODO https://github.com/ziglang/zig/blob/master/lib/std/testing.zig#L544
    try cwd.deleteTree("wasm-testsuite-output");
    try cwd.makeDir("wasm-testsuite-output");

    var modules_total: usize = 0;
    var modules_passed: usize = 0;

    var asserts_total: usize = 0;
    var asserts_passed: usize = 0;
    var asserts_skipped: usize = 0;

    for (test_files.items) |test_file| {
        var module_index: usize = 0;

        // Skip any assert_invalid at the start of the test.
        while (module_index < test_file.commands.len and
            test_file.commands[module_index].type != .module)
        {
            module_index += 1;
            asserts_skipped += 1;
        }

        while (module_index < test_file.commands.len) {
            const module_command = test_file.commands[module_index];
            assert(module_command.type == .module);
            var assert_index = module_index + 1;
            while (assert_index < test_file.commands.len and
                test_file.commands[assert_index].type != .module)
            {
                assert_index += 1;
            }
            const assert_commands = test_file.commands[module_index + 1 .. assert_index];
            module_index = assert_index;

            std.debug.print("Compiling {s}\n", .{module_command.filename.?});
            const module_result = try compileModule(allocator, module_command.filename.?);
            modules_total += 1;
            if (module_result) {
                modules_passed += 1;
                const assert_result = try compileAsserts(allocator, module_command, assert_commands);
                asserts_total += assert_commands.len;
                asserts_skipped += assert_result.skipped;
                if (assert_result.passed) asserts_passed += assert_commands.len - assert_result.skipped;
            }
        }
    }

    std.debug.print(
        \\modules: {}/{}
        \\asserts: {}/{} ({} skipped)
    , .{ modules_passed, modules_total, asserts_passed, asserts_total - asserts_skipped, asserts_skipped });
}

fn compileModule(allocator: Allocator, wasm_filename: []const u8) !bool {
    assert(std.mem.endsWith(u8, wasm_filename, ".wasm"));
    const wasm_path = try std.fmt.allocPrint(
        allocator,
        "deps/wasm-testsuite/{s}",
        .{wasm_filename},
    );
    const output_path = try std.fmt.allocPrint(
        allocator,
        "wasm-testsuite-output/{s}",
        .{wasm_filename[0 .. wasm_filename.len - ".wasm".len]},
    );
    const result = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{
            "zig",
            "run",
            "-Drelease-safe",
            "wasm2c.zig",
            "--",
            wasm_path,
            output_path,
        },
        .max_output_bytes = std.math.maxInt(usize),
    });
    if (result.term != .Exited or result.term.Exited != 0) {
        std.debug.print("compileModule(\"{s}\") failed:\n{s}\n", .{ wasm_filename, result.stderr });
        return false;
    } else {
        return true;
    }
}

const CompileAssertsResult = struct {
    passed: bool,
    skipped: usize,
};

fn compileAsserts(allocator: Allocator, module_command: TestCommand, assert_commands: []const TestCommand) !CompileAssertsResult {
    const wasm_filename = module_command.filename.?;
    assert(std.mem.endsWith(u8, wasm_filename, ".wasm"));
    const name = wasm_filename[0 .. wasm_filename.len - ".wasm".len];
    const c_path = try std.fmt.allocPrint(
        allocator,
        "wasm-testsuite-output/{s}.c",
        .{name},
    );
    const output_path = try std.fmt.allocPrint(
        allocator,
        "wasm-testsuite-output/{s}.zig",
        .{name},
    );

    var output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    var buffered_writer = std.io.bufferedWriter(output_file.writer());
    const writer = buffered_writer.writer();

    try writer.print(
        \\const std = @import("std");
        \\const expectEqual = std.testing.expectEqual;
        \\const c = @cImport({{
        \\    @cInclude("{s}.h");
        \\}});
        \\
    , .{name});

    var asserts_skipped: usize = 0;
    for (assert_commands) |assert_command| {
        if (assert_command.type == .assert_return and
            assert_command.action.?.type == .invoke and
            assert_command.expected.?.len == 1)
        {
            try compileAssertReturn(writer, assert_command);
        } else {
            asserts_skipped += 1;
        }
    }

    try buffered_writer.flush();

    const result = try std.ChildProcess.exec(.{
        .allocator = allocator,
        .argv = &.{
            "zig",
            "test",
            output_path,
            c_path,
            "-Iwasm-testsuite-output",
            "-lc",
        },
        .max_output_bytes = std.math.maxInt(usize),
    });
    const passed = result.term == .Exited and result.term.Exited == 0;
    if (!passed)
        std.debug.print("compileAssertReturn(\"{s}\", {}) failed:\n{s}\n", .{ name, module_command.line.?, result.stderr });
    return .{
        .passed = passed,
        .skipped = asserts_skipped,
    };
}

fn compileAssertReturn(writer: anytype, assert_command: TestCommand) !void {
    const test_action = assert_command.action.?;
    try writer.print(
        \\test "{}" {{
        \\    try std.testing.expectEqual(
    , .{assert_command.line.?});

    // TODO multiple returns
    assert(assert_command.expected.?.len == 1);
    try renderValue(writer, assert_command.expected.?[0]);
    try writer.writeAll(", ");

    switch (test_action.type) {
        .invoke => {
            try writer.print("c.wasm_{s}(", .{wasm2c.mangle(test_action.field.?)});
            for (test_action.args.?) |arg| {
                try renderValue(writer, arg);
                try writer.writeAll(", ");
            }
            try writer.writeAll("),");
        },
        .get => {
            try writer.print("c.wasm_{s},", .{wasm2c.mangle(test_action.field.?)});
        },
    }

    try writer.writeAll(");\n}");
}

fn renderValue(writer: anytype, test_value: TestValue) !void {
    const abi_type =
        if (std.mem.eql(u8, test_value.type, "i32"))
        "u32"
    else if (std.mem.eql(u8, test_value.type, "u32"))
        "u32"
    else if (std.mem.eql(u8, test_value.type, "i64"))
        "u64"
    else if (std.mem.eql(u8, test_value.type, "u64"))
        "u64"
    else if (std.mem.eql(u8, test_value.type, "f32"))
        "f32"
    else if (std.mem.eql(u8, test_value.type, "f64"))
        "f64"
    else
        panic("Don't know abi type for: {s}", .{test_value.type});
    const value_type =
        if (std.mem.eql(u8, test_value.type, "i32"))
        "u32"
    else if (std.mem.eql(u8, test_value.type, "u32"))
        "u32"
    else if (std.mem.eql(u8, test_value.type, "i64"))
        "u64"
    else if (std.mem.eql(u8, test_value.type, "u64"))
        "u64"
    else if (std.mem.eql(u8, test_value.type, "f32"))
        "u32"
    else if (std.mem.eql(u8, test_value.type, "f64"))
        "u64"
    else
        panic("Don't know abi type for: {s}", .{test_value.type});
    const value = if (std.mem.eql(u8, test_value.value.?, "nan:canonical") or
        std.mem.eql(u8, test_value.value.?, "nan:arithmetic"))
        (if (std.mem.eql(u8, test_value.type, "f32"))
            "std.math.nan_u32"
        else if (std.mem.eql(u8, test_value.type, "f64"))
            "std.math.nan_u32"
        else
            unreachable)
    else
        test_value.value.?;

    try writer.print("@bitCast({s}, @as({s}, {s}))", .{
        abi_type,
        value_type,
        value,
    });
}
