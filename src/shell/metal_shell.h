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

#ifdef __cplusplus
}
#endif
