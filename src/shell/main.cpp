// Ottsel iOS shell: SDL window, touch controls and the signed runtime boot.
//
// The game draws through OpenGOAL's own OpenGL renderer on an OpenGL ES 3.0 context
// (game/graphics/pipelines/opengl.cpp, see gl_view.h). The shell adds the touch controls and a
// CPU-drawn status surface (log tail, settings, "import your data"), both composited over the game.
// The runtime boots on a background thread.

#include <TargetConditionals.h>
#include <unistd.h>

#include <algorithm>
#include <cstdlib>
#include <cstdio>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <array>
#include <cmath>
#include <string>
#include <thread>
#include <vector>

#include "common/log/log.h"
#include "game/sce/ottsel_platform_input.h"
#include "game/sound/sndshim.h"
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>

#include "font5x7.h"
#include "ios_boot.h"
#include "game/graphics/pipelines/ottsel_gl_view.h"
#include "touch_controls.h"
#include "external_display.h"

#include <atomic>
extern std::atomic<int> g_ottsel_pause_request;  // game/sce/libpad.cpp

namespace {

// The font data in font5x7.h uses 7-bit rows (LSB = leftmost, bit 6 =
// rightmost; e.g. 'o' = 0x38/0x44/0x44/0x44/0x38 draws sides at bits 2
// and 6).  kFontW must cover all 7 columns or every glyph is clipped.
// The table is column-major: five bytes per glyph, one byte per column, and each
// byte carries that column seven rows from the top in its low bits.  Reading it
// row-major transposes every glyph and runs two bytes past each one (that is what
// made the shell status text an unreadable lattice of letter-like tiles).
constexpr int kFontW = 5;
constexpr int kFontH = 7;
constexpr int kTextLines = 18;  // lines of log on the surface
constexpr int kSurfWDefault = 1024;
constexpr int kSurfHDefault = 768;

SDL_Window* g_win = nullptr;
int g_surf_w = kSurfWDefault;
int g_surf_h = kSurfHDefault;
int g_font_scale = 2;
std::vector<unsigned char> g_rgba((size_t)kSurfWDefault * kSurfHDefault * 4, 0);
std::string g_log_path;
std::vector<std::string> g_lines;
size_t g_file_pos = 0;
bool g_quit = false;
int g_frame = 0;
// When the next main-loop iteration may start: a fixed 60 Hz grid (see the loop tail).
Uint64 g_next_frame_ns = 0;
SDL_Gamepad* g_gamepad = nullptr;
SDL_JoystickID g_gamepad_id = 0;

void select_mobile_gamepad();

// I3: shell-owned settings, persisted per device class.  The completion plan says to implement useful
// settings only with working behaviour and persistence, no decorative controls, so every field here is a
// value something actually reads.
struct ShellSettings {
  // 0 = auto (follow the input actually in use), 1 = always drawn, 2 = never drawn.
  int surface_visibility = 0;
  // 1 keeps the shell log surface over the game after the settings screen closes.
  int log_overlay = 0;
  // GAMEPLAY: the touch camera region's drag gain in percent, and whether its vertical drag is inverted.
  int camera_sensitivity = 100;
  int invert_camera_y = 0;
  // VIDEO: the drawable the game renders into, as a percent of the native resolution.  The shell owns the
  // CAMetalLayer's drawable size, so this is a real render-resolution change (the layer scales it back up).
  int render_scale = 100;
};
ShellSettings g_settings;
std::string g_settings_path;

const char* surface_visibility_name(int value) {
  switch (value) {
    case 1: return "ALWAYS";
    case 2: return "HIDDEN";
    default: return "AUTO";
  }
}

void save_settings() {
  if (g_settings_path.empty()) {
    return;
  }
  std::ofstream file(g_settings_path, std::ios::trunc);
  if (!file) {
    lg::warn("OTTSEL SETTINGS: unable to save {}", g_settings_path);
    return;
  }
  file << "2\n" << g_settings.surface_visibility << "\n" << g_settings.log_overlay << "\n"
       << g_settings.camera_sensitivity << "\n" << g_settings.invert_camera_y << "\n"
       << g_settings.render_scale << "\n";
  lg::info("OTTSEL SETTINGS: saved visible={} log={} sens={} invert={} scale={} path={}",
           surface_visibility_name(g_settings.surface_visibility),
           g_settings.log_overlay, g_settings.camera_sensitivity, g_settings.invert_camera_y,
           g_settings.render_scale, g_settings_path);
}

void load_settings() {
  if (g_settings_path.empty()) {
    return;
  }
  std::ifstream file(g_settings_path);
  int version = 0;
  // Version 1 also carried a music volume, now left to the game's own Options menu.
  if (!(file >> version) || (version != 1 && version != 2)) {
    return;
  }
  // Tolerant: a field the file does not carry keeps its current (default) value, so a file written before
  // the field existed still loads instead of being discarded and rewritten.
  const auto read_int = [&file](int fallback) {
    int value = fallback;
    if (file >> value) {
      return value;
    }
    return fallback;
  };
  const int visibility = read_int(g_settings.surface_visibility);
  if (version == 1) {
    read_int(100);
  }
  const int log_overlay = read_int(g_settings.log_overlay);
  const int sensitivity = read_int(g_settings.camera_sensitivity);
  const int invert = read_int(g_settings.invert_camera_y);
  const int scale = read_int(g_settings.render_scale);
  if (visibility < 0 || visibility > 2 ||
      (log_overlay != 0 && log_overlay != 1) || sensitivity < 50 || sensitivity > 200 ||
      (invert != 0 && invert != 1) || (scale != 50 && scale != 75 && scale != 100)) {
    return;
  }
  g_settings.surface_visibility = visibility;
  g_settings.log_overlay = log_overlay;
  g_settings.camera_sensitivity = sensitivity;
  g_settings.invert_camera_y = invert;
  g_settings.render_scale = scale;
  lg::info("OTTSEL SETTINGS: loaded visible={} log={} sens={} invert={} scale={} path={}",
           surface_visibility_name(g_settings.surface_visibility),
           g_settings.log_overlay, g_settings.camera_sensitivity, g_settings.invert_camera_y,
           g_settings.render_scale, g_settings_path);
}
// True while a keyboard, mouse or physical controller is the input in use; the touch controls hide
// (setting "Automatically") until a finger touches the screen again.
bool g_native_input_mode = false;
std::string g_writable_dir;
double g_presented_fps = 0.0;  // frames presented over the last second (FPS counter)

void update_touch_visibility() {
  ottsel_touch_set_hidden(g_native_input_mode);
}

void hide_touch_overlay_for_native_input() {
  if (g_native_input_mode) {
    return;
  }
  g_native_input_mode = true;
  update_touch_visibility();
  lg::info("OTTSEL INPUT: native keyboard/mouse/controller active; touch controls hidden");
}

// The mobile shell does not create the desktop Display/InputManager.  It
// nevertheless delivers the same completed DualShock snapshot to GOAL, via
// the platform bridge sampled by scePadRead.
struct ShellPadInput {
  ottsel::platform_input::PadState state;
  bool key_w = false;
  bool key_a = false;
  bool key_s = false;
  bool key_d = false;
  bool mouse_left = false;
  bool mouse_right = false;
  ottsel::platform_input::MouseMotionLatch mouse_motion_latch;
  bool mouse_position_valid = false;
  float last_mouse_x = 0.f;
  float last_mouse_y = 0.f;
  OttselTouchPad touch_prev;

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
    // Mouse buttons are actions, not a second movement source. Keeping the
    // left stick exclusively keyboard-driven prevents a simultaneous
    // Cross/Circle click from injecting an unexpected forward direction.
    state.lefty = key_w == key_s ? 127 : (key_w ? 0 : 255);
  }

  void keyboard(SDL_Keycode key, SDL_Scancode scancode, bool pressed) {
    hide_touch_overlay_for_native_input();
    using namespace ottsel::platform_input;
    Button digital_button = static_cast<Button>(0);
    // Movement is physical-key driven first. This keeps WASD stable across
    // keyboard layouts and avoids SDL text/keycode translation changing the
    // direction while a key is held.
    switch (scancode) {
      case SDL_SCANCODE_W: key_w = pressed; break;
      case SDL_SCANCODE_A: key_a = pressed; break;
      case SDL_SCANCODE_S: key_s = pressed; break;
      case SDL_SCANCODE_D: key_d = pressed; break;
      default:
        switch (key) {
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
          case SDLK_W: key_w = pressed; break;
          case SDLK_A: key_a = pressed; break;
          case SDLK_S: key_s = pressed; break;
          case SDLK_D: key_d = pressed; break;
          default: return;
        }
        break;
    }
    if (digital_button) {
      set_button(&state, digital_button, pressed);
      // Match the desktop keyboard event latch: eight 60 Hz pad reads
      // preserve a tap long enough for the independent GOAL thread, while
      // ordinary held keys continue to use the live state above.
      if (pressed) {
        latch_native_button(0, digital_button);
      }
    }
    update_keyboard_stick();
    publish();
    trace("keyboard");
  }

  void mouse_motion(float x, float y, float xrel, float yrel) {
    // A pointer just passing over the screen is not a player choosing the mouse: it steers the camera only
    // after a click has captured it (mouse_button), and it never hides the touch controls by itself.
    if (!g_win || !SDL_GetWindowRelativeMouseMode(g_win)) {
      return;
    }
    // Some SDL backends (notably Simulator pointer capture) report absolute
    // motion while leaving xrel/yrel at zero on the first captured event. Use
    // the position delta as a fallback so a native mouse cannot silently
    // produce a permanently neutral camera stick.
    if (mouse_position_valid && xrel == 0.f && yrel == 0.f) {
      xrel = x - last_mouse_x;
      yrel = y - last_mouse_y;
    }
    last_mouse_x = x;
    last_mouse_y = y;
    mouse_position_valid = true;
    // SDL may deliver several relative-motion events before the next pad
    // sample. Accumulate them from the neutral center instead of letting the
    // last event overwrite the earlier motion; settle_mouse() clears the
    // impulse after the frame is published.
    mouse_motion_latch.add(xrel, yrel);
    state.rightx = mouse_motion_latch.rightx;
    state.righty = mouse_motion_latch.righty;
    publish();
    trace("mouse-motion");
  }

  void settle_mouse() {
    const int before = mouse_motion_latch.remaining_reads;
    mouse_motion_latch.advance_event_loop();
    if (before != mouse_motion_latch.remaining_reads) {
      state.rightx = mouse_motion_latch.rightx;
      state.righty = mouse_motion_latch.righty;
      publish();
    }
  }

  void mouse_button(Uint8 button, bool pressed) {
    hide_touch_overlay_for_native_input();
    if (g_win) {
      SDL_SetWindowRelativeMouseMode(g_win, true);
    }
    using namespace ottsel::platform_input;
    if (button == SDL_BUTTON_LEFT) mouse_left = pressed;
    if (button == SDL_BUTTON_RIGHT) mouse_right = pressed;
    if (button == SDL_BUTTON_LEFT) set_button(&state, Cross, pressed);
    if (button == SDL_BUTTON_RIGHT) set_button(&state, Circle, pressed);
    if (pressed) {
      // A short click can otherwise disappear between SDL delivery and the
      // independent GOAL pad read. Keep mouse actions on the same bounded
      // tap-latch path as native keyboard actions.
      latch_native_button(0, button == SDL_BUTTON_LEFT ? Cross : Circle);
    }
    // Recompute the complete keyboard stick state so mouse release cannot
    // leave a stale direction behind or override a held physical WASD key.
    update_keyboard_stick();
    publish();
    trace("mouse-button");
  }

  void gamepad_button(SDL_JoystickID instance_id, Uint8 button, bool pressed) {
    if (instance_id != g_gamepad_id) {
      return;
    }
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

  void gamepad_axis(SDL_JoystickID instance_id, Uint8 axis, Sint16 value) {
    if (instance_id != g_gamepad_id) {
      return;
    }
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

  // The touch overlay (touch_controls.mm) reports its whole pad on every change; apply only what changed so
  // a held keyboard key or controller button is not released by an unrelated touch.
  void touch_pad(const OttselTouchPad& pad) {
    using namespace ottsel::platform_input;
    const auto axis = [](float v) {
      return static_cast<u8>(std::clamp(127 + static_cast<int>(std::lround(v * 128.f)), 0, 255));
    };
    const u16 changed = pad.buttons ^ touch_prev.buttons;
    for (int bit = 0; bit < 16; ++bit) {
      if (changed & (1u << bit)) {
        const auto button = static_cast<Button>(1u << bit);
        const bool pressed = (pad.buttons & (1u << bit)) != 0;
        set_button(&state, button, pressed);
        // Same latch as a keyboard tap: a short press survives until the game thread samples the pad.
        if (pressed) {
          latch_native_button(0, button);
        }
      }
    }
    if (pad.lx != touch_prev.lx || pad.ly != touch_prev.ly) {
      state.leftx = axis(pad.lx);
      state.lefty = axis(pad.ly);
    }
    if (pad.rx != touch_prev.rx || pad.ry != touch_prev.ry) {
      const float gain = (float)g_settings.camera_sensitivity / 100.f;
      state.rightx = axis(pad.rx * gain);
      state.righty = axis(pad.ry * gain * (g_settings.invert_camera_y ? -1.f : 1.f));
    }
    const bool buttons_changed = changed != 0;
    touch_prev = pad;
    publish();
    if (buttons_changed) {
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

void release_mobile_gamepad(const char* reason) {
  if (!g_gamepad) {
    return;
  }
  SDL_CloseGamepad(g_gamepad);
  g_gamepad = nullptr;
  g_gamepad_id = 0;
  g_input.neutralize();
  lg::info("OTTSEL GAMEPAD: pad0 released reason={} state=neutral", reason);
}

bool acquire_mobile_gamepad(SDL_JoystickID instance_id) {
  if (g_gamepad) {
    return false;
  }
  SDL_Gamepad* gamepad = SDL_OpenGamepad(instance_id);
  if (!gamepad) {
    lg::warn("OTTSEL GAMEPAD: open failed id={} error={}", instance_id, SDL_GetError());
    return false;
  }
  g_gamepad = gamepad;
  g_gamepad_id = SDL_GetGamepadID(gamepad);
  lg::info("OTTSEL GAMEPAD: pad0 acquired id={} name={}", g_gamepad_id,
           SDL_GetGamepadName(gamepad) ? SDL_GetGamepadName(gamepad) : "unknown");
  return true;
}

void select_mobile_gamepad() {
  if (g_gamepad) {
    return;
  }
  int count = 0;
  SDL_JoystickID* devices = SDL_GetGamepads(&count);
  for (int i = 0; i < count && !g_gamepad; ++i) {
    acquire_mobile_gamepad(devices[i]);
  }
  SDL_free(devices);
}

void handle_mobile_gamepad_added(SDL_JoystickID instance_id) {
  // One stable controller owns pad 0. Additional devices remain available to
  // SDL but cannot leak events into the selected pad.
  acquire_mobile_gamepad(instance_id);
}

void handle_mobile_gamepad_removed(SDL_JoystickID instance_id) {
  if (!ottsel::platform_input::owns_gamepad_event(g_gamepad_id, instance_id)) {
    return;
  }
  release_mobile_gamepad("disconnect");
  // SDL may deliver another GAMEPAD_ADDED event after the replacement is
  // enumerated; select now as well for already-present reconnects.
  select_mobile_gamepad();
}

void handle_mobile_gamepad_remapped(SDL_JoystickID instance_id) {
  if (!ottsel::platform_input::owns_gamepad_event(g_gamepad_id, instance_id)) {
    return;
  }
  // A remap can invalidate the button/axis interpretation while the old
  // snapshot is still held. Neutralize before reopening the same instance.
  release_mobile_gamepad("remapped");
  select_mobile_gamepad();
}

// I3: the settings file is per device class, so an iPhone and an iPad can carry
// different choices without one clobbering the other.
void refresh_settings_path() {
  if (g_writable_dir.empty()) {
    return;
  }
  const std::string want =
      g_writable_dir +
      (ottsel_ios_shell_is_phone() ? "settings-phone.cfg" : "settings-tablet.cfg");
  if (want == g_settings_path) {
    return;
  }
  g_settings_path = want;
  load_settings();
}

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
  for (int col = 0; col < kFontW; col++) {
    const uint8_t bits = glyph[col];
    for (int row = 0; row < kFontH; row++) {
      if (bits & (1 << row)) {
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
            "Ottsel",
            120, 200, 255);
  draw_text(8 * g_font_scale, 17 * g_font_scale, "Renderer: OpenGOAL OpenGL (ES 3.0)", 120, 255, 120);

  if (!ottsel_ios_has_user_data()) {
    draw_text(8 * g_font_scale, 26 * g_font_scale,
              "DATA: import OttselUserData in Files",
              255, 210, 90);
  }

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


// I3: the persistent three-dot settings entry.  The screen is composed on the CPU into g_rgba - the same
// surface the shell status screen uses - and handed to the product pass as the status overlay, so it needs
// no glyph geometry in the overlay vertex path.  The completion plan names six sections; only sections whose
// entries have real behaviour are offered (no decorative controls), and each section screen holds its own
// rows plus BACK.
// VIDEO: the game renders at this percentage of the window's pixels and is scaled up to the window.
void apply_render_scale() {
  ottsel_gl_set_render_scale(g_settings.render_scale);
}

// The touch overlay's menu reads and changes these (touch_controls.h).
int shell_setting(const char* key) {
  const std::string k = key;
  if (k == "controls") return g_settings.surface_visibility;
  if (k == "render_scale") return g_settings.render_scale;
  if (k == "camera_sensitivity") return g_settings.camera_sensitivity;
  if (k == "invert_camera_y") return g_settings.invert_camera_y;
  if (k == "log_overlay") return g_settings.log_overlay;
  return 0;
}

void set_shell_setting(const char* key, int value) {
  const std::string k = key;
  if (k == "controls") g_settings.surface_visibility = std::clamp(value, 0, 2);
  if (k == "render_scale") {
    g_settings.render_scale = value == 50 || value == 75 ? value : 100;
    apply_render_scale();
  }
  if (k == "camera_sensitivity") g_settings.camera_sensitivity = std::clamp(value, 50, 200);
  if (k == "invert_camera_y") g_settings.invert_camera_y = value ? 1 : 0;
  if (k == "log_overlay") {
    g_settings.log_overlay = value ? 1 : 0;
    if (!value) ottsel_gl_set_status(nullptr, 0, 0);
  }
  save_settings();
}

// iOS terminates an app that submits Metal (ANGLE) work while it is not active, so rendering stops before
// the app resigns active and resumes once it is active again. The game thread waits in vsync meanwhile.
bool g_render_suspended = false;

// Set by an atexit handler: after it, static objects (the audio player and its mutex, the input state)
// are being destroyed, but UIKit can still deliver "entered background" while iOS terminates the app.
std::atomic<bool> g_process_exiting{false};

bool on_event_watch(void*, SDL_Event* ev) {
  if (g_process_exiting.load()) return true;
  switch (ev->type) {
    case SDL_EVENT_WILL_ENTER_BACKGROUND:
      // Come back to the pause menu, not live action (game/sce/libpad.cpp -> main.gc).
      g_ottsel_pause_request = 1;
      if (!g_render_suspended) {
        g_render_suspended = true;
        ottsel_gl_suspend();
        lg::info("OTTSEL LIFECYCLE: resigning active; GPU work finished and rendering paused");
      }
      break;
    case SDL_EVENT_DID_ENTER_BACKGROUND:
      // Never leave movement or an action held when the app is suspended.
      g_input.neutralize();
      if (g_win) {
        SDL_SetWindowRelativeMouseMode(g_win, false);
      }
      snd_PauseAudioOutput();
      lg::info("OTTSEL LIFECYCLE: background input neutralized and audio paused");
      break;
    case SDL_EVENT_DID_ENTER_FOREGROUND:
      // A controller can disappear while the app is suspended without a
      // usable add event reaching the shell. Re-enumerate the selected pad so
      // reconnect does not require relaunching the app.
      select_mobile_gamepad();
      snd_ResumeAudioOutput();
      if (g_render_suspended) {
        g_render_suspended = false;
        lg::info("OTTSEL LIFECYCLE: active again; rendering resumed");
      }
      lg::info("OTTSEL LIFECYCLE: foreground controller rechecked and audio resumed");
      break;
    default:
      break;
  }
  return true;
}

}  // namespace

// Device class for the per-class settings file (declared in ios_boot.h), from SDL's UIKit backend.
bool ottsel_ios_shell_is_phone() {
  return !SDL_IsTablet();
}

int main(int argc, char** argv) {
  (void)argc;
  (void)argv;

  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)) {
    fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
    return 1;
  }
  SDL_AddEventWatch(on_event_watch, nullptr);
  // Registered after every static in the program was constructed, so it runs before their destructors.
  std::atexit([] { g_process_exiting = true; });
  select_mobile_gamepad();

  // The game renders with OpenGL ES (ANGLE on Metal) into this window's Metal layer (ottsel_gl_attach).
  g_win = SDL_CreateWindow("Ottsel Shell", 1024, 768, SDL_WINDOW_METAL | SDL_WINDOW_HIGH_PIXEL_DENSITY);
  if (!g_win) {
    fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
    return 1;
  }

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
  g_writable_dir = writable;
  refresh_settings_path();

  // All runtime log output (lg:: + kernel Msg/printstd) goes to this file;
  // the surface renders its tail.  The iOS app bundle is read-only.
  lg::set_file("ottsel-runtime.log", false, false, writable);
  lg::info("OTTSEL RUNTIME BOOT: pid={} writable={}", (u32)getpid(), writable);

  // OpenGOAL's renderer reads level files from the user-data root as soon as it exists.
  ottsel_ios_prepare_user_data();
  if (!ottsel_gl_attach(g_win)) {
    return 1;
  }
  apply_render_scale();
  ottsel_touch_install(g_win, {[](const OttselTouchPad& pad) { g_input.touch_pad(pad); },
                               shell_setting, set_shell_setting, [] { return g_presented_fps; },
                               [] { return ottsel_ios_has_user_data(); }, g_writable_dir.c_str()});
  ottsel_external_display_install();  // a connected TV shows the game; the iPad keeps the controls
  // With the real IOP, OVERLORD's InitSound starts the sound system (game/overlord/jak1/ssound.cpp).

  std::thread boot(ottsel_ios_run_boot);

  lg::info("OTTSEL SHELL: frame loop enter");
  while (!g_quit) {
    SDL_Event ev;
    while (SDL_PollEvent(&ev)) {
      if (ev.type == SDL_EVENT_QUIT) {
        lg::info("OTTSEL SHELL: quit event");
        g_quit = true;
      }
      switch (ev.type) {
        case SDL_EVENT_GAMEPAD_ADDED:
          handle_mobile_gamepad_added(ev.gdevice.which);
          break;
        case SDL_EVENT_GAMEPAD_REMOVED:
          handle_mobile_gamepad_removed(ev.gdevice.which);
          break;
        case SDL_EVENT_GAMEPAD_REMAPPED:
          handle_mobile_gamepad_remapped(ev.gdevice.which);
          break;
        case SDL_EVENT_KEY_DOWN:
        case SDL_EVENT_KEY_UP:
          g_input.keyboard(ev.key.key, ev.key.scancode, ev.type == SDL_EVENT_KEY_DOWN);
          break;
#if !TARGET_OS_SIMULATOR
        // In the Simulator the Mac pointer stands in for a finger (its clicks arrive as touches); its hover and
        // click mouse events are not a mouse the player plugged in.
        case SDL_EVENT_MOUSE_MOTION:
          if (ottsel::platform_input::routes_to_native_mouse(ev.motion.which,
                                                              SDL_TOUCH_MOUSEID)) {
            g_input.mouse_motion(ev.motion.x, ev.motion.y, ev.motion.xrel, ev.motion.yrel);
          }
          break;
        case SDL_EVENT_MOUSE_BUTTON_DOWN:
        case SDL_EVENT_MOUSE_BUTTON_UP:
          if (ottsel::platform_input::routes_to_native_mouse(ev.button.which,
                                                              SDL_TOUCH_MOUSEID)) {
            g_input.mouse_button(ev.button.button, ev.type == SDL_EVENT_MOUSE_BUTTON_DOWN);
          }
          break;
#endif
        case SDL_EVENT_WINDOW_FOCUS_LOST:
          g_input.neutralize();
          if (g_win) {
            SDL_SetWindowRelativeMouseMode(g_win, false);
          }
          break;
        case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
        case SDL_EVENT_GAMEPAD_BUTTON_UP:
          g_input.gamepad_button(ev.gbutton.which, ev.gbutton.button,
                                 ev.type == SDL_EVENT_GAMEPAD_BUTTON_DOWN);
          break;
        case SDL_EVENT_GAMEPAD_AXIS_MOTION:
          g_input.gamepad_axis(ev.gaxis.which, ev.gaxis.axis, ev.gaxis.value);
          break;
        case SDL_EVENT_FINGER_DOWN:
          // Touches on the controls go to UIKit; one that reaches the game view while a controller or
          // keyboard hid the controls means touch is the input in use again.
          if (g_native_input_mode) {
            g_native_input_mode = false;
            update_touch_visibility();
          }
          break;
        default:
          break;
      }
    }

    // I3 controller handoff: a pad that exists must end up owned.  The acquire path runs on
    // SDL_EVENT_GAMEPAD_ADDED, and if the shell ever drops the pad without a re-add event (a spurious
    // quit that ends the frame loop, a remap, a suspend) nothing brings it back - measured: the pad was
    // acquired and then released with reason 'shutdown' in the same second, so no pad input ever reached
    // the game.  Re-enumerate at most once a second so handoff is self-healing.
    {
      static Uint64 last_pad_check = 0;
      const Uint64 now_ticks = SDL_GetTicks();
      if (!g_gamepad && now_ticks - last_pad_check >= 1000) {
        last_pad_check = now_ticks;
        select_mobile_gamepad();
      }
    }
    g_input.settle_mouse();
    snd_PumpAudioInit();
    // BOT22: file-based input trigger for headless driving — creating
    // <bundle>/ottsel-press-start injects a START press (then the file is
    // removed).  Prefer the writable app directory; the installed bundle is
    // read-only on device but remains a useful Simulator diagnostic fallback.
    // Checked every fourth frame (15 times a second at 60 fps): ~30 file-system calls per check is
    // measurable main-thread time, and a hold is the file's presence, so it only starts later.
    static unsigned trigger_frame = 0;
    if ((++trigger_frame & 3) == 0) {
      const auto trigger_path = [&](const char* name) {
        std::string writable_path = writable + name;
        if (access(writable_path.c_str(), F_OK) == 0) {
          return writable_path;
        }
        return bundle + name;
      };
      // BOT59: an old 30-frame divider at ~9 fps throttled injected taps to one per 3.3 s, so a scripted
      // "hold" decayed into a one-frame pulse. The four-frame divider above keeps holds continuous.
      {
        std::string trig = trigger_path("ottsel-press-start");
        if (access(trig.c_str(), F_OK) == 0) {
          unlink(trig.c_str());
          g_input.keyboard(SDLK_RETURN, SDL_SCANCODE_RETURN, true);
          g_input.keyboard(SDLK_RETURN, SDL_SCANCODE_RETURN, false);
          fprintf(stderr, "ottsel BOT22: latched START tap (file trigger)\n");
        }
        std::string cross_trig = trigger_path("ottsel-press-cross");
        if (access(cross_trig.c_str(), F_OK) == 0) {
          unlink(cross_trig.c_str());
          g_input.keyboard(SDLK_SPACE, SDL_SCANCODE_SPACE, true);
          g_input.keyboard(SDLK_SPACE, SDL_SCANCODE_SPACE, false);
          fprintf(stderr, "ottsel BOT22: latched Cross tap (file trigger)\n");
        }
        std::string left_trig = trigger_path("ottsel-press-left");
        if (access(left_trig.c_str(), F_OK) == 0) {
          unlink(left_trig.c_str());
          g_input.keyboard(SDLK_LEFT, SDL_SCANCODE_LEFT, true);
          g_input.keyboard(SDLK_LEFT, SDL_SCANCODE_LEFT, false);
          fprintf(stderr, "ottsel BOT22: latched D-pad-left tap (file trigger)\n");
        }
        std::string down_trig = trigger_path("ottsel-press-down");
        if (access(down_trig.c_str(), F_OK) == 0) {
          unlink(down_trig.c_str());
          g_input.keyboard(SDLK_DOWN, SDL_SCANCODE_DOWN, true);
          g_input.keyboard(SDLK_DOWN, SDL_SCANCODE_DOWN, false);
          fprintf(stderr, "ottsel BOT22: latched D-pad-down tap (file trigger)\n");
        }
        std::string bgtrig = trigger_path("ottsel-bg-village1");
        if (access(bgtrig.c_str(), F_OK) == 0) {
          unlink(bgtrig.c_str());
          extern int g_ottsel_bg_village1_request;
          g_ottsel_bg_village1_request = 1;
          fprintf(stderr, "ottsel BOT22: (bg 'village1) requested (file trigger)\n");
        }
      }
      // BOT59: hold triggers.  For a sustained press the file's existence
      // *is* the button state: create ottsel-hold-left to press LEFT, remove
      // it to release.  A tap above is one frame; a hold is what the game's
      // own camera and movement code actually reads.
      struct HoldTrigger {
        const char* file;
        SDL_Keycode key;
        SDL_Scancode scancode;
        bool* down;
      };
      static bool hold_start = false;
      static bool hold_cross = false;
      static bool hold_left = false;
      static bool hold_right = false;
      static bool hold_down = false;
      static bool hold_up = false;
      // BOT62: the D-pad holds above cannot move Jak.  Jak 1 reads the LEFT
      // ANALOG STICK for movement, and the shell derives that stick from
      // A/D/W/S (see update_keyboard_stick).  Without a held stick the
      // "controllable" half of the product gate has no way to be driven, so
      // expose the same four movement keys as hold triggers.
      static bool hold_stick_left = false;
      static bool hold_stick_right = false;
      static bool hold_stick_down = false;
      static bool hold_stick_up = false;
      static const HoldTrigger hold_triggers[] = {
          {"ottsel-hold-start", SDLK_RETURN, SDL_SCANCODE_RETURN, &hold_start},
          {"ottsel-hold-cross", SDLK_SPACE, SDL_SCANCODE_SPACE, &hold_cross},
          {"ottsel-hold-left", SDLK_LEFT, SDL_SCANCODE_LEFT, &hold_left},
          {"ottsel-hold-right", SDLK_RIGHT, SDL_SCANCODE_RIGHT, &hold_right},
          {"ottsel-hold-down", SDLK_DOWN, SDL_SCANCODE_DOWN, &hold_down},
          {"ottsel-hold-up", SDLK_UP, SDL_SCANCODE_UP, &hold_up},
          {"ottsel-hold-stick-left", SDLK_A, SDL_SCANCODE_A, &hold_stick_left},
          {"ottsel-hold-stick-right", SDLK_D, SDL_SCANCODE_D, &hold_stick_right},
          {"ottsel-hold-stick-down", SDLK_S, SDL_SCANCODE_S, &hold_stick_down},
          {"ottsel-hold-stick-up", SDLK_W, SDL_SCANCODE_W, &hold_stick_up},
      };
      for (const HoldTrigger& hold : hold_triggers) {
        const bool present = access(trigger_path(hold.file).c_str(), F_OK) == 0;
        if (present != *hold.down) {
          *hold.down = present;
          g_input.keyboard(hold.key, hold.scancode, present);
        }
      }
    }
    // I3: a virtual gamepad behind a bounded trigger, so the gamepad path - discovery, mapping, stick and
    // button delivery, and the handoff when a pad disappears - can be exercised on a Simulator with no
    // hardware attached.  The pad file's existence is the pad's existence and each button/axis file is that
    // control's state, mirroring the keyboard hold triggers.  SDL derives the gamepad mapping from the
    // descriptor's mask in ascending button order, so the indices below follow the same order:
    // SOUTH(cross) EAST(circle) WEST(square) NORTH(triangle) BACK(select) START, L1, R1, DPAD up/down/left/right;
    // axes follow the mask order LEFTX, LEFTY, RIGHTX, RIGHTY.
    {
      struct VirtualButton {
        const char* file;
        int index;
      };
      struct VirtualAxis {
        const char* file;
        int index;
        int value;
      };
      static const VirtualButton kVirtualButtons[] = {
          {"cross", 0}, {"circle", 1}, {"square", 2}, {"triangle", 3}, {"select", 4},
          {"start", 5}, {"l1", 6},     {"r1", 7},     {"up", 8},       {"down", 9},
          {"left", 10}, {"right", 11},
      };
      static const VirtualAxis kVirtualAxes[] = {
          {"stick-left", 0, -32768}, {"stick-right", 0, 32767},
          {"stick-up", 1, -32768},   {"stick-down", 1, 32767},
      };
      static bool button_state[sizeof(kVirtualButtons) / sizeof(kVirtualButtons[0])] = {};
      static bool axis_state[sizeof(kVirtualAxes) / sizeof(kVirtualAxes[0])] = {};
      static SDL_JoystickID virtual_pad = 0;
      static bool virtual_pad_open_logged = false;
      static SDL_Joystick* virtual_joystick = nullptr;
      const bool pad_present = access((writable + "ottsel-virtual-pad").c_str(), F_OK) == 0;
      if (pad_present && !virtual_pad) {
        SDL_VirtualJoystickDesc desc;
        SDL_INIT_INTERFACE(&desc);
        desc.type = SDL_JOYSTICK_TYPE_GAMEPAD;
        desc.naxes = 4;
        desc.axis_mask = (1u << SDL_GAMEPAD_AXIS_LEFTX) | (1u << SDL_GAMEPAD_AXIS_LEFTY) |
                         (1u << SDL_GAMEPAD_AXIS_RIGHTX) | (1u << SDL_GAMEPAD_AXIS_RIGHTY);
        desc.nbuttons = 12;
        desc.button_mask = (1u << SDL_GAMEPAD_BUTTON_SOUTH) | (1u << SDL_GAMEPAD_BUTTON_EAST) |
                           (1u << SDL_GAMEPAD_BUTTON_WEST) | (1u << SDL_GAMEPAD_BUTTON_NORTH) |
                           (1u << SDL_GAMEPAD_BUTTON_BACK) | (1u << SDL_GAMEPAD_BUTTON_START) |
                           (1u << SDL_GAMEPAD_BUTTON_LEFT_SHOULDER) |
                           (1u << SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER) |
                           (1u << SDL_GAMEPAD_BUTTON_DPAD_UP) | (1u << SDL_GAMEPAD_BUTTON_DPAD_DOWN) |
                           (1u << SDL_GAMEPAD_BUTTON_DPAD_LEFT) | (1u << SDL_GAMEPAD_BUTTON_DPAD_RIGHT);
        desc.name = "Ottsel virtual pad";
        desc.vendor_id = 0x054c;
        desc.product_id = 0x0268;
        virtual_pad = SDL_AttachVirtualJoystick(&desc);
        // The diagnostics needs its own handle: the shell's gamepad can be closed (and with it the shared
        // joystick) by the input path at any time, and a borrowed handle would then silently drop every
        // button and axis this trigger exists to send.
        virtual_joystick = virtual_pad ? SDL_OpenJoystick(virtual_pad) : nullptr;
        virtual_pad_open_logged = false;
        lg::info("OTTSEL VIRTUAL PAD: attach id={} joystick={}", (int)virtual_pad,
                 virtual_joystick ? "open" : "missing");
      } else if (!pad_present && virtual_pad) {
        if (virtual_joystick) {
          SDL_CloseJoystick(virtual_joystick);
          virtual_joystick = nullptr;
        }
        SDL_DetachVirtualJoystick(virtual_pad);
        lg::info("OTTSEL VIRTUAL PAD: detach id={}", (int)virtual_pad);
        virtual_pad = 0;
        virtual_pad_open_logged = false;
        for (bool& state : button_state) {
          state = false;
        }
        for (bool& state : axis_state) {
          state = false;
        }
      }
      // SDL registers the virtual device on the next event pump, so the handle is (re)taken lazily rather
      // than only at attach time, where asking immediately returns null.
      if (!virtual_joystick && virtual_pad) {
        virtual_joystick = SDL_OpenJoystick(virtual_pad);
      }
      SDL_Joystick* virtual_pad_handle = virtual_joystick;
      if (virtual_pad && virtual_pad_handle && !virtual_pad_open_logged) {
        virtual_pad_open_logged = true;
        lg::info("OTTSEL VIRTUAL PAD: handle open id={}", (int)virtual_pad);
      }
      // The shell keeps one stable pad, and a device that was already present (the Simulator exposes one
      // named "Gamepad") otherwise keeps pad 0 and the diagnostics' buttons reach nothing.  The trigger
      // therefore claims pad 0 for itself while it is present.
      if (virtual_pad && virtual_pad_handle && g_gamepad_id != virtual_pad) {
        if (g_gamepad) {
          release_mobile_gamepad("virtual-pad-takeover");
        }
        acquire_mobile_gamepad(virtual_pad);
      }
      if (virtual_pad_handle) {
        for (size_t i = 0; i < sizeof(kVirtualButtons) / sizeof(kVirtualButtons[0]); ++i) {
          const std::string path = writable + "ottsel-virtual-pad-" + kVirtualButtons[i].file;
          const bool down = access(path.c_str(), F_OK) == 0;
          if (down != button_state[i]) {
            button_state[i] = down;
            SDL_SetJoystickVirtualButton(virtual_pad_handle, kVirtualButtons[i].index, down);
            lg::info("OTTSEL VIRTUAL PAD: button {} {}", kVirtualButtons[i].file,
                     down ? "down" : "up");
          }
        }
        for (size_t i = 0; i < sizeof(kVirtualAxes) / sizeof(kVirtualAxes[0]); ++i) {
          const std::string path = writable + "ottsel-virtual-pad-" + kVirtualAxes[i].file;
          const bool active = access(path.c_str(), F_OK) == 0;
          if (active != axis_state[i]) {
            axis_state[i] = active;
            SDL_SetJoystickVirtualAxis(virtual_pad_handle, kVirtualAxes[i].index,
                                       active ? (Sint16)kVirtualAxes[i].value : 0);
            lg::info("OTTSEL VIRTUAL PAD: axis {} {}", kVirtualAxes[i].file,
                     active ? "on" : "off");
          }
        }
      }
    }

    // The window's pixel size is only final after layout (and changes on rotation); the CPU status surface
    // follows it.
    {
      int dw = 0, dh = 0;
      SDL_GetWindowSizeInPixels(g_win, &dw, &dh);
      if (dw > 0 && dh > 0 && (dw != g_surf_w || dh != g_surf_h)) {
        g_surf_w = dw;
        g_surf_h = dh;
        g_rgba.assign((size_t)g_surf_w * g_surf_h * 4, 0);
        g_font_scale = std::max(3, g_surf_w / 430);
        lg::info("OTTSEL SHELL: window {}x{} font scale {}", dw, dh, g_font_scale);
      }
    }
    {
      // F1/G2.6: with no user data the status screen names what to import and covers the game until a pack
      // is in use; before the game has drawn anything it shows the boot log.
      const bool data_missing = !ottsel_ios_has_user_data();
      const bool live = ottsel_gl_has_live_scene();
      static bool status_overlay_active = false;
      static int logged_status_state = -1;
      const int status_state = (data_missing ? 1 : 0) | (live ? 2 : 0);
      if (status_state != logged_status_state) {
        logged_status_state = status_state;
        lg::info("OTTSEL DATA: status state={} data-missing={} live-scene={}", status_state,
                 data_missing ? 1 : 0, live ? 1 : 0);
      }
      if (data_missing || !live || g_settings.log_overlay) {
        static int status_upload_countdown = 0;  // the surface is a full window of pixels
        if (status_upload_countdown-- <= 0) {
          status_upload_countdown = 30;
          read_log_tail();
          render_surface();
          ottsel_gl_set_status(g_rgba.data(), g_surf_w, g_surf_h);
          status_overlay_active = true;
        }
      } else if (status_overlay_active) {
        ottsel_gl_set_status(nullptr, 0, 0);
        status_overlay_active = false;
      }
    }
    // OpenGOAL renders the frame and the status surface goes on top; UIKit draws the touch controls.
    if (g_render_suspended) {
      SDL_Delay(50);
      continue;
    }
    ottsel_gl_render(g_win);
    g_frame++;
    {
      static Uint64 fps_window_start = SDL_GetTicksNS();
      static int fps_frames = 0;
      ++fps_frames;
      const Uint64 now = SDL_GetTicksNS();
      if (now - fps_window_start >= 1000000000ull) {
        g_presented_fps = fps_frames * 1e9 / (double)(now - fps_window_start);
        fps_frames = 0;
        fps_window_start = now;
      }
    }
    // Cap the loop (and so the game, which advances once per presented frame) at 60 Hz. Deadlines
    // sit on a fixed grid, so a sleep that wakes late shortens the next wait instead of adding up:
    // "sleep the rest of 16.7 ms" settled near 56 fps and ran the game ~7% slow. A frame more than
    // one budget late resyncs rather than bursting to catch up.
    {
      const Uint64 budget_ns = 1000000000ull / 60ull;
      const Uint64 now_ns = SDL_GetTicksNS();
      g_next_frame_ns = g_next_frame_ns ? g_next_frame_ns + budget_ns : now_ns;
      if (g_next_frame_ns + budget_ns < now_ns) g_next_frame_ns = now_ns;
      if (now_ns < g_next_frame_ns) SDL_DelayNS(g_next_frame_ns - now_ns);
    }
  }
  release_mobile_gamepad("shutdown");

  // ask the dispatcher loop to stop (MasterExit lives in the runtime lib)
  extern void ottsel_ios_stop_dispatch();
  ottsel_ios_stop_dispatch();
  ottsel_gl_shutdown();
  boot.join();

  snd_StopSoundSystem();
  SDL_DestroyWindow(g_win);
  SDL_Quit();
  return 0;
}
