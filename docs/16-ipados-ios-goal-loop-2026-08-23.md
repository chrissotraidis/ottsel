# Ottsel iPadOS/iOS goal loop — post-macOS queue

This is the next goal-based loop after the macOS playability gate closes. It
does not authorize mobile work while the macOS gate is open.

## Gate M0 — macOS handoff

Pass only with a fresh cold start, coherent title/New Game/Village1/Training
frames, native mouse+keyboard release-neutral evidence, lifecycle recovery,
bounded soak, physical or explicitly documented audio route, and human audible
confirmation. Retain the executable hash, raw log, input/lifecycle transcript,
screenshots, fault scan, and package identity.

## Gate I0 — one iPad Simulator bootstrap

1. Shut down the macOS runtime; boot exactly one iPad Simulator.
2. Build the signed no-emit app from the canonical `h3-jak1-host-boot.patch`
   plus the current maintained outer patches.
3. Validate that no ROM, ISO, extracted game data, runtime executable pages,
   `MAP_JIT`, or dynamic trampoline enters the product bundle.
4. Launch a fresh user-data container and retain app identity, signing,
   device UDID, build hash, and raw logs.

Exit only when title and menu render coherently and the app accepts a real
`title-wait → Start → Cross → Down×4 → Cross` replay. A blank, rotated, or
partial frame remains non-playable.

## Gate I1 — macOS/iPad source parity

At the same validated phase, compare page/index texture lookup order, raw
particle IDs, AdGif TEX0, native `first-tex0`/TBP, and GOAL Sprite3 source.
If lookup diverges, trace page-directory/FR3/DGO ordering. If lookup matches,
trace texture-object/data-family state, DMA ownership, and the first native
consumer divergence. Do not change TBP, camera, shader, or Metal policy without
a falsifiable source-side result.

## Gate I2 — native visual composition

Implement one native Direct/Sprite/material bucket at a time against the
macOS reference. Each slice needs a focused fixture/regression, a fresh iPad
frame, a same-phase macOS frame, and a fault/audio/lifecycle scan. Do not call
the Simulator playable until Jak, title/menu, and the active scene compose
coherently and accept input.

## Gate I3 — mobile input/audio/lifecycle

Prove touch-to-pad state, visible touch controls, cancellation, controller
disconnect/reconnect, background/resume, neutral recovery, audio route and
nonzero callback telemetry. Keep one Simulator and one runtime; never run
macOS `gk` concurrently.

## Gate P1 — iPhone parity

Repeat the accepted iPad route on one iPhone Simulator profile, then compare
orientation, safe areas, touch layout, audio, lifecycle, and performance. Any
device-specific divergence gets a focused regression before a renderer change.

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
