# R1 fresh macOS phase window — 2026-08-21

## Gate

R1 same-transition Sprite3 phase sequence and source-item ownership.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Rebuilt native macOS `game/gk`; focused `Sprite3Native.*` passed 14/14.
- One Windowed macOS runtime, `-boot -fakeiso -nosound`; no Simulator
  concurrent.
- Fresh log: `out/jak-project/log/jak1.2026-08-21T02-37-02.log`.

## Change

Used a timestamped current-log selector and the bounded desktop group ledger:
world group ordinal, DMA chunk start, sprite count, MSCAL, first TBP/TEX0,
dimensions, decoded texture hash, and draw buckets. The trace trigger was
armed only after two fresh Village1 display markers.

## Live proof

The fresh log recorded two Village1 markers and three Sprite3 frames. Every
frame had the same producer group sequence:

```text
world group=0 count=48 mscal=3 chunk-start=0xce9a90 or 0x51ba50
first-tbp=9478 (0x2506) tex0=0x2004d0e59930a506 size=64x64
world group=1 count=16 first-tbp=0
```

The group-0 texture decoded as
`rgba-hash=0xc8679915dfac0e15`, alpha max 128, 2,615 nonzero-alpha texels
(the log reports 1,481 transparent texels in 64x64). The draw sequence then
contained 9478, 9496, 9682, and color-only TBP 0 buckets. No `0x24f2` draw
appeared in this fresh synchronized phase window. The runtime log contained
no crash, signal, or renderer assertion; normal `assert` object/code-map
names are startup link data, not failures.

## Verdict

OPEN. This capture confirms the mobile `0x2bc1` content-matching desktop
`0x2506` group is a stable producer phase, while the previously accepted
desktop `0x24f2` world group is not emitted in the same immediate window.
The open defect is phase/transition selection or a later producer handoff;
there is no evidence for a texture remap or native consumer policy change.

## Next gate

Extend only the desktop trace trigger window or arm a second bounded trace
after the first three frames, then capture the first transition from the
`0x2506` group family to `0x24f2`. Align its DMA chunk/group ordinal with the
mobile 66->68 bucket walk before considering a shared producer fix.
