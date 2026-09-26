#pragma once

#include <string>

// Ottsel S1.3 — iOS boot driver interface.
// The shell sets the bundle dir, then starts the boot on a background thread;
// the boot runs the no-emit runtime to the GOAL kernel dispatcher loop.

void ottsel_ios_set_bundle_dir(const std::string& dir);
std::string ottsel_ios_bundle_dir();

// The app bundle is read-only on iOS.  Keep logs and diagnostic captures in
// the per-app writable container while resources continue to resolve from the
// bundle directory above.
void ottsel_ios_set_writable_dir(const std::string& dir);
std::string ottsel_ios_writable_dir();

// True on a phone-shaped device (UIUserInterfaceIdiomPhone).  The shell keys the per-class settings
// file on this, deliberately not on a surface size: the window's pixel size is only known
// after layout (it reads the 1024x768 window request at creation) and a device reports pixels
// scaled by its display scale, so a raw pixel width would call a real iPhone a tablet.  Implemented in
// src/shell/main.cpp on SDL (SDL_IsTablet).
bool ottsel_ios_shell_is_phone();

// Diagnostic startup seam: prepare and cache the validated user-data root
// before the renderer starts reading level files.
void ottsel_ios_prepare_user_data();

// True only after a validated user-owned pack has been selected or promoted.
// A clean install deliberately returns false so the shell can provide a
// remediation message instead of making the diagnostic bundle look complete.
bool ottsel_ios_has_user_data();

// Runs the runtime boot (EE memory map, kernel link, dispatcher loop).
// Returns when MasterExit stops the dispatcher. Never returns on fatal boot
// failure (the gated-error path logs and aborts instead of crash-looping).
void ottsel_ios_run_boot();

// Ask the running dispatcher loop to stop (sets MasterExit = EXIT).
void ottsel_ios_stop_dispatch();

// Called from jak1::InitHeapAndSymbol (OTTSEL_IOS) to load KERNEL.CGO
// directly from the app bundle instead of the IOP/OVERLORD path.
extern "C" void ottsel_ios_load_kernel_from_bundle();
