# 11 — Graphics / audio / input deep dive

Research date: 2026-08-07  
Depends on execution-model CONDITIONAL GO.

## 1. Graphics

### Current OpenGOAL facts
- Only pipeline enum value used: `GfxPipeline::OpenGL`.
- Context requests OpenGL **4.3**, or **4.1 on macOS** (`game/graphics/pipelines/opengl.cpp`).
- `opengl_renderer/` is large: **103 files / ~45k LOC** at pin (headers+sources).
- Architecture is bucket/DMA oriented (OpenGOAL porting docs: three frames in flight; DMA copy from GOAL thread to graphics thread).
- Renderer is a collection of bucket renderers with Jak1/2/3 dispatch paths (`OpenGLRenderer`).

### Why this matters for iOS
- iOS has no OpenGL 4.3/4.1 desktop profile.
- OpenGL ES is legacy; Metal is the durable path.
- This is a major engineering workstream, but **secondary** to AOT/no-emit.

### Practical Bot 2 sequencing
1. Do not start Metal rewrite before H3 host boot proof.
2. After S1 shell exists, choose:
   - **S2a:** window/clear/present proof with temporary path
   - **S2:** first real game renderer output
3. Prefer implementing a Metal backend behind the existing renderer module boundary rather than inventing a second engine.

### Transferable prior art
- HarkinianPad/libultraship already has a Metal path for a different stack; useful as process inspiration only, not code transplant assumptions for OpenGOAL buckets.

## 2. Audio

- Game side uses Naughty Dog-era `989snd` under `game/sound`.
- Host output currently desktop-shaped; iOS should use SDL audio + AVAudioSession behaviors first.
- Lifecycle must pause/resume with app backgrounding.

No evidence that audio requires executable-memory tricks.

## 3. Input

### Current
- SDL3 HID stack (`game/system/hid`): display manager, input manager, keyboard/mouse/controller devices.
- Desktop assumptions (mouse look patterns, keyboard) are present.

### iOS needs
- Touch overlay controlling the same logical buttons/axes the game already understands.
- Optional physical controllers via GameController/SDL.
- iPad pointer/keyboard as enhancement.
- Info.plist: `UIApplicationSupportsIndirectInputEvents` if real mouse events are desired (SDL iOS readme).

### Design rule
Keep GOAL control semantics; normalize platform events in C++ only.

## 4. Files / onboarding

Upstream docs/FAQ:

- user must supply legitimate ISO
- extractor + `gk` flow on desktop
- all retail PS2 versions of Jak 1 supported; no PS3/4/5 support planned

iOS should **not** try to be a full desktop extractor first.
Preferred elegant path:

1. macOS host tool: legal ISO → verified asset package
2. iOS app: import package via Files/document picker into Documents
3. validate manifest, then boot

## 5. Lifecycle

SDL iOS explicitly surfaces background events. OpenGOAL has multiple threads (EE, IOP/overlord, graphics, audio). Bot 2 needs one coordinated pause seam, not only “stop drawing.”

## 6. Sources
- `game/graphics/**`
- OpenGOAL docs: `porting-info/graphics`, `drawable_and_tfrag`
- `ref/sdl3-ios/README-ios.md`
- OpenGOAL FAQ/installation pages
