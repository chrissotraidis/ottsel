# Ottsel

Build-and-proof repository for a **native iPadOS/iOS port** of *Jak and
Daxter: The Precursor Legacy* on top of
[OpenGOAL](https://github.com/open-goal/jak-project).

## Status
**2026-09-25: plays in the iPad Simulator; the device build is ready but has not run on hardware.**

- **Code:** all 518 of the game's code modules are signed ahead-of-time ARM64 code. Strict mode makes
  runtime code loading fatal, so the Simulator enforces what a device will.
- **Rendering:** OpenGOAL's own OpenGL renderer on OpenGL ES 3.0 from ANGLE (on Metal). In the iPad Pro
  11" Simulator the title and Training both run at ~58 fps at 2420x1668; the whole intro
  plays to Geyser Rock.
- **Controls:** SunPad-style touch controls and three-dot menu (UIKit), plus controllers and keyboard.
- **Device:** `scripts/install-ios-device.sh` signs, installs and launches on a connected iPad once
  Xcode is signed in to an Apple ID. Frame rate on hardware is not measured yet.
- Users supply their own game data; the repository contains no game assets.

## Build and run
Needs a Mac with Xcode, `brew install cmake ninja ripgrep glslang spirv-cross xcodegen`, and your own
Jak and Daxter (NTSC, SCUS-97124) disc image. ANGLE is downloaded by the build.

```sh
# 1. OpenGOAL at the pinned commit, plus Ottsel's patch (see patches/README.md)
git clone https://github.com/open-goal/jak-project out/jak-project
git -C out/jak-project checkout 641fb572e876750d8618434d9f7c1a531b43b366
git -C out/jak-project apply --binary ../../patches/ottsel-jak-project.patch

# 2. Host tools, your disc's data, and the game compiled for arm64
cd out/jak-project
cmake -S . -B build/h1 -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang \
  -DCMAKE_CXX_COMPILER=clang++ -DSTATICALLY_LINK=OFF -DINSTALL_GTEST=OFF -DOTTSEL_NO_EMIT=ON
ninja -C build/h1 goalc extractor ottsel-a11-slice
./build/h1/decompiler/extractor --extract --decompile /path/to/jak1.iso   # -> iso_data/jak1, out/jak1/fr3
./build/h1/goalc/goalc --game jak1 --isa arm64 -c '(mi)'                  # -> out/jak1/iso, out/jak1/obj
cd ../..

# 3. The iOS app (Simulator; OTTSEL_PLATFORM=device for iPad/iPhone)
OTTSEL_STRICT_EXEC=1 OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 OTTSEL_SIGNED_EXPORT_BANKS=1 \
  OTTSEL_SIGNED_MODULE_LIST=config/signed-game-strict.json bash scripts/build-ios.sh

# 4. Your data pack, installed into a booted Simulator
scripts/prepare-user-data-pack.sh out/jak-project/iso_data/jak1 /tmp/ottsel-pack out/jak-project/out/jak1/fr3
xcrun simctl install booted out/jak-project/out/ios/app/OttselShell.app
scripts/import-ios-user-data.sh <simulator-udid> /tmp/ottsel-pack
xcrun simctl launch booted com.ottsel.shell
```

On an iPad: sign in to Xcode with an Apple ID, connect and trust the iPad, enable Developer Mode, then
`scripts/install-ios-device.sh /tmp/ottsel-pack`. `scripts/test-ios-touch.sh <udid>` replays title ->
LOAD GAME -> Training by real touches.

## Start here
1. [`docs/GOAL_LOOP.md`](docs/GOAL_LOOP.md) — the single execution plan
2. [`docs/STATUS.md`](docs/STATUS.md) — the current board
3. [`jak1-researchloop.md`](jak1-researchloop.md) — the original requirement
4. [`patches/README.md`](patches/README.md) — rebuilding the OpenGOAL tree

## What this repo contains
- `docs/` — goal loop, status, Phase 1 research, evidence, reports, history
- `src/shell/` — the iOS app shell (window, touch controls, boot); the game renders through
  OpenGOAL's own OpenGL renderer on OpenGL ES 3.0
- `scripts/` — builds, route drivers, signed-AOT tools and regressions
- `patches/` — `ottsel-jak-project.patch`, the whole delta against the
  pinned OpenGOAL checkout
- `config/` — signed module lists for the build profiles
- `ref/` — local research corpus (ignored)
- `out/` — ignored local build/source/data worktree
- No game assets. Supply your own legal PS2 copy for local builds.

## Hard constraints
- No ISOs/extracted copyrighted assets in git
- No RWX/JIT or runtime-created executable-code product path on iOS
- Simulator iteration: one device simulator at a time
- At most one runtime executable; no fullscreen test executable

### macOS test controls

The native Windowed build defaults to `W/A/S/D` movement, mouse motion camera
control, left/right mouse for Cross/Circle, `Space/E/F/R` for
Cross/Circle/Square/Triangle, `Return` or `Esc` for Start/pause, and `Tab` for
Select/map. `I/J/K/L` provide keyboard camera movement; release every key or
button to return to neutral. Press Left Alt for the debug toolbar, then use
`Settings → Ottsel` for runtime upscaling and mute controls.

Package a Finder-visible macOS app with `./scripts/package-macos.sh`.

The Phase 1 research record remains in `docs/00`–`12`; implementation evidence
is under `docs/evidence/`.
