#pragma once
// The "Play as Mario" mod: Super Mario 64's own Mario (libsm64, from the player's US ROM) running in
// Jak 1's levels. Jak's collision becomes Mario's ground and walls; Mario is drawn into the game's frame;
// Jak stays in the game as an invisible stand-in at Mario's feet (goal_src/jak1/engine/game/main.gc).
#include <string>

// Finds the ROM (sm64.z64, .v64 or .n64 in the app's writable folder) and installs the draw hook.
void ottsel_mario_install(const std::string& writable_dir);
bool ottsel_mario_rom_present();
bool ottsel_mario_enabled();
void ottsel_mario_set_enabled(bool on);
// Mario's Moves: chained running jumps become his second jump and triple jump, and a jump out of a
// turn-around his sideflip (goal_src/jak1/engine/game/main.gc picks them; Jak's controls are unchanged).
bool ottsel_mario_moves();
void ottsel_mario_set_moves(bool on);
