# R1 data-root and Sprite3 frame-setup reconciliation — 2026-08-21

## Gate

Explain the first ordered mobile resource divergence without guessing at Metal
camera or shader behavior.

## Live data-root proof

The valid fresh normal-Metal route logged:

```text
OTTSEL F1: imported validated user pack into .../Application Support/local.ottsel/OttselUserData
OTTSEL BOOT PHASE: selecting iOS data root
OTTSEL BOOT PHASE: selected iOS data root
OTTSEL F1: save root=.../Application Support/local.ottsel/OttselShell/OpenGOAL/jak1/saves
```

The pack was prepared before Metal and the route reached Village1 twice. This
rules out the bundle-versus-user-pack selection boundary as the first cause of
the Sprite3 resource mismatch. The Simulator fault log remained zero bytes.

## Frame/setup proof

The retained mobile Sprite3 parser reaches the expected frame/matrix setup
shape before the divergent groups:

```text
frame transfer=9 size=656 imm=0x3d4
matrix transfer=12 size=80 imm=0x384
header transfer=13 count=48
```

The same setup shape was already proven on the prepared route in
`r1-prepared-route-full-sprite-phase-mismatch-2026-08-20.md`. The current
shared-vsync aggregate then reports the first populated resources as mobile
3D `0x2b8d`/`0x2be0`, followed by world `0x2d7c`/`0x2d8c`/`0x2c8d`, while the
macOS Sprite3 dispatch starts with 3D TBP 9710 and world TBP `0x24f2`.

## Interpretation

The data root and frame/matrix transfer boundary are not the first observed
failure. The remaining mismatch is in the producer's phase/resource contents
after setup—likely the source stream, texture-page ownership, or phase state—
and remains unproven at the exact GOAL producer field. No TBP remap, camera
sign change, shader change, or consumer widening is justified.

## Verdict and next slice

OPEN. The next falsifiable experiment is a narrow producer-side trace at the
first post-setup Sprite3 group that records the source stream/phase state and
resource identity on mobile, then compares that field to the macOS
`Sprite3::handle_sprite_frame_setup`/first `flush_sprites` state. Keep the
validated data-root boundary and Direct isolation unchanged.
