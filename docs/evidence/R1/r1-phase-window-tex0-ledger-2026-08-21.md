# R1 phase-window TEX0 ledger — 2026-08-21

## Gate

Capture the first Sprite3 phase owner and correlate its phase, TBP, AdGif TEX0,
texture address, and first vector without changing TBP, camera, shader, or
Metal policy.

## Fresh rebuilt replay

- Signed executable SHA-256: `2b162c85701ca99afb4d3607a064e3b04c9e64e9fa7c30839eaff183600210b4`.
- Simulator: one iPad Pro 11-inch (M4), UDID
  `08636791-2675-4675-8335-EF72EF954DCF`; runtime stopped after capture.
- Route: fresh title-wait → Start → Cross → Down×4 → Cross.
- Route result: `GAMEPLAY: enter village1` appeared twice.
- Runtime log: `/tmp/ottsel-r1-phase-tex0-runtime.log`.
- Screenshot: `/tmp/ottsel-r1-phase-tex0-route.png`, SHA-256
  `b0e51cab700270fcb5c68a201208de684334e9bc58bb21f7a2bd5191d32704eb`.
- Fault log: `/tmp/ottsel-r1-phase-tex0-fault.log`, 0 bytes.
- Audio: mixed frames remained `pcm-peak=0`.

The fresh phase-window trigger saw bucket 66 empty and bucket 67 world-only:
11 groups / 512 sprites, all world, first item TBP `0x25d2`, AdGif TEX0
`0x2004c8e55530a5d2`, and `tex0-addr=0x6`. The same route's source-boundary
window recorded world first TEX0 `0x2004c8e55530a5d2` and the preceding lookup
tail was `54,49,48,42,44`; the post-transition tail continued
`24,25,10,41,30,34,9`, all resident hits.

## Phase variability result

A prior same-checkout phase-window capture on chain 4965 (before this ledger
field extension) saw bucket 66 empty but bucket 67 begin with a 3D prefix:

```text
group 1: phase=3d count=48 tbp=0x24d2 psm=19 tw=6 th=6
group 2: phase=3d count=16 tbp=0x2525 psm=19 tw=5 th=5
group 3+: phase=world count=48 tbp=0x25d2 ...
```

The completed macOS oracle begins with `MSCAL=211` at TBP `0x24f2`, followed
by a second 3D group and then `MSCAL=3`. The two iPad captures therefore show
that phase ownership is chain/timing-dependent: the same mobile bucket can
present a 3D prefix or a world-only prefix. This is producer/DMA phase evidence,
not justification for remapping TBP or altering camera/shader/depth policy.

The diagnostic ledger now records phase-item AdGif TEX0, `tex0_addr`, and the
first vector alongside TBP/PSM/size. Raw particle-ID correlation remains a
separate producer trace and must be aligned to the same chain before a source
fix is selected.

## Fresh particle-ID correlation

A second fresh signed install armed the existing GOAL-side particle-AdGif
trace at the title-wait marker before replaying the same route. The runtime
captured the following page-2 producer pairs in the current world-only window:

```text
raw=0x00203500 index=0x35 -> TEX0=0x2004d0e59930a506
raw=0x00200400 index=0x04 -> TEX0=0x2004cfe55530a518
raw=0x00201200 index=0x12 -> TEX0=0x2004d0e59930a506
raw=0x00203000 index=0x30 -> TEX0=0x2004cbe59930a52e
raw=0x00203100 index=0x31 -> TEX0=0x2004cc651130a52d
```

The first pair matches the same route's native world source item TEX0 and
world TBP `0x25d2`; all sampled page-2 lookups were resident hits. The fresh
particle/runtime evidence is `/tmp/ottsel-r1-particle-phase-runtime.log`,
with screenshot `/tmp/ottsel-r1-particle-phase-route.png` (SHA-256
`da17573fd3e499fad6d58e33986853eb8cc5faac159ff0d5ccd77c861de72dac`) and
zero-byte fault log `/tmp/ottsel-r1-particle-phase-fault.log`. Audio remains
`pcm-peak=0`.

This does not identify the missing 3D owner: the same current phase window had
no 3D prefix, while the prior chain-4965 window did. It does prove that the
world TEX0 consumed by the native boundary is the producer's AdGif TEX0 in the
fresh run. No TBP remap or renderer policy change is justified.

## Verdict

OPEN. The native frame remains visibly corrupted/partial and non-playable; the
Simulator blank/partial-screen warning remains explicit. Direct/3D/material
composition, audio/lifecycle, iPhone parity, and physical-device gates remain
open.
