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
// Timestamp at the top of the previous main-loop iteration.  Used to turn the
// old unconditional SDL_Delay(16) into a 60 Hz budget cap (see the loop tail).
Uint64 g_loop_start_ns = 0;
SDL_Gamepad* g_gamepad = nullptr;
SDL_JoystickID g_gamepad_id = 0;

void select_mobile_gamepad();
void toggle_touch_editor();

enum class TouchRegion : size_t {
  LeftStick = 0,
  Camera,
  Circle,
  Cross,
  Square,
  Triangle,
  DpadUp,
  DpadRight,
  DpadDown,
  DpadLeft,
  Start,
  L1,
  R1,
  // I3: the persistent three-dot settings entry the completion plan names.  Appended after R1 so no
  // existing region index (and therefore no saved layout) shifts meaning.
  Menu,
  Count,
};

struct TouchRegionLayout {
  float x = 0.f;
  float y = 0.f;
  float w = 0.f;
  float h = 0.f;
};

struct TouchLayout {
  std::array<TouchRegionLayout, static_cast<size_t>(TouchRegion::Count)> regions{};
  float opacity = 1.f;
};

constexpr size_t kTouchRegionCount = static_cast<size_t>(TouchRegion::Count);

// The default regions, per device class (P1).  A region's tap size in surface units is its fraction times
// that axis, so one table gives very different targets on a phone and on a tablet - which is why the
// classes do not share one.  Every table is clamped into bounds by clamp_touch_region() before it is
// written, and load_touch_layout() accepts anything that survived that.
constexpr std::array<TouchRegionLayout, kTouchRegionCount> kTouchDefaultsTablet = {{
    {0.055f, 0.605f, 0.13f, 0.165f},  // left stick
    {0.70f, 0.36f, 0.16f, 0.10f},     // camera
    {0.785f, 0.615f, 0.055f, 0.055f}, // circle
    {0.875f, 0.715f, 0.055f, 0.055f}, // cross
    {0.875f, 0.615f, 0.055f, 0.055f}, // square
    // Keep the right edge on screen: 0.965 + 0.055 ran 2% of the width off the screen, which made the
    // whole default table unsaveable (see clamp_touch_region).
    {0.945f, 0.665f, 0.055f, 0.055f}, // triangle
    // I3 (2026-09-22): the game's own frontend navigates with the D-pad (cpad-pressed? 0 down and
    // friends) and the analog stick does not synthesise D-pad bits, so a touch-only player had no way
    // through any menu.  A compact cross sits between the stick and the middle of the screen.
    // Heights are the axis this surface is short in, so the D-pad arms and the top bars are sized to clear
    // the 44 pt tap guideline: at 0.05 x 834 and 0.045 x 834 they were 42 pt and 38 pt.
    {0.275f, 0.395f, 0.05f, 0.055f},  // dpad up
    {0.335f, 0.445f, 0.05f, 0.055f},  // dpad right
    {0.275f, 0.495f, 0.05f, 0.055f},  // dpad down
    {0.215f, 0.445f, 0.05f, 0.055f},  // dpad left
    {0.43f, 0.075f, 0.14f, 0.055f},   // start
    {0.08f, 0.075f, 0.12f, 0.055f},   // L1
    {0.80f, 0.075f, 0.12f, 0.055f},   // R1
    {0.62f, 0.075f, 0.06f, 0.055f},   // menu (three-dot settings entry)
}};

// P1 (2026-09-22): the same controls sized for a phone's shorter screen.  On the iPhone 16 Pro's 874x402
// surface the tablet table gave 48x22 pt face buttons and 44x20 pt D-pad arms - about half the 44 pt a tap
// target wants - because those regions are fractions of each axis and the phone's aspect is wider.  These
// fractions come out on that surface as 60x58 pt face buttons, 48x48 pt D-pad arms, 175x80 pt camera,
// 166x92 pt stick and 114x46 pt top bars, every region inside the screen and no two overlapping.
constexpr std::array<TouchRegionLayout, kTouchRegionCount> kTouchDefaultsPhone = {{
    {0.045f, 0.585f, 0.190f, 0.230f}, // left stick
    {0.620f, 0.200f, 0.200f, 0.200f}, // camera
    {0.780f, 0.572f, 0.069f, 0.145f}, // circle
    {0.880f, 0.572f, 0.069f, 0.145f}, // cross
    {0.780f, 0.408f, 0.069f, 0.145f}, // square
    {0.880f, 0.408f, 0.069f, 0.145f}, // triangle
    {0.272f, 0.341f, 0.055f, 0.119f}, // dpad up
    {0.332f, 0.460f, 0.055f, 0.119f}, // dpad right
    {0.272f, 0.581f, 0.055f, 0.119f}, // dpad down
    {0.212f, 0.460f, 0.055f, 0.119f}, // dpad left
    {0.435f, 0.018f, 0.130f, 0.115f}, // start
    {0.085f, 0.018f, 0.130f, 0.115f}, // L1
    {0.785f, 0.018f, 0.130f, 0.115f}, // R1
    {0.585f, 0.018f, 0.085f, 0.115f}, // menu (three-dot settings entry)
}};

TouchLayout g_touch_layout = {kTouchDefaultsTablet, 1.f};
std::string g_touch_layout_path;
std::string g_touch_layout_dir;

// I3: shell-owned settings, persisted beside the layout.  The completion plan says to implement useful
// settings only with working behaviour and persistence, no decorative controls, so every field here is a
// value something actually reads.
struct ShellSettings {
  // 0 = auto (follow the input actually in use), 1 = always drawn, 2 = never drawn.
  int surface_visibility = 0;
  // Music master volume in percent, applied through snd_SetMasterVolume's music group.
  int music_volume = 100;
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
  file << "1\n" << g_settings.surface_visibility << "\n" << g_settings.music_volume << "\n"
       << g_settings.log_overlay << "\n"
       << g_settings.camera_sensitivity << "\n" << g_settings.invert_camera_y << "\n"
       << g_settings.render_scale << "\n";
  lg::info("OTTSEL SETTINGS: saved visible={} music={} log={} sens={} invert={} scale={} path={}",
           surface_visibility_name(g_settings.surface_visibility), g_settings.music_volume,
           g_settings.log_overlay, g_settings.camera_sensitivity, g_settings.invert_camera_y,
           g_settings.render_scale, g_settings_path);
}

void load_settings() {
  if (g_settings_path.empty()) {
    return;
  }
  std::ifstream file(g_settings_path);
  int version = 0;
  if (!(file >> version) || version != 1) {
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
  const int music = read_int(g_settings.music_volume);
  const int log_overlay = read_int(g_settings.log_overlay);
  const int sensitivity = read_int(g_settings.camera_sensitivity);
  const int invert = read_int(g_settings.invert_camera_y);
  const int scale = read_int(g_settings.render_scale);
  if (visibility < 0 || visibility > 2 || music < 0 || music > 100 ||
      (log_overlay != 0 && log_overlay != 1) || sensitivity < 50 || sensitivity > 200 ||
      (invert != 0 && invert != 1) || (scale != 50 && scale != 75 && scale != 100)) {
    return;
  }
  g_settings.surface_visibility = visibility;
  g_settings.music_volume = music;
  g_settings.log_overlay = log_overlay;
  g_settings.camera_sensitivity = sensitivity;
  g_settings.invert_camera_y = invert;
  g_settings.render_scale = scale;
  lg::info("OTTSEL SETTINGS: loaded visible={} music={} log={} sens={} invert={} scale={} path={}",
           surface_visibility_name(g_settings.surface_visibility), g_settings.music_volume,
           g_settings.log_overlay, g_settings.camera_sensitivity, g_settings.invert_camera_y,
           g_settings.render_scale, g_settings_path);
}
// True once a persisted layout has replaced the class defaults: the player's placement is theirs and is not
// moved out of the safe area, only the shell's own defaults are.
bool g_touch_layout_from_file = false;
bool g_touch_editor = false;
bool g_touch_editor_active = false;
SDL_FingerID g_touch_editor_finger = 0;
TouchRegion g_touch_editor_region = TouchRegion::LeftStick;
bool g_native_input_mode = false;

// I3/P1 (2026-09-22): the layout file's own bounds.  save_touch_layout() clamps to them, so every state
// the editor can produce is loadable.  The compiled default table broke that invariant: its triangle row
// was 0.965 + 0.055 = 1.020, so the first editor save wrote a file load_touch_layout() rejected and the
// player silently got the defaults back on the next boot (measured on iPad with an otherwise identical
// file: triangle 0.965 -> no load line, triangle 0.945 -> loaded).
constexpr float kTouchRegionMinSize = 0.03f;
constexpr float kTouchRegionBoundTolerance = 1e-4f;

TouchRegionLayout clamp_touch_region(TouchRegionLayout region) {
  region.w = std::clamp(region.w, kTouchRegionMinSize, 1.f);
  region.h = std::clamp(region.h, kTouchRegionMinSize, 1.f);
  region.x = std::clamp(region.x, 0.f, 1.f - region.w);
  region.y = std::clamp(region.y, 0.f, 1.f - region.h);
  return region;
}

// P1 (2026-09-22): keep a region out of the safe area, which in landscape can hold the sensor housing on one
// side and the home indicator on the bottom edge.  A region is shrunk only if the usable strip is narrower
// than the region itself, so the tap size the class table asked for survives wherever it fits.
TouchRegionLayout clamp_touch_region_to_safe_area(TouchRegionLayout region, float left, float top,
                                                 float right, float bottom) {
  const float available_w = std::max(kTouchRegionMinSize, 1.f - left - right);
  const float available_h = std::max(kTouchRegionMinSize, 1.f - top - bottom);
  region.w = std::min(region.w, available_w);
  region.h = std::min(region.h, available_h);
  region.x = std::clamp(region.x, left, 1.f - right - region.w);
  region.y = std::clamp(region.y, top, 1.f - bottom - region.h);
  return clamp_touch_region(region);
}

// One Start double-tap opens the layout editor and another closes it.  The gesture has to be recognised
// before the editor consumes the event: while g_touch_editor is set handle_touch_editor() returns true for
// every finger event, so the game-input path that owns this check never runs and the editor could be
// entered by touch but never left by one (measured on iPhone 16 Pro: the second double-tap was swallowed
// and only dragged and saved a region; only the F6 key could close it).
Uint64 g_start_tap_ns = 0;
bool start_double_tap(Uint64 timestamp_ns) {
  if (g_start_tap_ns != 0 && timestamp_ns >= g_start_tap_ns &&
      timestamp_ns - g_start_tap_ns <= 400000000ULL) {
    g_start_tap_ns = 0;
    return true;
  }
  g_start_tap_ns = timestamp_ns;
  return false;
}

// The class is decided by the platform idiom, not by anything measured at runtime, so the defaults can be
// applied before the surface exists and a persisted file can then override them.
void apply_default_touch_layout() {
  g_touch_layout.regions =
      ottsel_ios_shell_is_phone() ? kTouchDefaultsPhone : kTouchDefaultsTablet;
  g_touch_layout_from_file = false;
}

// The class defaults are placed against the real safe area once the platform can report it.  A persisted
// layout is skipped: the player put those regions where they wanted them.  Returns true once there is
// nothing left to do, so a caller can retry while the window is still coming up.
bool apply_safe_area_to_default_touch_layout() {
  static bool applied = false;
  if (applied) {
    return true;
  }
  if (g_touch_layout_from_file) {
    return true;
  }
  float left = 0.f;
  float top = 0.f;
  float right = 0.f;
  float bottom = 0.f;
  if (!ottsel_ios_shell_safe_area(&left, &top, &right, &bottom) ||
      left + top + right + bottom <= 0.f) {
    return false;
  }
  for (auto& region : g_touch_layout.regions) {
    region = clamp_touch_region_to_safe_area(region, left, top, right, bottom);
  }
  applied = true;
  lg::info("OTTSEL TOUCH: defaults kept out of the safe area lrtb={:.0f}x{:.0f}x{:.0f}x{:.0f}",
           (double)(left * g_surf_w), (double)(top * g_surf_h), (double)(right * g_surf_w),
           (double)(bottom * g_surf_h));
  return true;
}

// The class is fixed at boot but the surface size is not known until the CAMetalLayer has laid out, and the
// tap size a region ends up with is its fraction times that size - so report the class, the surface and the
// smallest region box once per surface size.  This is the number the P1 reachability check reads.
void log_touch_layout_metrics() {
  static int last_w = 0;
  static int last_h = 0;
  if (g_surf_w == last_w && g_surf_h == last_h) {
    return;
  }
  last_w = g_surf_w;
  last_h = g_surf_h;
  float min_w = 0.f;
  float min_h = 0.f;
  for (size_t i = 0; i < kTouchRegionCount; ++i) {
    const auto& region = g_touch_layout.regions[i];
    const float w = region.w * static_cast<float>(g_surf_w);
    const float h = region.h * static_cast<float>(g_surf_h);
    min_w = i == 0 ? w : std::min(min_w, w);
    min_h = i == 0 ? h : std::min(min_h, h);
  }
  float left = 0.f;
  float top = 0.f;
  float right = 0.f;
  float bottom = 0.f;
  if (!ottsel_ios_shell_safe_area(&left, &top, &right, &bottom)) {
    left = top = right = bottom = 0.f;
  }
  lg::info("OTTSEL TOUCH: class={} surface={}x{} min-region={:.0f}x{:.0f} safe-lrtb={:.0f}x{:.0f}x{:.0f}x{:.0f}",
           ottsel_ios_shell_is_phone() ? "phone" : "tablet", g_surf_w, g_surf_h,
           (double)min_w, (double)min_h, (double)(left * g_surf_w), (double)(top * g_surf_h),
           (double)(right * g_surf_w), (double)(bottom * g_surf_h));
}

int touch_region_at(float x, float y);
void hide_touch_overlay_for_native_input();

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
  SDL_FingerID left_stick_finger = 0;
  SDL_FingerID action_finger = 0;
  SDL_FingerID camera_finger = 0;
  bool left_stick_active = false;
  bool action_active = false;
  bool camera_active = false;
  ottsel::platform_input::Button action_button =
      static_cast<ottsel::platform_input::Button>(0);
  float camera_origin_x = 0.f;
  float camera_origin_y = 0.f;
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
    hide_touch_overlay_for_native_input();
    if (g_win) {
      SDL_SetWindowRelativeMouseMode(g_win, true);
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

  void touch(const SDL_Event& event) {
    using namespace ottsel::platform_input;
    const auto& finger = event.tfinger;
    if (event.type == SDL_EVENT_FINGER_DOWN) {
      // I3: AUTO follows the input actually in use, but a keyboard, pad or mouse event hid the surface for
      // good - measured on the iPad lane, where one stray keyboard event removed the touch controls for the
      // rest of the run and a touch-only player had no way to bring them back.  A real touch means touch is
      // the input in use again, so the frame loop's upload gate puts the surface back.
      g_native_input_mode = false;
      const int region = touch_region_at(finger.x, finger.y);
      if (region == static_cast<int>(TouchRegion::L1) && !action_active) {
        // The top bars are L1/Start/R1 in the same order as the visible
        // tablet layout. They take precedence over the left-stick half.
        action_finger = finger.fingerID;
        action_active = true;
        action_button = L1;
        set_button(&state, action_button, true);
      } else if (region == static_cast<int>(TouchRegion::Start) && !action_active) {
        if (start_double_tap(finger.timestamp)) {
          toggle_touch_editor();
          return;
        }
        action_finger = finger.fingerID;
        action_active = true;
        action_button = Start;
        set_button(&state, action_button, true);
      } else if (region == static_cast<int>(TouchRegion::R1) && !action_active) {
        action_finger = finger.fingerID;
        action_active = true;
        action_button = R1;
        set_button(&state, action_button, true);
      } else if (region == static_cast<int>(TouchRegion::LeftStick) && !left_stick_active) {
        left_stick_finger = finger.fingerID;
        left_stick_active = true;
        stick_origin_x = finger.x;
        stick_origin_y = finger.y;
      } else if (region == static_cast<int>(TouchRegion::Camera) && !camera_active) {
        // The upper-right open region is the camera gesture surface. Keep it
        // independent from the face-button finger so movement + action +
        // camera can be sampled simultaneously.
        camera_finger = finger.fingerID;
        camera_active = true;
        camera_origin_x = finger.x;
        camera_origin_y = finger.y;
      } else if (region >= static_cast<int>(TouchRegion::Circle) &&
                 region <= static_cast<int>(TouchRegion::Triangle) && !action_active) {
        // Map the visible face-button regions to the same canonical buttons
        // used by SDL gamepads; this remains the shared ShellPadInput/PadState
        // producer.
        action_finger = finger.fingerID;
        action_active = true;
        action_button = Circle;
        if (region == static_cast<int>(TouchRegion::Cross)) action_button = Cross;
        if (region == static_cast<int>(TouchRegion::Square)) action_button = Square;
        if (region == static_cast<int>(TouchRegion::Triangle)) action_button = Triangle;
        set_button(&state, action_button, true);
      } else if (region >= static_cast<int>(TouchRegion::DpadUp) &&
                 region <= static_cast<int>(TouchRegion::DpadLeft) && !action_active) {
        // I3: the D-pad reaches the game as its own digital bits (the frontend's menus read
        // cpad-pressed? 0 up/down/left/right), which the analog stick never produces.
        action_finger = finger.fingerID;
        action_active = true;
        action_button = DpadDown;
        if (region == static_cast<int>(TouchRegion::DpadUp)) action_button = DpadUp;
        if (region == static_cast<int>(TouchRegion::DpadRight)) action_button = DpadRight;
        if (region == static_cast<int>(TouchRegion::DpadLeft)) action_button = DpadLeft;
        set_button(&state, action_button, true);
      }
    } else if (event.type == SDL_EVENT_FINGER_MOTION && left_stick_active &&
               finger.fingerID == left_stick_finger) {
      state.leftx = static_cast<u8>(std::clamp(127 + int((finger.x - stick_origin_x) * 510), 0, 255));
      state.lefty = static_cast<u8>(std::clamp(127 + int((finger.y - stick_origin_y) * 510), 0, 255));
    } else if (event.type == SDL_EVENT_FINGER_MOTION && camera_active &&
               finger.fingerID == camera_finger) {
      // GAMEPLAY: the camera region is the shell's own producer, so its drag gain and vertical direction
      // are the shell's to offer.  Both default to the previous behaviour (100%, not inverted).
      const float camera_gain = 510.f * (float)g_settings.camera_sensitivity / 100.f;
      const float camera_sign = g_settings.invert_camera_y ? -1.f : 1.f;
      state.rightx = static_cast<u8>(std::clamp(127 + int((finger.x - camera_origin_x) * camera_gain), 0, 255));
      state.righty = static_cast<u8>(
          std::clamp(127 + int((finger.y - camera_origin_y) * camera_gain * camera_sign), 0, 255));
    } else if ((event.type == SDL_EVENT_FINGER_UP || event.type == SDL_EVENT_FINGER_CANCELED) &&
               left_stick_active && finger.fingerID == left_stick_finger) {
      left_stick_finger = 0;
      left_stick_active = false;
      state.leftx = 127;
      state.lefty = 127;
    } else if ((event.type == SDL_EVENT_FINGER_UP || event.type == SDL_EVENT_FINGER_CANCELED) &&
               camera_active && finger.fingerID == camera_finger) {
      camera_finger = 0;
      camera_active = false;
      state.rightx = 127;
      state.righty = 127;
    } else if ((event.type == SDL_EVENT_FINGER_UP || event.type == SDL_EVENT_FINGER_CANCELED) &&
               action_active && finger.fingerID == action_finger) {
      action_finger = 0;
      action_active = false;
      set_button(&state, action_button, false);
      action_button = static_cast<Button>(0);
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

  // I3: which touch regions are held right now, as a bitmask over TouchRegion, so the on-screen
  // surface can show pressed/neutral feedback.  It is derived from the same state that routes input
  // (the stick/camera/action fingers), so the feedback cannot disagree with what the game receives.
  int pressed_region_mask() const {
    using namespace ottsel::platform_input;
    int mask = 0;
    const auto mark = [&mask](TouchRegion region) {
      mask |= 1 << static_cast<int>(region);
    };
    if (left_stick_active) mark(TouchRegion::LeftStick);
    if (camera_active) mark(TouchRegion::Camera);
    if (action_active) {
      switch (action_button) {
        case Cross: mark(TouchRegion::Cross); break;
        case Circle: mark(TouchRegion::Circle); break;
        case Square: mark(TouchRegion::Square); break;
        case Triangle: mark(TouchRegion::Triangle); break;
        case DpadUp: mark(TouchRegion::DpadUp); break;
        case DpadRight: mark(TouchRegion::DpadRight); break;
        case DpadDown: mark(TouchRegion::DpadDown); break;
        case DpadLeft: mark(TouchRegion::DpadLeft); break;
        case Start: mark(TouchRegion::Start); break;
        case L1: mark(TouchRegion::L1); break;
        case R1: mark(TouchRegion::R1); break;
        default: break;
      }
    }
    return mask;
  }
};

ShellPadInput g_input;
std::vector<OttselOverlayVertex> g_touch_overlay;
bool g_touch_overlay_uploaded = false;

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

int touch_region_at(float x, float y) {
  for (size_t i = 0; i < static_cast<size_t>(TouchRegion::Count); ++i) {
    const auto& region = g_touch_layout.regions[i];
    if (x >= region.x && x <= region.x + region.w && y >= region.y &&
        y <= region.y + region.h) {
      return static_cast<int>(i);
    }
  }
  return -1;
}

void load_touch_layout() {
  if (g_touch_layout_path.empty()) {
    return;
  }
  std::ifstream file(g_touch_layout_path);
  int version = 0;
  if (!(file >> version) || version != 1) {
    return;
  }
  TouchLayout candidate = g_touch_layout;
  if (!(file >> candidate.opacity)) {
    return;
  }
  for (auto& region : candidate.regions) {
    if (!(file >> region.x >> region.y >> region.w >> region.h)) {
      return;
    }
  }
  if (!std::isfinite(candidate.opacity) || candidate.opacity < 0.1f || candidate.opacity > 1.f) {
    return;
  }
  for (const auto& region : candidate.regions) {
    if (!std::isfinite(region.x) || !std::isfinite(region.y) || !std::isfinite(region.w) ||
        !std::isfinite(region.h) || region.w < kTouchRegionMinSize || region.h < kTouchRegionMinSize ||
        region.x < -kTouchRegionBoundTolerance || region.y < -kTouchRegionBoundTolerance ||
        region.x + region.w > 1.f + kTouchRegionBoundTolerance ||
        region.y + region.h > 1.f + kTouchRegionBoundTolerance) {
      return;
    }
  }
  g_touch_layout = candidate;
  g_touch_layout_from_file = true;
  lg::info("OTTSEL TOUCH: loaded persistent layout {}", g_touch_layout_path);
}

void save_touch_layout() {
  if (g_touch_layout_path.empty()) {
    return;
  }
  std::ofstream file(g_touch_layout_path, std::ios::trunc);
  if (!file) {
    lg::warn("OTTSEL TOUCH: unable to save layout {}", g_touch_layout_path);
    return;
  }
  file << "1\n" << std::setprecision(7) << g_touch_layout.opacity << "\n";
  for (auto& region : g_touch_layout.regions) {
    region = clamp_touch_region(region);
  }
  for (const auto& region : g_touch_layout.regions) {
    file << region.x << ' ' << region.y << ' ' << region.w << ' ' << region.h << "\n";
  }
  lg::info("OTTSEL TOUCH: saved persistent layout {}", g_touch_layout_path);
}

// I3/P1 (2026-09-22): the layout file is per device class.  The class is the platform idiom, not the
// surface width: the drawable is only known after the CAMetalLayer has laid out (at window creation it
// still reads the 1024x768 request, which is what handed the phone the tablet file when this was
// `g_surf_w < 1000`), and a device's layer reports points scaled by its contentsScale, so the same test
// would call a real iPhone a tablet.  load_touch_layout() is a no-op when the class' file is absent, so
// the class defaults survive.
void refresh_touch_layout_path() {
  if (g_touch_layout_dir.empty()) {
    return;
  }
  const std::string want =
      g_touch_layout_dir +
      (ottsel_ios_shell_is_phone() ? "touch-layout-phone.cfg" : "touch-layout-tablet.cfg");
  if (want == g_touch_layout_path) {
    return;
  }
  g_touch_layout_path = want;
  load_touch_layout();
}

// I3: the settings file follows the layout's per-class convention, so an iPhone and an iPad can carry
// different choices without one clobbering the other.
void refresh_settings_path() {
  if (g_touch_layout_dir.empty()) {
    return;
  }
  const std::string want =
      g_touch_layout_dir +
      (ottsel_ios_shell_is_phone() ? "settings-phone.cfg" : "settings-tablet.cfg");
  if (want == g_settings_path) {
    return;
  }
  g_settings_path = want;
  load_settings();
}

void build_touch_overlay(int pressed_mask = 0);
void upload_touch_overlay();

bool handle_touch_editor(const SDL_Event& event) {
  if (!g_touch_editor) {
    return false;
  }
  const auto& finger = event.tfinger;
  if (event.type == SDL_EVENT_FINGER_DOWN && !g_touch_editor_active) {
    const int region = touch_region_at(finger.x, finger.y);
    if (region == static_cast<int>(TouchRegion::Start) && start_double_tap(finger.timestamp)) {
      // The gesture that opens the editor also closes it.  This handler owns every finger event while
      // the editor is open, so the check has to live here as well as on the game-input path.
      toggle_touch_editor();
      return true;
    }
    if (region >= 0) {
      g_touch_editor_active = true;
      g_touch_editor_finger = finger.fingerID;
      g_touch_editor_region = static_cast<TouchRegion>(region);
    }
    return true;
  }
  if (g_touch_editor_active && finger.fingerID == g_touch_editor_finger &&
      event.type == SDL_EVENT_FINGER_MOTION) {
    auto& region = g_touch_layout.regions[static_cast<size_t>(g_touch_editor_region)];
    region.x = std::clamp(finger.x - region.w * 0.5f, 0.f, 1.f - region.w);
    region.y = std::clamp(finger.y - region.h * 0.5f, 0.f, 1.f - region.h);
    build_touch_overlay();
    upload_touch_overlay();
    return true;
  }
  if (g_touch_editor_active && finger.fingerID == g_touch_editor_finger &&
      (event.type == SDL_EVENT_FINGER_UP || event.type == SDL_EVENT_FINGER_CANCELED)) {
    g_touch_editor_active = false;
    g_touch_editor_finger = 0;
    save_touch_layout();
    g_input.neutralize();
    return true;
  }
  return true;
}

void toggle_touch_editor() {
  g_touch_editor = !g_touch_editor;
  g_touch_editor_active = false;
  g_input.neutralize();
  build_touch_overlay();
  upload_touch_overlay();
  lg::info("OTTSEL TOUCH: editor={} layout={}", g_touch_editor ? "on" : "off",
           g_touch_layout_path);
}

void adjust_touch_opacity(float delta) {
  if (!g_touch_editor) {
    return;
  }
  g_touch_layout.opacity = std::clamp(g_touch_layout.opacity + delta, 0.1f, 1.f);
  build_touch_overlay();
  upload_touch_overlay();
  save_touch_layout();
  lg::info("OTTSEL TOUCH: editor opacity={:.2f}", g_touch_layout.opacity);
}

void add_touch_rect(float x, float y, float w, float h,
                    float r, float g, float b, float a) {
  const float left = x * 2.f - 1.f;
  const float right = (x + w) * 2.f - 1.f;
  const float top = 1.f - y * 2.f;
  const float bottom = 1.f - (y + h) * 2.f;
  const float color[4] = {r, g, b, a};
  const float positions[6][2] = {{left, bottom}, {right, bottom}, {right, top},
                                 {left, bottom}, {right, top}, {left, top}};
  for (const auto& position : positions) {
    OttselOverlayVertex vertex = {};
    vertex.pos[0] = position[0];
    vertex.pos[1] = position[1];
    memcpy(vertex.color, color, sizeof(color));
    g_touch_overlay.push_back(vertex);
  }
}

struct TouchPoint {
  float x;
  float y;
};

// The overlay is a triangle list, so shapes are all that is needed for the PS2 button reference: a disc, a
// cross of two bars, a square and a triangle, each built in unit space (radius 1) and mapped into the
// region's own box with the axis aspect folded in, so the symbol is round on screen and inside its region.
void add_touch_unit_triangle(float cx, float cy, float radius, float aspect, float angle, float u0,
                             float v0, float u1, float v1, float u2, float v2, float r, float g,
                             float b, float a) {
  const float ca = cosf(angle);
  const float sa = sinf(angle);
  const auto map = [&](float u, float v) {
    const float su = u * ca - v * sa;
    const float sv = u * sa + v * ca;
    return TouchPoint{cx + su * radius * aspect, cy + sv * radius};
  };
  const TouchPoint p0 = map(u0, v0);
  const TouchPoint p1 = map(u1, v1);
  const TouchPoint p2 = map(u2, v2);
  const float color[4] = {r, g, b, a};
  const TouchPoint points[3] = {p0, p1, p2};
  for (const TouchPoint& point : points) {
    OttselOverlayVertex vertex = {};
    vertex.pos[0] = point.x * 2.f - 1.f;
    vertex.pos[1] = 1.f - point.y * 2.f;
    memcpy(vertex.color, color, sizeof(color));
    g_touch_overlay.push_back(vertex);
  }
}

void add_touch_unit_bar(float cx, float cy, float radius, float aspect, float angle, float half_length,
                        float half_width, float r, float g, float b, float a) {
  add_touch_unit_triangle(cx, cy, radius, aspect, angle, -half_length, -half_width, half_length,
                          -half_width, half_length, half_width, r, g, b, a);
  add_touch_unit_triangle(cx, cy, radius, aspect, angle, -half_length, -half_width, half_length,
                          half_width, -half_length, half_width, r, g, b, a);
}

void add_touch_unit_disc(float cx, float cy, float radius, float aspect, int segments, float r, float g,
                         float b, float a) {
  for (int i = 0; i < segments; ++i) {
    const float a0 = 6.2831855f * (float)i / (float)segments;
    const float a1 = 6.2831855f * (float)(i + 1) / (float)segments;
    add_touch_unit_triangle(cx, cy, radius, aspect, 0.f, 0.f, 0.f, cosf(a0), sinf(a0), cosf(a1),
                            sinf(a1), r, g, b, a);
  }
}

// The PS2 face symbols and the four D-pad arrowheads, drawn inside their own regions.
void add_touch_face_symbol(TouchRegion region, float cx, float cy, float radius, float aspect, float r,
                           float g, float b, float a) {
  switch (region) {
    case TouchRegion::Circle:
      add_touch_unit_disc(cx, cy, radius, aspect, 16, r, g, b, a);
      break;
    case TouchRegion::Cross:
      add_touch_unit_bar(cx, cy, radius, aspect, 0.7853982f, 1.15f, 0.30f, r, g, b, a);
      add_touch_unit_bar(cx, cy, radius, aspect, -0.7853982f, 1.15f, 0.30f, r, g, b, a);
      break;
    case TouchRegion::Square:
      add_touch_unit_bar(cx, cy, radius, aspect, 0.f, 1.f, 1.f, r, g, b, a);
      break;
    default:
      add_touch_unit_triangle(cx, cy, radius, aspect, 0.f, 0.f, -1.15f, -1.f, 1.f, 1.f, 1.f, r, g, b,
                              a);
      break;
  }
}

void add_touch_dpad_arrow(TouchRegion region, float cx, float cy, float radius, float aspect, float r,
                          float g, float b, float a) {
  float angle = 0.f;
  switch (region) {
    case TouchRegion::DpadRight: angle = 1.5707963f; break;
    case TouchRegion::DpadDown: angle = 3.1415927f; break;
    case TouchRegion::DpadLeft: angle = -1.5707963f; break;
    default: break;
  }
  add_touch_unit_triangle(cx, cy, radius, aspect, angle, 0.f, -1.25f, -1.f, 0.95f, 1.f, 0.95f, r, g, b,
                          a);
}

// I3: labels for the control surface.  The overlay's vertices sample a 1x1 white texture, so a glyph is
// emitted as one quad per lit pixel of the same column-major 5x7 font the shell status screen uses.  A
// three-character label is about forty quads, which is nothing beside the world's vertex budget.
void add_touch_glyph(float x, float y, float pixel_x, float pixel_y, char c, float r, float g, float b,
                     float a) {
  if (c < 32 || c > 126) {
    return;
  }
  const uint8_t* glyph = kFont5x7[(int)c - 32];
  for (int col = 0; col < kFontW; ++col) {
    const uint8_t bits = glyph[col];
    for (int row = 0; row < kFontH; ++row) {
      if (bits & (1 << row)) {
        add_touch_rect(x + (float)col * pixel_x, y + (float)row * pixel_y, pixel_x * 0.95f,
                       pixel_y * 0.95f, r, g, b, a);
      }
    }
  }
}

// The layout is stored in fractions of each axis, so a square glyph needs pixel_x = pixel_y * (h/w).
void add_touch_label(float cx, float cy, float pixel_y, float aspect, const char* text, float r,
                     float g, float b, float a) {
  const int length = (int)std::strlen(text);
  if (!length) {
    return;
  }
  const float pixel_x = pixel_y * aspect;
  const float width = (float)(length * (kFontW + 1) - 1) * pixel_x;
  float x = cx - width * 0.5f;
  const float y = cy - (float)kFontH * pixel_y * 0.5f;
  for (int i = 0; i < length; ++i) {
    add_touch_glyph(x, y, pixel_x, pixel_y, text[i], r, g, b, a);
    x += (float)(kFontW + 1) * pixel_x;
  }
}

// Short ASCII labels; the settings entry keeps its three dots as its own label.
const char* touch_region_label(TouchRegion region) {
  switch (region) {
    case TouchRegion::LeftStick: return "STK";
    case TouchRegion::Camera: return "CAM";
    case TouchRegion::Circle: return "O";
    case TouchRegion::Cross: return "X";
    case TouchRegion::Square: return "[]";
    case TouchRegion::Triangle: return "TR";
    case TouchRegion::DpadUp: return "^";
    case TouchRegion::DpadRight: return ">";
    case TouchRegion::DpadDown: return "v";
    case TouchRegion::DpadLeft: return "<";
    case TouchRegion::Start: return "ST";
    case TouchRegion::L1: return "L1";
    case TouchRegion::R1: return "R1";
    default: return "";
  }
}

void build_touch_overlay(int pressed_mask) {
  g_touch_overlay.clear();
  constexpr float colors[static_cast<size_t>(TouchRegion::Count)][4] = {
      {0.20f, 0.70f, 1.0f, 0.20f}, {0.95f, 0.75f, 0.20f, 0.16f},
      {1.0f, 0.35f, 0.35f, 0.24f}, {1.0f, 0.35f, 0.35f, 0.24f},
      {1.0f, 0.35f, 0.35f, 0.24f}, {1.0f, 0.35f, 0.35f, 0.24f},
      {0.85f, 0.55f, 0.95f, 0.20f}, {0.85f, 0.55f, 0.95f, 0.20f},
      {0.85f, 0.55f, 0.95f, 0.20f}, {0.85f, 0.55f, 0.95f, 0.20f},
      {0.95f, 0.65f, 0.20f, 0.22f}, {0.65f, 0.65f, 0.75f, 0.18f},
      {0.65f, 0.65f, 0.75f, 0.18f}, {0.95f, 0.95f, 0.98f, 0.30f}};
  for (size_t i = 0; i < static_cast<size_t>(TouchRegion::Count); ++i) {
    const auto& region = g_touch_layout.regions[i];
    if (i == static_cast<size_t>(TouchRegion::Menu)) {
      // I3: the settings entry reads as three dots instead of a block, so it is recognisable without a
      // label glyph.  The dots are small quads inside the region the hit-test already owns.
      const float dot = 0.008f;
      const float gap = 0.017f;
      const float cx = region.x + region.w * 0.5f;
      const float cy = region.y + region.h * 0.5f;
      for (int dot_index = -1; dot_index <= 1; ++dot_index) {
        add_touch_rect(cx + dot_index * gap - dot * 0.5f, cy - dot * 0.5f, dot, dot, 0.97f, 0.97f,
                       1.0f, 0.85f);
      }
      continue;
    }
    float r = colors[i][0];
    float g = colors[i][1];
    float b = colors[i][2];
    float a = colors[i][3] * g_touch_layout.opacity;
    if (pressed_mask & (1 << static_cast<int>(i))) {
      // I3 pressed/neutral feedback: a held region lifts toward white and deepens its tint, so the
      // player can see which control the game is receiving.  The neutral look is unchanged.
      // The lift and the alpha gain are chosen from measurement: at 0.45/3.0 over the training level's
      // foliage the pressed region moved its own static box by only ~2.4/255 per channel, which a player
      // cannot see, so the pressed state is a near-opaque light tint instead.
      constexpr float lift = 0.80f;
      r += (1.f - r) * lift;
      g += (1.f - g) * lift;
      b += (1.f - b) * lift;
      a = std::min(1.0f, a * 4.0f + 0.25f);
    }
    add_touch_rect(region.x, region.y, region.w, region.h, r, g, b, a);
    // I3: the mark sits inside its own hit region and brightens with the held state, so the surface says what
    // each control is and shows what the game is receiving.  The four face buttons and the D-pad arms carry
    // the PS2 symbols; the rest carry their short text label.
    const TouchRegion region_id = static_cast<TouchRegion>(i);
    const bool held = (pressed_mask & (1 << static_cast<int>(i))) != 0;
    const float aspect = (float)g_surf_h / (float)std::max(1, g_surf_w);
    const float cx = region.x + region.w * 0.5f;
    const float cy = region.y + region.h * 0.5f;
    const float symbol_radius = std::min(region.w / aspect, region.h) * 0.34f;
    const float ink_alpha = held ? 1.0f : 0.85f;
    if (region_id >= TouchRegion::Circle && region_id <= TouchRegion::Triangle) {
      add_touch_face_symbol(region_id, cx, cy, symbol_radius, aspect, 0.97f, 0.97f, 1.0f, ink_alpha);
    } else if (region_id >= TouchRegion::DpadUp && region_id <= TouchRegion::DpadLeft) {
      add_touch_dpad_arrow(region_id, cx, cy, symbol_radius, aspect, 0.97f, 0.97f, 1.0f, ink_alpha);
    } else {
      const char* label = touch_region_label(region_id);
      if (label[0]) {
        // Fit the glyph to its own region on both axes: the tablet's wide bars and the phone's narrower arms
        // do not share a workable fixed size (a fixed 0.007 overflowed the phone's 0.055-wide D-pad arms), and
        // the normalized axes differ, so the pixel is square on screen only with the aspect folded in.
        const int label_length = (int)std::strlen(label);
        const float label_units = (float)(label_length * (kFontW + 1) - 1);
        const float by_height = region.h / (float)(kFontH + 2);
        const float by_width = region.w * 0.82f / std::max(1.f, label_units * aspect);
        const float pixel_y = std::min(std::min(by_height, by_width), 0.0115f);
        add_touch_label(cx, cy, pixel_y, aspect, label,
                        0.92f + (held ? 0.08f : 0.f), 0.96f + (held ? 0.04f : 0.f), 1.0f,
                        ink_alpha);
      }
    }
  }
}

void upload_touch_overlay() {
  // I3 setting: AUTO follows the input in use (a physical device hides the surface), ALWAYS keeps it up and
  // HIDDEN never draws it.  The overlay builder and the hit-testing are unaffected.
  const bool surface_visible = g_settings.surface_visibility == 1 ||
                               (g_settings.surface_visibility == 0 && !g_native_input_mode);
  g_touch_overlay_uploaded = surface_visible && !g_touch_overlay.empty();
  ottsel_gl_set_overlay(g_touch_overlay_uploaded ? g_touch_overlay.data() : nullptr,
                        g_touch_overlay_uploaded ? (unsigned)g_touch_overlay.size() : 0);
}

// I3: re-upload the touch surface only when the set of held regions changes, so pressed feedback costs
// one mask compare per frame and nothing else.  Called once per frame after input and the touch triggers
// have been processed, so the drawn state is the state the game was just handed.
void update_touch_overlay_feedback() {
  static int uploaded_mask = -1;
  static int logged = 0;
  const int mask = g_input.pressed_region_mask();
  if (mask == uploaded_mask) {
    return;
  }
  uploaded_mask = mask;
  build_touch_overlay(mask);
  upload_touch_overlay();
  // I3 observability: bounded (20 lines) so the feedback path can be measured from the log even when a
  // capture is dominated by the scene's own animation.
  if (logged < 20) {
    ++logged;
    lg::info("OTTSEL TOUCH: feedback mask=0x{:x} vertices={} uploaded={}", mask,
             g_touch_overlay.size(), g_touch_overlay_uploaded ? 1 : 0);
    // The pressed region's first vertex carries the lifted RGBA, so the log states the feedback the
    // overlay was actually built with, not just that a rebuild happened.
    for (unsigned region = 0; region < static_cast<unsigned>(TouchRegion::Count); ++region) {
      const unsigned first_vertex = 6u * region;
      if (!(mask & (1 << region)) || g_touch_overlay.size() <= first_vertex) {
        continue;
      }
      const float* color = g_touch_overlay[first_vertex].color;
      lg::info("OTTSEL TOUCH: feedback region={} color=({:.3f},{:.3f},{:.3f},{:.3f})", region,
               color[0], color[1], color[2], color[3]);
      break;
    }
  }
}

void hide_touch_overlay_for_native_input() {
  if (g_native_input_mode) {
    return;
  }
  g_native_input_mode = true;
  g_touch_overlay_uploaded = false;
  g_touch_overlay.clear();
  ottsel_gl_set_overlay(nullptr, 0);
  lg::info("OTTSEL INPUT: native keyboard/mouse active; touch overlay hidden");
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
enum class SettingId {
  CameraSensitivity,
  InvertCameraY,
  SurfaceOpacity,
  SurfaceVisible,
  ResetLayout,
  RenderScale,
  MusicVolume,
  UserPack,
  DataRoot,
  LogOverlay,
};

struct SettingDef {
  const char* section;
  const char* label;
  SettingId id;
  bool actionable;
};

constexpr SettingDef kSettingDefs[] = {
    {"GAMEPLAY", "CAMERA SENSITIVITY", SettingId::CameraSensitivity, true},
    {"GAMEPLAY", "INVERT CAMERA Y", SettingId::InvertCameraY, true},
    {"CONTROLS", "SURFACE OPACITY", SettingId::SurfaceOpacity, true},
    {"CONTROLS", "SURFACE VISIBLE", SettingId::SurfaceVisible, true},
    {"CONTROLS", "RESET LAYOUT", SettingId::ResetLayout, true},
    {"VIDEO", "RENDER SCALE", SettingId::RenderScale, true},
    // Drives the music handler's own groups (1 and 2, see apply_music_volume); it was briefly labelled MASTER
    // VOLUME while it still drove group 16, which muted the whole mix.
    {"AUDIO", "MUSIC VOLUME", SettingId::MusicVolume, true},
    {"DATA & SAVES", "USER PACK", SettingId::UserPack, false},
    {"DATA & SAVES", "DATA ROOT", SettingId::DataRoot, false},
    {"DIAGNOSTICS", "LOG OVERLAY", SettingId::LogOverlay, true},
};
constexpr int kSettingCount = (int)(sizeof(kSettingDefs) / sizeof(kSettingDefs[0]));

bool g_settings_screen = false;
int g_settings_level = 0;    // 0 = the section list, 1 = one section's rows
int g_settings_section = 0;  // index into the distinct section names
int g_settings_row = 0;      // row inside the current section screen

int settings_section_count() {
  int count = 0;
  for (int i = 0; i < kSettingCount; ++i) {
    if (i == 0 || std::strcmp(kSettingDefs[i].section, kSettingDefs[i - 1].section) != 0) {
      ++count;
    }
  }
  return count;
}

const char* settings_section_name(int index) {
  int seen = -1;
  for (int i = 0; i < kSettingCount; ++i) {
    if (i == 0 || std::strcmp(kSettingDefs[i].section, kSettingDefs[i - 1].section) != 0) {
      ++seen;
      if (seen == index) {
        return kSettingDefs[i].section;
      }
    }
  }
  return "";
}

int settings_section_first_row(int index) {
  const char* name = settings_section_name(index);
  for (int i = 0; i < kSettingCount; ++i) {
    if (std::strcmp(kSettingDefs[i].section, name) == 0) {
      return i;
    }
  }
  return 0;
}

int settings_section_row_count(int index) {
  const char* name = settings_section_name(index);
  int count = 0;
  for (int i = 0; i < kSettingCount; ++i) {
    if (std::strcmp(kSettingDefs[i].section, name) == 0) {
      ++count;
    }
  }
  return count;
}

void fill_rect(int x, int y, int w, int h, unsigned char r, unsigned char g, unsigned char b) {
  for (int yy = y; yy < y + h; ++yy) {
    if (yy < 0 || yy >= g_surf_h) continue;
    for (int xx = x; xx < x + w; ++xx) {
      if (xx < 0 || xx >= g_surf_w) continue;
      const size_t i = ((size_t)yy * g_surf_w + (size_t)xx) * 4;
      g_rgba[i + 0] = r;
      g_rgba[i + 1] = g;
      g_rgba[i + 2] = b;
      g_rgba[i + 3] = 255;
    }
  }
}

std::string settings_value(SettingId id) {
  switch (id) {
    case SettingId::CameraSensitivity: {
      char buffer[16] = {};
      snprintf(buffer, sizeof(buffer), "%d%%", g_settings.camera_sensitivity);
      return buffer;
    }
    case SettingId::InvertCameraY:
      return g_settings.invert_camera_y ? "ON" : "OFF";
    case SettingId::SurfaceOpacity: {
      char buffer[16] = {};
      snprintf(buffer, sizeof(buffer), "%d%%", (int)(g_touch_layout.opacity * 100.f + 0.5f));
      return buffer;
    }
    case SettingId::SurfaceVisible:
      return surface_visibility_name(g_settings.surface_visibility);
    case SettingId::RenderScale: {
      char buffer[16] = {};
      snprintf(buffer, sizeof(buffer), "%d%%", g_settings.render_scale);
      return buffer;
    }
    case SettingId::MusicVolume: {
      char buffer[16] = {};
      snprintf(buffer, sizeof(buffer), "%d%%", g_settings.music_volume);
      return buffer;
    }
    case SettingId::UserPack:
      return ottsel_ios_has_user_data() ? "PRESENT" : "MISSING";
    case SettingId::DataRoot:
      return ottsel_ios_writable_dir();
    case SettingId::LogOverlay:
      return g_settings.log_overlay ? "ON" : "OFF";
    default:
      return "CROSS";
  }
}

void apply_music_volume() {
  // The music handler drives groups 1 and 2 (`ssound.cpp` `SetMusicVol`), so scaling those is a real music
  // control; group 16 is the synth *master*, and driving it muted the whole mix - ambience and dialogue too.
  const s32 volume = (s32)(0x400 * g_settings.music_volume / 100);
  snd_SetMasterVolume(1, volume);
  snd_SetMasterVolume(2, volume);
}

// VIDEO: the game renders at this percentage of the window's pixels and is scaled up to the window.
void apply_render_scale() {
  ottsel_gl_set_render_scale(g_settings.render_scale);
}

void show_log_surface() {
  if (g_rgba.empty()) {
    return;
  }
  read_log_tail();
  render_surface();
  ottsel_gl_set_status(g_rgba.data(), g_surf_w, g_surf_h);
}

void compose_settings_screen() {
  fill_rect(0, 0, g_surf_w, g_surf_h, 10, 12, 20);
  const int pad = 10 * g_font_scale;
  const int line = (kFontH + 5) * g_font_scale;
  const bool section_list = g_settings_level == 0;
  const int rows = section_list ? settings_section_count() + 1
                                : settings_section_row_count(g_settings_section) + 1;
  int y = pad;
  draw_text(pad, y, section_list ? "OTTSEL SETTINGS" : settings_section_name(g_settings_section),
            150, 220, 255);
  y += line * 2;
  for (int row = 0; row < rows; ++row) {
    std::string label;
    std::string value;
    if (section_list) {
      label = (row == settings_section_count()) ? "CLOSE" : settings_section_name(row);
    } else if (row == settings_section_row_count(g_settings_section)) {
      label = "BACK";
    } else {
      const int index = settings_section_first_row(g_settings_section) + row;
      label = kSettingDefs[index].label;
      value = settings_value(kSettingDefs[index].id);
    }
    if (row == g_settings_row) {
      fill_rect(pad - 4, y - 3, g_surf_w - 2 * (pad - 4), line, 34, 46, 70);
    }
    draw_text(pad, y, label, 235, 240, 250);
    if (!value.empty()) {
      draw_text(g_surf_w / 2, y, value, 255, 210, 120);
    }
    y += line;
  }
  y += line;
  draw_text(pad, y,
            section_list ? "D-PAD UP/DOWN SELECT   CROSS OPEN   CIRCLE OR DOTS CLOSE"
                         : "D-PAD UP/DOWN SELECT   CROSS OR LEFT/RIGHT CHANGE   CIRCLE BACK",
            170, 180, 200);
  y += line;
  draw_text(pad, y, "AUDIO CHANGES NEED THE SOUND SUBSTRATE; LOG OVERLAY APPLIES WHEN THIS SCREEN CLOSES",
            140, 150, 170);
  if (g_settings_path.empty()) {
    y += line;
    draw_text(pad, y, "NOT PERSISTED: NO SETTINGS PATH YET", 255, 140, 140);
  }
}

void upload_settings_screen() {
  if (g_rgba.empty()) {
    return;
  }
  compose_settings_screen();
  ottsel_gl_set_status(g_rgba.data(), g_surf_w, g_surf_h);
}

void close_settings_screen() {
  if (!g_settings_screen) {
    return;
  }
  g_settings_screen = false;
  if (g_settings.log_overlay) {
    // The diagnostics row is a real overlay: keep the shell log surface up over the game.
    show_log_surface();
  } else {
    ottsel_gl_set_status(nullptr, 0, 0);
  }
  lg::info("OTTSEL SETTINGS: screen closed visible={} music={} log={}",
           surface_visibility_name(g_settings.surface_visibility), g_settings.music_volume,
           g_settings.log_overlay);
}

void open_settings_screen() {
  g_settings_screen = true;
  g_settings_level = 0;
  g_settings_section = 0;
  g_settings_row = 0;
  apply_music_volume();
  upload_settings_screen();
  lg::info("OTTSEL SETTINGS: screen open level=0 visible={} music={} log={} sens={} invert={} scale={}",
           surface_visibility_name(g_settings.surface_visibility), g_settings.music_volume,
           g_settings.log_overlay, g_settings.camera_sensitivity, g_settings.invert_camera_y,
           g_settings.render_scale);
}

void settings_activate_selected(int delta) {
  if (g_settings_level != 1) {
    return;
  }
  if (g_settings_row >= settings_section_row_count(g_settings_section)) {
    g_settings_level = 0;  // BACK
    g_settings_row = g_settings_section;
    upload_settings_screen();
    return;
  }
  const int index = settings_section_first_row(g_settings_section) + g_settings_row;
  if (index < 0 || index >= kSettingCount) {
    return;
  }
  const SettingDef& def = kSettingDefs[index];
  if (!def.actionable) {
    lg::info("OTTSEL SETTINGS: row={} value={} is read-only", def.label, settings_value(def.id));
    return;
  }
  if (delta == 0) {
    delta = 1;
  }
  switch (def.id) {
    case SettingId::CameraSensitivity:
      g_settings.camera_sensitivity =
          std::clamp(g_settings.camera_sensitivity + 25 * delta, 50, 200);
      save_settings();
      break;
    case SettingId::InvertCameraY:
      g_settings.invert_camera_y = g_settings.invert_camera_y ? 0 : 1;
      save_settings();
      break;
    case SettingId::SurfaceOpacity:
      g_touch_layout.opacity =
          std::clamp(g_touch_layout.opacity + 0.25f * (float)delta, 0.25f, 1.f);
      build_touch_overlay(g_input.pressed_region_mask());
      upload_touch_overlay();
      save_touch_layout();
      break;
    case SettingId::SurfaceVisible:
      g_settings.surface_visibility = (g_settings.surface_visibility + (delta > 0 ? 1 : 2)) % 3;
      save_settings();
      upload_touch_overlay();
      break;
    case SettingId::ResetLayout:
      apply_default_touch_layout();
      save_touch_layout();
      build_touch_overlay(g_input.pressed_region_mask());
      upload_touch_overlay();
      break;
    case SettingId::RenderScale:
      // Cycle 100 -> 75 -> 50 -> 100, so the setting always lands on a value the drawable can take.
      g_settings.render_scale = g_settings.render_scale == 100 ? 75
                                : g_settings.render_scale == 75 ? 50
                                                                : 100;
      apply_render_scale();
      save_settings();
      break;
    case SettingId::MusicVolume:
      g_settings.music_volume = std::clamp(g_settings.music_volume + 10 * delta, 0, 100);
      apply_music_volume();
      save_settings();
      break;
    case SettingId::LogOverlay:
      g_settings.log_overlay = g_settings.log_overlay ? 0 : 1;
      save_settings();
      break;
    default:
      break;
  }
  upload_settings_screen();
  lg::info("OTTSEL SETTINGS: changed section={} row={} value={}", def.section, def.label,
           settings_value(def.id));
}

// Returns true when the touch belongs to the settings surface.  While the screen is up the shell owns every
// finger, so the game cannot be driven behind it; the Menu region opens it and Circle or Menu closes it.
bool handle_settings_touch(const SDL_Event& event) {
  if (event.type != SDL_EVENT_FINGER_DOWN && event.type != SDL_EVENT_FINGER_MOTION &&
      event.type != SDL_EVENT_FINGER_UP && event.type != SDL_EVENT_FINGER_CANCELED) {
    return false;
  }
  const int region = touch_region_at(event.tfinger.x, event.tfinger.y);
  if (!g_settings_screen) {
    if (event.type == SDL_EVENT_FINGER_DOWN && region == static_cast<int>(TouchRegion::Menu)) {
      open_settings_screen();
      return true;
    }
    return false;
  }
  if (event.type == SDL_EVENT_FINGER_DOWN) {
    const int row_count = g_settings_level == 0 ? settings_section_count()
                                                : settings_section_row_count(g_settings_section);
    if (region == static_cast<int>(TouchRegion::Menu)) {
      close_settings_screen();
    } else if (region == static_cast<int>(TouchRegion::Circle)) {
      if (g_settings_level == 1) {
        g_settings_level = 0;
        g_settings_row = g_settings_section;
        upload_settings_screen();
      } else {
        close_settings_screen();
      }
    } else if (region == static_cast<int>(TouchRegion::DpadUp)) {
      g_settings_row = (g_settings_row + row_count) % (row_count + 1);
      upload_settings_screen();
    } else if (region == static_cast<int>(TouchRegion::DpadDown)) {
      g_settings_row = (g_settings_row + 1) % (row_count + 1);
      upload_settings_screen();
    } else if (region == static_cast<int>(TouchRegion::Cross) ||
               region == static_cast<int>(TouchRegion::DpadRight)) {
      if (g_settings_level == 0) {
        if (g_settings_row < settings_section_count()) {
          g_settings_level = 1;
          g_settings_section = g_settings_row;
          g_settings_row = 0;
          upload_settings_screen();
        } else {
          close_settings_screen();
        }
      } else {
        settings_activate_selected(1);
      }
    } else if (region == static_cast<int>(TouchRegion::DpadLeft)) {
      settings_activate_selected(-1);
    }
  }
  return true;
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
      lg::info("OTTSEL LIFECYCLE: foreground controller rechecked and audio resumed");
      break;
    default:
      break;
  }
  return true;
}

}  // namespace

// Device class and safe area for the touch layout (declared in ios_boot.h), from SDL's UIKit backend.
bool ottsel_ios_shell_is_phone() {
  return !SDL_IsTablet();
}

int ottsel_ios_shell_safe_area(float* left, float* top, float* right, float* bottom) {
  int w = 0, h = 0;
  SDL_Rect safe;
  if (!g_win || !SDL_GetWindowSize(g_win, &w, &h) || w <= 0 || h <= 0 ||
      !SDL_GetWindowSafeArea(g_win, &safe)) {
    return 0;
  }
  *left = (float)safe.x / (float)w;
  *top = (float)safe.y / (float)h;
  *right = (float)(w - safe.x - safe.w) / (float)w;
  *bottom = (float)(h - safe.y - safe.h) / (float)h;
  return 1;
}

int main(int argc, char** argv) {
  (void)argc;
  (void)argv;

  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)) {
    fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
    return 1;
  }
  SDL_AddEventWatch(on_event_watch, nullptr);
  select_mobile_gamepad();

  SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
  SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
  SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
  SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
  SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 8);
#if TARGET_OS_SIMULATOR
  // The Simulator's OpenGL ES is a CPU rasterizer: a 1x window keeps the final blit affordable.
  g_win = SDL_CreateWindow("Ottsel Shell", 1024, 768, SDL_WINDOW_OPENGL);
#else
  g_win = SDL_CreateWindow("Ottsel Shell", 1024, 768,
                           SDL_WINDOW_OPENGL | SDL_WINDOW_HIGH_PIXEL_DENSITY);
#endif
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
  g_touch_layout_dir = writable;
  apply_default_touch_layout();
  refresh_touch_layout_path();
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

  load_touch_layout();
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
          if (ev.type == SDL_EVENT_KEY_DOWN && ev.key.key == SDLK_F6) {
            toggle_touch_editor();
          } else if (ev.type == SDL_EVENT_KEY_DOWN && ev.key.key == SDLK_LEFTBRACKET) {
            adjust_touch_opacity(-0.05f);
          } else if (ev.type == SDL_EVENT_KEY_DOWN && ev.key.key == SDLK_RIGHTBRACKET) {
            adjust_touch_opacity(0.05f);
          } else {
            g_input.keyboard(ev.key.key, ev.key.scancode, ev.type == SDL_EVENT_KEY_DOWN);
          }
          break;
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
        case SDL_EVENT_FINGER_MOTION:
        case SDL_EVENT_FINGER_UP:
        case SDL_EVENT_FINGER_CANCELED:
          // I3: the settings surface is a shell modal, so it sees the finger before the layout editor and
          // before the game's pad producer.
          if (!handle_settings_touch(ev)) {
            if (!handle_touch_editor(ev)) {
              g_input.touch(ev);
            }
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
    {
      const auto trigger_path = [&](const char* name) {
        std::string writable_path = writable + name;
        if (access(writable_path.c_str(), F_OK) == 0) {
          return writable_path;
        }
        return bundle + name;
      };
      // BOT59: poll every frame.  The old 30-frame divider throttled injected
      // taps to about one per 3.3 s at the measured ~9 chains/s, so a scripted
      // "hold" decayed into a single one-frame pulse that no actor could act
      // on.  That made an input experiment look like an input failure.
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
      // I3 (2026-09-22): touch is the iPad's primary control surface and there is no non-UI way to press a
      // finger on it, so this bounded trigger drives the *same* path a real finger takes
      // (handle_touch_editor then g_input.touch): create <writable>ottsel-touch-<region> to press that
      // region's centre and remove it to release.  Names follow the TouchRegion order.
      {
        static const char* const kTouchTriggers[] = {"left-stick", "camera", "circle", "cross",
                                                     "square", "triangle", "dpad-up", "dpad-right",
                                                     "dpad-down", "dpad-left", "start", "l1", "r1",
                                                     "menu"};
        // One finger per present region, so a stick and a button can be held at the same time - the gesture
        // the iPad actually plays with.  Each region keeps its own finger id and its own down state.
        static std::array<bool, std::size(kTouchTriggers)> touch_down{};
        for (size_t i = 0; i < std::size(kTouchTriggers); ++i) {
          const std::string touch_path = writable + "ottsel-touch-" + kTouchTriggers[i];
          const bool present = access(touch_path.c_str(), F_OK) == 0;
          if (present == touch_down[i]) {
            continue;
          }
          touch_down[i] = present;
          const SDL_FingerID finger = 0x7f000000 + static_cast<SDL_FingerID>(i) + 1;
          const auto& region = g_touch_layout.regions[i];
          SDL_Event ev{};
          ev.tfinger.fingerID = finger;
          ev.tfinger.timestamp = SDL_GetTicksNS();
          ev.tfinger.x = region.x + region.w * 0.5f;
          ev.tfinger.y = region.y + region.h * 0.5f;
          if (present) {
            ev.type = SDL_EVENT_FINGER_DOWN;
            if (!handle_settings_touch(ev)) {
              if (!handle_touch_editor(ev)) {
                g_input.touch(ev);
              }
            }
            // A press alone leaves the stick centred (its state comes from drag), so follow it with a small
            // drag; button regions ignore motion for a non-stick finger.
            SDL_Event drag{};
            drag.type = SDL_EVENT_FINGER_MOTION;
            drag.tfinger.fingerID = finger;
            drag.tfinger.timestamp = SDL_GetTicksNS();
            drag.tfinger.x = std::min(1.f, ev.tfinger.x + 0.08f);
            drag.tfinger.y = ev.tfinger.y - 0.04f;
            if (!handle_settings_touch(drag)) {
              if (!handle_touch_editor(drag)) {
                g_input.touch(drag);
              }
            }
          } else {
            ev.type = SDL_EVENT_FINGER_UP;
            if (!handle_settings_touch(ev)) {
              if (!handle_touch_editor(ev)) {
                g_input.touch(ev);
              }
            }
          }
        }
      }
    }
    update_touch_overlay_feedback();
    // I3: the overlay's geometry depends on the surface size twice over - the layout is clamped to it by the
    // safe-area pass and a label's aspect (pixel_x = pixel_y * h / w) is derived from it - so rebuild the
    // vertices whenever the drawable size moves instead of keeping the first size's proportions.
    {
      static int overlay_surface_w = 0;
      static int overlay_surface_h = 0;
      if (g_surf_w != overlay_surface_w || g_surf_h != overlay_surface_h) {
        overlay_surface_w = g_surf_w;
        overlay_surface_h = g_surf_h;
        build_touch_overlay(g_input.pressed_region_mask());
        upload_touch_overlay();
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

    // I3: the persisted music volume is applied once the sound substrate is up, so a relaunch honours it
    // without the settings screen being opened.
    {
      static bool music_volume_applied = false;
      if (!music_volume_applied && g_frame >= 5) {
        music_volume_applied = true;
        apply_music_volume();
      }
    }
    // The window's pixel size is only final after layout (and changes on rotation); the CPU status surface
    // and the touch layout follow it.
    {
      int dw = 0, dh = 0;
      SDL_GetWindowSizeInPixels(g_win, &dw, &dh);
      if (dw > 0 && dh > 0 && (dw != g_surf_w || dh != g_surf_h)) {
        g_surf_w = dw;
        g_surf_h = dh;
        g_rgba.assign((size_t)g_surf_w * g_surf_h * 4, 0);
        g_font_scale = std::max(3, g_surf_w / 430);
        refresh_touch_layout_path();
        refresh_settings_path();
        apply_safe_area_to_default_touch_layout();
        log_touch_layout_metrics();
        lg::info("OTTSEL SHELL: window {}x{} font scale {}", dw, dh, g_font_scale);
      }
    }
    // P1: the safe area can arrive after the window exists; the helper latches after its first answer.
    apply_safe_area_to_default_touch_layout();
    if (!g_touch_overlay_uploaded && !g_native_input_mode && g_frame >= 60) {
      build_touch_overlay();
      upload_touch_overlay();
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
      if (data_missing || !live) {
        static int status_upload_countdown = 0;  // the surface is a full window of pixels
        if (status_upload_countdown-- <= 0) {
          status_upload_countdown = 30;
          read_log_tail();
          render_surface();
          ottsel_gl_set_status(g_rgba.data(), g_surf_w, g_surf_h);
          status_overlay_active = true;
        }
      } else if (status_overlay_active && !g_settings_screen && !g_settings.log_overlay) {
        ottsel_gl_set_status(nullptr, 0, 0);
        status_overlay_active = false;
      }
    }
    // OpenGOAL renders the frame, the touch controls and status surface go on top, then it presents.
    ottsel_gl_render(g_win);
    g_frame++;
    // This used to be an unconditional SDL_Delay(16), which pinned the loop
    // (and therefore gfx_vsync's release rate) to a fixed ~23 Hz no matter how
    // long present actually took.  Pacing is already the job of gfx_vsync, so
    // treat this as a cap instead of a delay: sleep only the remainder of a
    // 60 Hz budget and let a slow present take as long as it needs.
    if (g_loop_start_ns) {
      const Uint64 budget_ns = 1000000000ull / 60ull;
      const Uint64 now_ns = SDL_GetTicksNS();
      const Uint64 elapsed_ns = now_ns - g_loop_start_ns;
      if (elapsed_ns < budget_ns) {
        SDL_DelayNS(budget_ns - elapsed_ns);
      }
    }
    g_loop_start_ns = SDL_GetTicksNS();
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
