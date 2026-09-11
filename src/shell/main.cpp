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
  Start,
  L1,
  R1,
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

TouchLayout g_touch_layout = {
    {{{0.055f, 0.605f, 0.13f, 0.165f},  // left stick
      {0.70f, 0.36f, 0.16f, 0.10f},   // camera
      {0.785f, 0.615f, 0.055f, 0.055f}, // circle
      {0.875f, 0.715f, 0.055f, 0.055f}, // cross
      {0.875f, 0.615f, 0.055f, 0.055f}, // square
      {0.965f, 0.665f, 0.055f, 0.055f}, // triangle
      {0.43f, 0.08f, 0.14f, 0.045f},  // start
      {0.08f, 0.08f, 0.12f, 0.045f},  // L1
      {0.80f, 0.08f, 0.12f, 0.045f}}}, // R1
    1.f};
std::string g_touch_layout_path;
bool g_touch_editor = false;
bool g_touch_editor_active = false;
SDL_FingerID g_touch_editor_finger = 0;
TouchRegion g_touch_editor_region = TouchRegion::LeftStick;
bool g_native_input_mode = false;

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
  Uint64 last_start_tap_ns = 0;
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
      const int region = touch_region_at(finger.x, finger.y);
      if (region == static_cast<int>(TouchRegion::L1) && !action_active) {
        // The top bars are L1/Start/R1 in the same order as the visible
        // tablet layout. They take precedence over the left-stick half.
        action_finger = finger.fingerID;
        action_active = true;
        action_button = L1;
        set_button(&state, action_button, true);
      } else if (region == static_cast<int>(TouchRegion::Start) && !action_active) {
        if (last_start_tap_ns != 0 && finger.timestamp >= last_start_tap_ns &&
            finger.timestamp - last_start_tap_ns <= 400000000ULL) {
          last_start_tap_ns = 0;
          toggle_touch_editor();
          return;
        }
        last_start_tap_ns = finger.timestamp;
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
      }
    } else if (event.type == SDL_EVENT_FINGER_MOTION && left_stick_active &&
               finger.fingerID == left_stick_finger) {
      state.leftx = static_cast<u8>(std::clamp(127 + int((finger.x - stick_origin_x) * 510), 0, 255));
      state.lefty = static_cast<u8>(std::clamp(127 + int((finger.y - stick_origin_y) * 510), 0, 255));
    } else if (event.type == SDL_EVENT_FINGER_MOTION && camera_active &&
               finger.fingerID == camera_finger) {
      state.rightx = static_cast<u8>(std::clamp(127 + int((finger.x - camera_origin_x) * 510), 0, 255));
      state.righty = static_cast<u8>(std::clamp(127 + int((finger.y - camera_origin_y) * 510), 0, 255));
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
};

ShellPadInput g_input;
std::vector<OttselMetalOverlayVertex> g_touch_overlay;
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
        !std::isfinite(region.h) || region.w < 0.03f || region.h < 0.03f || region.x < 0.f ||
        region.y < 0.f || region.x + region.w > 1.f || region.y + region.h > 1.f) {
      return;
    }
  }
  g_touch_layout = candidate;
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
  for (const auto& region : g_touch_layout.regions) {
    file << region.x << ' ' << region.y << ' ' << region.w << ' ' << region.h << "\n";
  }
  lg::info("OTTSEL TOUCH: saved persistent layout {}", g_touch_layout_path);
}

void build_touch_overlay();
void upload_touch_overlay();

bool handle_touch_editor(const SDL_Event& event) {
  if (!g_touch_editor) {
    return false;
  }
  const auto& finger = event.tfinger;
  if (event.type == SDL_EVENT_FINGER_DOWN && !g_touch_editor_active) {
    const int region = touch_region_at(finger.x, finger.y);
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
    OttselMetalOverlayVertex vertex = {};
    vertex.pos[0] = position[0];
    vertex.pos[1] = position[1];
    vertex.uv[0] = 0.f;
    vertex.uv[1] = 0.f;
    memcpy(vertex.color, color, sizeof(color));
    g_touch_overlay.push_back(vertex);
  }
}

void build_touch_overlay() {
  g_touch_overlay.clear();
  constexpr float colors[static_cast<size_t>(TouchRegion::Count)][4] = {
      {0.20f, 0.70f, 1.0f, 0.20f}, {0.95f, 0.75f, 0.20f, 0.16f},
      {1.0f, 0.35f, 0.35f, 0.24f}, {1.0f, 0.35f, 0.35f, 0.24f},
      {1.0f, 0.35f, 0.35f, 0.24f}, {1.0f, 0.35f, 0.35f, 0.24f},
      {0.95f, 0.65f, 0.20f, 0.22f}, {0.65f, 0.65f, 0.75f, 0.18f},
      {0.65f, 0.65f, 0.75f, 0.18f}};
  for (size_t i = 0; i < static_cast<size_t>(TouchRegion::Count); ++i) {
    const auto& region = g_touch_layout.regions[i];
    add_touch_rect(region.x, region.y, region.w, region.h, colors[i][0], colors[i][1],
                   colors[i][2], colors[i][3] * g_touch_layout.opacity);
  }
}

void upload_touch_overlay() {
  if (!g_native_input_mode && g_metal && !g_touch_overlay.empty()) {
    ottsel_metal_set_touch_overlay(g_metal, g_touch_overlay.data(),
                                   static_cast<unsigned int>(g_touch_overlay.size()));
    g_touch_overlay_uploaded = true;
  }
}

void hide_touch_overlay_for_native_input() {
  if (g_native_input_mode) {
    return;
  }
  g_native_input_mode = true;
  g_touch_overlay_uploaded = false;
  g_touch_overlay.clear();
  if (g_metal) {
    ottsel_metal_set_touch_overlay(g_metal, nullptr, 0);
  }
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

int main(int argc, char** argv) {
  (void)argc;
  (void)argv;

  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMEPAD)) {
    fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
    return 1;
  }
  SDL_AddEventWatch(on_event_watch, nullptr);
  select_mobile_gamepad();

  g_win = SDL_CreateWindow("Ottsel Shell", 1024, 768, 0);
  if (!g_win) {
    fprintf(stderr, "SDL_CreateWindow failed: %s\n", SDL_GetError());
    return 1;
  }
  g_surf = SDL_GetWindowSurface(g_win);

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
  g_touch_layout_path = writable +
                        (g_surf_w < 1000 ? "touch-layout-phone.cfg" : "touch-layout-tablet.cfg");

  // All runtime log output (lg:: + kernel Msg/printstd) goes to this file;
  // the surface renders its tail.  The iOS app bundle is read-only.
  lg::set_file("ottsel-runtime.log", false, false, writable);
  lg::info("OTTSEL RUNTIME BOOT: pid={} writable={}", (u32)getpid(), writable);
  if (std::getenv("OTTSEL_PREPARE_DATA_BEFORE_METAL")) {
    ottsel_ios_prepare_user_data();
  }

  // S2.0: Metal presentation path (falls back to the SDL surface if the
  // Metal device/pipeline cannot be created on this Simulator).
  // The Simulator's SimMetalHost can terminate a process while the drawable
  // service is unavailable. Keep a diagnostic SDL-only mode so boot/data
  // boundaries can be verified independently; the product default remains
  // the Metal path.
  const bool disable_metal = std::getenv("OTTSEL_DISABLE_METAL") != nullptr;
  g_metal = disable_metal ? nullptr : ottsel_metal_create(g_win);
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
    fprintf(stderr, "ottsel S2.0: %s; using SDL software surface\n",
            disable_metal ? "Metal disabled by diagnostic environment" : "Metal init failed");
  }

  // S2.2: register the shell's Metal instance as the Gfx renderer backend so
  // the game's texture uploads decode and present through the CAMetalLayer.
  ottsel_metal_gfx_register(g_metal);

  load_touch_layout();
  // AU1: start the maintained playback-only 989snd/SDL output substrate.
  // Game-bank requests remain a separate IOP/OVERLORD integration gate.
  lg::info("OTTSEL AUDIO: starting playback substrate");
  snd_StartSoundSystem();

  std::thread boot(ottsel_ios_run_boot);

  while (!g_quit) {
    SDL_Event ev;
    while (SDL_PollEvent(&ev)) {
      if (ev.type == SDL_EVENT_QUIT) {
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
          if (!handle_touch_editor(ev)) {
            g_input.touch(ev);
          }
          break;
        default:
          break;
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
      static int ottsel_trig_divider = 0;
      if ((++ottsel_trig_divider % 30) == 0) {
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
  release_mobile_gamepad("shutdown");
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
      // Defer the first Metal resource allocation until the app has presented
      // a few frames.  Allocating a new shared buffer from SDL's launch timer
      // races the Simulator Metal host and aborts the app before it reaches
      // the foreground.  The layout is static for this first T1 increment;
      // later editor changes will reset this one-shot upload flag.
      if (!g_touch_overlay_uploaded && !g_native_input_mode && g_frame >= 60) {
        build_touch_overlay();
        upload_touch_overlay();
      }
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
    ottsel_metal_gfx_signal_vsync();
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

  // ask the dispatcher loop to stop (MasterExit lives in the runtime lib)
  extern void ottsel_ios_stop_dispatch();
  ottsel_ios_stop_dispatch();
  ottsel_metal_gfx_stop_vsync_waiters();
  boot.join();

  snd_StopSoundSystem();
  SDL_DestroyWindow(g_win);
  ottsel_metal_destroy(g_metal);
  SDL_Quit();
  return 0;
}
