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
} OttselMetalTieDraw;

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
                                 const float camera_trans[4],
                                 const float fog_params[4],
                                 const float fog_color[4]);

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

#ifdef __cplusplus
}
#endif
