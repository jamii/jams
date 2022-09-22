const std = @import("std");
const builtin = @import("builtin");
const imgui = @import("imgui");
const glfw = @import("glfw.zig");
const assert = std.debug.assert;

const GLFW_HEADER_VERSION = glfw.GLFW_VERSION_MAJOR * 1000 + glfw.GLFW_VERSION_MINOR * 100;
const GLFW_HAS_NEW_CURSORS = @hasDecl(glfw, "GLFW_RESIZE_NESW_CURSOR") and (GLFW_HEADER_VERSION >= 3400); // 3.4+ GLFW_RESIZE_ALL_CURSOR, GLFW_RESIZE_NESW_CURSOR, GLFW_RESIZE_NWSE_CURSOR, GLFW_NOT_ALLOWED_CURSOR
const GLFW_HAS_GAMEPAD_API = (GLFW_HEADER_VERSION >= 3300); // 3.3+ glfwGetGamepadState() new api
const GLFW_HAS_GET_KEY_NAME = (GLFW_HEADER_VERSION >= 3200); // 3.2+ glfwGetKeyName()

const IS_EMSCRIPTEN = false;

// GLFW data
const GlfwClientApi = enum(u32) {
    Unknown,
    OpenGL,
    Vulkan,
    _,
};

const Data = extern struct {
    Window: ?*glfw.GLFWwindow = null,
    ClientApi: GlfwClientApi = .Unknown,
    Time: f64 = 0,
    MouseWindow: ?*glfw.GLFWwindow = null,
    MouseCursors: [imgui.MouseCursor.COUNT]?*glfw.GLFWcursor = [_]?*glfw.GLFWcursor{null} ** imgui.MouseCursor.COUNT,
    LastValidMousePos: imgui.Vec2 = .{ .x = 0, .y = 0 },
    InstalledCallbacks: bool = false,

    // Chain GLFW callbacks: our callbacks will call the user's previously installed callbacks, if any.
    PrevUserCallbackWindowFocus: glfw.GLFWwindowfocusfun = null,
    PrevUserCallbackCursorPos: glfw.GLFWcursorposfun = null,
    PrevUserCallbackCursorEnter: glfw.GLFWcursorenterfun = null,
    PrevUserCallbackMousebutton: glfw.GLFWmousebuttonfun = null,
    PrevUserCallbackScroll: glfw.GLFWscrollfun = null,
    PrevUserCallbackKey: glfw.GLFWkeyfun = null,
    PrevUserCallbackChar: glfw.GLFWcharfun = null,
    PrevUserCallbackMonitor: glfw.GLFWmonitorfun = null,
};

// Backend data stored in io.BackendPlatformUserData to allow support for multiple Dear ImGui contexts
// It is STRONGLY preferred that you use docking branch with multi-viewports (== single Dear ImGui context + multiple windows) instead of multiple Dear ImGui contexts.
// FIXME: multi-context support is not well tested and probably dysfunctional in this backend.
// - Because glfwPollEvents() process all windows and some events may be called outside of it, you will need to register your own callbacks
//   (passing install_callbacks=false in ImGui_ImplGlfw_InitXXX functions), set the current dear imgui context and then call our callbacks.
// - Otherwise we may need to store a GLFWWindow* -> ImGuiContext* map and handle this in the backend, adding a little bit of extra complexity to it.
// FIXME: some shared resources (mouse cursor shape, gamepad) are mishandled when using multi-context.
fn GetBackendData() ?*Data {
    return if (imgui.GetCurrentContext() != null) @ptrCast(?*Data, @alignCast(@alignOf(Data), imgui.GetIO().BackendPlatformUserData)) else null;
}

// Functions
fn GetClipboardText(user_data: ?*anyopaque) callconv(.C) ?[*:0]const u8 {
    return glfw.glfwGetClipboardString(@ptrCast(*glfw.GLFWwindow, user_data));
}

fn SetClipboardText(user_data: ?*anyopaque, text: ?[*:0]const u8) callconv(.C) void {
    glfw.glfwSetClipboardString(@ptrCast(*glfw.GLFWwindow, user_data), text.?);
}

fn KeyToImGuiKey(key: i32) imgui.Key {
    return switch (key) {
        glfw.GLFW_KEY_TAB => .Tab,
        glfw.GLFW_KEY_LEFT => .LeftArrow,
        glfw.GLFW_KEY_RIGHT => .RightArrow,
        glfw.GLFW_KEY_UP => .UpArrow,
        glfw.GLFW_KEY_DOWN => .DownArrow,
        glfw.GLFW_KEY_PAGE_UP => .PageUp,
        glfw.GLFW_KEY_PAGE_DOWN => .PageDown,
        glfw.GLFW_KEY_HOME => .Home,
        glfw.GLFW_KEY_END => .End,
        glfw.GLFW_KEY_INSERT => .Insert,
        glfw.GLFW_KEY_DELETE => .Delete,
        glfw.GLFW_KEY_BACKSPACE => .Backspace,
        glfw.GLFW_KEY_SPACE => .Space,
        glfw.GLFW_KEY_ENTER => .Enter,
        glfw.GLFW_KEY_ESCAPE => .Escape,
        glfw.GLFW_KEY_APOSTROPHE => .Apostrophe,
        glfw.GLFW_KEY_COMMA => .Comma,
        glfw.GLFW_KEY_MINUS => .Minus,
        glfw.GLFW_KEY_PERIOD => .Period,
        glfw.GLFW_KEY_SLASH => .Slash,
        glfw.GLFW_KEY_SEMICOLON => .Semicolon,
        glfw.GLFW_KEY_EQUAL => .Equal,
        glfw.GLFW_KEY_LEFT_BRACKET => .LeftBracket,
        glfw.GLFW_KEY_BACKSLASH => .Backslash,
        glfw.GLFW_KEY_RIGHT_BRACKET => .RightBracket,
        glfw.GLFW_KEY_GRAVE_ACCENT => .GraveAccent,
        glfw.GLFW_KEY_CAPS_LOCK => .CapsLock,
        glfw.GLFW_KEY_SCROLL_LOCK => .ScrollLock,
        glfw.GLFW_KEY_NUM_LOCK => .NumLock,
        glfw.GLFW_KEY_PRINT_SCREEN => .PrintScreen,
        glfw.GLFW_KEY_PAUSE => .Pause,
        glfw.GLFW_KEY_KP_0 => .Keypad0,
        glfw.GLFW_KEY_KP_1 => .Keypad1,
        glfw.GLFW_KEY_KP_2 => .Keypad2,
        glfw.GLFW_KEY_KP_3 => .Keypad3,
        glfw.GLFW_KEY_KP_4 => .Keypad4,
        glfw.GLFW_KEY_KP_5 => .Keypad5,
        glfw.GLFW_KEY_KP_6 => .Keypad6,
        glfw.GLFW_KEY_KP_7 => .Keypad7,
        glfw.GLFW_KEY_KP_8 => .Keypad8,
        glfw.GLFW_KEY_KP_9 => .Keypad9,
        glfw.GLFW_KEY_KP_DECIMAL => .KeypadDecimal,
        glfw.GLFW_KEY_KP_DIVIDE => .KeypadDivide,
        glfw.GLFW_KEY_KP_MULTIPLY => .KeypadMultiply,
        glfw.GLFW_KEY_KP_SUBTRACT => .KeypadSubtract,
        glfw.GLFW_KEY_KP_ADD => .KeypadAdd,
        glfw.GLFW_KEY_KP_ENTER => .KeypadEnter,
        glfw.GLFW_KEY_KP_EQUAL => .KeypadEqual,
        glfw.GLFW_KEY_LEFT_SHIFT => .LeftShift,
        glfw.GLFW_KEY_LEFT_CONTROL => .LeftCtrl,
        glfw.GLFW_KEY_LEFT_ALT => .LeftAlt,
        glfw.GLFW_KEY_LEFT_SUPER => .LeftSuper,
        glfw.GLFW_KEY_RIGHT_SHIFT => .RightShift,
        glfw.GLFW_KEY_RIGHT_CONTROL => .RightCtrl,
        glfw.GLFW_KEY_RIGHT_ALT => .RightAlt,
        glfw.GLFW_KEY_RIGHT_SUPER => .RightSuper,
        glfw.GLFW_KEY_MENU => .Menu,
        glfw.GLFW_KEY_0 => .@"0",
        glfw.GLFW_KEY_1 => .@"1",
        glfw.GLFW_KEY_2 => .@"2",
        glfw.GLFW_KEY_3 => .@"3",
        glfw.GLFW_KEY_4 => .@"4",
        glfw.GLFW_KEY_5 => .@"5",
        glfw.GLFW_KEY_6 => .@"6",
        glfw.GLFW_KEY_7 => .@"7",
        glfw.GLFW_KEY_8 => .@"8",
        glfw.GLFW_KEY_9 => .@"9",
        glfw.GLFW_KEY_A => .A,
        glfw.GLFW_KEY_B => .B,
        glfw.GLFW_KEY_C => .C,
        glfw.GLFW_KEY_D => .D,
        glfw.GLFW_KEY_E => .E,
        glfw.GLFW_KEY_F => .F,
        glfw.GLFW_KEY_G => .G,
        glfw.GLFW_KEY_H => .H,
        glfw.GLFW_KEY_I => .I,
        glfw.GLFW_KEY_J => .J,
        glfw.GLFW_KEY_K => .K,
        glfw.GLFW_KEY_L => .L,
        glfw.GLFW_KEY_M => .M,
        glfw.GLFW_KEY_N => .N,
        glfw.GLFW_KEY_O => .O,
        glfw.GLFW_KEY_P => .P,
        glfw.GLFW_KEY_Q => .Q,
        glfw.GLFW_KEY_R => .R,
        glfw.GLFW_KEY_S => .S,
        glfw.GLFW_KEY_T => .T,
        glfw.GLFW_KEY_U => .U,
        glfw.GLFW_KEY_V => .V,
        glfw.GLFW_KEY_W => .W,
        glfw.GLFW_KEY_X => .X,
        glfw.GLFW_KEY_Y => .Y,
        glfw.GLFW_KEY_Z => .Z,
        glfw.GLFW_KEY_F1 => .F1,
        glfw.GLFW_KEY_F2 => .F2,
        glfw.GLFW_KEY_F3 => .F3,
        glfw.GLFW_KEY_F4 => .F4,
        glfw.GLFW_KEY_F5 => .F5,
        glfw.GLFW_KEY_F6 => .F6,
        glfw.GLFW_KEY_F7 => .F7,
        glfw.GLFW_KEY_F8 => .F8,
        glfw.GLFW_KEY_F9 => .F9,
        glfw.GLFW_KEY_F10 => .F10,
        glfw.GLFW_KEY_F11 => .F11,
        glfw.GLFW_KEY_F12 => .F12,
        else => .None,
    };
}

fn KeyToModifier(key: i32) ?i32 {
    if (key == glfw.GLFW_KEY_LEFT_CONTROL or key == glfw.GLFW_KEY_RIGHT_CONTROL)
        return glfw.GLFW_MOD_CONTROL;
    if (key == glfw.GLFW_KEY_LEFT_SHIFT or key == glfw.GLFW_KEY_RIGHT_SHIFT)
        return glfw.GLFW_MOD_SHIFT;
    if (key == glfw.GLFW_KEY_LEFT_ALT or key == glfw.GLFW_KEY_RIGHT_ALT)
        return glfw.GLFW_MOD_ALT;
    if (key == glfw.GLFW_KEY_LEFT_SUPER or key == glfw.GLFW_KEY_RIGHT_SUPER)
        return glfw.GLFW_MOD_SUPER;
    return null;
}

fn UpdateKeyModifiers(mods: i32) void {
    const io = imgui.GetIO();
    io.AddKeyEvent(.ModCtrl, (mods & glfw.GLFW_MOD_CONTROL) != 0);
    io.AddKeyEvent(.ModShift, (mods & glfw.GLFW_MOD_SHIFT) != 0);
    io.AddKeyEvent(.ModAlt, (mods & glfw.GLFW_MOD_ALT) != 0);
    io.AddKeyEvent(.ModSuper, (mods & glfw.GLFW_MOD_SUPER) != 0);
}

pub fn MouseButtonCallback(window: *glfw.GLFWwindow, button: i32, action: i32, mods: i32) callconv(.C) void {
    const bd = GetBackendData().?;
    if (bd.PrevUserCallbackMousebutton != null and window == bd.Window)
        bd.PrevUserCallbackMousebutton.?(window, button, action, mods);

    UpdateKeyModifiers(mods);

    const io = imgui.GetIO();
    if (button >= 0 and button < imgui.MouseButton.COUNT)
        io.AddMouseButtonEvent(button, action == glfw.GLFW_PRESS);
}

pub fn ScrollCallback(window: *glfw.GLFWwindow, xoffset: f64, yoffset: f64) callconv(.C) void {
    const bd = GetBackendData().?;
    if (bd.PrevUserCallbackScroll != null and window == bd.Window)
        bd.PrevUserCallbackScroll.?(window, xoffset, yoffset);

    const io = imgui.GetIO();
    io.AddMouseWheelEvent(@floatCast(f32, xoffset), @floatCast(f32, yoffset));
}

fn TranslateUntranslatedKey(raw_key: i32, scancode: i32) i32 {
    if (GLFW_HAS_GET_KEY_NAME and !IS_EMSCRIPTEN) {
        // GLFW 3.1+ attempts to "untranslate" keys, which goes the opposite of what every other framework does, making using lettered shortcuts difficult.
        // (It had reasons to do so: namely GLFW is/was more likely to be used for WASD-type game controls rather than lettered shortcuts, but IHMO the 3.1 change could have been done differently)
        // See https://github.com/glfw/glfw/issues/1502 for details.
        // Adding a workaround to undo this (so our keys are translated->untranslated->translated, likely a lossy process).
        // This won't cover edge cases but this is at least going to cover common cases.
        if (raw_key >= glfw.GLFW_KEY_KP_0 and raw_key <= glfw.GLFW_KEY_KP_EQUAL)
            return raw_key;
        if (glfw.glfwGetKeyName(raw_key, scancode)) |key_name| {
            if (key_name[0] != 0 and key_name[1] == 0) {
                const char_names = "`-=[]\\,;\'./";
                const char_keys = [_]u8{ glfw.GLFW_KEY_GRAVE_ACCENT, glfw.GLFW_KEY_MINUS, glfw.GLFW_KEY_EQUAL, glfw.GLFW_KEY_LEFT_BRACKET, glfw.GLFW_KEY_RIGHT_BRACKET, glfw.GLFW_KEY_BACKSLASH, glfw.GLFW_KEY_COMMA, glfw.GLFW_KEY_SEMICOLON, glfw.GLFW_KEY_APOSTROPHE, glfw.GLFW_KEY_PERIOD, glfw.GLFW_KEY_SLASH };
                comptime assert(char_names.len == char_keys.len);
                if (key_name[0] >= '0' and key_name[0] <= '9') {
                    return glfw.GLFW_KEY_0 + (key_name[0] - '0');
                } else if (key_name[0] >= 'A' and key_name[0] <= 'Z') {
                    return glfw.GLFW_KEY_A + (key_name[0] - 'A');
                } else if (key_name[0] >= 'a' and key_name[0] <= 'z') {
                    return glfw.GLFW_KEY_A + (key_name[0] - 'a');
                } else if (std.mem.indexOfScalar(u8, char_names, key_name[0])) |idx| {
                    return char_keys[idx];
                }
            }
        }
        // if (action == GLFW_PRESS) std.debug.print("key {} scancode {} name '{s}'\n", .{ key, scancode, key_name });
    }
    return raw_key;
}

pub fn KeyCallback(window: *glfw.GLFWwindow, raw_keycode: i32, scancode: i32, action: i32, mods: i32) callconv(.C) void {
    const bd = GetBackendData().?;
    if (bd.PrevUserCallbackKey != null and window == bd.Window)
        bd.PrevUserCallbackKey.?(window, raw_keycode, scancode, action, mods);

    if (action != glfw.GLFW_PRESS and action != glfw.GLFW_RELEASE)
        return;

    // Workaround: X11 does not include current pressed/released modifier key in 'mods' flags. https://github.com/glfw/glfw/issues/1630
    var key_mods = mods;
    if (KeyToModifier(raw_keycode)) |keycode_to_mod|
        key_mods = if (action == glfw.GLFW_PRESS) (mods | keycode_to_mod) else (mods & ~keycode_to_mod);
    UpdateKeyModifiers(key_mods);

    const keycode = TranslateUntranslatedKey(raw_keycode, scancode);

    const io = imgui.GetIO();
    const imgui_key = KeyToImGuiKey(keycode);
    io.AddKeyEvent(imgui_key, (action == glfw.GLFW_PRESS));
    io.SetKeyEventNativeData(imgui_key, keycode, scancode); // To support legacy indexing (<1.87 user code)
}

pub fn WindowFocusCallback(window: *glfw.GLFWwindow, focused: i32) callconv(.C) void {
    const bd = GetBackendData().?;
    if (bd.PrevUserCallbackWindowFocus != null and window == bd.Window)
        bd.PrevUserCallbackWindowFocus.?(window, focused);

    const io = imgui.GetIO();
    io.AddFocusEvent(focused != 0);
}

pub fn CursorPosCallback(window: *glfw.GLFWwindow, x: f64, y: f64) callconv(.C) void {
    const bd = GetBackendData().?;
    if (bd.PrevUserCallbackCursorPos != null and window == bd.Window)
        bd.PrevUserCallbackCursorPos.?(window, x, y);

    const io = imgui.GetIO();
    io.AddMousePosEvent(@floatCast(f32, x), @floatCast(f32, y));
    bd.LastValidMousePos = .{ .x = @floatCast(f32, x), .y = @floatCast(f32, y) };
}

// Workaround: X11 seems to send spurious Leave/Enter events which would make us lose our position,
// so we back it up and restore on Leave/Enter (see https://github.com/ocornut/imgui/issues/4984)
pub fn CursorEnterCallback(window: *glfw.GLFWwindow, entered: i32) callconv(.C) void {
    const bd = GetBackendData().?;
    if (bd.PrevUserCallbackCursorEnter != null and window == bd.Window)
        bd.PrevUserCallbackCursorEnter.?(window, entered);

    const io = imgui.GetIO();
    if (entered != 0) {
        bd.MouseWindow = window;
        io.AddMousePosEvent(bd.LastValidMousePos.x, bd.LastValidMousePos.y);
    } else if (entered == 0 and bd.MouseWindow == window) {
        bd.LastValidMousePos = io.MousePos;
        bd.MouseWindow = null;
        io.AddMousePosEvent(-imgui.FLT_MAX, -imgui.FLT_MAX);
    }
}

pub fn CharCallback(window: *glfw.GLFWwindow, c: u32) callconv(.C) void {
    const bd = GetBackendData().?;
    if (bd.PrevUserCallbackChar != null and window == bd.Window)
        bd.PrevUserCallbackChar.?(window, c);

    const io = imgui.GetIO();
    io.AddInputCharacter(c);
}

pub fn MonitorCallback(monitor: *glfw.GLFWmonitor, event: i32) callconv(.C) void {
    const bd = GetBackendData().?;
    if (bd.PrevUserCallbackMonitor != null)
        bd.PrevUserCallbackMonitor.?(monitor, event);

    // Unused in 'master' branch but 'docking' branch will use this, so we declare it ahead of it so if you have to install callbacks you can install this one too.
}

pub fn InstallCallbacks(window: *glfw.GLFWwindow) void {
    const bd = GetBackendData().?;
    assert(bd.InstalledCallbacks == false); // Callbacks already installed!
    assert(bd.Window == window);

    bd.PrevUserCallbackWindowFocus = glfw.glfwSetWindowFocusCallback(window, WindowFocusCallback);
    bd.PrevUserCallbackCursorEnter = glfw.glfwSetCursorEnterCallback(window, CursorEnterCallback);
    bd.PrevUserCallbackCursorPos = glfw.glfwSetCursorPosCallback(window, CursorPosCallback);
    bd.PrevUserCallbackMousebutton = glfw.glfwSetMouseButtonCallback(window, MouseButtonCallback);
    bd.PrevUserCallbackScroll = glfw.glfwSetScrollCallback(window, ScrollCallback);
    bd.PrevUserCallbackKey = glfw.glfwSetKeyCallback(window, KeyCallback);
    bd.PrevUserCallbackChar = glfw.glfwSetCharCallback(window, CharCallback);
    bd.PrevUserCallbackMonitor = glfw.glfwSetMonitorCallback(MonitorCallback);
    bd.InstalledCallbacks = true;
}

pub fn RestoreCallbacks(window: *glfw.GLFWwindow) void {
    const bd = GetBackendData().?;
    assert(bd.InstalledCallbacks == true); // Callbacks not installed!
    assert(bd.Window == window);

    _ = glfw.glfwSetWindowFocusCallback(window, bd.PrevUserCallbackWindowFocus);
    _ = glfw.glfwSetCursorEnterCallback(window, bd.PrevUserCallbackCursorEnter);
    _ = glfw.glfwSetCursorPosCallback(window, bd.PrevUserCallbackCursorPos);
    _ = glfw.glfwSetMouseButtonCallback(window, bd.PrevUserCallbackMousebutton);
    _ = glfw.glfwSetScrollCallback(window, bd.PrevUserCallbackScroll);
    _ = glfw.glfwSetKeyCallback(window, bd.PrevUserCallbackKey);
    _ = glfw.glfwSetCharCallback(window, bd.PrevUserCallbackChar);
    _ = glfw.glfwSetMonitorCallback(bd.PrevUserCallbackMonitor);
    bd.InstalledCallbacks = false;
    bd.PrevUserCallbackWindowFocus = null;
    bd.PrevUserCallbackCursorEnter = null;
    bd.PrevUserCallbackCursorPos = null;
    bd.PrevUserCallbackMousebutton = null;
    bd.PrevUserCallbackScroll = null;
    bd.PrevUserCallbackKey = null;
    bd.PrevUserCallbackChar = null;
    bd.PrevUserCallbackMonitor = null;
}

fn Init(window: *glfw.GLFWwindow, install_callbacks: bool, client_api: GlfwClientApi) bool {
    const io = imgui.GetIO();
    assert(io.BackendPlatformUserData == null); // Already initialized a platform backend!

    // Setup backend capabilities flags
    const bd = @ptrCast(*Data, @alignCast(@alignOf(Data), imgui.MemAlloc(@sizeOf(Data))));
    bd.* = .{
        .Window = window,
        .Time = 0,
        .ClientApi = client_api,
    };

    io.BackendPlatformUserData = bd;
    io.BackendPlatformName = "imgui_impl_glfw";
    io.BackendFlags.HasMouseCursors = true; // We can honor GetMouseCursor() values (optional)
    io.BackendFlags.HasSetMousePos = true; // We can honor io.WantSetMousePos requests (optional, rarely used)

    io.SetClipboardTextFn = SetClipboardText;
    io.GetClipboardTextFn = GetClipboardText;
    io.ClipboardUserData = window;

    // Set platform dependent data in viewport
    if (builtin.os.tag == .windows) {
        imgui.GetMainViewport().?.PlatformHandleRaw = glfw.glfwGetWin32Window(window);
    }

    // Create mouse cursors
    // (By design, on X11 cursors are user configurable and some cursors may be missing. When a cursor doesn't exist,
    // GLFW will emit an error which will often be printed by the app, so we temporarily disable error reporting.
    // Missing cursors will return NULL and our _UpdateMouseCursor() function will use the Arrow cursor instead.)
    const prev_error_callback = glfw.glfwSetErrorCallback(null);
    bd.MouseCursors[@enumToInt(imgui.MouseCursor.Arrow)] = glfw.glfwCreateStandardCursor(glfw.GLFW_ARROW_CURSOR);
    bd.MouseCursors[@enumToInt(imgui.MouseCursor.TextInput)] = glfw.glfwCreateStandardCursor(glfw.GLFW_IBEAM_CURSOR);
    bd.MouseCursors[@enumToInt(imgui.MouseCursor.ResizeNS)] = glfw.glfwCreateStandardCursor(glfw.GLFW_VRESIZE_CURSOR);
    bd.MouseCursors[@enumToInt(imgui.MouseCursor.ResizeEW)] = glfw.glfwCreateStandardCursor(glfw.GLFW_HRESIZE_CURSOR);
    bd.MouseCursors[@enumToInt(imgui.MouseCursor.Hand)] = glfw.glfwCreateStandardCursor(glfw.GLFW_HAND_CURSOR);
    if (GLFW_HAS_NEW_CURSORS) {
        bd.MouseCursors[@enumToInt(imgui.MouseCursor.ResizeAll)] = glfw.glfwCreateStandardCursor(glfw.GLFW_RESIZE_ALL_CURSOR);
        bd.MouseCursors[@enumToInt(imgui.MouseCursor.ResizeNESW)] = glfw.glfwCreateStandardCursor(glfw.GLFW_RESIZE_NESW_CURSOR);
        bd.MouseCursors[@enumToInt(imgui.MouseCursor.ResizeNWSE)] = glfw.glfwCreateStandardCursor(glfw.GLFW_RESIZE_NWSE_CURSOR);
        bd.MouseCursors[@enumToInt(imgui.MouseCursor.NotAllowed)] = glfw.glfwCreateStandardCursor(glfw.GLFW_NOT_ALLOWED_CURSOR);
    } else {
        bd.MouseCursors[@enumToInt(imgui.MouseCursor.ResizeAll)] = glfw.glfwCreateStandardCursor(glfw.GLFW_ARROW_CURSOR);
        bd.MouseCursors[@enumToInt(imgui.MouseCursor.ResizeNESW)] = glfw.glfwCreateStandardCursor(glfw.GLFW_ARROW_CURSOR);
        bd.MouseCursors[@enumToInt(imgui.MouseCursor.ResizeNWSE)] = glfw.glfwCreateStandardCursor(glfw.GLFW_ARROW_CURSOR);
        bd.MouseCursors[@enumToInt(imgui.MouseCursor.NotAllowed)] = glfw.glfwCreateStandardCursor(glfw.GLFW_ARROW_CURSOR);
    }
    _ = glfw.glfwSetErrorCallback(prev_error_callback);

    // Chain GLFW callbacks: our callbacks will call the user's previously installed callbacks, if any.
    if (install_callbacks)
        InstallCallbacks(window);

    return true;
}

pub fn InitForOpenGL(window: *glfw.GLFWwindow, install_callbacks: bool) bool {
    return Init(window, install_callbacks, .OpenGL);
}

pub fn InitForVulkan(window: *glfw.GLFWwindow, install_callbacks: bool) bool {
    return Init(window, install_callbacks, .Vulkan);
}

pub fn InitForOther(window: *glfw.GLFWwindow, install_callbacks: bool) bool {
    return Init(window, install_callbacks, .Unknown);
}

pub fn Shutdown() void {
    const bd = GetBackendData();
    assert(bd != null); // No platform backend to shutdown, or already shutdown?
    const io = imgui.GetIO();

    if (bd.?.InstalledCallbacks)
        RestoreCallbacks(bd.?.Window.?);

    for (bd.?.MouseCursors) |cursor|
        if (cursor) |c| glfw.glfwDestroyCursor(c);

    io.BackendPlatformName = null;
    io.BackendPlatformUserData = null;
    imgui.MemFree(bd.?);
}

fn UpdateMouseData() void {
    const bd = GetBackendData().?;
    const io = imgui.GetIO();

    const is_app_focused = if (IS_EMSCRIPTEN) true else (glfw.glfwGetWindowAttrib(bd.Window.?, glfw.GLFW_FOCUSED) != 0);
    if (is_app_focused) {
        // (Optional) Set OS mouse position from Dear ImGui if requested (rarely used, only when ImGuiConfigFlags_NavEnableSetMousePos is enabled by user)
        if (io.WantSetMousePos)
            glfw.glfwSetCursorPos(bd.Window.?, io.MousePos.x, io.MousePos.y);

        // (Optional) Fallback to provide mouse position when focused (ImGui_ImplGlfw_CursorPosCallback already provides this when hovered or captured)
        if (is_app_focused and bd.MouseWindow == null) {
            var mouse_x: f64 = 0;
            var mouse_y: f64 = 0;
            glfw.glfwGetCursorPos(bd.Window.?, &mouse_x, &mouse_y);
            io.AddMousePosEvent(@floatCast(f32, mouse_x), @floatCast(f32, mouse_y));
            bd.LastValidMousePos = .{ .x = @floatCast(f32, mouse_x), .y = @floatCast(f32, mouse_y) };
        }
    }
}

fn UpdateMouseCursor() void {
    const bd = GetBackendData().?;
    const io = imgui.GetIO();
    if ((io.ConfigFlags.NoMouseCursorChange) or glfw.glfwGetInputMode(bd.Window.?, glfw.GLFW_CURSOR) == glfw.GLFW_CURSOR_DISABLED)
        return;

    const imgui_cursor = imgui.GetMouseCursor();
    if (imgui_cursor == .None or io.MouseDrawCursor) {
        // Hide OS mouse cursor if imgui is drawing it or if it wants no cursor
        glfw.glfwSetInputMode(bd.Window.?, glfw.GLFW_CURSOR, glfw.GLFW_CURSOR_HIDDEN);
    } else {
        // Show OS mouse cursor
        // FIXME-PLATFORM: Unfocused windows seems to fail changing the mouse cursor with GLFW 3.2, but 3.3 works here.
        glfw.glfwSetCursor(bd.Window.?, bd.MouseCursors[@intCast(usize, @enumToInt(imgui_cursor))] orelse bd.MouseCursors[@intCast(usize, @enumToInt(imgui.MouseCursor.Arrow))]);
        glfw.glfwSetInputMode(bd.Window.?, glfw.GLFW_CURSOR, glfw.GLFW_CURSOR_NORMAL);
    }
}

// Update gamepad inputs
inline fn Saturate(v: f32) f32 {
    return if (v < 0) 0 else if (v > 1) 1 else v;
}

fn UpdateGamepads() void {
    const io = imgui.GetIO();
    if (!io.ConfigFlags.NavEnableGamepad)
        return;

    const InputKind = enum { Button, Analog };
    const Mapping = struct { kind: InputKind, key: imgui.Key, btn: u32, low: f32 = 0, high: f32 = 0 };
    const mappings = [_]Mapping{
        .{ .kind = .Button, .key = .GamepadStart, .btn = glfw.GLFW_GAMEPAD_BUTTON_START },
        .{ .kind = .Button, .key = .GamepadBack, .btn = glfw.GLFW_GAMEPAD_BUTTON_BACK },
        .{ .kind = .Button, .key = .GamepadFaceDown, .btn = glfw.GLFW_GAMEPAD_BUTTON_A }, // Xbox A, PS Cross
        .{ .kind = .Button, .key = .GamepadFaceRight, .btn = glfw.GLFW_GAMEPAD_BUTTON_B }, // Xbox B, PS Circle
        .{ .kind = .Button, .key = .GamepadFaceLeft, .btn = glfw.GLFW_GAMEPAD_BUTTON_X }, // Xbox X, PS Square
        .{ .kind = .Button, .key = .GamepadFaceUp, .btn = glfw.GLFW_GAMEPAD_BUTTON_Y }, // Xbox Y, PS Triangle
        .{ .kind = .Button, .key = .GamepadDpadLeft, .btn = glfw.GLFW_GAMEPAD_BUTTON_DPAD_LEFT },
        .{ .kind = .Button, .key = .GamepadDpadRight, .btn = glfw.GLFW_GAMEPAD_BUTTON_DPAD_RIGHT },
        .{ .kind = .Button, .key = .GamepadDpadUp, .btn = glfw.GLFW_GAMEPAD_BUTTON_DPAD_UP },
        .{ .kind = .Button, .key = .GamepadDpadDown, .btn = glfw.GLFW_GAMEPAD_BUTTON_DPAD_DOWN },
        .{ .kind = .Button, .key = .GamepadL1, .btn = glfw.GLFW_GAMEPAD_BUTTON_LEFT_BUMPER },
        .{ .kind = .Button, .key = .GamepadR1, .btn = glfw.GLFW_GAMEPAD_BUTTON_RIGHT_BUMPER },
        .{ .kind = .Analog, .key = .GamepadL2, .btn = glfw.GLFW_GAMEPAD_AXIS_LEFT_TRIGGER, .low = -0.75, .high = 1.0 },
        .{ .kind = .Analog, .key = .GamepadR2, .btn = glfw.GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER, .low = -0.75, .high = 1.0 },
        .{ .kind = .Button, .key = .GamepadL3, .btn = glfw.GLFW_GAMEPAD_BUTTON_LEFT_THUMB },
        .{ .kind = .Button, .key = .GamepadR3, .btn = glfw.GLFW_GAMEPAD_BUTTON_RIGHT_THUMB },
        .{ .kind = .Analog, .key = .GamepadLStickLeft, .btn = glfw.GLFW_GAMEPAD_AXIS_LEFT_X, .low = -0.25, .high = -1.0 },
        .{ .kind = .Analog, .key = .GamepadLStickRight, .btn = glfw.GLFW_GAMEPAD_AXIS_LEFT_X, .low = 0.25, .high = 1.0 },
        .{ .kind = .Analog, .key = .GamepadLStickUp, .btn = glfw.GLFW_GAMEPAD_AXIS_LEFT_Y, .low = -0.25, .high = -1.0 },
        .{ .kind = .Analog, .key = .GamepadLStickDown, .btn = glfw.GLFW_GAMEPAD_AXIS_LEFT_Y, .low = 0.25, .high = 1.0 },
        .{ .kind = .Analog, .key = .GamepadRStickLeft, .btn = glfw.GLFW_GAMEPAD_AXIS_RIGHT_X, .low = -0.25, .high = -1.0 },
        .{ .kind = .Analog, .key = .GamepadRStickRight, .btn = glfw.GLFW_GAMEPAD_AXIS_RIGHT_X, .low = 0.25, .high = 1.0 },
        .{ .kind = .Analog, .key = .GamepadRStickUp, .btn = glfw.GLFW_GAMEPAD_AXIS_RIGHT_Y, .low = -0.25, .high = -1.0 },
        .{ .kind = .Analog, .key = .GamepadRStickDown, .btn = glfw.GLFW_GAMEPAD_AXIS_RIGHT_Y, .low = 0.25, .high = 1.0 },
    };

    io.BackendFlags.HasGamepad = false;
    if (GLFW_HAS_GAMEPAD_API) {
        var gamepad: glfw.GLFWgamepadstate = undefined;
        if (glfw.glfwGetGamepadState(glfw.GLFW_JOYSTICK_1, &gamepad) == 0)
            return;
        inline for (mappings) |m| switch (m.kind) {
            .Button => io.AddKeyEvent(m.key, gamepad.buttons[m.btn] != 0),
            .Analog => {
                var v = gamepad.axes[m.btn];
                v = (v - m.low) / (m.high - m.low);
                io.AddKeyAnalogEvent(m.key, v > 0.1, Saturate(v));
            },
        };
    } else {
        var axes_count: c_int = 0;
        var buttons_count: c_int = 0;
        const axes = glfw.glfwGetJoystickAxes(glfw.GLFW_JOYSTICK_1, &axes_count);
        const buttons = glfw.glfwGetJoystickButtons(glfw.GLFW_JOYSTICK_1, &buttons_count);
        if (axes_count == 0 or buttons_count == 0)
            return;

        inline for (mappings) |m| switch (m.kind) {
            .Button => io.AddKeyEvent(m.key, m.btn > buttons_count and buttons.?[m.btn] != 0),
            .Analog => {
                var v: f32 = if (m.btn < axes_count) axes.?[m.btn] else m.low;
                v = (v - m.low) / (m.high - m.low);
                io.AddKeyAnalogEvent(m.key, v > 0.1, Saturate(v));
            },
        };
    }
    io.BackendFlags.HasGamepad = true;
}

pub fn NewFrame() void {
    const bd = GetBackendData().?; // Did you call ImGui_ImplGlfw_InitForXXX()?
    const io = imgui.GetIO();

    // Setup display size (every frame to accommodate for window resizing)
    var w: c_int = 0;
    var h: c_int = 0;
    var display_w: c_int = 0;
    var display_h: c_int = 0;
    glfw.glfwGetWindowSize(bd.Window.?, &w, &h);
    glfw.glfwGetFramebufferSize(bd.Window.?, &display_w, &display_h);
    io.DisplaySize = .{ .x = @intToFloat(f32, w), .y = @intToFloat(f32, h) };
    if (w > 0 and h > 0) {
        io.DisplayFramebufferScale = .{
            .x = @intToFloat(f32, display_w) / @intToFloat(f32, w),
            .y = @intToFloat(f32, display_h) / @intToFloat(f32, h),
        };
    }

    // Setup time step
    const current_time = glfw.glfwGetTime();
    io.DeltaTime = if (bd.Time > 0) @floatCast(f32, current_time - bd.Time) else (1.0 / 60.0);
    bd.Time = current_time;

    UpdateMouseData();
    UpdateMouseCursor();

    // Update game controllers (if enabled and available)
    UpdateGamepads();
}
