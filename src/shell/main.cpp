// Ottsel S1.2 — iOS Simulator shell (headless-renderer).
//
// Scope: prove an app shell launches on the iPad Simulator with an SDL3
// window, a stubbed renderer (no OpenGL/GLES, no Metal), no listener/REPL,
// and clean lifecycle. The no-emit runtime boots here in S1.3.

#include <cstdio>
#include <cstring>
#include <ctime>
#include <string>

#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

namespace {

FILE* g_log = nullptr;

void log_line(const char* msg) {
  char ts[64];
  time_t now = time(nullptr);
  struct tm tmv = {};
  localtime_r(&now, &tmv);
  strftime(ts, sizeof(ts), "%H:%M:%S", &tmv);
  if (g_log) {
    fprintf(g_log, "[%s] %s\n", ts, msg);
    fflush(g_log);
  }
  fprintf(stderr, "[%s] %s\n", ts, msg);
  fflush(stderr);
}

// iOS lifecycle events (background/foreground) are only delivered via an
// event-watch callback, not the poll queue.
bool on_event_watch(void*, SDL_Event* ev) {
  switch (ev->type) {
    case SDL_EVENT_WILL_ENTER_BACKGROUND:
      log_line("WILL_ENTER_BACKGROUND");
      break;
    case SDL_EVENT_DID_ENTER_BACKGROUND:
      log_line("DID_ENTER_BACKGROUND (still alive)");
      break;
    case SDL_EVENT_WILL_ENTER_FOREGROUND:
      log_line("WILL_ENTER_FOREGROUND");
      break;
    case SDL_EVENT_DID_ENTER_FOREGROUND:
      log_line("DID_ENTER_FOREGROUND (still alive)");
      break;
    default:
      break;
  }
  return true;  // keep the event in the queue
}

// Log file lives in the app Documents dir (sandbox), where the S1.3 runtime
// boot log will also be written.
std::string documents_dir() {
  const char* base = SDL_GetBasePath();
  if (base && *base) {
    return std::string(base);
  }
  return ".";
}

}  // namespace

int main(int argc, char** argv) {
  (void)argc;
  (void)argv;

  std::string log_path = documents_dir() + "ottsel-shell.log";
  g_log = fopen(log_path.c_str(), "w");
  log_line("ottsel S1.2 shell starting");
  log_line(("log file: " + log_path).c_str());

  if (!SDL_Init(SDL_INIT_VIDEO)) {
    log_line(("SDL_Init failed: " + std::string(SDL_GetError())).c_str());
    return 1;
  }
  log_line("SDL_Init ok (video only; renderer stubbed)");
  // iOS lifecycle events are only delivered via an event watch callback.
  SDL_AddEventWatch(on_event_watch, nullptr);

  // Windowed, no fullscreen flag. On iOS the app view fills the device
  // display by platform design; the operator's no-fullscreen constraint
  // concerns macOS host windows.
  SDL_Window* win = SDL_CreateWindow("Ottsel Shell", 1024, 768, 0);
  if (!win) {
    log_line(("SDL_CreateWindow failed: " + std::string(SDL_GetError())).c_str());
    SDL_Quit();
    return 1;
  }
  log_line("window created (no renderer)");

  // Visible surface without a renderer/GPU: fill the window surface so the
  // screenshot is not a blank black frame.
  SDL_Surface* surf = SDL_GetWindowSurface(win);
  if (surf) {
    Uint32 color = SDL_MapSurfaceRGB(surf, 24, 48, 96);
    SDL_FillSurfaceRect(surf, nullptr, color);
    SDL_UpdateWindowSurface(win);
    log_line("window surface filled (headless renderer stub)");
  } else {
    log_line(("SDL_GetWindowSurface failed: " + std::string(SDL_GetError())).c_str());
  }

  bool running = true;
  Uint64 frames = 0;
  while (running) {
    SDL_Event ev;
    while (SDL_PollEvent(&ev)) {
      switch (ev.type) {
        case SDL_EVENT_QUIT:
          log_line("QUIT event");
          running = false;
          break;
        default:
          break;
      }
    }
    if (surf && (++frames % 300 == 0)) {
      // keep the visible surface live; cheap no-op updates only
      SDL_UpdateWindowSurface(win);
    }
    SDL_Delay(8);
  }

  log_line("shell exiting cleanly");
  SDL_DestroyWindow(win);
  SDL_Quit();
  if (g_log) {
    fclose(g_log);
  }
  return 0;
}
