#pragma once
// Ottsel S2.0 — Metal shell surface.
//
// Minimal CAMetalLayer pipeline for the iOS shell: a Metal device, command
// queue, a fullscreen textured-triangle pipeline, and a per-frame texture
// upload of the CPU-rendered log surface.  Declared sub-gate S2.0 (Metal
// spike): this is the first frame delivered through Metal from the shell;
// it is NOT yet a frame from Jak 1 game systems (that is S2.1/S2.2).
//
// C interface so main.cpp (plain C++) stays Objective-C-free; the
// implementation lives in metal_shell.mm (Objective-C++).

#ifdef __cplusplus
extern "C" {
#endif

typedef struct OttselMetal OttselMetal;

typedef struct OttselMetalTieDraw {
  unsigned int index_offset;
  unsigned int index_count;
  int texture_index;
  unsigned int mode;
  unsigned int owner_tag;
} OttselMetalTieDraw;

typedef struct OttselMetalSpriteVertex {
  float pos[2];
  float uv[2];
  float color[4];
} OttselMetalSpriteVertex;

typedef struct OttselMetalOverlayVertex {
  float pos[2];
  float uv[2];
  float color[4];
} OttselMetalOverlayVertex;

// Create a Metal device/queue/pipeline on the SDL window's CAMetalLayer.
// Returns nullptr on failure (caller keeps the software fallback).
OttselMetal* ottsel_metal_create(void* sdl_window);

// Upload an RGBA8 frame (w x h, top-left origin) and present it through
// the layer.  No-op if the drawable cannot be acquired.
void ottsel_metal_present(OttselMetal* m, const unsigned char* rgba, int w, int h);

// Current CAMetalLayer drawable size in pixels (0,0 on failure).  The
// caller sizes its CPU surface to match so the frame maps 1:1 to the
// drawable instead of being stretched.
int ottsel_metal_drawable_size(OttselMetal* m, int* w, int* h);

void ottsel_metal_destroy(OttselMetal* m);

// Ottsel S2.2: register the shell's Metal instance as the Gfx renderer
// backend so the game's texture uploads (pc_texture_upload_now) decode and
// present through the CAMetalLayer.  Returns the registered renderer pointer
// (or nullptr if the shell has no Metal instance).
const void* ottsel_metal_gfx_register(void* metal);
void ottsel_metal_gfx_signal_vsync(void);
void ottsel_metal_gfx_stop_vsync_waiters(void);

// S2.2: if the game backend decoded a frame, return it (RGBA8, top-left
// origin) and 1; otherwise return 0.
int ottsel_metal_gfx_game_frame(const unsigned char** rgba, int* w, int* h);

// Bounded S2.3 scene proof: upload one pre-expanded normal-TIE mesh and the
// matching PC-port camera. The shell owns its Metal buffers after each call.
// Texture, time-of-day, fog, blending, and visibility remain separate gates.
void ottsel_metal_set_tie_mesh(OttselMetal* m,
                               const void* vertices,
                               unsigned int vertex_count,
                               const unsigned int* triangle_indices,
                               unsigned int index_count,
                               const OttselMetalTieDraw* draws,
                               unsigned int draw_count);
void ottsel_metal_set_tie_texture(OttselMetal* m,
                                  unsigned int texture_index,
                                  const unsigned int* rgba,
                                  unsigned int width,
                                  unsigned int height);
void ottsel_metal_set_tie_colors(OttselMetal* m,
                                 const unsigned char* rgba,
                                 unsigned int color_count);
void ottsel_metal_set_tie_camera(OttselMetal* m,
                                 const float pc_camera[16],
                                 const float merc_perspective[16],
                                 const float camera_trans[4],
                                 const float fog_params[4],
                                 const float fog_color[4],
                                 const float hvdf_offset[4],
                                 float fog_constant);

// Opaque TFRAG uses the same FR3 vertex layout and material records as TIE,
// but occupies an independent mesh and color table so it can render first.
void ottsel_metal_set_tfrag_mesh(OttselMetal* m,
                                 const void* vertices,
                                 unsigned int vertex_count,
                                 const unsigned int* triangle_indices,
                                 unsigned int index_count,
                                 const OttselMetalTieDraw* draws,
                                 unsigned int draw_count);
void ottsel_metal_set_tfrag_colors(OttselMetal* m,
                                   const unsigned char* rgba,
                                   unsigned int color_count);

// Append CPU-skinned Merc geometry for the current frame. Vertices use the
// same 32-byte layout as native TIE/TFRAG, sharing their camera/material path.
void ottsel_metal_append_merc_mesh(OttselMetal* m,
                                   const void* vertices,
                                   unsigned int vertex_count,
                                   const unsigned int* triangle_indices,
                                   unsigned int index_count,
                                   const OttselMetalTieDraw* draws,
                                   unsigned int draw_count);
// Keep the Jak player model independent from transient title/logo Merc
// snapshots. The game emits its setup packet before the Village1 camera
// packet, so replacing the whole presentation batch can otherwise erase it.
void ottsel_metal_set_merc_actor_mesh(OttselMetal* m,
                                      const void* vertices,
                                      unsigned int vertex_count,
                                      const unsigned int* triangle_indices,
                                      unsigned int index_count,
                                      const OttselMetalTieDraw* draws,
                                      unsigned int draw_count);

// R1 bounded Sprite3 proof: upload one expanded native quad/triangle list.
// Positions are already in drawable clip space; no CPU frame is produced.
void ottsel_metal_set_sprite_mesh(OttselMetal* m,
                                  const OttselMetalSpriteVertex vertices[6],
                                  const unsigned char* rgba,
                                  unsigned int width,
                                  unsigned int height,
                                  int blended);

// Same Sprite3 path with a bounded triangle-list vertex count. The texture
// remains one live TEX0 identity for the submitted group.
void ottsel_metal_set_sprite_mesh_n(OttselMetal* m,
                                    const OttselMetalSpriteVertex* vertices,
                                    unsigned int vertex_count,
                                    const unsigned char* rgba,
                                    unsigned int width,
                                    unsigned int height,
                                    int blended);

// Append a native Sprite3 batch to the current present. The renderer clears
// appended batches after encoding one frame; this preserves world/HUD order.
void ottsel_metal_append_sprite_mesh_n(OttselMetal* m,
                                       const OttselMetalSpriteVertex* vertices,
                                       unsigned int vertex_count,
                                       const unsigned char* rgba,
                                       unsigned int width,
                                       unsigned int height,
                                       int blended);

// Append Direct/GIF geometry to the background pass. These batches render
// before TFRAG/TIE so Sky and other pre-world Direct buckets preserve the
// desktop renderer's ordering.
void ottsel_metal_append_sky_mesh_n(OttselMetal* m,
                                    const OttselMetalSpriteVertex* vertices,
                                    unsigned int vertex_count,
                                    const unsigned char* rgba,
                                    unsigned int width,
                                    unsigned int height,
                                    int blended,
                                    unsigned char ta0);

// Append foreground Direct/GIF geometry (title logo, "PRESS START", debug and
// menu text).  Drawn after the world and after sprites, matching the desktop
// DirectRenderer's ordering for the debug/text bucket.
void ottsel_metal_append_direct_mesh_n(OttselMetal* m,
                                       const OttselMetalSpriteVertex* vertices,
                                       unsigned int vertex_count,
                                       const unsigned char* rgba,
                                       unsigned int width,
                                       unsigned int height,
                                       int blended,
                                       unsigned char ta0);

// T1 first increment: draw the visible touch overlay above the native scene.
// The shared ShellPadInput seam remains the input owner; this only supplies
// native Metal overlay geometry.
void ottsel_metal_set_touch_overlay(OttselMetal* m,
                                    const OttselMetalOverlayVertex* vertices,
                                    unsigned int vertex_count);

// D3 fixture path: upload one generated RGBA pattern and draw it directly
// through Metal at a normalized drawable rectangle. This is opt-in and does
// not consume the CPU-composed frame.
void ottsel_metal_set_direct_fixture(OttselMetal* m,
                                     const unsigned char* rgba,
                                     unsigned int width,
                                     unsigned int height,
                                     unsigned long long texture_key,
                                     float x,
                                     float y,
                                     float w,
                                     float h,
                                     float u0,
                                     float v0,
                                     float u1,
                                     float v1,
                                     const float color[4]);
// Retain a decoded user-data texture by its GS TEX0/TBP identity without
// activating a draw. Direct state resolution selects from this cache later.
void ottsel_metal_upload_direct_texture(OttselMetal* m,
                                        const unsigned char* rgba,
                                        unsigned int width,
                                        unsigned int height,
                                        unsigned long long texture_key);
void ottsel_metal_clear_direct_fixture(OttselMetal* m);
void ottsel_metal_set_direct_fixture_state(OttselMetal* m,
                                           unsigned long long prim,
                                           unsigned long long tex0,
                                           unsigned long long tex1,
                                           unsigned long long clamp,
                                           unsigned long long frame,
                                           unsigned long long alpha,
                                           unsigned long long test,
                                           unsigned long long zbuf,
                                           unsigned long long texa,
                                           unsigned int scissor_x0,
                                           unsigned int scissor_x1,
                                           unsigned int scissor_y0,
                                           unsigned int scissor_y1);

#ifdef __cplusplus
}
#endif
