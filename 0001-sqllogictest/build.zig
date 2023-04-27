const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const mode = b.standardReleaseOptions();
    var target = b.standardTargetOptions(.{});

    const generate_grammar = addBin(b, mode, target, "generate_grammar", "Generate the sql grammar", "./bin/generate_grammar.zig");
    generate_grammar.run.addArgs(b.args orelse &[0][]const u8{});

    const test_slt = addBin(b, mode, target, "test_slt", "Run the sqlite logic test suite", "./test/slt.zig");
    test_slt.run.addArgs(b.args orelse &[0][]const u8{});

    const test_unit_bin = b.addTestExe("test_unit", "./test/slt.zig");
    commonSetup(test_unit_bin, mode, target);
    const test_unit_run = test_unit_bin.run();
    const test_unit_step = b.step("test_unit", "Run unit tests");
    test_unit_step.dependOn(&test_unit_run.step);
}

fn addBin(
    b: *std.build.Builder,
    mode: std.builtin.Mode,
    target: std.zig.CrossTarget,
    name: []const u8,
    description: []const u8,
    exe_path: []const u8,
) struct {
    bin: *std.build.LibExeObjStep,
    run: *std.build.RunStep,
    step: *std.build.Step,
} {
    const bin = b.addExecutable(name, exe_path);
    commonSetup(bin, mode, target);
    const run = bin.run();
    const step = b.step(name, description);
    step.dependOn(&run.step);
    return .{ .bin = bin, .run = run, .step = step };
}

fn commonSetup(
    bin: *std.build.LibExeObjStep,
    mode: std.builtin.Mode,
    target: std.zig.CrossTarget,
) void {
    bin.setMainPkgPath("./");
    bin.setBuildMode(mode);
    bin.setTarget(target);
    bin.linkLibC();
    bin.omit_frame_pointer = false;
}

fn getRelativePath() []const u8 {
    comptime var src: std.builtin.SourceLocation = @src();
    return std.fs.path.dirname(src.file).? ++ std.fs.path.sep_str;
}
