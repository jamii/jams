//!************************************************************************
//! GLFW 3.3 - www.glfw.org
//! A library for OpenGL, window and input
//!------------------------------------------------------------------------
//! Copyright (c) 2002-2006 Marcus Geelnard
//! Copyright (c) 2006-2019 Camilla Löwy <elmindreda@glfw.org>
//!
//! This software is provided 'as-is', without any express or implied
//! warranty. In no event will the authors be held liable for any damages
//! arising from the use of this software.
//!
//! Permission is granted to anyone to use this software for any purpose,
//! including commercial applications, and to alter it and redistribute it
//! freely, subject to the following restrictions:
//!
//! 1. The origin of this software must not be misrepresented; you must not
//!    claim that you wrote the original software. If you use this software
//!    in a product, an acknowledgment in the product documentation would
//!    be appreciated but is not required.
//!
//! 2. Altered source versions must be plainly marked as such, and must not
//!    be misrepresented as being the original software.
//!
//! 3. This notice may not be removed or altered from any source
//!    distribution.
//!
//!------------------------------------------------------------------------
//! These bindings for Zig are Copyright (c) 2022 Martin Wickham
//!
//! Permission is hereby granted, free of charge, to any person obtaining a copy
//! of this software and associated documentation files (the "Software"), to deal
//! in the Software without restriction, including without limitation the rights
//! to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//! copies of the Software, and to permit persons to whom the Software is
//! furnished to do so, subject to the following conditions:
//!
//! The above copyright notice and this permission notice shall be included in all
//! copies or substantial portions of the Software.
//!
//! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//! AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//! LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//! OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//! SOFTWARE.
//!
//!************************************************************************

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

pub const GLFW_VERSION_MAJOR = 3;
pub const GLFW_VERSION_MINOR = 3;
pub const GLFW_VERSION_REVISION = 7;
pub const GLFW_TRUE = 1;
pub const GLFW_FALSE = 0;

pub const GLFW_RELEASE = 0;
pub const GLFW_PRESS = 1;
pub const GLFW_REPEAT = 2;

pub const GLFW_HAT_CENTERED = 0;
pub const GLFW_HAT_UP = 1;
pub const GLFW_HAT_RIGHT = 2;
pub const GLFW_HAT_DOWN = 4;
pub const GLFW_HAT_LEFT = 8;
pub const GLFW_HAT_RIGHT_UP = (GLFW_HAT_RIGHT | GLFW_HAT_UP);
pub const GLFW_HAT_RIGHT_DOWN = (GLFW_HAT_RIGHT | GLFW_HAT_DOWN);
pub const GLFW_HAT_LEFT_UP = (GLFW_HAT_LEFT | GLFW_HAT_UP);
pub const GLFW_HAT_LEFT_DOWN = (GLFW_HAT_LEFT | GLFW_HAT_DOWN);

pub const GLFW_KEY_UNKNOWN = -1;

pub const GLFW_KEY_SPACE = 32;
pub const GLFW_KEY_APOSTROPHE = 39; // '
pub const GLFW_KEY_COMMA = 44; // ,
pub const GLFW_KEY_MINUS = 45; // -
pub const GLFW_KEY_PERIOD = 46; // .
pub const GLFW_KEY_SLASH = 47; // /
pub const GLFW_KEY_0 = 48;
pub const GLFW_KEY_1 = 49;
pub const GLFW_KEY_2 = 50;
pub const GLFW_KEY_3 = 51;
pub const GLFW_KEY_4 = 52;
pub const GLFW_KEY_5 = 53;
pub const GLFW_KEY_6 = 54;
pub const GLFW_KEY_7 = 55;
pub const GLFW_KEY_8 = 56;
pub const GLFW_KEY_9 = 57;
pub const GLFW_KEY_SEMICOLON = 59; // ;
pub const GLFW_KEY_EQUAL = 61; // =
pub const GLFW_KEY_A = 65;
pub const GLFW_KEY_B = 66;
pub const GLFW_KEY_C = 67;
pub const GLFW_KEY_D = 68;
pub const GLFW_KEY_E = 69;
pub const GLFW_KEY_F = 70;
pub const GLFW_KEY_G = 71;
pub const GLFW_KEY_H = 72;
pub const GLFW_KEY_I = 73;
pub const GLFW_KEY_J = 74;
pub const GLFW_KEY_K = 75;
pub const GLFW_KEY_L = 76;
pub const GLFW_KEY_M = 77;
pub const GLFW_KEY_N = 78;
pub const GLFW_KEY_O = 79;
pub const GLFW_KEY_P = 80;
pub const GLFW_KEY_Q = 81;
pub const GLFW_KEY_R = 82;
pub const GLFW_KEY_S = 83;
pub const GLFW_KEY_T = 84;
pub const GLFW_KEY_U = 85;
pub const GLFW_KEY_V = 86;
pub const GLFW_KEY_W = 87;
pub const GLFW_KEY_X = 88;
pub const GLFW_KEY_Y = 89;
pub const GLFW_KEY_Z = 90;
pub const GLFW_KEY_LEFT_BRACKET = 91; // [
pub const GLFW_KEY_BACKSLASH = 92; // \
pub const GLFW_KEY_RIGHT_BRACKET = 93; // ]
pub const GLFW_KEY_GRAVE_ACCENT = 96; // `
pub const GLFW_KEY_WORLD_1 = 161; // non-US #1
pub const GLFW_KEY_WORLD_2 = 162; // non-US #2

pub const GLFW_KEY_ESCAPE = 256;
pub const GLFW_KEY_ENTER = 257;
pub const GLFW_KEY_TAB = 258;
pub const GLFW_KEY_BACKSPACE = 259;
pub const GLFW_KEY_INSERT = 260;
pub const GLFW_KEY_DELETE = 261;
pub const GLFW_KEY_RIGHT = 262;
pub const GLFW_KEY_LEFT = 263;
pub const GLFW_KEY_DOWN = 264;
pub const GLFW_KEY_UP = 265;
pub const GLFW_KEY_PAGE_UP = 266;
pub const GLFW_KEY_PAGE_DOWN = 267;
pub const GLFW_KEY_HOME = 268;
pub const GLFW_KEY_END = 269;
pub const GLFW_KEY_CAPS_LOCK = 280;
pub const GLFW_KEY_SCROLL_LOCK = 281;
pub const GLFW_KEY_NUM_LOCK = 282;
pub const GLFW_KEY_PRINT_SCREEN = 283;
pub const GLFW_KEY_PAUSE = 284;
pub const GLFW_KEY_F1 = 290;
pub const GLFW_KEY_F2 = 291;
pub const GLFW_KEY_F3 = 292;
pub const GLFW_KEY_F4 = 293;
pub const GLFW_KEY_F5 = 294;
pub const GLFW_KEY_F6 = 295;
pub const GLFW_KEY_F7 = 296;
pub const GLFW_KEY_F8 = 297;
pub const GLFW_KEY_F9 = 298;
pub const GLFW_KEY_F10 = 299;
pub const GLFW_KEY_F11 = 300;
pub const GLFW_KEY_F12 = 301;
pub const GLFW_KEY_F13 = 302;
pub const GLFW_KEY_F14 = 303;
pub const GLFW_KEY_F15 = 304;
pub const GLFW_KEY_F16 = 305;
pub const GLFW_KEY_F17 = 306;
pub const GLFW_KEY_F18 = 307;
pub const GLFW_KEY_F19 = 308;
pub const GLFW_KEY_F20 = 309;
pub const GLFW_KEY_F21 = 310;
pub const GLFW_KEY_F22 = 311;
pub const GLFW_KEY_F23 = 312;
pub const GLFW_KEY_F24 = 313;
pub const GLFW_KEY_F25 = 314;
pub const GLFW_KEY_KP_0 = 320;
pub const GLFW_KEY_KP_1 = 321;
pub const GLFW_KEY_KP_2 = 322;
pub const GLFW_KEY_KP_3 = 323;
pub const GLFW_KEY_KP_4 = 324;
pub const GLFW_KEY_KP_5 = 325;
pub const GLFW_KEY_KP_6 = 326;
pub const GLFW_KEY_KP_7 = 327;
pub const GLFW_KEY_KP_8 = 328;
pub const GLFW_KEY_KP_9 = 329;
pub const GLFW_KEY_KP_DECIMAL = 330;
pub const GLFW_KEY_KP_DIVIDE = 331;
pub const GLFW_KEY_KP_MULTIPLY = 332;
pub const GLFW_KEY_KP_SUBTRACT = 333;
pub const GLFW_KEY_KP_ADD = 334;
pub const GLFW_KEY_KP_ENTER = 335;
pub const GLFW_KEY_KP_EQUAL = 336;
pub const GLFW_KEY_LEFT_SHIFT = 340;
pub const GLFW_KEY_LEFT_CONTROL = 341;
pub const GLFW_KEY_LEFT_ALT = 342;
pub const GLFW_KEY_LEFT_SUPER = 343;
pub const GLFW_KEY_RIGHT_SHIFT = 344;
pub const GLFW_KEY_RIGHT_CONTROL = 345;
pub const GLFW_KEY_RIGHT_ALT = 346;
pub const GLFW_KEY_RIGHT_SUPER = 347;
pub const GLFW_KEY_MENU = 348;

pub const GLFW_KEY_LAST = GLFW_KEY_MENU;

pub const GLFW_MOD_SHIFT = 0x0001;
pub const GLFW_MOD_CONTROL = 0x0002;
pub const GLFW_MOD_ALT = 0x0004;
pub const GLFW_MOD_SUPER = 0x0008;
pub const GLFW_MOD_CAPS_LOCK = 0x0010;
pub const GLFW_MOD_NUM_LOCK = 0x0020;

pub const GLFW_MOUSE_BUTTON_1 = 0;
pub const GLFW_MOUSE_BUTTON_2 = 1;
pub const GLFW_MOUSE_BUTTON_3 = 2;
pub const GLFW_MOUSE_BUTTON_4 = 3;
pub const GLFW_MOUSE_BUTTON_5 = 4;
pub const GLFW_MOUSE_BUTTON_6 = 5;
pub const GLFW_MOUSE_BUTTON_7 = 6;
pub const GLFW_MOUSE_BUTTON_8 = 7;
pub const GLFW_MOUSE_BUTTON_LAST = GLFW_MOUSE_BUTTON_8;
pub const GLFW_MOUSE_BUTTON_LEFT = GLFW_MOUSE_BUTTON_1;
pub const GLFW_MOUSE_BUTTON_RIGHT = GLFW_MOUSE_BUTTON_2;
pub const GLFW_MOUSE_BUTTON_MIDDLE = GLFW_MOUSE_BUTTON_3;

pub const GLFW_JOYSTICK_1 = 0;
pub const GLFW_JOYSTICK_2 = 1;
pub const GLFW_JOYSTICK_3 = 2;
pub const GLFW_JOYSTICK_4 = 3;
pub const GLFW_JOYSTICK_5 = 4;
pub const GLFW_JOYSTICK_6 = 5;
pub const GLFW_JOYSTICK_7 = 6;
pub const GLFW_JOYSTICK_8 = 7;
pub const GLFW_JOYSTICK_9 = 8;
pub const GLFW_JOYSTICK_10 = 9;
pub const GLFW_JOYSTICK_11 = 10;
pub const GLFW_JOYSTICK_12 = 11;
pub const GLFW_JOYSTICK_13 = 12;
pub const GLFW_JOYSTICK_14 = 13;
pub const GLFW_JOYSTICK_15 = 14;
pub const GLFW_JOYSTICK_16 = 15;
pub const GLFW_JOYSTICK_LAST = GLFW_JOYSTICK_16;

pub const GLFW_GAMEPAD_BUTTON_A = 0;
pub const GLFW_GAMEPAD_BUTTON_B = 1;
pub const GLFW_GAMEPAD_BUTTON_X = 2;
pub const GLFW_GAMEPAD_BUTTON_Y = 3;
pub const GLFW_GAMEPAD_BUTTON_LEFT_BUMPER = 4;
pub const GLFW_GAMEPAD_BUTTON_RIGHT_BUMPER = 5;
pub const GLFW_GAMEPAD_BUTTON_BACK = 6;
pub const GLFW_GAMEPAD_BUTTON_START = 7;
pub const GLFW_GAMEPAD_BUTTON_GUIDE = 8;
pub const GLFW_GAMEPAD_BUTTON_LEFT_THUMB = 9;
pub const GLFW_GAMEPAD_BUTTON_RIGHT_THUMB = 10;
pub const GLFW_GAMEPAD_BUTTON_DPAD_UP = 11;
pub const GLFW_GAMEPAD_BUTTON_DPAD_RIGHT = 12;
pub const GLFW_GAMEPAD_BUTTON_DPAD_DOWN = 13;
pub const GLFW_GAMEPAD_BUTTON_DPAD_LEFT = 14;
pub const GLFW_GAMEPAD_BUTTON_LAST = GLFW_GAMEPAD_BUTTON_DPAD_LEFT;

pub const GLFW_GAMEPAD_BUTTON_CROSS = GLFW_GAMEPAD_BUTTON_A;
pub const GLFW_GAMEPAD_BUTTON_CIRCLE = GLFW_GAMEPAD_BUTTON_B;
pub const GLFW_GAMEPAD_BUTTON_SQUARE = GLFW_GAMEPAD_BUTTON_X;
pub const GLFW_GAMEPAD_BUTTON_TRIANGLE = GLFW_GAMEPAD_BUTTON_Y;

pub const GLFW_GAMEPAD_AXIS_LEFT_X = 0;
pub const GLFW_GAMEPAD_AXIS_LEFT_Y = 1;
pub const GLFW_GAMEPAD_AXIS_RIGHT_X = 2;
pub const GLFW_GAMEPAD_AXIS_RIGHT_Y = 3;
pub const GLFW_GAMEPAD_AXIS_LEFT_TRIGGER = 4;
pub const GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER = 5;
pub const GLFW_GAMEPAD_AXIS_LAST = GLFW_GAMEPAD_AXIS_RIGHT_TRIGGER;

pub const GLFW_NO_ERROR = 0;
pub const GLFW_NOT_INITIALIZED = 0x00010001;
pub const GLFW_NO_CURRENT_CONTEXT = 0x00010002;
pub const GLFW_INVALID_ENUM = 0x00010003;
pub const GLFW_INVALID_VALUE = 0x00010004;
pub const GLFW_OUT_OF_MEMORY = 0x00010005;
pub const GLFW_API_UNAVAILABLE = 0x00010006;
pub const GLFW_VERSION_UNAVAILABLE = 0x00010007;
pub const GLFW_PLATFORM_ERROR = 0x00010008;
pub const GLFW_FORMAT_UNAVAILABLE = 0x00010009;
pub const GLFW_NO_WINDOW_CONTEXT = 0x0001000A;

pub const GLFW_FOCUSED = 0x00020001;
pub const GLFW_ICONIFIED = 0x00020002;
pub const GLFW_RESIZABLE = 0x00020003;
pub const GLFW_VISIBLE = 0x00020004;
pub const GLFW_DECORATED = 0x00020005;
pub const GLFW_AUTO_ICONIFY = 0x00020006;
pub const GLFW_FLOATING = 0x00020007;
pub const GLFW_MAXIMIZED = 0x00020008;
pub const GLFW_CENTER_CURSOR = 0x00020009;
pub const GLFW_TRANSPARENT_FRAMEBUFFER = 0x0002000A;
pub const GLFW_HOVERED = 0x0002000B;
pub const GLFW_FOCUS_ON_SHOW = 0x0002000C;

pub const GLFW_RED_BITS = 0x00021001;
pub const GLFW_GREEN_BITS = 0x00021002;
pub const GLFW_BLUE_BITS = 0x00021003;
pub const GLFW_ALPHA_BITS = 0x00021004;
pub const GLFW_DEPTH_BITS = 0x00021005;
pub const GLFW_STENCIL_BITS = 0x00021006;
pub const GLFW_ACCUM_RED_BITS = 0x00021007;
pub const GLFW_ACCUM_GREEN_BITS = 0x00021008;
pub const GLFW_ACCUM_BLUE_BITS = 0x00021009;
pub const GLFW_ACCUM_ALPHA_BITS = 0x0002100A;
pub const GLFW_AUX_BUFFERS = 0x0002100B;
pub const GLFW_STEREO = 0x0002100C;
pub const GLFW_SAMPLES = 0x0002100D;
pub const GLFW_SRGB_CAPABLE = 0x0002100E;
pub const GLFW_REFRESH_RATE = 0x0002100F;
pub const GLFW_DOUBLEBUFFER = 0x00021010;

pub const GLFW_CLIENT_API = 0x00022001;
pub const GLFW_CONTEXT_VERSION_MAJOR = 0x00022002;
pub const GLFW_CONTEXT_VERSION_MINOR = 0x00022003;
pub const GLFW_CONTEXT_REVISION = 0x00022004;
pub const GLFW_CONTEXT_ROBUSTNESS = 0x00022005;
pub const GLFW_OPENGL_FORWARD_COMPAT = 0x00022006;
pub const GLFW_OPENGL_DEBUG_CONTEXT = 0x00022007;
pub const GLFW_OPENGL_PROFILE = 0x00022008;
pub const GLFW_CONTEXT_RELEASE_BEHAVIOR = 0x00022009;
pub const GLFW_CONTEXT_NO_ERROR = 0x0002200A;
pub const GLFW_CONTEXT_CREATION_API = 0x0002200B;
pub const GLFW_SCALE_TO_MONITOR = 0x0002200C;
pub const GLFW_COCOA_RETINA_FRAMEBUFFER = 0x00023001;
pub const GLFW_COCOA_FRAME_NAME = 0x00023002;
pub const GLFW_COCOA_GRAPHICS_SWITCHING = 0x00023003;
pub const GLFW_X11_CLASS_NAME = 0x00024001;
pub const GLFW_X11_INSTANCE_NAME = 0x00024002;

pub const GLFW_NO_API = 0;
pub const GLFW_OPENGL_API = 0x00030001;
pub const GLFW_OPENGL_ES_API = 0x00030002;

pub const GLFW_NO_ROBUSTNESS = 0;
pub const GLFW_NO_RESET_NOTIFICATION = 0x00031001;
pub const GLFW_LOSE_CONTEXT_ON_RESET = 0x00031002;

pub const GLFW_OPENGL_ANY_PROFILE = 0;
pub const GLFW_OPENGL_CORE_PROFILE = 0x00032001;
pub const GLFW_OPENGL_COMPAT_PROFILE = 0x00032002;

pub const GLFW_CURSOR = 0x00033001;
pub const GLFW_STICKY_KEYS = 0x00033002;
pub const GLFW_STICKY_MOUSE_BUTTONS = 0x00033003;
pub const GLFW_LOCK_KEY_MODS = 0x00033004;
pub const GLFW_RAW_MOUSE_MOTION = 0x00033005;

pub const GLFW_CURSOR_NORMAL = 0x00034001;
pub const GLFW_CURSOR_HIDDEN = 0x00034002;
pub const GLFW_CURSOR_DISABLED = 0x00034003;

pub const GLFW_ANY_RELEASE_BEHAVIOR = 0;
pub const GLFW_RELEASE_BEHAVIOR_FLUSH = 0x00035001;
pub const GLFW_RELEASE_BEHAVIOR_NONE = 0x00035002;

pub const GLFW_NATIVE_CONTEXT_API = 0x00036001;
pub const GLFW_EGL_CONTEXT_API = 0x00036002;
pub const GLFW_OSMESA_CONTEXT_API = 0x00036003;

pub const GLFW_ARROW_CURSOR = 0x00036001;
pub const GLFW_IBEAM_CURSOR = 0x00036002;
pub const GLFW_CROSSHAIR_CURSOR = 0x00036003;
pub const GLFW_HAND_CURSOR = 0x00036004;
pub const GLFW_HRESIZE_CURSOR = 0x00036005;
pub const GLFW_VRESIZE_CURSOR = 0x00036006;

pub const GLFW_CONNECTED = 0x00040001;
pub const GLFW_DISCONNECTED = 0x00040002;

pub const GLFW_JOYSTICK_HAT_BUTTONS = 0x00050001;
pub const GLFW_COCOA_CHDIR_RESOURCES = 0x00051001;
pub const GLFW_COCOA_MENUBAR = 0x00051002;

pub const GLFW_DONT_CARE = -1;

pub const GLFWglproc = ?fn (...) callconv(.C) void;

pub const GLFWmonitor = opaque {};
pub const GLFWwindow = opaque {};
pub const GLFWcursor = opaque {};

pub const GLFWerrorfun = ?fn (error_code: i32, description: ?[*:0]const u8) callconv(.C) void;
pub const GLFWwindowposfun = ?fn (window: *GLFWwindow, xpos: i32, ypos: i32) callconv(.C) void;
pub const GLFWwindowsizefun = ?fn (window: *GLFWwindow, width: i32, height: i32) callconv(.C) void;
pub const GLFWwindowclosefun = ?fn (window: *GLFWwindow) callconv(.C) void;
pub const GLFWwindowrefreshfun = ?fn (window: *GLFWwindow) callconv(.C) void;
pub const GLFWwindowfocusfun = ?fn (window: *GLFWwindow, focused: i32) callconv(.C) void;
pub const GLFWwindowiconifyfun = ?fn (window: *GLFWwindow, iconified: i32) callconv(.C) void;
pub const GLFWwindowmaximizefun = ?fn (window: *GLFWwindow, maximized: i32) callconv(.C) void;
pub const GLFWframebuffersizefun = ?fn (window: *GLFWwindow, width: i32, height: i32) callconv(.C) void;
pub const GLFWwindowcontentscalefun = ?fn (window: *GLFWwindow, xscale: f32, yscale: f32) callconv(.C) void;
pub const GLFWmousebuttonfun = ?fn (window: *GLFWwindow, button: i32, action: i32, mods: i32) callconv(.C) void;
pub const GLFWcursorposfun = ?fn (window: *GLFWwindow, xpos: f64, ypos: f64) callconv(.C) void;
pub const GLFWcursorenterfun = ?fn (window: *GLFWwindow, entered: i32) callconv(.C) void;
pub const GLFWscrollfun = ?fn (window: *GLFWwindow, xoffset: f64, yoffset: f64) callconv(.C) void;
pub const GLFWkeyfun = ?fn (window: *GLFWwindow, key: i32, scancode: i32, action: i32, mods: i32) callconv(.C) void;
pub const GLFWcharfun = ?fn (window: *GLFWwindow, codepoint: u32) callconv(.C) void;
pub const GLFWcharmodsfun = ?fn (window: *GLFWwindow, codepoint: u32, mods: i32) callconv(.C) void;
pub const GLFWdropfun = ?fn (window: *GLFWwindow, path_count: i32, paths: ?[*]?[*:0]const u8) callconv(.C) void;
pub const GLFWmonitorfun = ?fn (monitor: *GLFWmonitor, event: i32) callconv(.C) void;
pub const GLFWjoystickfun = ?fn (jid: i32, event: i32) callconv(.C) void;

pub const GLFWvidmode = extern struct {
    width: i32,
    height: i32,
    redBits: i32,
    greenBits: i32,
    blueBits: i32,
    refreshRate: i32,
};

pub const GLFWgammaramp = extern struct {
    red: ?[*]u16,
    green: ?[*]u16,
    blue: ?[*]u16,
    size: u32,
};

pub const GLFWimage = extern struct {
    width: i32,
    height: i32,
    pixels: ?[*]u8,
};

pub const GLFWgamepadstate = extern struct {
    buttons: [15]u8,
    axes: [6]f32,
};

pub extern fn glfwInit() callconv(.C) i32;
pub extern fn glfwTerminate() callconv(.C) void;
pub extern fn glfwInitHint(hint: i32, value: i32) callconv(.C) void;

pub extern fn glfwGetVersion(major: ?*i32, minor: ?*i32, rev: ?*i32) callconv(.C) void;
pub extern fn glfwGetVersionString() callconv(.C) [*:0]const u8;

pub extern fn glfwGetError(description: ?*?[*:0]const u8) callconv(.C) i32;
pub extern fn glfwSetErrorCallback(callback: GLFWerrorfun) callconv(.C) GLFWerrorfun;

pub extern fn glfwGetMonitors(count: *i32) callconv(.C) ?[*]const *GLFWmonitor;
pub extern fn glfwGetPrimaryMonitor() callconv(.C) ?*GLFWmonitor;
pub extern fn glfwGetMonitorPos(monitor: *GLFWmonitor, xpos: ?*i32, ypos: ?*i32) callconv(.C) void;
pub extern fn glfwGetMonitorWorkarea(monitor: *GLFWmonitor, xpos: ?*i32, ypos: ?*i32, width: ?*i32, height: ?*i32) callconv(.C) void;
pub extern fn glfwGetMonitorPhysicalSize(monitor: *GLFWmonitor, widthMM: ?*i32, heightMM: ?*i32) callconv(.C) void;
pub extern fn glfwGetMonitorContentScale(monitor: *GLFWmonitor, xscale: ?*f32, yscale: ?*f32) callconv(.C) void;
pub extern fn glfwGetMonitorName(monitor: *GLFWmonitor) callconv(.C) ?[*:0]const u8;
pub extern fn glfwSetMonitorUserPointer(monitor: *GLFWmonitor, pointer: ?*anyopaque) callconv(.C) void;
pub extern fn glfwGetMonitorUserPointer(monitor: *GLFWmonitor) callconv(.C) ?*anyopaque;
pub extern fn glfwSetMonitorCallback(callback: GLFWmonitorfun) callconv(.C) GLFWmonitorfun;
pub extern fn glfwGetVideoModes(monitor: *GLFWmonitor, count: *i32) callconv(.C) ?[*]const GLFWvidmode;
pub extern fn glfwGetVideoMode(monitor: *GLFWmonitor) callconv(.C) ?*const GLFWvidmode;
pub extern fn glfwSetGamma(monitor: *GLFWmonitor, gamma: f32) callconv(.C) void;
pub extern fn glfwGetGammaRamp(monitor: *GLFWmonitor) callconv(.C) ?*const GLFWgammaramp;
pub extern fn glfwSetGammaRamp(monitor: *GLFWmonitor, ramp: *const GLFWgammaramp) callconv(.C) void;

pub extern fn glfwDefaultWindowHints() callconv(.C) void;
pub extern fn glfwWindowHint(hint: i32, value: i32) callconv(.C) void;
pub extern fn glfwWindowHintString(hint: i32, value: [*:0]const u8) callconv(.C) void;
pub extern fn glfwCreateWindow(width: i32, height: i32, title: [*:0]const u8, monitor: ?*GLFWmonitor, share: ?*GLFWwindow) callconv(.C) ?*GLFWwindow;
pub extern fn glfwDestroyWindow(window: *GLFWwindow) callconv(.C) void;

pub extern fn glfwWindowShouldClose(window: *GLFWwindow) callconv(.C) i32;
pub extern fn glfwSetWindowShouldClose(window: *GLFWwindow, value: i32) callconv(.C) void;
pub extern fn glfwSetWindowTitle(window: *GLFWwindow, title: [*:0]const u8) callconv(.C) void;
pub extern fn glfwSetWindowIcon(window: *GLFWwindow, count: i32, images: [*]const GLFWimage) callconv(.C) void;
pub extern fn glfwGetWindowPos(window: *GLFWwindow, xpos: ?*i32, ypos: ?*i32) callconv(.C) void;
pub extern fn glfwSetWindowPos(window: *GLFWwindow, xpos: i32, ypos: i32) callconv(.C) void;
pub extern fn glfwGetWindowSize(window: *GLFWwindow, width: ?*i32, height: ?*i32) callconv(.C) void;
pub extern fn glfwSetWindowSizeLimits(window: *GLFWwindow, minwidth: i32, minheight: i32, maxwidth: i32, maxheight: i32) callconv(.C) void;
pub extern fn glfwSetWindowAspectRatio(window: *GLFWwindow, numer: i32, denom: i32) callconv(.C) void;
pub extern fn glfwSetWindowSize(window: *GLFWwindow, width: i32, height: i32) callconv(.C) void;
pub extern fn glfwGetFramebufferSize(window: *GLFWwindow, width: ?*i32, height: ?*i32) callconv(.C) void;
pub extern fn glfwGetWindowFrameSize(window: *GLFWwindow, left: ?*i32, top: ?*i32, right: ?*i32, bottom: ?*i32) callconv(.C) void;
pub extern fn glfwGetWindowContentScale(window: *GLFWwindow, xscale: ?*f32, yscale: ?*f32) callconv(.C) void;
pub extern fn glfwGetWindowOpacity(window: *GLFWwindow) callconv(.C) f32;
pub extern fn glfwSetWindowOpacity(window: *GLFWwindow, opacity: f32) callconv(.C) void;

pub extern fn glfwIconifyWindow(window: *GLFWwindow) callconv(.C) void;
pub extern fn glfwRestoreWindow(window: *GLFWwindow) callconv(.C) void;
pub extern fn glfwMaximizeWindow(window: *GLFWwindow) callconv(.C) void;
pub extern fn glfwShowWindow(window: *GLFWwindow) callconv(.C) void;
pub extern fn glfwHideWindow(window: *GLFWwindow) callconv(.C) void;
pub extern fn glfwFocusWindow(window: *GLFWwindow) callconv(.C) void;
pub extern fn glfwRequestWindowAttention(window: *GLFWwindow) callconv(.C) void;

pub extern fn glfwGetWindowMonitor(window: *GLFWwindow) callconv(.C) ?*GLFWmonitor;
pub extern fn glfwSetWindowMonitor(window: *GLFWwindow, monitor: ?*GLFWmonitor, xpos: i32, ypos: i32, width: i32, height: i32, refreshRate: i32) callconv(.C) void;
pub extern fn glfwGetWindowAttrib(window: *GLFWwindow, attrib: i32) callconv(.C) i32;
pub extern fn glfwSetWindowAttrib(window: *GLFWwindow, attrib: i32, value: i32) callconv(.C) void;
pub extern fn glfwSetWindowUserPointer(window: *GLFWwindow, pointer: ?*anyopaque) callconv(.C) void;
pub extern fn glfwGetWindowUserPointer(window: *GLFWwindow) callconv(.C) ?*anyopaque;

pub extern fn glfwSetWindowPosCallback(window: *GLFWwindow, callback: GLFWwindowposfun) callconv(.C) GLFWwindowposfun;
pub extern fn glfwSetWindowSizeCallback(window: *GLFWwindow, callback: GLFWwindowsizefun) callconv(.C) GLFWwindowsizefun;
pub extern fn glfwSetWindowCloseCallback(window: *GLFWwindow, callback: GLFWwindowclosefun) callconv(.C) GLFWwindowclosefun;
pub extern fn glfwSetWindowRefreshCallback(window: *GLFWwindow, callback: GLFWwindowrefreshfun) callconv(.C) GLFWwindowrefreshfun;
pub extern fn glfwSetWindowFocusCallback(window: *GLFWwindow, callback: GLFWwindowfocusfun) callconv(.C) GLFWwindowfocusfun;
pub extern fn glfwSetWindowIconifyCallback(window: *GLFWwindow, callback: GLFWwindowiconifyfun) callconv(.C) GLFWwindowiconifyfun;
pub extern fn glfwSetWindowMaximizeCallback(window: *GLFWwindow, callback: GLFWwindowmaximizefun) callconv(.C) GLFWwindowmaximizefun;
pub extern fn glfwSetFramebufferSizeCallback(window: *GLFWwindow, callback: GLFWframebuffersizefun) callconv(.C) GLFWframebuffersizefun;
pub extern fn glfwSetWindowContentScaleCallback(window: *GLFWwindow, callback: GLFWwindowcontentscalefun) callconv(.C) GLFWwindowcontentscalefun;

pub extern fn glfwPollEvents() callconv(.C) void;
pub extern fn glfwWaitEvents() callconv(.C) void;
pub extern fn glfwWaitEventsTimeout(timeout: f64) callconv(.C) void;
pub extern fn glfwPostEmptyEvent() callconv(.C) void;

pub extern fn glfwGetInputMode(window: *GLFWwindow, mode: i32) callconv(.C) i32;
pub extern fn glfwSetInputMode(window: *GLFWwindow, mode: i32, value: i32) callconv(.C) void;
pub extern fn glfwRawMouseMotionSupported() callconv(.C) i32;
pub extern fn glfwGetKeyName(key: i32, scancode: i32) callconv(.C) ?[*:0]const u8;
pub extern fn glfwGetKeyScancode(key: i32) callconv(.C) i32;
pub extern fn glfwGetKey(window: *GLFWwindow, key: i32) callconv(.C) i32;
pub extern fn glfwGetMouseButton(window: *GLFWwindow, button: i32) callconv(.C) i32;

pub extern fn glfwGetCursorPos(window: *GLFWwindow, xpos: ?*f64, ypos: ?*f64) callconv(.C) void;
pub extern fn glfwSetCursorPos(window: *GLFWwindow, xpos: f64, ypos: f64) callconv(.C) void;
pub extern fn glfwCreateCursor(image: *const GLFWimage, xhot: i32, yhot: i32) callconv(.C) ?*GLFWcursor;
pub extern fn glfwCreateStandardCursor(shape: i32) callconv(.C) ?*GLFWcursor;
pub extern fn glfwDestroyCursor(cursor: *GLFWcursor) callconv(.C) void;
pub extern fn glfwSetCursor(window: *GLFWwindow, cursor: ?*GLFWcursor) callconv(.C) void;

pub extern fn glfwSetKeyCallback(window: *GLFWwindow, callback: GLFWkeyfun) callconv(.C) GLFWkeyfun;
pub extern fn glfwSetCharCallback(window: *GLFWwindow, callback: GLFWcharfun) callconv(.C) GLFWcharfun;
pub extern fn glfwSetCharModsCallback(window: *GLFWwindow, callback: GLFWcharmodsfun) callconv(.C) GLFWcharmodsfun;
pub extern fn glfwSetMouseButtonCallback(window: *GLFWwindow, callback: GLFWmousebuttonfun) callconv(.C) GLFWmousebuttonfun;
pub extern fn glfwSetCursorPosCallback(window: *GLFWwindow, callback: GLFWcursorposfun) callconv(.C) GLFWcursorposfun;
pub extern fn glfwSetCursorEnterCallback(window: *GLFWwindow, callback: GLFWcursorenterfun) callconv(.C) GLFWcursorenterfun;
pub extern fn glfwSetScrollCallback(window: *GLFWwindow, callback: GLFWscrollfun) callconv(.C) GLFWscrollfun;
pub extern fn glfwSetDropCallback(window: *GLFWwindow, callback: GLFWdropfun) callconv(.C) GLFWdropfun;

pub extern fn glfwJoystickPresent(jid: i32) callconv(.C) i32;
pub extern fn glfwGetJoystickAxes(jid: i32, count: *i32) callconv(.C) ?[*]const f32;
pub extern fn glfwGetJoystickButtons(jid: i32, count: *i32) callconv(.C) ?[*]const u8;
pub extern fn glfwGetJoystickHats(jid: i32, count: *i32) callconv(.C) ?[*]const u8;
pub extern fn glfwGetJoystickName(jid: i32) callconv(.C) ?[*:0]const u8;
pub extern fn glfwGetJoystickGUID(jid: i32) callconv(.C) ?[*:0]const u8;
pub extern fn glfwSetJoystickUserPointer(jid: i32, pointer: ?*anyopaque) callconv(.C) void;
pub extern fn glfwGetJoystickUserPointer(jid: i32) callconv(.C) ?*anyopaque;
pub extern fn glfwJoystickIsGamepad(jid: i32) callconv(.C) i32;
pub extern fn glfwSetJoystickCallback(callback: GLFWjoystickfun) callconv(.C) GLFWjoystickfun;

pub extern fn glfwUpdateGamepadMappings(string: [*:0]const u8) callconv(.C) i32;
pub extern fn glfwGetGamepadName(jid: i32) callconv(.C) ?[*:0]const u8;
pub extern fn glfwGetGamepadState(jid: i32, state: *GLFWgamepadstate) callconv(.C) i32;
pub extern fn glfwSetClipboardString(window: ?*GLFWwindow, string: [*:0]const u8) callconv(.C) void;
pub extern fn glfwGetClipboardString(window: ?*GLFWwindow) callconv(.C) ?[*:0]const u8;

pub extern fn glfwGetTime() callconv(.C) f64;
pub extern fn glfwSetTime(time: f64) callconv(.C) void;
pub extern fn glfwGetTimerValue() callconv(.C) u64;
pub extern fn glfwGetTimerFrequency() callconv(.C) u64;

pub extern fn glfwMakeContextCurrent(window: ?*GLFWwindow) callconv(.C) void;
pub extern fn glfwGetCurrentContext() callconv(.C) ?*GLFWwindow;

pub extern fn glfwSwapBuffers(window: *GLFWwindow) callconv(.C) void;
pub extern fn glfwSwapInterval(interval: i32) callconv(.C) void;

pub extern fn glfwExtensionSupported(extension: [*:0]const u8) callconv(.C) i32;
pub extern fn glfwGetProcAddress(procname: [*:0]const u8) callconv(.C) GLFWglproc;

pub extern fn glfwGetRequiredInstanceExtensions(count: *u32) callconv(.C) ?[*][*:0]const u8;

pub extern fn glfwGetWin32Adapter(monitor: *GLFWmonitor) ?[*:0]const u8;
pub extern fn glfwGetWin32Monitor(monitor: *GLFWmonitor) ?[*:0]const u8;
pub extern fn glfwGetWin32Window(window: *GLFWwindow) std.os.windows.HWND;
