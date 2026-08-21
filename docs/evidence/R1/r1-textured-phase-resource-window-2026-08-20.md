# R1 textured phase/resource window — 2026-08-20

## Gate

Capture the current mobile 66→68 product interval after the background route
has actually entered its producer path, then compare the first textured tuple
with the macOS Sprite3 world dispatch.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed app executable SHA-256:
  `f224fcacc6615e588f9e178e5e776ccef4cd058df222f1d1943a245b9f640a99`.
- One iPad Pro 11-inch (M4) Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`; PID `24214`.

## Live proof

After the current process logged `(bg 'village1)`, the product interval at
`chain=1996 / vsync=1997` emitted:

```text
group=1 phase=world count=48 tbp=0x2bc1 psm=19 tw=6 th=6
group=2 phase=world count=16 tbp=0x0 psm=0 tw=0 th=0
RAW SPAN transfers=23 headers=2 rejected=0 boundary-stops=0
PHASE groups=2 sprites=64 world=64 hud=0 3d=0 other=0
```

The split window agreed: bucket 66 was setup-only and bucket 67→68 contained
the same two groups. The level-status sampler was still `loading`, so this is
not a final Village1 frame. The fault log was 0 bytes.

## Comparison and verdict

The first textured mobile tuple is `0x2bc1`/64×64, while the same-route macOS
world oracle begins at `0x24f2`/64×64 and dispatches 55 sprites in its first
accepted group. The mobile tuple mismatch persists before native clip/image
comparison; no texture remap, camera change, or shader relaxation is justified.

OPEN. This closes another timing/trigger ambiguity but not R1 parity or
playability. The next slice is producer/resource ownership for the textured
`0x2bc1` group while retaining the current 66→68 boundary.
