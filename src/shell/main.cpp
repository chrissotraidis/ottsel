// Ottsel S1.3 / S2.0 — iOS shell: SDL window + no-emit runtime boot.
//
// The window surface is the visible log surface: the last lines of the
// runtime log are drawn with a built-in 5x7 bitmap font into a CPU RGBA
// buffer.  S2.0: the buffer is presented through a Metal CAMetalLayer
// pipeline (metal_shell.mm); the SDL software surface remains as a
// fallback if Metal init fails.  The runtime boots on a background thread.

#include <unistd.h>

#include <cstdio>
#include <cstring>
#include <fstream>
#include <string>
#include <thread>
#include <vector>

#include "common/log/log.h"
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include "font5x7.h"
#include "ios_boot.h"
#include "metal_shell.h"

namespace {

// The font data in font5x7.h uses 7-bit rows (LSB = leftmost, bit 6 =
// rightmost; e.g. 'o' = 0x38/0x44/0x44/0x44/0x38 draws sides at bits 2
// and 6).  kFontW must cover all 7 columns or every glyph is clipped.
constexpr int kFontW = 7;
constexpr int kFontH = 7;
constexpr int kTextLines = 18;  // lines of log on the surface
constexpr int kSurfWDefault = 1024;
constexpr int kSurfHDefault = 768;

SDL_Window* g_win = nullptr;
SDL_Surface* g_surf = nullptr;
OttselMetal* g_metal = nullptr;
int g_surf_w = kSurfWDefault;
int g_surf_h = kSurfHDefault;
int g_font_scale = 2;
std::vector<unsigned char> g_rgba((size_t)kSurfWDefault * kSurfHDefault * 4, 0);
std::string g_log_path;
std::vector<std::string> g_lines;
size_t g_file_pos = 0;
bool g_quit = false;
int g_frame = 0;

void put_pixel(int x, int y, unsigned char r, unsigned char g, unsigned char b) {
  if (x < 0 || y < 0 || x >= g_surf_w || y >= g_surf_h) {
    return;
  }
  size_t i = ((size_t)y * g_surf_w + (size_t)x) * 4;
  g_rgba[i + 0] = r;
  g_rgba[i + 1] = g;
  g_rgba[i + 2] = b;
  g_rgba[i + 3] = 255;
}

void draw_char(int x, int y, char c, unsigned char r, unsigned char g, unsigned char b) {
  if (c < 32 || c > 126) {
    c = '?';
  }
  const uint8_t* glyph = kFont5x7[c - 32];
  for (int row = 0; row < kFontH; row++) {
    uint8_t bits = glyph[row];
    for (int col = 0; col < kFontW; col++) {
      if (bits & (1 << col)) {
        for (int sy = 0; sy < g_font_scale; sy++) {
          for (int sx = 0; sx < g_font_scale; sx++) {
            put_pixel(x + col * g_font_scale + sx, y + row * g_font_scale + sy, r, g, b);
          }
        }
      }
    }
  }
}

void draw_text(int x, int y, const std::string& text,
               unsigned char r, unsigned char g, unsigned char b) {
  int cx = x;
  for (char c : text) {
    draw_char(cx, y, c, r, g, b);
    cx += (kFontW + 1) * g_font_scale;
  }
}

void read_log_tail() {
  std::ifstream f(g_log_path, std::ios::binary);
  if (!f) {
    return;
  }
  f.seekg(0, std::ios::end);
  size_t end = (size_t)f.tellg();
  if (end <= g_file_pos) {
    return;
  }
  f.seekg((std::streamoff)g_file_pos);
  std::string chunk((size_t)(end - g_file_pos), '\0');
  f.read(chunk.data(), (std::streamsize)chunk.size());
  g_file_pos = end;

  size_t start = 0;
  while (true) {
    size_t nl = chunk.find('\n', start);
    if (nl == std::string::npos) {
      break;
    }
    g_lines.push_back(chunk.substr(start, nl - start));
    start = nl + 1;
  }
  if (start < chunk.size()) {
    // partial last line; keep the position so the rest arrives next poll
    g_file_pos -= (chunk.size() - start);
  }
  if (g_lines.size() > 512) {
    g_lines.erase(g_lines.begin(), g_lines.begin() + (g_lines.size() - 512));
  }
}

void render_surface() {
  std::fill(g_rgba.begin(), g_rgba.end(), 0);
  // dark navy background
  for (int y = 0; y < g_surf_h; y++) {
    for (int x = 0; x < g_surf_w; x++) {
      size_t i = ((size_t)y * g_surf_w + (size_t)x) * 4;
      g_rgba[i + 0] = 8;
      g_rgba[i + 1] = 10;
      g_rgba[i + 2] = 18;
      g_rgba[i + 3] = 255;
    }
  }

  draw_text(8 * g_font_scale, 8 * g_font_scale,
            "ottsel S2.0 - Metal",
            120, 200, 255);
  draw_text(8 * g_font_scale, 17 * g_font_scale,
            g_metal ? "GPU path: Metal" : "GPU path: SDL software",
            g_metal ? 120 : 255, g_metal ? 255 : 90, g_metal ? 120 : 90);

  int first = (int)g_lines.size() - kTextLines;
  if (first < 0) {
    first = 0;
  }
  int y = 34 * g_font_scale;
  int cols = g_surf_w / ((kFontW + 1) * g_font_scale);
  for (int i = first; i < (int)g_lines.size(); i++) {
    const std::string& line = g_lines[i];
    unsigned char r = 220, g = 225, b = 235;
    if (line.find("BOOT FAILED") != std::string::npos) {
      r = 255; g = 90; b = 90;
    } else if (line.find("machine started") != std::string::npos ||
               line.find("dispatcher") != std::string::npos) {
      r = 120; g = 255; b = 150;
    }
    draw_text(8 * g_font_scale, y, line.substr(0, (size_t)cols), r, g, b);
    y += (kFontH + 3) * g_font_scale;
  }
}

// Debug aid (S2.0): dump the exact presented CPU surface as a PPM so the
// evidence set can be verified pixel-for-pixel against the Simulator
// screenshot.  Triggered once per surface-size change.
void dump_surface_ppm() {
  char* prefs = SDL_GetPrefPath("ottsel", "shell");
  if (!prefs) {
    return;
  }
  std::string path = std::string(prefs) + "surface.ppm";
  SDL_free(prefs);
  FILE* f = fopen(path.c_str(), "wb");
  if (!f) {
    return;
  }
  fprintf(f, "P6\n%d %d\n255\n", g_surf_w, g_surf_h);
  for (int y = 0; y < g_surf_h; y++) {
    for (int x = 0; x < g_surf_w; x++) {
      size_t i = ((size_t)y * g_surf_w + (size_t)x) * 4;
      fputc(g_rgba[i + 0], f);
      fputc(g_rgba[i + 1], f);
      fputc(g_rgba[i + 2], f);
    }
  }
  fclose(f);
}

bool on_event_watch(void*, SDL_Event* ev) {
  switch (ev->type) {
    case SDL_EVENT_DID_ENTER_BACKGROUND:
      // keep the runtime running while backgrounded (Simulator keeps CPU)
      break;
    case SDL_EVENT_DID_ENTER_FOREGROUND:
      break;
    default:
      break;
  }
  return true;
}

}  // namespace

int main(int argc, char** argv) {
  (void)argc;
  (void)argv;

  if (!SDL_Init(SDL_INIT_VIDEO)) {
    fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
    return 1;
  }
  SDL_AddEventWatch(on_event_watch, nullptr);

  g_win = SDL_CreateWindow("Ottsel Shell", 1024, 768, 0);
  if (!g_win) {
    fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
    return 1;
  }
  g_surf = SDL_GetWindowSurface(g_win);

  // S2.0: Metal presentation path (falls back to the SDL surface if the
  // Metal device/pipeline cannot be created on this Simulator).
  g_metal = ottsel_metal_create(g_win);
  if (g_metal) {
    fprintf(stderr, "ottsel S2.0: Metal surface active (CAMetalLayer)\n");
    int dw = 0, dh = 0;
    if (ottsel_metal_drawable_size(g_metal, &dw, &dh) && dw > 0 && dh > 0) {
      g_surf_w = dw;
      g_surf_h = dh;
      g_rgba.assign((size_t)g_surf_w * g_surf_h * 4, 0);
      g_font_scale = std::max(3, g_surf_w / 430);
      fprintf(stderr, "ottsel S2.0: drawable %dx%d font scale %d\n", dw, dh, g_font_scale);
    }
  } else {
    fprintf(stderr, "ottsel S2.0: Metal init failed; using SDL software surface\n");
  }

  // S2.2: register the shell's Metal instance as the Gfx renderer backend so
  // the game's texture uploads decode and present through the CAMetalLayer.
  ottsel_metal_gfx_register(g_metal);

  std::string bundle = SDL_GetBasePath();
  ottsel_ios_set_bundle_dir(bundle);
  g_log_path = bundle + "ottsel-runtime.log";

  // All runtime log output (lg:: + kernel Msg/printstd) goes to this file;
  // the surface renders its tail.
  lg::set_file("ottsel-runtime.log", false, false, bundle);

  std::thread boot(ottsel_ios_run_boot);

  while (!g_quit) {
    SDL_Event ev;
    while (SDL_PollEvent(&ev)) {
      if (ev.type == SDL_EVENT_QUIT) {
        g_quit = true;
      }
      // BOT22: any tap/click/key presses START on the synthetic pad for a
      // few reads (the game's title screen advances on START/circle/X).
      if (ev.type == SDL_EVENT_FINGER_DOWN || ev.type == SDL_EVENT_MOUSE_BUTTON_DOWN ||
          ev.type == SDL_EVENT_KEY_DOWN) {
        extern unsigned int g_ottsel_synthetic_buttons;
        extern int g_ottsel_synthetic_frames;
        g_ottsel_synthetic_buttons = 0x0008;  // START (PadData::ButtonIndex::START = bit 3)
        g_ottsel_synthetic_frames = 30;
        fprintf(stderr, "ottsel BOT22: synthetic START press (event 0x%x)\n", ev.type);
      }
    }
    // BOT22: file-based input trigger for headless driving — creating
    // <bundle>/ottsel-press-start injects a START press (then the file is
    // removed).  Complements the tap/key mapping above.
    {
      static int ottsel_trig_divider = 0;
      if ((++ottsel_trig_divider % 30) == 0) {
        std::string trig = bundle + "ottsel-press-start";
        if (access(trig.c_str(), F_OK) == 0) {
          unlink(trig.c_str());
          extern unsigned int g_ottsel_synthetic_buttons;
          extern int g_ottsel_synthetic_frames;
          g_ottsel_synthetic_buttons = 0x0008;  // START
          g_ottsel_synthetic_frames = 30;
          fprintf(stderr, "ottsel BOT22: synthetic START press (file trigger)\n");
        }
        std::string bgtrig = bundle + "ottsel-bg-village1";
        if (access(bgtrig.c_str(), F_OK) == 0) {
          unlink(bgtrig.c_str());
          extern int g_ottsel_bg_village1_request;
          g_ottsel_bg_village1_request = 1;
          fprintf(stderr, "ottsel BOT22: (bg 'village1) requested (file trigger)\n");
        }
      }
    }
    if (g_surf || g_metal) {
      read_log_tail();
      render_surface();
    }
    if (g_metal) {
      // The CAMetalLayer's drawable size is only meaningful after the SDL
      // window finishes layout (at creation it can report a pre-layout
      // value like 480x320).  Re-query each frame and resize the CPU
      // surface to match so the frame maps 1:1 to the drawable.
      int dw = 0, dh = 0;
      if (ottsel_metal_drawable_size(g_metal, &dw, &dh) && dw > 0 && dh > 0 &&
          (dw != g_surf_w || dh != g_surf_h)) {
        g_surf_w = dw;
        g_surf_h = dh;
        g_rgba.assign((size_t)g_surf_w * g_surf_h * 4, 0);
        g_font_scale = std::max(3, g_surf_w / 430);
        fprintf(stderr, "ottsel S2.0: drawable resized to %dx%d font scale %d\n",
                dw, dh, g_font_scale);
        dump_surface_ppm();
      }
      // S2.2: once the game backend has decoded a frame (the game's texture
      // uploads through the Metal Gfx module), present that instead of the
      // shell log surface.  The texture is scaled to the drawable.
      const unsigned char* game_frame = nullptr;
      int gw = 0, gh = 0;
      if (ottsel_metal_gfx_game_frame(&game_frame, &gw, &gh)) {
        static std::vector<unsigned char> scaled;
        scaled.resize((size_t)g_surf_w * g_surf_h * 4);
        for (int y = 0; y < g_surf_h; y++) {
          for (int x = 0; x < g_surf_w; x++) {
            int sx = gw <= 1 ? 0 : (x * gw / g_surf_w);
            int sy = gh <= 1 ? 0 : (y * gh / g_surf_h);
            const unsigned char* src = game_frame + ((size_t)sy * gw + sx) * 4;
            unsigned char* dst = scaled.data() + ((size_t)y * g_surf_w + x) * 4;
            dst[0] = src[0];
            dst[1] = src[1];
            dst[2] = src[2];
            dst[3] = 255;
          }
        }
        ottsel_metal_present(g_metal, scaled.data(), g_surf_w, g_surf_h);
      } else {
        ottsel_metal_present(g_metal, g_rgba.data(), g_surf_w, g_surf_h);
      }
      if ((g_frame++ % 300) == 0) {
        dump_surface_ppm();
      }
    } else if (g_surf) {
      SDL_UpdateWindowSurface(g_win);
    }
    SDL_Delay(16);
  }

  // ask the dispatcher loop to stop (MasterExit lives in the runtime lib)
  extern void ottsel_ios_stop_dispatch();
  ottsel_ios_stop_dispatch();
  boot.join();

  SDL_DestroyWindow(g_win);
  ottsel_metal_destroy(g_metal);
  SDL_Quit();
  return 0;
}
