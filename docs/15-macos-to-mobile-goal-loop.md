# Ottsel cross-platform playable loop

## Product goal

Make Jak 1 playable as one product on macOS, iPadOS, and iOS. macOS is the
first live verification gate and the behavioral/rendering reference. A mobile
runtime pass begins only after the current macOS replay is visibly playable;
shared source seams may be prepared in the meantime, but they must not replace
that gate. Each platform must ultimately share one game-pad contract:
left/right sticks, canonical DualShock button bits, pressure where the game
consumes it, and a guaranteed neutral state on disconnect, background, and
resume.

The current macOS runtime is the reference for title-to-Training, scene
rendering, controller support, keyboard/mouse support, and streamed timing.
Audio may stay disabled during a narrow visual/input experiment, but audible
output is a product gate on every shipping platform. It must be output-only;
never accept a microphone permission as a workaround.

## Operating discipline

1. Run exactly one game runtime at a time. Close macOS `gk` before booting an
   iPad/iPhone Simulator, and close the Simulator app before returning to Mac.
   Launch the mobile app only with `simctl launch`/the Simulator host; never
   target the Simulator binary directly with desktop automation. A direct
   launch fails in dyld before Ottsel starts (`DYLD_ROOT_PATH not set`).
2. Preserve user data, extracted assets, saves, build output, IPAs, and signing
   material as local/ignored inputs.
3. Start every compatibility change with a focused probe or regression. Fix
   the smallest verified producer/consumer boundary; do not hide an ABI,
   compiler, renderer, or lifecycle fault in Jak GOAL code.
4. A build, log, texture upload, or title screen is not a platform pass. Each
   pass needs live interaction, a current captured frame, fault scan, and a
   neutral-input check.
5. After any GOAL change, rebuild all affected payloads before testing. After
   maintained-source changes, refresh the patch and clean/reverse-apply check.
6. Three repeated runs with the same root blocker require a dated evidence
   stop report; then move to another independent gate rather than spin boots.

## Gate P0 — shared input contract

**Status: in progress.** The 2026-08-18 fresh macOS replay reached Training
through the retail title/New Game/A/B/C/D1/D2 path, with visible world
rendering and output-only audio. In Training, W produced a forward pad sample
then neutral; Space produced Cross with pressure 255 then neutral; E produced
Circle then neutral. The in-game Input Options UI also enabled Mouse, Track
Camera, and Player Movement. A real mouse gesture produced a non-neutral right
stick `(0,255)` and visibly rotated the Training camera. A connected-controller
movement/action replay and the two-button mouse-forward gesture remain open;
this host reports no active game controller.

Use the exact `PadData`/`scePadRead` representation everywhere. Desktop SDL
input remains authoritative: controller South/East/West/North maps to
Cross/Circle/Square/Triangle; Return/Space/E/F/R and WASD are the matching
keyboard path; configured mouse behavior remains a desktop feature. Mobile
hosts feed the same button bits, axes, and pressure snapshot directly when no
desktop `Display` exists.

Exit evidence:

- Mac: physical keyboard movement/action and controller movement/action are
  observed in Training; mouse camera/action behavior is separately observed
  when enabled.
- iPadOS/iOS: external keyboard and Game Controller generate the same sampled
  button/axis values, then clear to neutral across background/foreground.
- The mobile touch layer is visible and customizable before it is called
  playable; a temporary touch-to-pad adapter only establishes the runtime seam.

## Gate P1 — macOS reference stays healthy

For every shared-runtime or mobile change, rebuild and replay the canonical
Mac path: title → New Game → A/B/C/D1/D2 → Training. Require a current frame,
movement, Cross and Circle actions, and no crash. Streaming warnings must be
correlated with an actual blocked transition before they are treated as a
failure. In the current replay, the two-frame `loader stall on art` warnings
for `sage-intro-sequence-a` and `sage-intro-sequence-d1` each resolved into
their spool start in the same timestamp and the run reached Training; retain
them as normal pending-to-active stream synchronization, not a loader defect.
A five-minute active Training soak after the input configuration retained one
live `gk`, nonzero PCM health samples, and no crash/error records. Keep that
soak as a periodic regression.

Mac audio is not an external-host exemption. The application must create an
output-only stream without requesting microphone access and prove audible game
audio through the selected output. Use `-nosound` only while isolating another
gate; return to this audio implementation gate after each such experiment.

**Current audio evidence (2026-08-18): passed startup/mix; route soak remains
open.** The first output-only route used the system default, which is the
virtual Jump Desktop Audio device and exposes input channels. The repaired SDL
path now honors `OTTSEL_AUDIO_OUTPUT_DEVICE`; the normal launcher selects
`MacBook Air Speakers` instead. It also marks the SDL CoreAudio backend
playback-only before initialization, so it neither discovers input endpoints
nor installs the default-recording-device listener. This eliminates the TCC
trigger from virtual input-capable devices instead of accepting microphone
access. A fresh default app restart reached the game window without a
microphone sheet, logged the named playback device, started SDL callbacks,
advanced the real VAG clock, and reported nonzero mixed PCM peaks during title
audio. The stream is intentionally process-scoped across in-process game
resets; failed opens clear their opening state and retry after a bounded delay.

Keep explicit `-nosound` as a diagnostic fallback only. Do not add an input
device, accept microphone permission, or replace the named-speaker selection
with the virtual default route. The remaining audio work is longer gameplay
and route/interruption coverage, not basic output startup.

## Gate P2 — iPadOS platform layer

Build the no-emit ARM64 app from local user data and preserve the signed native
`__TEXT`/no-runtime-code-generation requirement. Bring forward the proven
desktop architecture: real streaming/timing, bucket renderer semantics, and
the shared pad contract. Do not make the old VU/software-rasterizer diagnostic
shell the product renderer.

### Active P2 renderer loop — port the PC bucket contract, not the diagnostic VU path

The iPad run on 2026-08-18 corrected the renderer diagnosis. It loaded
`village1-vis`, both level slots became active, and background work contained
one TFRAG plus three TIE trees. The normal TIE VU/DMA producer did not run
because the desktop port intentionally comments out those calls in
`engine/gfx/tie/tie-methods.gc`: the desktop C++ bucket renderer draws normal
TIE directly. The iOS shell therefore cannot become playable by guessing VIF
headers or routing every `MSCAL` through TFRAG microcode.

The next loop is deliberately product-shaped:

1. **Passed, narrow proof:** the iPad shell now loads the same compressed FR3
   level data, consumes a live PC-port camera packet, and submits the visible
   normal-TIE selection through Metal. The only observed transform incompatibility was the
   standard OpenGL `[-w,w]` versus Metal `[0,w]` clip-depth range; the shader
   remaps depth while preserving desktop x/y/w. The same tree now uses its
   actual per-draw level textures and live time-of-day palette; see
   `docs/evidence/I1/i1-tie-geometry-transform-2026-08-18.md` and
   `docs/evidence/I1/i1-tie-texture-color-2026-08-18.md`.
2. Complete the remaining normal-TIE material contract: per-draw fog enable,
   alpha/blend/decal settings, and dynamic visibility updates as the camera
   moves. Keep the same FR3 and PC-port seam; do not copy screenshots,
   decode arbitrary DMA as geometry, or retain the VU/software rasterizer as
   the mobile renderer.
3. Instrument the macOS renderer and the new mobile seam with matching,
   bounded per-frame counters: active level, TFRAG/TIE/Merc bucket submissions,
   cull counts, texture misses, and final draw count. Capture the same title
   and Village1 phase on both platforms before implementing a bucket.
4. Implement one scene-bearing bucket at a time from the macOS reference:
   TIE first (the verified Village1 work-list geometry), then opaque TFRAG,
   then trans/dirt/ice TFRAG, Merc, and sprites/direct effects. Each bucket
   needs a focused fixture or deterministic captured input before it is
   enabled in the live app.
5. After every bucket, launch one iPad Simulator only, capture the screen,
   require finite transforms and nonzero submission evidence, then replay the
   macOS title-to-Training reference before moving on. A nonempty GIF packet,
   a texture page, or a black frame with a loading indicator is not a pass.
6. When iPad reaches a repeatable visible title and Village1 frame through
   this seam, run the shared keyboard/controller and neutral-lifecycle tests.
   Only then repeat at iPhone size; touch, audio route/interruption behavior,
   physical-device acceptance, and shipping performance remain separate gates.

The old VU/software path may remain a bounded diagnostic oracle while it
helps decode a specific stream. It must not control product-frame acceptance
or become a substitute for the PC renderer.

### Current visual truth — 2026-08-18

A fresh signed iPad run received live fog colors `(41,128,200)`,
`(159,150,200)`, and `(128,179,242)`, then displayed Village1 with a
119-batch normal-TIE submission (252,888 triangles). A follow-up run added
one visible opaque-TFRAG tree (77 batches / 53,304 triangles), revealing the
Village1 hill, tower, and foreground terrain. The captured frame is still
mostly black above that geometry. This is not a scene-composition pass:
Direct/Sprite sky and effects, transparent/dirt/ice TFRAG, and remaining
normal-TIE material semantics have not been ported. The next implementation
gate is therefore Direct/Sprite from the same live bucket stream, followed by
a same-phase macOS/iPad frame comparison; fog and opaque-TFRAG are retained
as verified data/render boundaries, not promoted as the visual fix.

The first exit bar is a live iPad Simulator frame from the game renderer plus
keyboard/controller state and a neutral lifecycle test. The next bar is the
Mac-equivalent title-to-Village1 path. Audio, touch overlay, and physical
device acceptance remain distinct subsequent gates.

### Fullscreen composition checkpoint — 2026-08-18

**Verified renderer milestone; not a playability pass.** The signed iPad app
now declares both iPhone and iPad device families and landscape-only iPad
orientations. On the one iPad Pro M4 Simulator it changed from the old
480x320 iPhone-compatibility Metal drawable to a 1210x834 drawable and showed
a full-screen Village1 TFRAG/TIE frame. The stale Direct/GIF CPU frame is now
consumed once, rather than being re-presented forever, and shell log text is
suppressed while live background geometry is active. Evidence and the current
frame are recorded in `docs/evidence/I1/i1-fullscreen-composed-frame-2026-08-18.md`.

The visible scene still lacks a title-to-gameplay interaction proof, a touch
overlay, mobile controller hardware proof, transparent/effect buckets, audio,
and iPhone validation. Continue from this full-size composed frame; do not
promote it to P2 completion. The shared transport has now been live-checked:
a right-side touch and an external-keyboard Space press each delivered Cross
`0x4000` at pressure 255 then neutral, and background/resume emitted neutral
sticks/buttons before the frame returned. This is a seam/lifecycle proof, not
a visible touch-control or controller-acceptance result.

The live Direct/GIF discriminator rules out a shortcut through the generic
VU interpreter: 5,149 Direct transfers / 24,883 packed GIF tags yielded no
diagnostic primitives, and a one-shot retail generic-VU run at the observed
`MSCAL 46` capped at 50,000 instructions with zero GIF output. Treat Direct
as the next native Metal render-target/composition bucket; do not lift the VU
limit or route arbitrary MSCAL traffic through the TFRAG program.

### New Game script-link checkpoint — 2026-08-18

**Verified bootstrap repair; Sequence A is not yet a visual-playability pass.**
The fresh iPad New Game path reached `target-continue`, loaded Misty, and then
faulted at the EE base when it called `start-sequence-a`. The call shim and
return address were valid; the function symbol itself was zero. The packaged
app had copied the retail `VI1.DGO`, whose `sequence-a-village1` object is
PS2 v3 data (9,664 bytes, leading word `0x00000000`) and is correctly rejected
by the no-emit loader. The ARM64 build had already generated the matching
`out/jak1/iso/VI1.DGO`, whose same object is 61,635 bytes and begins with
`GOAL` magic.

`scripts/build-ios.sh` now excludes retail `VI1.DGO` with `TIT.DGO` and copies
both generated DGOs last. A fresh Simulator package hash matched the generated
VI1 payload. Through visible external-keyboard input, the repaired app then
completed title → New Game → overwrite confirmation → Village1, loaded Misty,
linked `sequence-a-village1`, and started `sage-intro-sequence-a` without an
`ottsel-fault.log` record. The short `loader stall on art sage-intro-sequence-a`
warnings resolved into a spool start, as they do on Mac. See
`docs/evidence/I1/i1-new-game-sequence-a-2026-08-18.md`.

The current iPad frame during this sequence still has missing/black composition
and an incomplete camera/Direct presentation. Keep the DGO packaging fix;
continue visual work through the explicit Direct/Sprite and remaining bucket
gates above. Do not restore the retail DGO or re-open ARM64 return-path work
unless a new fault contradicts the linked-symbol evidence.

### Direct/Sprite decision — 2026-08-18

A bounded live trace confirmed that the title/progress stream supplies real
14-qword packed GIF strips, but they target an offscreen GS rectangle
(`SCISSOR 0..127`, with positions around `2430,4040`). The desktop
`DirectRenderer` handles this through its explicit offscreen-target state.
The old iOS CPU raster diagnostic has no equivalent target/composition model:
it decoded thousands of strips but produced no foreground pixels. Do not add
more coordinate or scissor guesses to that diagnostic. The next renderer work
is a native Metal Direct pass with explicit GS FRAME/scissor/offscreen-target
state, then composition into the final Metal drawable. Its first proof is one
title/menu packet that produces a nonzero offscreen draw plus a visible
composed title frame; only then expand to the remaining Direct/Sprite stream.

## Gate P3 — iPhone parity

After the iPad integration produces a repeatable rendered and controllable
path, repeat it in an iPhone-sized Simulator. Treat compact layout, touch
ergonomics, performance, thermal behavior, route/interruption audio, signing,
and physical-device acceptance as separate evidence gates. Simulator success
does not establish physical-device acceptance.

## Iteration checklist

1. Record the platform, build identity, running PID/Simulator, and current
   phase from a fresh launch.
2. Capture the visible frame before input or code changes.
3. Make one probe/fix with a regression that fails before it.
4. Rebuild, run only that platform, and capture the exact new behavior.
5. Mark the gate verified, still-open, or blocked with evidence paths in
   `docs/13-current-state.md`; never promote a platform from inference.
