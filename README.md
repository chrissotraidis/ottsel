# Ottsel

<p align="center">
  <strong>Jak and Daxter: The Precursor Legacy on iPad and iPhone, built on OpenGOAL with the game's code compiled ahead of time to signed ARM64.</strong><br>
  Touch controls and a three-dot settings menu in the style of SunPad, controller and keyboard input, and game data you supply from your own disc.
</p>

<p align="center">
  <img alt="iOS and iPadOS 18.5+" src="https://img.shields.io/badge/iOS%20%2F%20iPadOS-18.5%2B-0A84FF?logo=apple">
  <img alt="OpenGL ES 3.0 on Metal through ANGLE" src="https://img.shields.io/badge/renderer-OpenGL%20ES%20on%20Metal%20(ANGLE)-5E5CE6">
  <img alt="Game code compiled ahead of time, no JIT" src="https://img.shields.io/badge/GOAL%20code-signed%20ARM64%2C%20no%20JIT-FF9F0A">
  <img alt="iPad Simulator tested" src="https://img.shields.io/badge/iPad%20Simulator-tested-30D158">
  <img alt="Physical iPad not yet tested" src="https://img.shields.io/badge/physical%20iPad-not%20yet%20tested-8E8E93">
  <img alt="Game data not included" src="https://img.shields.io/badge/game%20data-not%20included-FF453A">
</p>

![Ottsel running Jak and Daxter in Geyser Rock's training course with the touch controls](docs/readme/ottsel-training-touch.jpg)

Ottsel packages [OpenGOAL](https://github.com/open-goal/jak-project), the open-source port of Jak and
Daxter built from its decompiled GOAL source, as a native iPadOS and iOS app. On a PC, OpenGOAL compiles
and links the game's code at run time into executable memory. iOS does not allow that, so Ottsel
compiles all 518 of the game's code modules to ARM64 at build time and signs them into the app. A strict
mode makes any attempt to load code at run time fatal, so the Simulator enforces the same rule a device
does. OpenGOAL's own OpenGL renderer draws the game through OpenGL ES 3.0, which
[ANGLE](https://chromium.googlesource.com/angle/angle) translates to Metal.

This repository contains the iOS app shell, one patch against a pinned OpenGOAL commit, and the build
scripts. It does **not** contain Jak and Daxter, a disc image, extracted game files, or saves.

## Current status

Everything below is proven in the iPad Pro 11-inch (M4) Simulator. The app has not yet run on a physical
iPad or iPhone.

| Area | Current result |
|---|---|
| Game code | All 518 GOAL code modules compiled ahead of time to ARM64 and signed into the app; strict mode on |
| Rendering | OpenGOAL's OpenGL renderer on OpenGL ES 3.0 through ANGLE on Metal; title, intro and Training run at about 58 fps at the full 2420×1668 |
| Play | New Game plays the whole intro to Geyser Rock; Load Game restores a save into the training course; Jak walks, jumps and attacks by touch |
| Touch | Move stick, camera stick, D-pad, Cross, Circle, Square, Triangle, L1, R1 and Start, with haptics and a per-device drag-and-resize layout |
| Settings | **•••** menu with Display (render resolution), FPS counter, Controls, Game Data import and Diagnostics |
| Controllers | Apple GameController and hardware keyboard; the touch controls hide while either is in use and return on the next touch |
| Sound | OpenGOAL's own IOP and OVERLORD sound code runs on iOS; audible playback on a device is not yet checked |
| Device build | The `iphoneos` build compiles, links and signs; `scripts/install-ios-device.sh` installs it once Xcode is signed in to an Apple ID |

The current plan and its exit criteria are in [`docs/GOAL_LOOP.md`](docs/GOAL_LOOP.md); the live board is
[`docs/STATUS.md`](docs/STATUS.md). The next gate is a physical iPad reaching the training course twice
from a cold launch, then a measured frame rate on that iPad.

## Build from source

You need:

- an Apple Silicon Mac with Xcode and its command-line tools;
- `brew install cmake ninja ripgrep glslang spirv-cross xcodegen`;
- an Apple ID signed in to Xcode (a free Personal Team is enough) for a physical device; and
- your own Jak and Daxter: The Precursor Legacy disc image, NTSC-U (`SCUS-97124`).

The build downloads a prebuilt ANGLE. Every generated tree stays under the ignored `out/` directory.

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

# 3. The app (Simulator; add OTTSEL_PLATFORM=device for iPad or iPhone)
OTTSEL_STRICT_EXEC=1 OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 OTTSEL_SIGNED_EXPORT_BANKS=1 \
  OTTSEL_SIGNED_MODULE_LIST=config/signed-game-strict.json bash scripts/build-ios.sh

# 4. A game-data pack from your disc, outside the repository
scripts/prepare-user-data-pack.sh out/jak-project/iso_data/jak1 /tmp/ottsel-pack out/jak-project/out/jak1/fr3
```

A first build takes about 25 minutes on an M-series Mac. After a change to nested OpenGOAL source,
refresh the patch with
`scripts/snapshot-jak-project.sh write` and commit it with the change.

## First launch

**Simulator.** Install the app, copy your pack into it, and launch:

```sh
xcrun simctl install booted out/jak-project/out/ios/app/OttselShell.app
scripts/import-ios-user-data.sh <simulator-udid> /tmp/ottsel-pack
xcrun simctl launch booted com.ottsel.shell
```

**iPad or iPhone.** Sign in to Xcode with an Apple ID, connect and trust the device, and turn on Developer
Mode. Then run `scripts/install-ios-device.sh /tmp/ottsel-pack`. It finds your signing identity, has
Xcode create a development profile if needed, builds the strict device app, installs it, copies the pack
into the app, and launches it.

You can also move a pack onto the device yourself: put the pack folder in Files, open **••• → Game Data →
Import Game Data…**, choose the folder, then close and reopen Ottsel. The app checks the pack on launch
and keeps it for later launches.

## Touch controls

The layout follows [SunPad](https://github.com/chrissotraidis/sunpad): controls sit at the screen edges so
the middle of the picture stays clear.

- **Left:** move stick, D-pad and L1.
- **Right:** camera stick, the Cross, Circle, Square and Triangle diamond, and R1.
- **Bottom centre:** Start.
- **Menu:** the **•••** button opens Display, Show FPS Counter, Controls, Game Data and Diagnostics.
- **Customise:** **Controls → Touch Control Settings…** sets when the controls show (Auto, Always,
  Never), their opacity and size, camera speed and camera inversion. **Move Touch Controls** lets you
  drag and resize each control, and the layout is saved per device.

Buttons respond to a finger sliding onto them, so a thumb can roll from Cross to Square without lifting.
With **Show** on Auto, a connected controller or keyboard hides the controls, and the next touch brings
them back.

<table>
  <tr>
    <td width="50%"><img src="docs/readme/ottsel-menu.jpg" alt="The Ottsel three-dot menu open over gameplay"></td>
    <td width="50%"><img src="docs/readme/ottsel-touch-settings.jpg" alt="Ottsel's Touch Control Settings panel"></td>
  </tr>
  <tr>
    <td align="center"><strong>Three-dot menu</strong><br>Display, controls, game data and diagnostics.</td>
    <td align="center"><strong>Touch Control Settings</strong><br>Visibility, opacity, size and camera.</td>
  </tr>
</table>

## Screenshots

<table>
  <tr>
    <td width="50%"><img src="docs/readme/ottsel-main-menu.jpg" alt="The Jak and Daxter main menu with the touch controls"></td>
    <td width="50%"><img src="docs/readme/ottsel-intro-cutscene.jpg" alt="Jak in the opening cutscene"></td>
  </tr>
  <tr>
    <td align="center"><strong>Menus by touch</strong><br>The D-pad, Cross and Start drive every menu.</td>
    <td align="center"><strong>The whole intro plays</strong><br>OpenGOAL's cutscenes, start to finish, on iOS.</td>
  </tr>
</table>

All screenshots come from the iPad Pro 11-inch (M4) Simulator, using game data from a disc owned by the
person running it. No game data is part of this repository.

## Supported game data

| Disc | Region | Status |
|---|---|---|
| `SCUS-97124` | NTSC-U | The only disc tested |

OpenGOAL supports other releases of the game; Ottsel has not been tested with them.

## How it fits together

```text
Your Jak and Daxter disc image (on the Mac)
        ↓  OpenGOAL extractor and decompiler
Game data + OpenGOAL's GOAL source
        ↓  goalc compiles the game for arm64; build-ios.sh signs all 518 modules into the app,
        ↓  cross-compiles the 92 shaders to GLSL ES and embeds ANGLE
Ottsel app (Simulator or device)  +  your game-data pack
        ↓
OpenGOAL runtime → OpenGL ES 3.0 → ANGLE → Metal
```

Building also copies a few files generated from your disc into the app: the compiled `KERNEL.CGO` and
`GAME.CGO`, the title and village DGO files, and the text files. The app you build is for your own
devices only, and there is no public IPA. Moving those files into the pack is open work
([G7](docs/GOAL_LOOP.md)).

## Frequently asked questions

### Does this repository include Jak and Daxter?

No. You need your own disc image. Do not open issues asking for game data or download links.

### Is Ottsel an emulator?

No. OpenGOAL runs the game's own GOAL code natively; it does not emulate a PlayStation 2. Ottsel makes
that code run on iOS by compiling it ahead of time, and adapts OpenGOAL's renderer, input and file access
to the platform.

### Does it use a JIT?

No. There is no JIT, no memory that is both writable and executable, and no code patching at run time.
Every piece of game code is ARM64 compiled on the Mac and signed with the app.

### Can I download an IPA?

Not yet. The app you build contains files generated from your disc, so it cannot be shared. A public
build waits until all game-derived files live in the pack.

### Does it run on a real iPad or iPhone?

It has not been tested on one yet. The device build compiles, links and signs, and
`scripts/install-ios-device.sh` installs it. The app is universal and landscape-only; the iPhone
layout has not been checked.

### Is it finished?

No. Still open: a physical iPad run, the frame rate on that iPad, level transitions beyond the training
course, saving and continuing across a relaunch on a device, sound on a device, a paired controller on a
device, and iPhone. The acceptance gates are in [`docs/GOAL_LOOP.md`](docs/GOAL_LOOP.md).

## Mac test build

The patched OpenGOAL tree also builds for macOS, which is useful for comparing output against iOS.
`scripts/package-macos.sh` makes a Finder app. Its keyboard defaults are W/A/S/D to move, the mouse or
I/J/K/L for the camera, Space/E/F/R for Cross/Circle/Square/Triangle, Return or Esc for Start, and Tab for
Select.

## Project map

| Path | Purpose |
|---|---|
| [`src/shell/`](src/shell/) | The iOS app shell: window, boot, touch controls and the three-dot menu |
| [`patches/ottsel-jak-project.patch`](patches/ottsel-jak-project.patch) | The whole delta against the pinned OpenGOAL commit ([how to refresh it](patches/README.md)) |
| [`scripts/build-ios.sh`](scripts/build-ios.sh) | Builds SDL, zstd and the runtime; signs the modules; translates shaders; assembles the app |
| [`scripts/install-ios-device.sh`](scripts/install-ios-device.sh) | Signs, installs and launches on a connected iPad or iPhone, and copies the pack |
| [`scripts/prepare-user-data-pack.sh`](scripts/prepare-user-data-pack.sh) | Builds a game-data pack from your extracted disc, outside the repository |
| [`scripts/import-ios-user-data.sh`](scripts/import-ios-user-data.sh) | Copies a pack into a Simulator install |
| [`scripts/translate-gl-shaders.py`](scripts/translate-gl-shaders.py) | Cross-compiles OpenGOAL's desktop shaders to GLSL ES 3.00 |
| [`scripts/test-ios-touch.sh`](scripts/test-ios-touch.sh) | Plays title → Load Game → training course by real touches (XCUITest) |
| [`scripts/replay-ios-normal-route.py`](scripts/replay-ios-normal-route.py) | Drives the menus into New Game or a saved slot for quick checks |
| [`config/`](config/) | Signed-module lists for the build profiles |
| [`docs/GOAL_LOOP.md`](docs/GOAL_LOOP.md) | The plan: goal, gates and exit criteria |
| [`docs/STATUS.md`](docs/STATUS.md) | The current board and a short log |
| [`docs/evidence/`](docs/evidence/) | One short record per proven gate |
| [`jak1-researchloop.md`](jak1-researchloop.md) | The original requirement |
| `docs/00`–`12` | The Phase 1 research record |
| `out/`, `ref/` | Ignored local build trees, game data and research clones |

## Credits

Ottsel stands on the [OpenGOAL](https://github.com/open-goal/jak-project) project, whose team decompiled
the game, wrote the GOAL compiler and runtime, and built the renderer that Ottsel uses. ANGLE comes from
[kivy/angle-builder](https://github.com/kivy/angle-builder) releases. [SDL](https://github.com/libsdl-org/SDL)
provides the window and input, and [glslang](https://github.com/KhronosGroup/glslang) with
[SPIRV-Cross](https://github.com/KhronosGroup/SPIRV-Cross) translate the shaders at build time. The
touch controls and menu follow [SunPad](https://github.com/chrissotraidis/sunpad).

## Legal

Ottsel is an unofficial community project and is not affiliated with or endorsed by Sony Interactive
Entertainment or Naughty Dog. Jak and Daxter names and screenshots are used only to identify
compatibility and show the project working. No disc image, extracted game file or save is included in
this repository. OpenGOAL is released under the ISC License, and each other component keeps its own
license.

## Contributing

The most useful contribution right now is a report from a physical iPad or iPhone: the device, iOS
version, what happened from launch to the training course, and the frame rate from **••• → Show FPS
Counter**. Never attach game data, extracted files, a built app or saves to an issue or pull request.
