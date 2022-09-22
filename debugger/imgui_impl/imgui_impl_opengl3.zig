// dear imgui: Renderer Backend for modern OpenGL with shaders / programmatic pipeline
// - Desktop GL: 2.x 3.x 4.x
// - Embedded GL: ES 2.0 (WebGL 1.0), ES 3.0 (WebGL 2.0)
// This needs to be used along with a Platform Backend (e.g. GLFW, SDL, Win32, custom..)

// Implemented features:
//  [X] Renderer: User texture binding. Use 'GLuint' OpenGL texture identifier as void*/ImTextureID. Read the FAQ about ImTextureID!
//  [x] Renderer: Desktop GL only: Support for large meshes (64k+ vertices) with 16-bit indices.

// You can copy and use unmodified imgui_impl_* files in your project. See main.cpp for an example of using this.
// If you are new to dear imgui, read examples/README.txt and read the documentation at the top of imgui.cpp.
// https://github.com/ocornut/imgui

//----------------------------------------
// OpenGL    GLSL      GLSL
// version   version   string
//----------------------------------------
//  2.0       110       "#version 110"
//  2.1       120       "#version 120"
//  3.0       130       "#version 130"
//  3.1       140       "#version 140"
//  3.2       150       "#version 150"
//  3.3       330       "#version 330 core"
//  4.0       400       "#version 400 core"
//  4.1       410       "#version 410 core"
//  4.2       420       "#version 410 core"
//  4.3       430       "#version 430 core"
//  ES 2.0    100       "#version 100"      = WebGL 1.0
//  ES 3.0    300       "#version 300 es"   = WebGL 2.0
//----------------------------------------

const std = @import("std");
const imgui = @import("imgui");
const gl = @import("./gl.zig");
const builtin = @import("builtin");

const assert = std.debug.assert;

const is_darwin = builtin.os.tag.isDarwin();

// Desktop GL 3.2+ has glDrawElementsBaseVertex() which GL ES and WebGL don't have.
const MAY_HAVE_VTX_OFFSET = @hasDecl(gl, "glDrawElementsBaseVertex");
const MAY_HAVE_BIND_SAMPLER = @hasDecl(gl, "glBindSampler");
const MAY_HAVE_PRIMITIVE_RESTART = @hasDecl(gl, "GL_PRIMITIVE_RESTART");
const MAY_HAVE_EXTENSIONS = @hasDecl(gl, "GL_NUM_EXTENSIONS");
const MAY_HAVE_CLIP_ORIGIN = @hasDecl(gl, "GL_CLIP_ORIGIN");
const HAS_POLYGON_MODE = @hasDecl(gl, "glPolygonMode");

// OpenGL Data
const Data = extern struct {
    GlVersion: gl.GLuint = 0, // Extracted at runtime using GL_MAJOR_VERSION, GL_MINOR_VERSION queries.
    GlslVersionString: [32]u8 = undefined, // Specified by user or detected based on compile time GL settings.
    FontTexture: c_uint = 0,
    ShaderHandle: c_uint = 0,
    AttribLocationTex: i32 = 0,
    AttribLocationProjMtx: i32 = 0, // Uniforms location
    AttribLocationVtxPos: i32 = 0,
    AttribLocationVtxUV: i32 = 0,
    AttribLocationVtxColor: i32 = 0, // Vertex attributes location
    VboHandle: c_uint = 0,
    ElementsHandle: c_uint = 0,
    VertexBufferSize: gl.GLsizeiptr = 0,
    IndexBufferSize: gl.GLsizeiptr = 0,
    HasClipOrigin: bool = false,
    UseBufferSubData: bool = false,
};

fn GetBackendData() ?*Data {
    return if (imgui.GetCurrentContext() != null) @ptrCast(?*Data, @alignCast(@alignOf(Data), imgui.GetIO().BackendRendererUserData)) else null;
}

// Functions
pub fn Init(glsl_version_opt: ?[]const u8) bool {
    const io = imgui.GetIO();
    assert(io.BackendRendererUserData == null); // Already initialized a renderer backend

    const bd = @ptrCast(*Data, @alignCast(@alignOf(Data), imgui.MemAlloc(@sizeOf(Data))));
    bd.* = .{};

    io.BackendRendererUserData = bd;
    io.BackendRendererName = "imgui_impl_opengl3";

    // Query for GL version
    var major: gl.GLint = 0;
    var minor: gl.GLint = 0;
    gl.glGetIntegerv(gl.GL_MAJOR_VERSION, &major);
    gl.glGetIntegerv(gl.GL_MINOR_VERSION, &minor);
    if (major == 0 and minor == 0) {
        const gl_version = gl.glGetString(gl.GL_VERSION);
        var it = std.mem.tokenize(u8, std.mem.span(gl_version), ".");
        major = std.fmt.parseInt(gl.GLint, it.next() orelse "0", 10) catch 0;
        minor = std.fmt.parseInt(gl.GLint, it.next() orelse "0", 10) catch 0;
    }
    bd.GlVersion = @intCast(gl.GLuint, major * 100 + minor);

    // Query vendor to enable glBufferSubData kludge
    if (builtin.os.tag == .windows) {
        if (gl.glGetString(gl.GL_VENDOR)) |vendor| {
            if (std.mem.eql(u8, vendor[0..5], "Intel")) {
                bd.UseBufferSubData = true;
            }
        }
    }

    // Setup back-end capabilities flags
    if (MAY_HAVE_VTX_OFFSET and bd.GlVersion >= 320) {
        io.BackendFlags.RendererHasVtxOffset = true; // We can honor the ImDrawCmd::VtxOffset field, allowing for large meshes.
    }

    // Store GLSL version string so we can refer to it later in case we recreate shaders.
    // Note: GLSL version is NOT the same as GL version. Leave this to NULL if unsure.
    const default_glsl_version = if (is_darwin) "#version 150" else "#version 130";
    const glsl_version: []const u8 = glsl_version_opt orelse default_glsl_version;

    assert(glsl_version.len + 2 < bd.GlslVersionString.len);
    std.mem.copy(u8, bd.GlslVersionString[0..glsl_version.len], glsl_version);
    bd.GlslVersionString[glsl_version.len] = '\n';
    bd.GlslVersionString[glsl_version.len + 1] = 0;

    // Make a dummy GL call (we don't actually need the result)
    // IF YOU GET A CRASH HERE: it probably means that you haven't initialized the OpenGL function loader used by this code.
    // Desktop OpenGL 3/4 need a function loader. See the LOADER_xxx explanation above.
    var current_texture: gl.GLint = undefined;
    gl.glGetIntegerv(gl.GL_TEXTURE_BINDING_2D, &current_texture);

    bd.HasClipOrigin = (bd.GlVersion >= 450);
    if (MAY_HAVE_EXTENSIONS) {
        var extensions: gl.GLint = 0;
        gl.glGetIntegerv(gl.GL_NUM_EXTENSIONS, &extensions);
        var i: gl.GLint = 0;
        while (i < extensions) : (i += 1) {
            if (gl.glGetStringi(gl.GL_EXTENSIONS, @intCast(gl.GLuint, i))) |ext_nt| {
                const ext = std.mem.span(ext_nt);
                if (std.mem.eql(u8, ext, "GL_ARB_clip_control"))
                    bd.HasClipOrigin = true;
            }
        }
    }

    return true;
}

pub fn Shutdown() void {
    const bd = GetBackendData().?; // Not initialized or already shutdown?
    const io = imgui.GetIO();

    DestroyDeviceObjects();
    io.BackendRendererName = null;
    io.BackendRendererUserData = null;
    imgui.MemFree(bd);
}

pub fn NewFrame() void {
    const bd = GetBackendData().?; // Did you call Init()?
    if (bd.ShaderHandle == 0) {
        _ = CreateDeviceObjects();
    }
}

fn SetupRenderState(draw_data: *imgui.DrawData, fb_width: c_int, fb_height: c_int, vertex_array_object: gl.GLuint) void {
    const bd = GetBackendData().?;
    // Setup render state: alpha-blending enabled, no face culling, no depth testing, scissor enabled, polygon fill
    gl.glEnable(gl.GL_BLEND);
    gl.glBlendEquation(gl.GL_FUNC_ADD);
    gl.glBlendFuncSeparate(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA, gl.GL_ONE, gl.GL_ONE_MINUS_SRC_ALPHA);
    gl.glDisable(gl.GL_CULL_FACE);
    gl.glDisable(gl.GL_DEPTH_TEST);
    gl.glDisable(gl.GL_STENCIL_TEST);
    gl.glEnable(gl.GL_SCISSOR_TEST);

    if (MAY_HAVE_PRIMITIVE_RESTART and bd.GlVersion >= 310) {
        gl.glDisable(gl.GL_PRIMITIVE_RESTART);
    }
    if (HAS_POLYGON_MODE) {
        gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_FILL);
    }

    // Support for GL 4.5 rarely used glClipControl(GL_UPPER_LEFT)
    var clip_origin_lower_left = true;
    if (MAY_HAVE_CLIP_ORIGIN and bd.HasClipOrigin) {
        var current_clip_origin: gl.GLint = 0;
        gl.glGetIntegerv(gl.GL_CLIP_ORIGIN, &current_clip_origin);
        if (current_clip_origin == gl.GL_UPPER_LEFT)
            clip_origin_lower_left = false;
    }

    // Setup viewport, orthographic projection matrix
    // Our visible imgui space lies from draw_data.DisplayPos (top left) to draw_data.DisplayPos+data_data.DisplaySize (bottom right). DisplayPos is (0,0) for single viewport apps.
    gl.glViewport(0, 0, @intCast(gl.GLsizei, fb_width), @intCast(gl.GLsizei, fb_height));
    var L = draw_data.DisplayPos.x;
    var R = draw_data.DisplayPos.x + draw_data.DisplaySize.x;
    var T = draw_data.DisplayPos.y;
    var B = draw_data.DisplayPos.y + draw_data.DisplaySize.y;
    if (MAY_HAVE_CLIP_ORIGIN and !clip_origin_lower_left) {
        // swap top and bottom if origin is upper left
        const tmp = T;
        T = B;
        B = tmp;
    }
    const ortho_projection = [4][4]f32{
        [4]f32{ 2.0 / (R - L), 0.0, 0.0, 0.0 },
        [4]f32{ 0.0, 2.0 / (T - B), 0.0, 0.0 },
        [4]f32{ 0.0, 0.0, -1.0, 0.0 },
        [4]f32{ (R + L) / (L - R), (T + B) / (B - T), 0.0, 1.0 },
    };
    gl.glUseProgram(bd.ShaderHandle);
    gl.glUniform1i(bd.AttribLocationTex, 0);
    gl.glUniformMatrix4fv(bd.AttribLocationProjMtx, 1, gl.GL_FALSE, &ortho_projection[0][0]);
    if (MAY_HAVE_BIND_SAMPLER and bd.GlVersion >= 330) {
        gl.glBindSampler(0, 0); // We use combined texture/sampler state. Applications using GL 3.3 may set that otherwise.
    }

    gl.glBindVertexArray(vertex_array_object);
    // Bind vertex/index buffers and setup attributes for ImDrawVert
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, bd.VboHandle);
    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, bd.ElementsHandle);
    gl.glEnableVertexAttribArray(@intCast(c_uint, bd.AttribLocationVtxPos));
    gl.glEnableVertexAttribArray(@intCast(c_uint, bd.AttribLocationVtxUV));
    gl.glEnableVertexAttribArray(@intCast(c_uint, bd.AttribLocationVtxColor));
    gl.glVertexAttribPointer(
        @intCast(c_uint, bd.AttribLocationVtxPos),
        2,
        gl.GL_FLOAT,
        gl.GL_FALSE,
        @sizeOf(imgui.DrawVert),
        @intToPtr(?*anyopaque, @offsetOf(imgui.DrawVert, "pos")),
    );
    gl.glVertexAttribPointer(
        @intCast(c_uint, bd.AttribLocationVtxUV),
        2,
        gl.GL_FLOAT,
        gl.GL_FALSE,
        @sizeOf(imgui.DrawVert),
        @intToPtr(?*anyopaque, @offsetOf(imgui.DrawVert, "uv")),
    );
    gl.glVertexAttribPointer(
        @intCast(c_uint, bd.AttribLocationVtxColor),
        4,
        gl.GL_UNSIGNED_BYTE,
        gl.GL_TRUE,
        @sizeOf(imgui.DrawVert),
        @intToPtr(?*anyopaque, @offsetOf(imgui.DrawVert, "col")),
    );
}

fn getGLInt(name: gl.GLenum) gl.GLint {
    var value: gl.GLint = undefined;
    gl.glGetIntegerv(name, &value);
    return value;
}
fn getGLInts(name: gl.GLenum, comptime N: comptime_int) [N]gl.GLint {
    var value: [N]gl.GLint = undefined;
    gl.glGetIntegerv(name, &value);
    return value;
}

// OpenGL3 Render function.
// Note that this implementation is little overcomplicated because we are saving/setting up/restoring every OpenGL state explicitly.
// This is in order to be able to run within any OpenGL engine that doesn't do so.
pub fn RenderDrawData(draw_data: *imgui.DrawData) void {
    // Avoid rendering when minimized, scale coordinates for retina displays (screen coordinates != framebuffer coordinates)
    const fb_width = @floatToInt(c_int, draw_data.DisplaySize.x * draw_data.FramebufferScale.x);
    const fb_height = @floatToInt(c_int, draw_data.DisplaySize.y * draw_data.FramebufferScale.y);
    if (fb_width <= 0 or fb_height <= 0)
        return;

    const bd = GetBackendData().?;

    // Backup GL state
    const last_active_texture = @intCast(gl.GLenum, getGLInt(gl.GL_ACTIVE_TEXTURE));
    gl.glActiveTexture(gl.GL_TEXTURE0);
    const last_program = getGLInt(gl.GL_CURRENT_PROGRAM);
    const last_texture = getGLInt(gl.GL_TEXTURE_BINDING_2D);

    const last_sampler = if (MAY_HAVE_BIND_SAMPLER and bd.GlVersion >= 330) getGLInt(gl.GL_SAMPLER_BINDING) else @as(gl.GLint, 0);
    const last_array_buffer = getGLInt(gl.GL_ARRAY_BUFFER_BINDING);
    const last_vertex_array_object = getGLInt(gl.GL_VERTEX_ARRAY_BINDING);
    const last_polygon_mode = if (HAS_POLYGON_MODE) getGLInts(gl.GL_POLYGON_MODE, 2) else void{};

    const last_viewport = getGLInts(gl.GL_VIEWPORT, 4);
    const last_scissor_box = getGLInts(gl.GL_SCISSOR_BOX, 4);
    const last_blend_src_rgb = @intCast(gl.GLenum, getGLInt(gl.GL_BLEND_SRC_RGB));
    const last_blend_dst_rgb = @intCast(gl.GLenum, getGLInt(gl.GL_BLEND_DST_RGB));
    const last_blend_src_alpha = @intCast(gl.GLenum, getGLInt(gl.GL_BLEND_SRC_ALPHA));
    const last_blend_dst_alpha = @intCast(gl.GLenum, getGLInt(gl.GL_BLEND_DST_ALPHA));
    const last_blend_equation_rgb = @intCast(gl.GLenum, getGLInt(gl.GL_BLEND_EQUATION_RGB));
    const last_blend_equation_alpha = @intCast(gl.GLenum, getGLInt(gl.GL_BLEND_EQUATION_ALPHA));
    const last_enable_blend = gl.glIsEnabled(gl.GL_BLEND);
    const last_enable_cull_face = gl.glIsEnabled(gl.GL_CULL_FACE);
    const last_enable_depth_test = gl.glIsEnabled(gl.GL_DEPTH_TEST);
    const last_enable_stencil_test = gl.glIsEnabled(gl.GL_STENCIL_TEST);
    const last_enable_scissor_test = gl.glIsEnabled(gl.GL_SCISSOR_TEST);

    const last_enable_primitive_restart = if (MAY_HAVE_PRIMITIVE_RESTART and bd.GlVersion >= 310) gl.glIsEnabled(gl.GL_PRIMITIVE_RESTART) else gl.GL_FALSE;

    // Setup desired GL state
    // Recreate the VAO every time (this is to easily allow multiple GL contexts to be rendered to. VAO are not shared among GL contexts)
    // The renderer would actually work without any VAO bound, but then our VertexAttrib calls would overwrite the default one currently bound.
    var vertex_array_object: gl.GLuint = 0;

    gl.glGenVertexArrays(1, &vertex_array_object);

    SetupRenderState(draw_data, fb_width, fb_height, vertex_array_object);

    // Will project scissor/clipping rectangles into framebuffer space
    var clip_off = draw_data.DisplayPos; // (0,0) unless using multi-viewports
    var clip_scale = draw_data.FramebufferScale; // (1,1) unless using retina display which are often (2,2)

    // Render command lists
    if (draw_data.CmdListsCount > 0) {
        for (draw_data.CmdLists.?[0..@intCast(usize, draw_data.CmdListsCount)]) |cmd_list| {
            // Upload vertex/index buffers
            // - On Intel windows drivers we got reports that regular glBufferData() led to accumulating leaks when using multi-viewports, so we started using orphaning + glBufferSubData(). (See https://github.com/ocornut/imgui/issues/4468)
            // - On NVIDIA drivers we got reports that using orphaning + glBufferSubData() led to glitches when using multi-viewports.
            // - OpenGL drivers are in a very sorry state in 2022, for now we are switching code path based on vendors.
            const vtx_buffer_size = cmd_list.VtxBuffer.size_in_bytes();
            const idx_buffer_size = cmd_list.IdxBuffer.size_in_bytes();
            if (bd.UseBufferSubData) {
                if (bd.VertexBufferSize < vtx_buffer_size) {
                    bd.VertexBufferSize = vtx_buffer_size;
                    gl.glBufferData(gl.GL_ARRAY_BUFFER, bd.VertexBufferSize, null, gl.GL_STREAM_DRAW);
                }
                if (bd.IndexBufferSize < idx_buffer_size) {
                    bd.IndexBufferSize = idx_buffer_size;
                    gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, bd.IndexBufferSize, null, gl.GL_STREAM_DRAW);
                }
                gl.glBufferSubData(gl.GL_ARRAY_BUFFER, 0, vtx_buffer_size, cmd_list.VtxBuffer.Data);
                gl.glBufferSubData(gl.GL_ELEMENT_ARRAY_BUFFER, 0, idx_buffer_size, cmd_list.IdxBuffer.Data);
            } else {
                gl.glBufferData(gl.GL_ARRAY_BUFFER, vtx_buffer_size, cmd_list.VtxBuffer.Data, gl.GL_STREAM_DRAW);
                gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, idx_buffer_size, cmd_list.IdxBuffer.Data, gl.GL_STREAM_DRAW);
            }

            for (cmd_list.CmdBuffer.items()) |pcmd| {
                if (pcmd.UserCallback) |fnPtr| {
                    // User callback, registered via ImDrawList::AddCallback()
                    // (ImDrawCallback_ResetRenderState is a special callback value used by the user to request the renderer to reset render state.)
                    if (fnPtr == imgui.DrawCallback_ResetRenderState) {
                        SetupRenderState(draw_data, fb_width, fb_height, vertex_array_object);
                    } else {
                        fnPtr(cmd_list, &pcmd);
                    }
                } else {
                    // Project scissor/clipping rectangles into framebuffer space
                    var clip_min = imgui.Vec2{
                        .x = (pcmd.ClipRect.x - clip_off.x) * clip_scale.x,
                        .y = (pcmd.ClipRect.y - clip_off.y) * clip_scale.y,
                    };
                    var clip_max = imgui.Vec2{
                        .x = (pcmd.ClipRect.z - clip_off.x) * clip_scale.x,
                        .y = (pcmd.ClipRect.w - clip_off.y) * clip_scale.y,
                    };
                    if (clip_max.x <= clip_min.x or clip_max.y <= clip_min.y)
                        continue;

                    // Apply scissor/clipping rectangle (Y is inverted in OpenGL)
                    gl.glScissor(
                        @floatToInt(c_int, clip_min.x),
                        fb_height - @floatToInt(c_int, clip_max.y),
                        @floatToInt(c_int, clip_max.x - clip_min.x),
                        @floatToInt(c_int, clip_max.y - clip_min.y),
                    );

                    // Bind texture, Draw
                    gl.glBindTexture(gl.GL_TEXTURE_2D, @intCast(gl.GLuint, @ptrToInt(pcmd.GetTexID())));
                    if (MAY_HAVE_VTX_OFFSET and bd.GlVersion >= 320) {
                        gl.glDrawElementsBaseVertex(
                            gl.GL_TRIANGLES,
                            @intCast(gl.GLsizei, pcmd.ElemCount),
                            if (@sizeOf(imgui.DrawIdx) == 2) gl.GL_UNSIGNED_SHORT else gl.GL_UNSIGNED_INT,
                            @intToPtr(?*const anyopaque, pcmd.IdxOffset * @sizeOf(imgui.DrawIdx)),
                            @intCast(gl.GLint, pcmd.VtxOffset),
                        );
                    } else {
                        gl.glDrawElements(
                            gl.GL_TRIANGLES,
                            @intCast(gl.GLsizei, pcmd.ElemCount),
                            if (@sizeOf(imgui.DrawIdx) == 2) gl.GL_UNSIGNED_SHORT else gl.GL_UNSIGNED_INT,
                            @intToPtr(?*const anyopaque, pcmd.IdxOffset * @sizeOf(imgui.DrawIdx)),
                        );
                    }
                }
            }
        }
    }

    // Destroy the temporary VAO
    gl.glDeleteVertexArrays(1, &vertex_array_object);

    // Restore modified GL state
    gl.glUseProgram(@intCast(c_uint, last_program));
    gl.glBindTexture(gl.GL_TEXTURE_2D, @intCast(c_uint, last_texture));
    if (MAY_HAVE_BIND_SAMPLER and bd.GlVersion >= 330) gl.glBindSampler(0, last_sampler);
    gl.glActiveTexture(last_active_texture);
    gl.glBindVertexArray(@intCast(c_uint, last_vertex_array_object));
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, @intCast(c_uint, last_array_buffer));
    gl.glBlendEquationSeparate(last_blend_equation_rgb, last_blend_equation_alpha);
    gl.glBlendFuncSeparate(last_blend_src_rgb, last_blend_dst_rgb, last_blend_src_alpha, last_blend_dst_alpha);
    if (last_enable_blend != 0) gl.glEnable(gl.GL_BLEND) else gl.glDisable(gl.GL_BLEND);
    if (last_enable_cull_face != 0) gl.glEnable(gl.GL_CULL_FACE) else gl.glDisable(gl.GL_CULL_FACE);
    if (last_enable_depth_test != 0) gl.glEnable(gl.GL_DEPTH_TEST) else gl.glDisable(gl.GL_DEPTH_TEST);
    if (last_enable_stencil_test != 0) gl.glEnable(gl.GL_STENCIL_TEST) else gl.glDisable(gl.GL_STENCIL_TEST);
    if (last_enable_scissor_test != 0) gl.glEnable(gl.GL_SCISSOR_TEST) else gl.glDisable(gl.GL_SCISSOR_TEST);
    if (MAY_HAVE_PRIMITIVE_RESTART and bd.GlVersion > 310)
        if (last_enable_primitive_restart != 0) gl.glEnable(gl.GL_PRIMITIVE_RESTART) else gl.glDisable(gl.GL_PRIMITIVE_RESTART);
    if (HAS_POLYGON_MODE) gl.glPolygonMode(gl.GL_FRONT_AND_BACK, @intCast(gl.GLenum, last_polygon_mode[0]));
    gl.glViewport(last_viewport[0], last_viewport[1], @intCast(gl.GLsizei, last_viewport[2]), @intCast(gl.GLsizei, last_viewport[3]));
    gl.glScissor(last_scissor_box[0], last_scissor_box[1], @intCast(gl.GLsizei, last_scissor_box[2]), @intCast(gl.GLsizei, last_scissor_box[3]));
}

fn CreateFontsTexture() bool {
    const io = imgui.GetIO();
    const bd = GetBackendData().?;

    // Build texture atlas
    var pixels: ?[*]u8 = undefined;
    var width: i32 = undefined;
    var height: i32 = undefined;
    io.Fonts.?.GetTexDataAsRGBA32(&pixels, &width, &height); // Load as RGBA 32-bit (75% of the memory is wasted, but default font is so small) because it is more likely to be compatible with user's existing shaders. If your ImTextureId represent a higher-level concept than just a GL texture id, consider calling GetTexDataAsAlpha8() instead to save on GPU memory.

    // Upload texture to graphics system
    // (Bilinear sampling is required by default. Set 'io.Fonts->Flags |= ImFontAtlasFlags_NoBakedLines' or 'style.AntiAliasedLinesUseTex = false' to allow point/nearest sampling)
    var last_texture: gl.GLint = undefined;
    gl.glGetIntegerv(gl.GL_TEXTURE_BINDING_2D, &last_texture);
    gl.glGenTextures(1, &bd.FontTexture);
    gl.glBindTexture(gl.GL_TEXTURE_2D, bd.FontTexture);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
    if (@hasDecl(gl, "GL_UNPACK_ROW_LENGTH"))
        gl.glPixelStorei(gl.GL_UNPACK_ROW_LENGTH, 0);
    gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGBA, width, height, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, pixels);

    // Store our identifier
    io.Fonts.?.SetTexID(@intToPtr(imgui.TextureID, bd.FontTexture));

    // Restore state
    gl.glBindTexture(gl.GL_TEXTURE_2D, @intCast(c_uint, last_texture));

    return true;
}

fn DestroyFontsTexture() void {
    const io = imgui.GetIO();
    const bd = GetBackendData().?;
    if (bd.FontTexture != 0) {
        gl.glDeleteTextures(1, &bd.FontTexture);
        io.Fonts.?.SetTexID(null);
        bd.FontTexture = 0;
    }
}

// If you get an error please report on github. You may try different GL context version or GLSL version. See GL<>GLSL version table at the top of this file.
fn CheckShader(handle: gl.GLuint, desc: []const u8) bool {
    const bd = GetBackendData().?;
    var status: gl.GLint = 0;
    var log_length: gl.GLint = 0;
    gl.glGetShaderiv(handle, gl.GL_COMPILE_STATUS, &status);
    gl.glGetShaderiv(handle, gl.GL_INFO_LOG_LENGTH, &log_length);
    if (status == gl.GL_FALSE)
        std.debug.print("ERROR: imgui_impl_opengl3.CreateDeviceObjects: failed to compile {s}! With GLSL: {s}\n", .{ desc, std.mem.sliceTo(&bd.GlslVersionString, 0) });
    if (log_length > 1) {
        var buf: imgui.Vector(u8) = .{};
        defer buf.deinit();
        buf.resize_undefined(@intCast(u32, log_length + 1));
        gl.glGetShaderInfoLog(handle, log_length, null, @ptrCast([*]gl.GLchar, buf.Data.?));
        std.debug.print("{s}\n", .{buf.items()});
    }
    return status != gl.GL_FALSE;
}

// If you get an error please report on GitHub. You may try different GL context version or GLSL version.
fn CheckProgram(handle: gl.GLuint, desc: []const u8) bool {
    const bd = GetBackendData().?;
    var status: gl.GLint = 0;
    var log_length: gl.GLint = 0;
    gl.glGetProgramiv(handle, gl.GL_LINK_STATUS, &status);
    gl.glGetProgramiv(handle, gl.GL_INFO_LOG_LENGTH, &log_length);
    if (status == gl.GL_FALSE)
        std.debug.print("ERROR: imgui_impl_opengl3.CreateDeviceObjects: failed to link {s}! With GLSL {s}\n", .{ desc, std.mem.sliceTo(&bd.GlslVersionString, 0) });
    if (log_length > 1) {
        var buf: imgui.Vector(u8) = .{};
        defer buf.deinit();
        buf.resize_undefined(@intCast(u32, log_length + 1));
        gl.glGetProgramInfoLog(handle, log_length, null, @ptrCast([*]gl.GLchar, buf.Data.?));
        std.debug.print("{s}\n", .{buf.items()});
    }
    return status != gl.GL_FALSE;
}

fn CreateDeviceObjects() bool {
    const bd = GetBackendData().?;

    // Backup GL state
    var last_texture = getGLInt(gl.GL_TEXTURE_BINDING_2D);
    var last_array_buffer = getGLInt(gl.GL_ARRAY_BUFFER_BINDING);
    var last_vertex_array = getGLInt(gl.GL_VERTEX_ARRAY_BINDING);

    // Parse GLSL version string
    var glsl_version: u32 = 130;

    const numberPart = std.mem.sliceTo(bd.GlslVersionString["#version ".len..], '\n');
    if (std.fmt.parseInt(u32, numberPart, 10)) |value| {
        glsl_version = value;
    } else |err| {
        std.debug.print("Couldn't parse glsl version from '{s}', '{s}'. Error: {any}\n", .{ std.mem.sliceTo(&bd.GlslVersionString, 0), numberPart, err });
    }

    const vertex_shader_glsl_120 = "uniform mat4 ProjMtx;\n" ++
        "attribute vec2 Position;\n" ++
        "attribute vec2 UV;\n" ++
        "attribute vec4 Color;\n" ++
        "varying vec2 Frag_UV;\n" ++
        "varying vec4 Frag_Color;\n" ++
        "void main()\n" ++
        "{\n" ++
        "    Frag_UV = UV;\n" ++
        "    Frag_Color = Color;\n" ++
        "    gl_Position = ProjMtx * vec4(Position.xy,0,1);\n" ++
        "}\n";

    const vertex_shader_glsl_130 = "uniform mat4 ProjMtx;\n" ++
        "in vec2 Position;\n" ++
        "in vec2 UV;\n" ++
        "in vec4 Color;\n" ++
        "out vec2 Frag_UV;\n" ++
        "out vec4 Frag_Color;\n" ++
        "void main()\n" ++
        "{\n" ++
        "    Frag_UV = UV;\n" ++
        "    Frag_Color = Color;\n" ++
        "    gl_Position = ProjMtx * vec4(Position.xy,0,1);\n" ++
        "}\n";

    const vertex_shader_glsl_300_es = "precision highp float;\n" ++
        "layout (location = 0) in vec2 Position;\n" ++
        "layout (location = 1) in vec2 UV;\n" ++
        "layout (location = 2) in vec4 Color;\n" ++
        "uniform mat4 ProjMtx;\n" ++
        "out vec2 Frag_UV;\n" ++
        "out vec4 Frag_Color;\n" ++
        "void main()\n" ++
        "{\n" ++
        "    Frag_UV = UV;\n" ++
        "    Frag_Color = Color;\n" ++
        "    gl_Position = ProjMtx * vec4(Position.xy,0,1);\n" ++
        "}\n";

    const vertex_shader_glsl_410_core = "layout (location = 0) in vec2 Position;\n" ++
        "layout (location = 1) in vec2 UV;\n" ++
        "layout (location = 2) in vec4 Color;\n" ++
        "uniform mat4 ProjMtx;\n" ++
        "out vec2 Frag_UV;\n" ++
        "out vec4 Frag_Color;\n" ++
        "void main()\n" ++
        "{\n" ++
        "    Frag_UV = UV;\n" ++
        "    Frag_Color = Color;\n" ++
        "    gl_Position = ProjMtx * vec4(Position.xy,0,1);\n" ++
        "}\n";

    const fragment_shader_glsl_120 = "#ifdef GL_ES\n" ++
        "    precision mediump float;\n" ++
        "#endif\n" ++
        "uniform sampler2D Texture;\n" ++
        "varying vec2 Frag_UV;\n" ++
        "varying vec4 Frag_Color;\n" ++
        "void main()\n" ++
        "{\n" ++
        "    gl_FragColor = Frag_Color * texture2D(Texture, Frag_UV.st);\n" ++
        "}\n";

    const fragment_shader_glsl_130 = "uniform sampler2D Texture;\n" ++
        "in vec2 Frag_UV;\n" ++
        "in vec4 Frag_Color;\n" ++
        "out vec4 Out_Color;\n" ++
        "void main()\n" ++
        "{\n" ++
        "    Out_Color = Frag_Color * texture(Texture, Frag_UV.st);\n" ++
        "}\n";

    const fragment_shader_glsl_300_es = "precision mediump float;\n" ++
        "uniform sampler2D Texture;\n" ++
        "in vec2 Frag_UV;\n" ++
        "in vec4 Frag_Color;\n" ++
        "layout (location = 0) out vec4 Out_Color;\n" ++
        "void main()\n" ++
        "{\n" ++
        "    Out_Color = Frag_Color * texture(Texture, Frag_UV.st);\n" ++
        "}\n";

    const fragment_shader_glsl_410_core = "in vec2 Frag_UV;\n" ++
        "in vec4 Frag_Color;\n" ++
        "uniform sampler2D Texture;\n" ++
        "layout (location = 0) out vec4 Out_Color;\n" ++
        "void main()\n" ++
        "{\n" ++
        "    Out_Color = Frag_Color * texture(Texture, Frag_UV.st);\n" ++
        "}\n";

    // Select shaders matching our GLSL versions
    var vertex_shader: [*:0]const u8 = undefined;
    var fragment_shader: [*:0]const u8 = undefined;
    if (glsl_version < 130) {
        vertex_shader = vertex_shader_glsl_120;
        fragment_shader = fragment_shader_glsl_120;
    } else if (glsl_version >= 410) {
        vertex_shader = vertex_shader_glsl_410_core;
        fragment_shader = fragment_shader_glsl_410_core;
    } else if (glsl_version == 300) {
        vertex_shader = vertex_shader_glsl_300_es;
        fragment_shader = fragment_shader_glsl_300_es;
    } else {
        vertex_shader = vertex_shader_glsl_130;
        fragment_shader = fragment_shader_glsl_130;
    }

    // Create shaders
    const version_str = @ptrCast([*:0]const u8, &bd.GlslVersionString);
    const vertex_shader_with_version = [_][*:0]const u8{ version_str, vertex_shader };
    const vert_handle = gl.glCreateShader(gl.GL_VERTEX_SHADER);
    gl.glShaderSource(vert_handle, 2, &vertex_shader_with_version, null);
    gl.glCompileShader(vert_handle);
    _ = CheckShader(vert_handle, "vertex shader");

    const fragment_shader_with_version = [_][*:0]const u8{ version_str, fragment_shader };
    const frag_handle = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
    gl.glShaderSource(frag_handle, 2, &fragment_shader_with_version, null);
    gl.glCompileShader(frag_handle);
    _ = CheckShader(frag_handle, "fragment shader");

    bd.ShaderHandle = gl.glCreateProgram();
    gl.glAttachShader(bd.ShaderHandle, vert_handle);
    gl.glAttachShader(bd.ShaderHandle, frag_handle);
    gl.glLinkProgram(bd.ShaderHandle);
    _ = CheckProgram(bd.ShaderHandle, "shader program");

    gl.glDetachShader(bd.ShaderHandle, vert_handle);
    gl.glDetachShader(bd.ShaderHandle, frag_handle);
    gl.glDeleteShader(vert_handle);
    gl.glDeleteShader(frag_handle);

    bd.AttribLocationTex = gl.glGetUniformLocation(bd.ShaderHandle, "Texture");
    bd.AttribLocationProjMtx = gl.glGetUniformLocation(bd.ShaderHandle, "ProjMtx");
    bd.AttribLocationVtxPos = gl.glGetAttribLocation(bd.ShaderHandle, "Position");
    bd.AttribLocationVtxUV = gl.glGetAttribLocation(bd.ShaderHandle, "UV");
    bd.AttribLocationVtxColor = gl.glGetAttribLocation(bd.ShaderHandle, "Color");

    // Create buffers
    gl.glGenBuffers(1, &bd.VboHandle);
    gl.glGenBuffers(1, &bd.ElementsHandle);

    _ = CreateFontsTexture();

    // Restore modified GL state
    gl.glBindTexture(gl.GL_TEXTURE_2D, @intCast(c_uint, last_texture));
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, @intCast(c_uint, last_array_buffer));
    gl.glBindVertexArray(@intCast(c_uint, last_vertex_array));

    return true;
}

fn DestroyDeviceObjects() void {
    const bd = GetBackendData().?;
    if (bd.VboHandle != 0) {
        gl.glDeleteBuffers(1, &bd.VboHandle);
        bd.VboHandle = 0;
    }
    if (bd.ElementsHandle != 0) {
        gl.glDeleteBuffers(1, &bd.ElementsHandle);
        bd.ElementsHandle = 0;
    }
    if (bd.ShaderHandle != 0) {
        gl.glDeleteProgram(bd.ShaderHandle);
        bd.ShaderHandle = 0;
    }
    DestroyFontsTexture();
}
