#pragma once

#include <string>

// Ottsel S1.3 — iOS boot driver interface.
// The shell sets the bundle dir, then starts the boot on a background thread;
// the boot runs the no-emit runtime to the GOAL kernel dispatcher loop.

void ottsel_ios_set_bundle_dir(const std::string& dir);
std::string ottsel_ios_bundle_dir();

// Runs the runtime boot (EE memory map, kernel link, dispatcher loop).
// Returns when MasterExit stops the dispatcher. Never returns on fatal boot
// failure (the gated-error path logs and aborts instead of crash-looping).
void ottsel_ios_run_boot();

// Ask the running dispatcher loop to stop (sets MasterExit = EXIT).
void ottsel_ios_stop_dispatch();

// Called from jak1::InitHeapAndSymbol (OTTSEL_IOS) to load KERNEL.CGO
// directly from the app bundle instead of the IOP/OVERLORD path.
extern "C" void ottsel_ios_load_kernel_from_bundle();
