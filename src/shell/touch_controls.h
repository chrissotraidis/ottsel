#pragma once
// Ottsel's touch controls and three-dot menu: a UIKit overlay above the game view, built the way SunPad's
// controller is (github.com/chrissotraidis/sunpad, apple/ios/SunPadGameOverlay.mm) and mapped to the
// DualShock 2. Everything here runs on the main thread (UIKit and SDL's event loop).

#include <cstdint>

struct SDL_Window;

// The overlay's pad. Sticks are -1..1 with x to the right and y down (DualShock orientation); buttons use
// the ottsel::platform_input::Button bits.
struct OttselTouchPad {
  uint16_t buttons = 0;
  float lx = 0.f, ly = 0.f;
  float rx = 0.f, ry = 0.f;
};

struct OttselTouchHooks {
  void (*pad_changed)(const OttselTouchPad& pad);
  // Shell settings: "controls" (0 automatic, 1 always, 2 never), "render_scale" (50/75/100),
  // "camera_sensitivity" (50-200), "invert_camera_y", "log_overlay".
  int (*setting)(const char* key);
  void (*set_setting)(const char* key, int value);
  double (*fps)();          // presented frames per second over the last second
  bool (*has_game_data)();  // a validated user pack is in use
  const char* log_dir;      // holds ottsel-runtime.log and ottsel-fault.log
};

// Add the overlay to the window's view (after the GL context exists, so it sits above the game).
void ottsel_touch_install(SDL_Window* window, const OttselTouchHooks& hooks);
// A keyboard, mouse or controller is in use (hide the controls when set to "Automatically").
void ottsel_touch_set_hidden(bool hidden);
