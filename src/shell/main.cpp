// Ottsel S1.3 — iOS shell: SDL window + no-emit runtime boot.
//
// The window surface is the visible log surface: the last lines of the
// runtime log are drawn with a built-in 5x7 bitmap font (no renderer, no
// GPU, no OpenGL/GLES/Metal).  The runtime boots on a background thread.

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

namespace {

constexpr int kFontW = 5;
constexpr int kFontH = 7;
constexpr int kTextCols = 96;   // characters per line on the 1024px surface
constexpr int kTextLines = 18;  // lines of log on the surface

SDL_Window* g_win = nullptr;
SDL_Surface* g_surf = nullptr;
std::string g_log_path;
std::vector<std::string> g_lines;
size_t g_file_pos = 0;
bool g_quit = false;

void draw_char(SDL_Surface* s, int x, int y, char c, uint32_t color) {
  if (c < 32 || c > 126) {
    c = '?';
  }
  const uint8_t* g = kFont5x7[c - 32];
  for (int row = 0; row < kFontH; row++) {
    uint8_t bits = g[row];
    for (int col = 0; col < kFontW; col++) {
      if (bits & (1 << col)) {
        SDL_Rect px{x + col, y + row, 1, 1};
        SDL_FillSurfaceRect(s, &px, color);
      }
    }
  }
}

void draw_text(SDL_Surface* s, int x, int y, const std::string& text, uint32_t color) {
  int cx = x;
  for (char c : text) {
    draw_char(s, cx, y, c, color);
    cx += kFontW + 1;
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
  uint32_t bg = SDL_MapSurfaceRGB(g_surf, 8, 10, 18);
  SDL_FillSurfaceRect(g_surf, nullptr, bg);

  uint32_t title = SDL_MapSurfaceRGB(g_surf, 120, 200, 255);
  uint32_t text = SDL_MapSurfaceRGB(g_surf, 220, 225, 235);
  uint32_t dim = SDL_MapSurfaceRGB(g_surf, 130, 140, 155);
  draw_text(g_surf, 8, 8, "ottsel S1.3 - no-emit ARM64 runtime", title);

  int first = (int)g_lines.size() - kTextLines;
  if (first < 0) {
    first = 0;
  }
  int y = 24;
  for (int i = first; i < (int)g_lines.size(); i++) {
    const std::string& line = g_lines[i];
    uint32_t col = line.find("BOOT FAILED") != std::string::npos
                       ? SDL_MapSurfaceRGB(g_surf, 255, 90, 90)
                       : (line.find("machine started") != std::string::npos ||
                                  line.find("dispatcher") != std::string::npos
                              ? SDL_MapSurfaceRGB(g_surf, 120, 255, 150)
                              : text);
    draw_text(g_surf, 8, y, line.substr(0, (size_t)kTextCols), col);
    (void)dim;
    y += kFontH + 3;
  }
  SDL_UpdateWindowSurface(g_win);
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
    }
    if (g_surf) {
      read_log_tail();
      render_surface();
    }
    SDL_Delay(16);
  }

  // ask the dispatcher loop to stop (MasterExit lives in the runtime lib)
  extern void ottsel_ios_stop_dispatch();
  ottsel_ios_stop_dispatch();
  boot.join();

  SDL_DestroyWindow(g_win);
  SDL_Quit();
  return 0;
}
