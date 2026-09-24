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
  // MERC effect flag; zero for terrain and other producers.
#ifdef __cplusplus
  unsigned int merc_ignore_alpha = 0;
#else
  unsigned int merc_ignore_alpha;
#endif
} OttselMetalTieDraw;

typedef struct OttselMetalDirectDepthState {
  unsigned long long test;
  unsigned long long zbuf;
} OttselMetalDirectDepthState;

typedef struct OttselMetalSpriteVertex {
  float pos[2];
  float uv[2];
  float color[4];
  // Direct/Sky: pos/z are NDC and uv/q are STQ. Sprite APIs: pos/z are
  // homogeneous clip XYZ, q is clip W, and uv is ordinary texture UV.
  // Legacy Sprite producers use W=1. Layout remains shared at 40 bytes.
#ifdef __cplusplus
  float q = 1.f;
  float z = 0.f;
#else
  float q;  // C callers initialize this to 1 for ordinary UV.
  float z;  // Legacy producers initialize this to 0.
#endif
} OttselMetalSpriteVertex;

typedef struct OttselMetalOverlayVertex {
  float pos[2];
  float uv[2];
  float color[4];
#ifdef __cplusplus
  float q = 1.f;
  float z = 0.f;
#else
  float q;
  float z;
#endif
} OttselMetalOverlayVertex;

// I3: one on-screen control as the accessibility layer should see it.  The shell draws these regions itself,
// so nothing in UIKit would name them; the bridge below publishes them as accessibility elements with a
// spoken label and a frame in the container's own coordinates.
typedef struct OttselAccessibilityRegion {
  float x;
  float y;
  float w;
  float h;
  const char* label;
} OttselAccessibilityRegion;

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
void ottsel_metal_set_tie_mesh(OttselMetal* m, const char* level,
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
void ottsel_metal_set_tie_colors(OttselMetal* m, const char* level,
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
void ottsel_metal_set_tfrag_mesh(OttselMetal* m, const char* level,
                                 const void* vertices,
                                 unsigned int vertex_count,
                                 const unsigned int* triangle_indices,
                                 unsigned int index_count,
                                 const OttselMetalTieDraw* draws,
                                 unsigned int draw_count);
void ottsel_metal_set_tfrag_colors(OttselMetal* m, const char* level,
                                   const unsigned char* rgba,
                                   unsigned int color_count);

// Append CPU-skinned Merc geometry for the current frame. Vertices use the
// same 32-byte layout as native TIE/TFRAG. lit_rgba contains four float
// channels per vertex and is copied into the same completed-frame transaction.
void ottsel_metal_append_merc_mesh(OttselMetal* m,
                                   const void* vertices,
                                   unsigned int vertex_count,
                                   const float* lit_rgba,
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
                                   const float* lit_rgba,
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
// G2.2 HUD parity: how many sprite batches the store currently holds.  Used to
// place a producer's append against the pass' snapshot (observability only).
unsigned int ottsel_metal_sprite_store_size(OttselMetal* m);

// Append Direct/GIF geometry to the background pass. These batches render
// before TFRAG/TIE so Sky and other pre-world Direct buckets preserve the
// desktop renderer's ordering.
// A complete bucket replaces the retained Sky; a failed attempt keeps it.
void ottsel_metal_begin_sky_bucket(OttselMetal* m);
// G2.2 blend ledger: re-arm the bounded per-site GS blend-register sample.
void ottsel_metal_arm_blend_ledger(OttselMetal* m);
// G2.2: non-zero reproduces the previous behaviour of drawing the Sky bucket's
// quads even though their composited source texture is not implemented here
// (A/B control only).
int ottsel_metal_sky_draw_legacy(OttselMetal* m);
// G2.2: the SkyBlend producer composes the 32x32/64x64 buffers the sky bucket
// samples, so the sky draw is on by default; this reports only the explicit
// skip control (`ottsel-trace-sky-skip-draw`).
int ottsel_metal_sky_skip_draw(OttselMetal* m);
void ottsel_metal_finish_sky_bucket(OttselMetal* m, int complete);
int ottsel_metal_append_sky_mesh_n(OttselMetal* m,
                                    const OttselMetalSpriteVertex* vertices,
                                    unsigned int vertex_count,
                                    const unsigned char* rgba,
                                    unsigned int width,
                                    unsigned int height,
                                    int blended,
                                    unsigned char ta0,
                                    const OttselMetalDirectDepthState* depth_state,
                                    unsigned long long diagnostic_alpha);

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
                                       unsigned char ta0,
                                    const OttselMetalDirectDepthState* depth_state,
                                    unsigned long long diagnostic_alpha);

// T1 first increment: draw the visible touch overlay above the native scene.
// The shared ShellPadInput seam remains the input owner; this only supplies
// native Metal overlay geometry.
void ottsel_metal_set_touch_overlay(OttselMetal* m,
                                    const OttselMetalOverlayVertex* vertices,
                                    unsigned int vertex_count);

// F1/G2.6: composite the shell own status screen (the data-import instruction
// and the log tail) inside the product pass, so it is visible while the game
// renderer owns the layer.  rgba is top-left origin, w x h; null clears it.
void ottssel_metal_set_status_overlay(OttselMetal* m,
                                     const unsigned char* rgba,
                                     unsigned int width,
                                     unsigned int height);

// I3: publish the touch regions to the accessibility layer, and report what the container answers (the probe
// is opt-in and bounded so it cannot flood the log).
void ottssel_metal_set_accessibility_regions(OttselMetal* m,
                                             const OttselAccessibilityRegion* regions,
                                             unsigned int count);
void ottssel_metal_log_accessibility(OttselMetal* m);

// I3 VIDEO: the shell owns the CAMetalLayer, so it owns the drawable size the game renders into.  The
// percent scales that drawable (the layer scales it back up to the view), so it is a real render-resolution
// change; 100 leaves the layer at its native size.
void ottssel_metal_set_render_scale(OttselMetal* m, unsigned int percent);

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


void ottsel_metal_begin_scene_frame(OttselMetal* m);

void ottsel_metal_publish_scene_frame(OttselMetal* m);

void ottsel_metal_reference_scene(OttselMetal* m, const char* level, int tfrag);

#ifdef __cplusplus
}
#endif
