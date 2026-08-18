// Ottsel S1.3 / S2.0 — iOS shell: SDL window + no-emit runtime boot.
//
// The window surface is the visible log surface: the last lines of the
// runtime log are drawn with a built-in 5x7 bitmap font into a CPU RGBA
// buffer.  S2.0: the buffer is presented through a Metal CAMetalLayer
// pipeline (metal_shell.mm); the SDL software surface remains as a
// fallback if Metal init fails.  The runtime boots on a background thread.

#include <unistd.h>

#include <algorithm>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <string>
#include <thread>
#include <vector>

#include "common/log/log.h"
#include "game/sce/ottsel_platform_input.h"
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include "font5x7.h"
#include "ios_boot.h"
#include "metal_shell.h"

int ottsel_metal_gfx_has_live_scene();

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

// The mobile shell does not create the desktop Display/InputManager.  It
// nevertheless delivers the same completed DualShock snapshot to GOAL, via
// the platform bridge sampled by scePadRead.
struct ShellPadInput {
  ottsel::platform_input::PadState state;
  bool key_w = false;
  bool key_a = false;
  bool key_s = false;
  bool key_d = false;
  SDL_FingerID left_stick_finger = 0;
  SDL_FingerID action_finger = 0;
  float stick_origin_x = 0;
  float stick_origin_y = 0;

  void publish() const { ottsel::platform_input::set_pad_state(0, state); }

  void trace(const char* source) const {
    const char* enabled = std::getenv("OTTSEL_TRACE_MOBILE_INPUT");
    // Keep the first host events visible without requiring an environment
    // variable that cannot be set after a Simulator launch. This separates
    // keyboard-delivery failures from PadState/GOAL-consumer failures while
    // retaining opt-in full tracing for controller/touch investigation.
    static u32 first_events = 0;
    const bool full_trace = enabled && enabled[0] == '1';
    if (!full_trace && first_events >= 12) {
      return;
    }
    ++first_events;
    lg::info("OTTSEL MOBILE INPUT: source={} event={} buttons=0x{:x} left=({}, {}) right=({}, {}) "
             "cross-pressure={}",
             source, first_events, state.buttons, state.leftx, state.lefty, state.rightx,
             state.righty, state.pressure.at(6));
  }

  void update_keyboard_stick() {
    state.leftx = key_a == key_d ? 127 : (key_a ? 0 : 255);
    state.lefty = key_w == key_s ? 127 : (key_w ? 0 : 255);
  }

  void keyboard(SDL_Keycode key, bool pressed) {
    using namespace ottsel::platform_input;
    Button digital_button = static_cast<Button>(0);
    switch (key) {
      case SDLK_W: key_w = pressed; break;
      case SDLK_A: key_a = pressed; break;
      case SDLK_S: key_s = pressed; break;
      case SDLK_D: key_d = pressed; break;
      case SDLK_RETURN: digital_button = Start; break;
      case SDLK_SPACE: digital_button = Cross; break;
      case SDLK_E: digital_button = Circle; break;
      case SDLK_F: digital_button = Square; break;
      case SDLK_R: digital_button = Triangle; break;
      case SDLK_Q: digital_button = L1; break;
      case SDLK_O: digital_button = R1; break;
      case SDLK_1: digital_button = L2; break;
      case SDLK_P: digital_button = R2; break;
      case SDLK_UP: digital_button = DpadUp; break;
      case SDLK_RIGHT: digital_button = DpadRight; break;
      case SDLK_DOWN: digital_button = DpadDown; break;
      case SDLK_LEFT: digital_button = DpadLeft; break;
      default: return;
    }
    if (digital_button) {
      set_button(&state, digital_button, pressed);
      // Match the desktop keyboard event latch: eight 60 Hz pad reads
      // preserve a tap long enough for the independent GOAL thread, while
      // ordinary held keys continue to use the live state above.
      if (pressed) {
        latch_button(0, digital_button, 8);
      }
    }
    update_keyboard_stick();
    publish();
    trace("keyboard");
  }

  void gamepad_button(Uint8 button, bool pressed) {
    using namespace ottsel::platform_input;
    Button mapped = static_cast<Button>(0);
    switch (button) {
      case SDL_GAMEPAD_BUTTON_SOUTH: mapped = Cross; break;
      case SDL_GAMEPAD_BUTTON_EAST: mapped = Circle; break;
      case SDL_GAMEPAD_BUTTON_WEST: mapped = Square; break;
      case SDL_GAMEPAD_BUTTON_NORTH: mapped = Triangle; break;
      case SDL_GAMEPAD_BUTTON_LEFT_SHOULDER: mapped = L1; break;
      case SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER: mapped = R1; break;
      case SDL_GAMEPAD_BUTTON_BACK: mapped = Select; break;
      case SDL_GAMEPAD_BUTTON_START: mapped = Start; break;
      case SDL_GAMEPAD_BUTTON_DPAD_UP: mapped = DpadUp; break;
      case SDL_GAMEPAD_BUTTON_DPAD_RIGHT: mapped = DpadRight; break;
      case SDL_GAMEPAD_BUTTON_DPAD_DOWN: mapped = DpadDown; break;
      case SDL_GAMEPAD_BUTTON_DPAD_LEFT: mapped = DpadLeft; break;
      default: return;
    }
    set_button(&state, mapped, pressed);
    publish();
    trace("gamepad-button");
  }

  void gamepad_axis(Uint8 axis, Sint16 value) {
    const auto normalize = [](Sint16 input) {
      return static_cast<u8>(std::clamp(127 + int(input) * 128 / 32767, 0, 255));
    };
    switch (axis) {
      case SDL_GAMEPAD_AXIS_LEFTX: state.leftx = normalize(value); break;
      case SDL_GAMEPAD_AXIS_LEFTY: state.lefty = normalize(value); break;
      case SDL_GAMEPAD_AXIS_RIGHTX: state.rightx = normalize(value); break;
      case SDL_GAMEPAD_AXIS_RIGHTY: state.righty = normalize(value); break;
      case SDL_GAMEPAD_AXIS_LEFT_TRIGGER:
        ottsel::platform_input::set_button(&state, ottsel::platform_input::L2, value > 1638);
        break;
      case SDL_GAMEPAD_AXIS_RIGHT_TRIGGER:
        ottsel::platform_input::set_button(&state, ottsel::platform_input::R2, value > 1638);
        break;
      default: return;
    }
    publish();
    trace("gamepad-axis");
  }

  void touch(const SDL_Event& event) {
    using namespace ottsel::platform_input;
    const auto& finger = event.tfinger;
    if (event.type == SDL_EVENT_FINGER_DOWN) {
      if (finger.x < 0.5f && left_stick_finger == 0) {
        left_stick_finger = finger.fingerID;
        stick_origin_x = finger.x;
        stick_origin_y = finger.y;
      } else if (action_finger == 0) {
        // Match the desktop Space/controller-South Cross action. A visible,
        // configurable touch overlay is the next mobile UI layer.
        action_finger = finger.fingerID;
        set_button(&state, Cross, true);
      }
    } else if (event.type == SDL_EVENT_FINGER_MOTION && finger.fingerID == left_stick_finger) {
      state.leftx = static_cast<u8>(std::clamp(127 + int((finger.x - stick_origin_x) * 510), 0, 255));
      state.lefty = static_cast<u8>(std::clamp(127 + int((finger.y - stick_origin_y) * 510), 0, 255));
    } else if ((event.type == SDL_EVENT_FINGER_UP || event.type == SDL_EVENT_FINGER_CANCELED) &&
               finger.fingerID == left_stick_finger) {
      left_stick_finger = 0;
      state.leftx = 127;
      state.lefty = 127;
    } else if ((event.type == SDL_EVENT_FINGER_UP || event.type == SDL_EVENT_FINGER_CANCELED) &&
               finger.fingerID == action_finger) {
      action_finger = 0;
      set_button(&state, Cross, false);
    } else {
      return;
    }
    publish();
    if (event.type != SDL_EVENT_FINGER_MOTION) {
      trace("touch");
    }
  }

  void neutralize() {
    *this = {};
    publish();
    trace("lifecycle");
  }
};

ShellPadInput g_input;

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
      // Never leave movement or an action held when the app is suspended.
      g_input.neutralize();
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

  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)) {
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
  char* prefs = SDL_GetPrefPath("local.ottsel", "OttselShell");
  if (!prefs) {
    fprintf(stderr, "SDL_GetPrefPath failed: %s\n", SDL_GetError());
    return 1;
  }
  std::string writable = prefs;
  SDL_free(prefs);
  ottsel_ios_set_writable_dir(writable);
  g_log_path = writable + "ottsel-runtime.log";

  // All runtime log output (lg:: + kernel Msg/printstd) goes to this file;
  // the surface renders its tail.  The iOS app bundle is read-only.
  lg::set_file("ottsel-runtime.log", false, false, writable);

  std::thread boot(ottsel_ios_run_boot);

  while (!g_quit) {
    SDL_Event ev;
    while (SDL_PollEvent(&ev)) {
      if (ev.type == SDL_EVENT_QUIT) {
        g_quit = true;
      }
      switch (ev.type) {
        case SDL_EVENT_KEY_DOWN:
        case SDL_EVENT_KEY_UP:
          g_input.keyboard(ev.key.key, ev.type == SDL_EVENT_KEY_DOWN);
          break;
        case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
        case SDL_EVENT_GAMEPAD_BUTTON_UP:
          g_input.gamepad_button(ev.gbutton.button, ev.type == SDL_EVENT_GAMEPAD_BUTTON_DOWN);
          break;
        case SDL_EVENT_GAMEPAD_AXIS_MOTION:
          g_input.gamepad_axis(ev.gaxis.axis, ev.gaxis.value);
          break;
        case SDL_EVENT_FINGER_DOWN:
        case SDL_EVENT_FINGER_MOTION:
        case SDL_EVENT_FINGER_UP:
        case SDL_EVENT_FINGER_CANCELED:
          g_input.touch(ev);
          break;
        default:
          break;
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
      if (!g_metal || !ottsel_metal_gfx_has_live_scene()) {
        read_log_tail();
        render_surface();
      } else {
        // Keep a neutral base behind the live TFRAG/TIE draws without
        // drawing the shell's diagnostic text into the game frame.
        std::fill(g_rgba.begin(), g_rgba.end(), 0);
        for (size_t i = 0; i < g_rgba.size(); i += 4) {
          g_rgba[i + 0] = 8;
          g_rgba[i + 1] = 10;
          g_rgba[i + 2] = 18;
          g_rgba[i + 3] = 255;
        }
      }
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
