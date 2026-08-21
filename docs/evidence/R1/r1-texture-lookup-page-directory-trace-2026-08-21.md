# R1 texture lookup/page-directory trace — 2026-08-21

## Verdict

OPEN. This is a producer-side diagnostic slice, not a renderer fix and not a
playability result. It records the raw page/index lookup sequence on macOS so
the next iPad build can be compared at the same source boundary.

## Why this slice exists

The preceding AdGif/TEX0 evidence proved that the native consumer uses the
producer's TEX0 words without a native TBP remap. It did not identify why the
same apparent Sprite3 phase selects different source resources on macOS and
iPad. The earlier `first-prims3-reg=20` field is not a logical texture ID:
`adgif-shader.texture-id` aliases `prims[3]`, and `particle-setup-adgif`
overwrites that slot with the GS TEX1 register ID `0x14`. The source logical
ID must therefore be traced before that overwrite.

## Change

`goal_src/jak1/engine/gfx/texture/texture.gc` now retains the resolved texture
from `lookup-texture-by-id` and emits at most 128 page-2 lookup records. It
does not change lookup behavior, allocation, texture contents, or rendering.
The canonical maintained-source patch is
`patches/r1-texture-lookup-trace.patch`.

## Evidence

- GOAL `(mi)` completed all 546 targets after the source edit; log:
  `/tmp/ottsel-mi-texture-lookup.log`.
- The patch reverse-applies cleanly to the current maintained upstream tree.
- A completed iOS build with the earlier producer trace passed strict deep
  codesign and had executable SHA-256
  `05e1554bef9824d40a09e2e9a41dba56d76f40d6b45c785a959d7f425c677033`.
  The later iOS rebuild intended to include this lookup trace was stopped at
  the user's request; no iPad lookup-trace capture exists yet.
- The completed macOS native arm64 run recorded page 2 hits including indices
  `18`, `15`, `30`, `0`, `28`, and `3` (hex indices `0x12`, `0xf`, `0x1e`,
  `0x0`, `0x1c`, and `0x3`). The stable matching 3D phase's downstream AdGif
  TEX0 had TBP `0x24f2`.
- The trace prints `dest=0` on the host. That field is not authoritative for
  this investigation; use raw particle ID, AdGif TEX0, and the native
  `first-tex0`/TBP boundary for resource identity.

## Next falsifiable experiment

Build the signed iPad app from this exact source, replay one fresh validated
pack through title-wait → Start → Cross → Down×4 → Cross, and capture:

1. `OTTSEL TEX LOOKUP` page/index hit sequence;
2. the first current-boot `MSCAL=211` Sprite3 records;
3. raw particle ID → AdGif TEX0 and native `first-tex0`/TBP on the same chain.

If the raw lookup sequence differs from macOS, inspect page-directory login,
FR3/DGO texture ordering, and `texture-page-default-allocate`/VRAM allocation
state. If it matches, inspect the texture object fields and downstream data
family with reliable raw output. Do not remap TBP, camera, shader, or Metal
state before this source-side comparison.

## Boundaries

The Simulator is known to be blank or partially corrupted in current runs;
the simulator is not evidence of a playable product. iPhone parity, physical
device signing/acceptance, audio audibility/route/interruption proof, and
touch/controller lifecycle proof remain open independent gates.
