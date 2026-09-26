# 03 — Platform surface (iPadOS / iOS)

Research date: 2026-08-07  
Depends on: `02-execution-model-verdict.md` (hard gate already decided: CONDITIONAL GO)

This document assumes Strategy A/B from the execution-model verdict. It does **not** reopen RWX/JIT as a product option.

## 1. Target product shape

- Native app for **iPadOS first**, iPhone second.
- Built on macOS with Xcode.
- Iteration on **iOS Simulator and iPadOS Simulator, one at a time** (never both booted for Bot 2 work).
- User-supplied legal PS2 Jak 1 assets imported on device/Simulator; never bundled in git or release zips as copyrighted content.
- No live compiler/REPL in the mobile app.

## 2. Platform matrix

| Surface | OpenGOAL today | iOS/iPadOS target | Notes |
|---|---|---|---|
| CPU ISA | x86-64+AVX (Rosetta on Apple Silicon Macs) | arm64 only | No Rosetta on iOS |
| Code model | Runtime-linked GOAL objects into executable EE memory | AOT ARM64, no runtime emit | Hard gate |
| Windowing | SDL3 desktop window | SDL3 UIKit / native shell | SDL3 has first-class iOS support |
| Graphics API | OpenGL 4.3 (4.1 on macOS) | Metal preferred; GLES only if temporary | OpenGL 4.x unavailable on iOS |
| Audio | 989SND + host glue | AVAudioSession via SDL audio first | Keep game-side 989SND |
| Input | keyboard/mouse/gamepad via SDL | touch + optional gamepad + optional keyboard/pointer on iPad | Needs new mapping layer |
| Files | ISO folder / desktop FS | Documents + Files picker / onboarding importer | Writable sandbox only |
| Lifecycle | desktop forever-running process | suspend/resume, memory warnings, audio interruption | Must pause EE/overlord cleanly |
| Networking REPL | DECI2 listener | disabled on iOS | Host-only |
| Packaging | desktop binaries | `.app` / unsigned IPA research artifact | No asset pack-in |
| Distribution | GitHub releases (upstream) | sideload/TestFlight later; App Store only if code model is signing-safe | Legal/content rules still apply |

## 3. Graphics

### Current
- Only `GfxPipeline::OpenGL` exists.
- Context creation requests OpenGL **4.3**, or **4.1** on macOS (`game/graphics/pipelines/opengl.cpp`).
- Renderer is a substantial custom OpenGL port of the game’s buckets/pipelines.

### iOS constraint
- iOS does not provide OpenGL 4.x.
- OpenGL ES exists but is legacy; Apple’s direction is Metal.
- SDL3 iOS docs still discuss GLES details, but a serious port should plan Metal.

### Plan
1. **Short-term research spike (after G2 proofs):** determine whether a minimal GLES2/3 path can show a frame faster than Metal.
2. **Product path:** Metal backend implementing the existing renderer interface boundary (`GfxRendererModule` / bucket renderers), likely by translating the OpenGL renderer’s resource traffic rather than rewriting game buckets from scratch.
3. Do not couple touch UI work to the first-frame graphics spike beyond a clear color / first scene proof.

## 4. Audio

- Keep `game/sound` 989SND logic.
- Host output should use SDL audio on iOS first (AVAudioSession under the hood).
- Handle interruptions (`SDL_EVENT_WILL_ENTER_BACKGROUND`, phone calls, route changes).
- No assumption of desktop device sample-rate quirks.

## 5. Input

Minimum viable playable controls for Jak 1:

- virtual left stick (move)
- camera controls (second stick or drag)
- jump / attack / use / crouch / secondary actions as face buttons
- pause / map
- optional DualSense/Xbox controller via GameController/SDL

Design rules:

- touch controls are an **overlay**, not a rewrite of GOAL input tables
- keep a single platform input normalization layer in C++ (`game/system/hid` or ottsel overlay)
- iPad pointer/keyboard are enhancements, not requirements for MVP

## 6. Filesystem and onboarding

Upstream expects ISO extraction on desktop into `iso_data/jak1`.

iOS needs:

1. first-launch onboarding explaining user must own the game
2. import path via Files/`UIDocumentPicker` for either:
   - pre-extracted portable asset pack produced on Mac by Ottsel host tools, or
   - supported raw dump format if practical (likely too heavy; prefer host-prepared legal asset pack)
3. durable install into app Documents
4. no network asset fetch of copyrighted content

Recommended elegant split:

- **Host tool (macOS):** user ISO → verified extract → Ottsel asset package (local)
- **iOS app:** import package → validate manifest/hash → play

## 7. Lifecycle

Must explicitly handle:

- background/foreground
- memory warning
- audio pause/resume
- saving settings/progress to sandbox
- no crash if suspended mid-frame

OpenGOAL’s multi-thread EE/IOP design means Bot 2 needs a single “pause the world” seam before UIKit suspension, not only GL pause.

## 8. Packaging / signing

Phase 2 research artifact goals:

- Simulator builds for iPhone + iPad targets
- optional unsigned IPA packaging script later
- deterministic, ROM-free repo checkout

Physical device signing remains an external gate (Apple ID / team / provisioning) and must not be faked as complete from Simulator evidence.

## 9. App Store vs sideload implications for code model

Because the hard problem is executable code origin:

- **Safest distribution story:** all CPU-executable game code is compiled into the signed app/native libraries at build time (Strategy B or Strategy A-MachO variant).
- **Riskier story:** app loads AOT bytes and creates RX pages at runtime. Even if technically possible in some environments, it is a policy/engineering trap and may be a dead end for store distribution.

Bot 2 should implement host proofs first, then choose the packaging form that preserves no-emit semantics under signing.

## 10. Simulator rules for Bot 2

- Never boot iPhone and iPad simulators simultaneously for this project’s active loop.
- Prefer one device target per gate proof.
- Capture logs/screenshots as evidence.
- Simulator success ≠ physical device acceptance.

## 11. Minimum OS / device posture (planning defaults)

Unless Bot 2 discovers a stronger constraint in SDL/Xcode:

- iOS/iPadOS 16+ planning baseline (adjust if SDL3/Xcode toolchain requires newer)
- arm64 only
- iPad landscape primary

## 12. What not to do

- Do not vendor copyrighted assets “for convenience.”
- Do not enable goalc listener ports on iOS.
- Do not claim Metal complete because SDL created a window.
- Do not treat Rosetta macOS gameplay as iOS evidence.


## 13. Deep-pass references
- Expanded graphics/audio/input notes: [`11-graphics-audio-input-deep-dive.md`](11-graphics-audio-input-deep-dive.md)
- Packaging/signing: [`10-code-packaging-and-signing.md`](10-code-packaging-and-signing.md)
- OpenGOAL game version support details: `ref/opengoal-docs/game_versions.html`
- SDL3 currently used upstream (Q2 2026 progress report notes SDL 3.4.10 update)
