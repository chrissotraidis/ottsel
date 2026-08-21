# M1 platform split and audio boundary — 2026-08-20

## Result

The macOS build is materially ahead of the iPadOS/iOS build, but the two
tracks have different open gates and must not be conflated. The running Mac
scene looks decent; stability and audible output remain bounded observations.
The Simulator is a blank, non-audible surface and supplies no visual or audio
acceptance evidence.

| Area | macOS reference | iPadOS/iOS product path |
|---|---|---|
| Renderer | Broad native OpenGL path renders the retail title-to-Village1 route. | Native Metal still needs complete bucket composition and title/gameplay parity; Direct and Sprite3 work is diagnostic and partial. |
| Route/input | Retail route reaches Training and accepts keyboard/mouse pad input. | Canonical input seams and touch regions exist, but a fresh post-Start state edge is not yet a reliable live boundary; iPhone parity is not started. |
| Audio | SDL selected MacBook Air Speakers, started the output device/callback, and logged nonzero title PCM. | Mobile audio, route/interruption behavior, and human-audible acceptance remain open. |
| Stability/device | One-minute fresh run stayed alive; the prior five-minute active soak is retained, but current confidence is still bounded. | Simulator host/drawable failures and blank output remain diagnostic boundaries; physical-device signing/performance proof is open. |

## Sound verdict

There is evidence that the macOS audio pipeline is alive: device selection,
SDL callback activity, and nonzero PCM were all logged, including a real
`ndi-intro` VAG path. There is not yet human-audible acceptance, speaker/route
interruption proof, or equivalent mobile audio proof. Therefore the answer is
“audio is partially wired and producing PCM on macOS,” not “sound is accepted
as working.”

## Live continuation

The next product dependency remains the iPad R1 renderer-composition boundary.
The canonical normal-Metal route now has the in-runtime `start edge in
title-wait` then `GAMEPLAY: enter village1` sequence, so route synchronization
is no longer the immediate blocker. Log-file ordering and stale writable
triggers remain invalid state synchronization. Sprite3 counts still need a
shared-vsync/chain ledger before producer parity can be inferred; the
trigger-gated probe is recorded in
`docs/evidence/R1/r1-frame-boundary-correlation-2026-08-20.md`.

## 2026-08-21 continuation note

A fresh one-runtime iPad Pro 11-inch (M4) Simulator attempt reached the
in-runtime `title-wait-ready` marker and then stalled before the Start edge:
the host-side `/tmp/ottsel-press-start` trigger was not consumed in this
attempt. No bucket-67 readback trigger was armed and no new image artifact was
created. This is a route-driver synchronization failure, not evidence that
the native upload probe regressed; the previously recorded `drawn=640`,
`candidates=640`, `fixture-uploaded=true` probe remains the latest renderer
boundary. The Simulator was shut down after the bounded attempt.

This reinforces the product split: macOS has a broad renderer and a bounded
retail route that looks decent, with device/callback/nonzero-PCM audio evidence;
iPadOS still has the earlier title-to-Village1 liveness and partial Metal
diagnostics, but remains blank and non-audible in the Simulator. Neither
platform has a human-audible acceptance result yet.

## Verdict

OPEN. macOS is a useful behavioral reference, not a substitute for iPadOS/iOS
composition, touch/lifecycle, mobile audio, iPhone parity, or physical-device
readiness. No playability, audible, iPhone, or device claim is made here.
