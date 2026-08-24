# Ottsel iPadOS/iOS goal loop — active mobile queue

The current macOS build is the accepted behavioral reference. iPadOS is now
the active product gate. `docs/BOT36_PROMPT.md` is authoritative.

## Gate M0 — accepted macOS reference

Use the current macOS build as the scene, input responsiveness, and fluidity
reference. Do not reopen macOS as a platform-order blocker unless a shared
regression is proven.

## Gate I0 — one visible iPad Simulator bootstrap

1. Boot exactly one iPad Simulator and visibly open the Simulator app.
2. Build the signed no-emit app from the canonical `h3-jak1-host-boot.patch`
   plus the current maintained outer patches.
3. Validate that no ROM, ISO, extracted game data, runtime executable pages,
   `MAP_JIT`, or dynamic trampoline enters the product bundle.
4. Launch a fresh user-data container and retain app identity, signing,
   device UDID, build hash, and raw logs.

Exit only when title and menu render coherently and the app accepts a real
`title-wait → Start → Cross → Down×4 → Cross` replay. A blank, rotated,
duplicated, partial, or debug-control frame remains non-playable.

## Gate I1 — stable and fluid scene parity

Close native TFRAG, TIE, MERC/Jak, Sprite3, Direct/HUD, material, depth, and
composition defects one at a time against macOS. Require focused regressions,
fresh inspected frames, frame-pacing evidence, and a bounded gameplay route.

## Gate I2 — audio and lifecycle

Require nonzero game PCM, audible route acceptance, interruption handling,
background/foreground recovery, neutral input after cancellation/disconnect,
save persistence, and termination/relaunch.

## Gate I3 — DualShock 2 touch/controller frontend

Use `ref/sunpad` as the menu, interaction, persistence, and diagnostics
reference, then design an Ottsel-specific PS2 layout. Require both sticks,
D-pad, four face buttons, L1/L2/R1/R2, L3/R3, Start, Select, multitouch,
pressed/neutral feedback, editable normalized layouts, controller handoff,
and separate iPad/iPhone defaults. The persistent three-dot frontend owns
Gameplay, Controls, Video, Audio, Data & Saves, and Diagnostics settings.
Capture three visual directions before implementation and validate the chosen
one live with accessibility labels and lifecycle tests.

## Gate P1 — iPhone parity

Repeat the accepted iPad route on one iPhone Simulator profile, then rework the
control layout for phone reachability and compare scene, safe areas, audio,
lifecycle, persistence, and performance.

## Gate D1 — physical-device readiness

Verify signing/provisioning, legal user-data import, save persistence, install,
launch, input, audio, interruption, background/resume, and termination/relaunch
on a physical iPad and iPhone. Do not claim release readiness from Simulator
evidence alone.

## Operating loop

For each experiment record: current evidence, one falsifiable question, the
smallest change, the before-failing regression, the exact route, and the exit
bar. Keep evidence concise, preserve ROM safety, and stop at the first failed
gate instead of switching platforms as a workaround.
