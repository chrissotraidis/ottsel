#pragma once
// Ottsel's touch controls: a UIKit overlay above the game view, built the way SunPad's controller is
// (github.com/chrissotraidis/sunpad, apple/ios/SunPadGameOverlay.mm): stick views with a moving thumb,
// round buttons, a grouped D-pad, a three-dot settings menu, and a layout the player can drag and keep.
// Mapped to the DualShock 2. Everything here runs on the main thread (UIKit and SDL's event loop).

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
  // Shell settings shown in the menu: "controls" (0 automatic, 1 always, 2 hidden), "render_scale",
  // "music_volume", "camera_sensitivity", "invert_camera_y", "log_overlay".
  int (*setting)(const char* key);
  void (*set_setting)(const char* key, int value);
};

// Add the overlay to the window's view (after the GL context exists, so it sits above the game).
void ottsel_touch_install(SDL_Window* window, const OttselTouchHooks& hooks);
// Hide the controls (the menu stays), e.g. while a physical controller or keyboard is in use.
void ottsel_touch_set_hidden(bool hidden);
