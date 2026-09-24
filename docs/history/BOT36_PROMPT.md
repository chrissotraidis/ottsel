# BOT36 — iPadOS stability, PS2 touch frontend, then iPhone parity

This is the active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`.
The current macOS build is the accepted behavioral and visual reference.

## Product goal

Deliver an honestly playable native Jak 1 build on iPadOS with the same
coherent scene, responsive input, audio, stability, and fluidity as macOS.
After the game route is stable, deliver a purpose-built DualShock 2 touch and
controller frontend, then prove iPhone parity and physical-device readiness.
Keep the app ROM-safe, signed-native, and free of runtime executable-code
generation, `MAP_JIT`, or dynamic trampolines.

## Platform order

1. iPadOS scene correctness, stability, audio, lifecycle, and fluidity.
2. iPadOS PS2 touch/controller frontend and three-dot menu.
3. iPhone layout, performance, input, audio, and lifecycle parity.
4. Physical iPad/iPhone signing, installation, and hands-on acceptance.

Use one visible Simulator and one runtime. Do not call a build playable from a
link, launch, log, first frame, partial scene, or colored debug controls.

## Active gate I0 — visible iPad runtime

- Build, sign, install, and visibly launch Ottsel in the Simulator app.
- Retain a fresh screenshot and inspect it directly.
- Treat stretched, duplicated, missing, rotated, or debug-only composition as
  a failure even when the process remains alive.
- Preserve the validated user-data boundary and keep game data out of Git.

Current failure: Village1 is partial; the CPU fallback duplicates content,
TIE materially worsens the scene, Jak is not accepted in-frame, touch controls
are debug rectangles, and audio telemetry remains `pcm-peak=0`.

## Paused checkpoint — 2026-08-24

- The build and Simulator are intentionally stopped; resume from one freshly
  booted iPad Simulator and one runtime.
- Sequence A now advances with the no-IOP stream clock. If the unavailable
  intro masters make Sequence B impossible, the game records that boundary
  and enters normal play instead of hanging in the cutscene.
- Sprite3 scene data now crosses the Metal boundary through an owned snapshot,
  removing the prior resource-lifetime race.
- The DMA consumer keeps the expensive VIF/GIF decode budget at 512 transfers
  and performs only a cheap PC_PORT camera/actor tail scan up to 4096. The
  focused platform-input/scene-policy suite passes 13/13 and the signed app
  build completes.
- Runtime acceptance of that final two-tier DMA change was not run before the
  pause. The earlier full 4096-transfer decode improved visible world content
  but broke frame pacing and input delivery, so it was not retained.
- I0/I1/I2 remain OPEN: the last accepted frame was still malformed, Jak was
  not proven live in normal play, and game PCM remained zero. Do not promote
  the build from compile/tests alone.

## Gate I1 — stable and fluid game scene

Fix one falsifiable native family at a time against the macOS reference:
TFRAG, TIE, MERC/Jak, Sprite3, Direct/HUD, materials, depth, and composition.
Every change requires a focused regression, a fresh visible iPad frame, a
fault scan, and a bounded active route. Measure frame pacing and input latency;
the exit bar is coherent title → New Game → Village1 → Training gameplay with
Jak visible, stable camera motion, no corruption, and sustained fluid output.

## Gate I2 — audio and lifecycle

Require nonzero game PCM, audible route acceptance, interruption handling,
background/foreground recovery, neutral input on focus loss or disconnect,
save persistence, and termination/relaunch. A live process or opened audio
device alone is not a pass.

## Gate I3 — excellent DualShock 2 frontend

Use `ref/sunpad` as an interaction, menu, persistence, diagnostics, and logging
reference. Do not copy its GameCube layout verbatim. Design for Jak 1 and the
full PS2 schema:

- left: movement stick, D-pad, L1/L2 within one-thumb reach;
- right: camera stick, Triangle/Circle/Cross/Square diamond, R1/R2;
- compact Start, Select, L3, R3, and a persistent safe-area-aware ellipsis;
- multitouch movement + camera + action + shoulder combinations;
- clear pressed, held, neutral, and analog-stick feedback with restrained
  haptics and legible PS2 labels/icons;
- separate iPad and iPhone defaults, normalized saved positions, global and
  per-control size, opacity, move/edit mode, reset, and safe-area clamping;
- physical-controller handoff, stable player ownership, disconnect release,
  resume reconciliation, and an explicit show/hide-touch preference.

The three-dot frontend must provide Gameplay, Controls, Video, Audio, Data &
Saves, and Diagnostics sections. Include render scale/upscaling, aspect ratio,
mute/volume, controller mapping, touch editing, reset, FPS/frame pacing, and a
privacy-bounded diagnostic export. Logs must be low-frequency, rate-limited,
redacted, retained across the previous session, and useful for renderer,
audio, input, lifecycle, and crash attribution.

Before implementing the new visual system, capture SunPad's supplied visual
references and menu contract, create three Ottsel-specific visual directions,
and select one target. The frontend passes only through live Simulator use,
multitouch/control-state tests, accessibility labels, and lifecycle recovery.

## Gate P1 — iPhone parity

Run the accepted iPad route on one iPhone Simulator after shutting down the
iPad Simulator. Rework—not merely shrink—the layout for phone reachability and
safe areas. Match scene correctness, controls, audio, lifecycle, persistence,
and frame pacing before advancing.

## Operating loop

For each experiment: state current evidence, ask one falsifiable question,
make the smallest change, add the before-failing regression, run one visible
route, inspect the screen, and record PASS or OPEN honestly. Keep large logs
and recordings in `/tmp`, preserve all user-owned dirty work, never use
`git add -A`, and keep evidence concise.
