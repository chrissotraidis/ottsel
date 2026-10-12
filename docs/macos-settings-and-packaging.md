# Ottsel on the Mac

The Mac app is the iPad app built for Apple Silicon Macs: the same shell, game code, renderer (OpenGL ES
from ANGLE on Metal), Mario mod and settings. The iPad's three-dot menu is the menu bar.

## Build

```sh
OTTSEL_PLATFORM=macos OTTSEL_SIGN_IDENTITY="Apple Development: …" \
OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 OTTSEL_SIGNED_MODULE_LIST=config/signed-game-strict.json \
OTTSEL_SIGNED_EXPORT_BANKS=1 bash scripts/build-ios.sh
open out/jak-project/out/macos/app/Ottsel.app
```

Without `OTTSEL_SIGN_IDENTITY` the app is signed ad hoc, which runs on the Mac that built it.
Settings, saves, logs and game data live in `~/Library/Application Support/local.ottsel/OttselShell/`.

## Game data and Mario

- **Game Data → Import Game Data…** takes the `OttselUserData` folder made by
  `scripts/prepare-user-data-pack.sh` from your own disc. Ottsel validates it on the next launch and
  keeps it.
- **Mods → Add Super Mario 64 (US) ROM…** copies your own ROM in; then **Play as Mario**.

## Menus

Display (Full Screen ⌃⌘F, Render Resolution, FPS counter in the window title), Cheats, Mods,
Controls (camera speed, invert camera, keyboard and mouse help), Game Data, Diagnostics (log overlay,
Show Logs in Finder, Jump to Level), Help.

## Controls

A game controller works as on the iPad. Keyboard: W A S D move, Space jump, F punch, E spin kick,
R triangle, O crouch/roll (R1), Q L1, Return Start, arrow keys D-pad; click the game to steer the camera
with the mouse.

## Status (2026-10-12)

M3 Max, macOS 26.6: Geyser Rock with Mario at a steady 60 fps at 2560x1920 (2 ms of drawing per frame).
Another GPU-heavy app (the iOS Simulator) cut it to 25–45 fps. Quitting waits up to 2 s for the game thread,
then exits. Not yet: Developer ID signing and notarization for other people's Macs, or keyboard
remapping.
