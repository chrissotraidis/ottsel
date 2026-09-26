#pragma once
// Ottsel on a TV or monitor (HDMI, USB-C, AirPlay): while an external screen is connected the game
// renders full-screen there at that screen's resolution, and the iPad keeps the touch controls and menu.

// The renderer and touch overlay exist: use an external screen that is (or later becomes) connected.
// Main thread, after ottsel_gl_attach and ottsel_touch_install.
void ottsel_external_display_install();
