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

The follow-up signed iPad replay added page-directory/page-segment state. The
initial capture reported a 1,610-entry directory, resident page-2 length 55,
and a second destination set caused by duplicate `ART.CGO` loading. The iPad
boot now registers the native `engine`/`art`/`common` package markers after
direct GAME.CGO linking; a fresh replay reports only the original
`601152/632576/633664` relocation and no ART.CGO load. The raw post-Start
lookup order still differs from the Mac window, so source/resource parity
remains open. See `docs/evidence/R1/r1-page-directory-state-2026-08-21.md`;
do not remap TBP.

## Phase-aligned correction

The post-Start comparison is now aligned. The macOS and iPad windows both
begin `54,49,48,42,44`, and the same-route raw particle/TEX0 pairs match for
the captured families, including raw `0x00200f00` →
`0x2004c8e55530a5d2`. The iPad page-2 object has one stable relocation set
after the package-ledger fix. The earlier apparent lookup divergence came
from including pre-Start/title-stream records in one sequence; it is not a
current page-directory or texture-object mismatch.

R1 remains open at the producer phase/DMA and native composition boundary:
the iPad source capture and visible frame still do not match the macOS phase,
and the Simulator is corrupted/non-audible. See
`docs/evidence/R1/r1-phase-aligned-raw-parity-2026-08-21.md`.

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

## 2026-08-21 phase-owner follow-up

The fresh signed replay required by the next experiment was completed with
the particle-AdGif trigger armed at title-wait. The aligned page-2 producer
pairs included `0x00203500 -> 0x2004d0e59930a506`,
`0x00200400 -> 0x2004cfe55530a518`, and
`0x00201200 -> 0x2004d0e59930a506`; the native world boundary consumed the
same TEX0 and all sampled lookups were resident hits.

The phase-window capture saw bucket 66 empty and bucket 67 world-only on the
fresh route. A prior same-checkout phase window captured bucket 67's alternate
3D prefix (`MSCAL=211`, 48 sprites at `0x24d2`, then 16 at `0x2525`) before
world `0x25d2`; the macOS oracle begins at `0x24f2`. This makes the remaining
R1 defect a chain/timing-dependent producer/DMA phase owner, not a page-
directory residency or stable TBP mapping defect. The diagnostic phase ledger
now records AdGif TEX0 and first-vector data. No TBP, camera, shader, or Metal
policy change was made.

Fresh evidence is tracked in
`docs/evidence/R1/r1-phase-window-tex0-ledger-2026-08-21.md`. The screenshot
remains corrupted/partial, audio remains `pcm-peak=0`, and playability,
iPhone, and physical-device gates remain open.

## Bucket-67 ownership follow-up

The next source-side fix exports the frame/matrix setup from the bucket-66
Sprite3 walk and performs a bounded bucket-67 Sprite3 pass with inherited
setup. This addresses the proven DMA ownership seam while keeping MSCAL=211
diagnostic-only. A fresh signed replay reached Village1 twice and consumed 64
bucket-67 Sprite3 records with inherited frame/matrix/HUD setup. The frame
remains corrupted/partial; this is not playability proof. See
`docs/evidence/R1/r1-native-composition-consumer-boundary-2026-08-21.md`.
