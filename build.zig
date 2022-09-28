const std = @import("std");
const imgui = @import("deps/zig-imgui/zig-imgui/imgui_build.zig");

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

    const debugger = addBin(b, mode, target, "run_debugger", "Run the debugger", "./debugger/debugger.zig");
    imgui.link(debugger.bin);
    linkGlfw(debugger.bin, target);
    linkGlad(debugger.bin, target);
    debugger.bin.install();
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

fn linkGlad(exe: *std.build.LibExeObjStep, target: std.zig.CrossTarget) void {
    _ = target;
    exe.addIncludeDir("debugger/imgui_impl/");
    exe.addCSourceFile("debugger/imgui_impl/glad.c", &[_][]const u8{"-std=c99"});
    //exe.linkSystemLibrary("opengl");
}

fn linkGlfw(exe: *std.build.LibExeObjStep, target: std.zig.CrossTarget) void {
    if (target.isWindows()) {
        exe.addObjectFile(if (target.getAbi() == .msvc) "debugger/imgui_impl/glfw3.lib" else "debugger/imgui_impl/libglfw3.a");
        exe.linkSystemLibrary("gdi32");
        exe.linkSystemLibrary("shell32");
    } else {
        exe.linkSystemLibrary("glfw");
    }
}
