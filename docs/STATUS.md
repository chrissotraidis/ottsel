# STATUS — Ottsel

## Current self-audit — 2026-08-21

**Plain status:** macOS now has one fresh bounded stability increment, but it
is still not fully proven stable/playable. iPadOS remains unproven and
diagnostic-only. The authoritative product order is:

1. **macOS stable and visibly playable first.**
2. **iPadOS parity/playability second.**
3. **iPhone parity and physical-device readiness third.**

No iPad/iPhone renderer or resource-parity slice may become the active product
dependency until macOS has a fresh end-to-end stability pass: visible title,
menu/world progression, real input, audible output, neutral lifecycle/input,
and a fault-free soak. Until that pass exists, the active queue starts with an
honest macOS reproducibility/stability audit—not another Simulator trace.

This section is the canonical current board. The dated material below is
preserved evidence history; where it conflicts with this section, it is
historical and must not be used as a release or playability claim.

| Product stage | Audited status | What is actually proven | What still prevents completion |
|---|---|---|---|
| ARM64/no-emit foundation | **PASS** | OpenGOAL code runs from signed Mach-O `__TEXT` without runtime-created executable code; native host and Simulator boot evidence exists. | Nothing at this layer unless new contradictory evidence appears. |
| macOS stable reference | **PARTIAL PASS — ACTIVE QUEUE** | The fresh 2026-08-21 current-checkout run showed title → New Game → retail cinematics → Village1 → Training, real W movement, ten active interaction cycles, coherent post-soak play, and no matching fault. Keyboard-only and human-audible acceptance remain open. | Repeat cold-start reproducibility, retain raw audio evidence, obtain human audible-output acceptance, prove neutral background/resume lifecycle, and complete a longer controller/keyboard soak before calling macOS stable/playable. |
| iPadOS renderer + runtime | **PAUSED — DIAGNOSTIC ONLY** | Signed Simulator builds can boot, consume scripted input, reach Village1 markers, and emit partial/corrupted Metal output. R1 traces isolate producer/resource differences. | Blocked behind completion of all remaining macOS-stable-reference clauses. Even after unblocking, Direct/Sprite/material composition, visible touch/input/audio, lifecycle, and playable replay remain open. |
| iPhone parity | **PAUSED** | The app declares iPhone support. | Explicitly after iPadOS; then simulator parity and physical-device performance/signing acceptance. |
| Release / handoff | **BLOCKED** | Repository remains ROM-safe; current feature work is local on branch `codex/r1-macos-adgif-output-mapping-2026-08-21` at `b2e36fc`; `main`/`origin/main` remain `549508e`. | All platform playability, device, packaging, and legal user-data workflow gates. |

The current macOS product observation is positive but bounded: the title/world
scene looks decent in the running reference, while stability is not yet a
soak claim. A fresh one-minute audio-enabled run reached title and repeated
Village1 display phases without a retained crash/fault marker. SDL selected
`MacBook Air Speakers`, started output device 37, observed its callback, and
logged real title-intro PCM (`pcm-peak=2621`); this proves stream/device/PCM
liveness, not human-audible acceptance. The macOS track is therefore much
further along than iPadOS/iOS: it has a broad OpenGL renderer and retail route,
where mobile still has native Metal bucket composition, clean input/route
progression, mobile audio, iPhone parity, and physical-device gates open. See
`docs/evidence/M1/m1-macos-product-observation-audio-2026-08-20.md`.
The platform split and this audio boundary are recorded directly in
`docs/evidence/M1/m1-platform-split-and-audio-boundary-2026-08-20.md`.

The 2026-08-21 macOS follow-up completed the missing half of the particle
producer trace. At the shared Village1 target marker, macOS producer IDs map
directly to its own AdGif/TEX0 family (`0x...a518`, `0x...a4f2`, `0x...a5ee`,
`0x...a6e1`), while the fresh iPad trace maps to a different family beginning
`0x...ab8d`. Both consumers preserve their producer output; no TBP remap,
camera rewrite, or shader change is justified. The first open R1 dependency
is now the source/data-family selection around Sprite3 frame setup and
`flush_sprites`, before native Metal composition. See
`docs/evidence/R1/r1-macos-particle-adgif-output-mapping-2026-08-21.md`.

The follow-up GOAL producer trace now records the first AdGif resource before
DMA. Its `prims[3]` field is the GS `TEX1` register ID (`0x14`), not a logical
texture ID, because `particle-setup-adgif` overwrites that overlay. The fresh
macOS route emits TBP `0x24f2` (64×64) while iPad emits `0x2bc1` (64×64); the
earlier raw particle-ID trace confirms their input/resource sequences also
differ. The native consumer therefore is not the first divergence, but the
exact producer lookup/resource owner remains open. No texture substitution or
TBP remap is allowed without that source-side comparison. See
`docs/evidence/R1/r1-sparticle-source-texture-page-comparison-2026-08-21.md`.

Supplemental Jak 2 ARM64 research was read on 2026-08-20. It shares the
Ottsel upstream pin and supplies useful regression oracles, but its MAP_JIT,
dynamic-trampoline, inventory-only AOT, and frame-clear Metal paths are not
Ottsel product paths and do not supersede the current renderer/audio/input
queue. One independently identified shared defect was selected as J2R1: a
red executable `sqrt_f32` test proved Ottsel used the ARM64 source/destination
field incorrectly, and the minimal `Rm(dst)` to `Rd(dst)` fix now passes with
the focused 11-test set. The signed-native foundation remains closed; the
next product dependency is still R1 Sprite3 route stability/parity. See
`docs/evidence/J2R1/j2r1-sqrt-f32-2026-08-20.md`.

The current iPad follow-up rebuilt the signed app after adding a narrow
progress/memory-card probe: all 546 GOAL targets rebuilt, 18 focused tests
passed, strict signing passed, and the product executable scan still found no
JIT/executable-page markers. A one-runtime normal-Metal Simulator launch stayed
alive, loaded the Village1 path, and repeatedly entered the progress method,
but GOAL's `~D` formatter emitted blank numeric fields, so the card/option
branch remains unidentified. This is a useful liveness boundary, not a mobile
playability result; the Simulator was blank and non-audible. See
`docs/evidence/I1/i1-memcard-probe-build-and-live-boundary-2026-08-20.md`.

The follow-up route probe now identifies the first genuinely open mobile
dependency: the raw Start/Cross/Down seam reaches the real
`save-game-title` screen, and the file-trigger path now uses the canonical
latched keyboard/touch input seam. A bounded normal-Metal replay consumed four
Down edges plus Cross, entered Village1, stayed alive through the follow-up,
and kept the fault log at 0 bytes. This is an I1 route/liveness increment; the
next gates are still native Metal composition/parity, visible touch acceptance,
mobile audio, and the broader playable interaction replay.

The latest same-chain R1 ledger confirms the canonical normal-Metal route also
emits `GAMEPLAY: enter village1` and `intro-start` camera setup. Its populated
Sprite3 phase remains `tbp=0x2c8d` while the macOS Village1 reference begins its
captured world group at `tbp=0x24f2`. The new title-state marker now proves a
fresh current-boot `target-title-wait` entry before Start; that replay consumed
the settled Cross/Down/Cross route, reached Village1, and captured 64 Sprite3
records with a zero-byte fault log. This closes route synchronization as the
immediate blocker but does not close R1: resource ownership/state parity and
the final image remain open. A fresh empty-config macOS replay now captures the
same route's world oracle at TBP `0x24f2` (64×64, 2,432 group-0 sprites), making
the iPad `0x2c8d` phase mismatch concrete. The next experiment is producer-side
bucket/group ownership comparison; no camera or shader change is justified.
The Simulator remains blank and non-audible. See
`docs/evidence/R1/r1-title-marker-route-sprite-ledger-2026-08-20.md` and
`docs/evidence/R1/r1-macos-same-route-sprite-ledger-2026-08-20.md`. The
producer audit now makes the remaining comparison explicit: macOS Sprite3
Jak 1 owns pre-Direct, distort, group-0/world, shadow, and group-1/HUD phases,
while mobile currently proves only the bucket-66 group-0 parser plus a separate
bucket-67 Direct walk. The next experiment is a phase-aligned mobile ledger;
the latest trigger-location miss is excluded from renderer interpretation. See
`docs/evidence/R1/r1-sprite3-producer-ownership-audit-2026-08-20.md`.

On 2026-08-21, a fresh bounded retry reached `title-wait-ready` but did not
consume the host-side Start trigger, so it produced no new Village1 readback
artifact. This is recorded as route-driver synchronization noise, not as a
renderer regression. The latest valid native probe remains diagnostic-only
(`drawn=640`, `fixture-uploaded=true`, `cpu-product-frame=0`); the Simulator
remains blank and non-audible. See
`docs/evidence/R1/r1-route-driver-retry-2026-08-21.md`.

A later fresh-boot replay corrected the stale-log race and reached Village1
twice. Bucket 67 contained the expected seven exact world tuples, but the
native probe rejected all 384 candidates as not visibly usable and uploaded
none (`fixture-uploaded=false`); the fault log stayed at zero and no new PPM
was written. The next R1 slice is transformed-bound/timing comparison for
that retained tuple, not a broad bucket or shader change.

The subsequent source audit reconciled the mobile MSCAL-3 expansion with the
maintained desktop Sprite3 shader order (Q, HVDF, scale/rotation, XY lookup,
post-divide/scissor). Because mobile still supplies `0x2c8d` world groups
where the macOS accepted frame supplies `0x24f2`, the transform comparison is
not same-phase evidence yet. The queue remains producer/resource ownership;
camera sign, shader math, and clip eligibility remain unchanged. See
`docs/evidence/R1/r1-transform-resource-reconciliation-2026-08-21.md`.

The new phase-window ledger makes the producer boundary more precise: the
bucket-66 data interval through bucket 67 contains setup only, while the
bucket-67 through bucket-68 interval contains 64 3D plus 320 world Sprite3
sprites. The product walk therefore spans 66→68, but bucket 67 must not be
treated as Direct-only or widened wholesale. The mobile sequence still does
not match macOS (51 world blocks / 2,432 sprites beginning at `0x24f2`). See
`docs/evidence/R1/r1-sprite3-phase-window-2026-08-21.md`.

The retained product-walk follow-up classified one complete 66→68 interval as
10 groups / 448 sprites (64 3D + 384 world), with world resources `0x2d8c`,
`0x2c8d`, and `0x2b84`. Its difference from the earlier 9-group/384-sprite
window means a single bucket snapshot is not a stable frame oracle. The next
R1 experiment is shared-vsync frame aggregation against the macOS dispatch.

The shared-vsync aggregate is now proven: one fresh Village1 boundary closed
with `chains=1`, `groups=9`, `sprites=384`, `world=320`, and `3d=64`, matching
the split window. The 10-group result was a different phase, not parser
nondeterminism. Mobile still lacks the macOS 51-world-block/2,432-sprite
dispatch, so the next slice is ordered missing-group/resource mapping.

The newer R1 replay evidence closes that mapping prerequisite enough to select
the next product slice: mobile is stable within a valid route state, and bucket
67 contains distinct 3D, world, and HUD Sprite3 phases rather than a Direct-only
stream. The maintained `Sprite3Native.*` suite now passes 14/14, including the
bucket-67 world tuple guard and native alpha/depth/blend contracts. The next
open dependency is phase-specific native Sprite3 composition/readback for the
retained world tuple, while excluding bucket-67 HUD/3D widening. The existing
native probe remains diagnostic-only (`cpu-product-frame=0`); the Simulator is
blank/non-audible and no R1 or playability claim follows. See
`docs/evidence/R1/r1-mobile-producer-replay-stability-2026-08-21.md`,
`docs/evidence/R1/r1-ordered-group-resource-mapping-2026-08-21.md`, and
`docs/evidence/R1/r1-post-village1-bucket-ownership-2026-08-20.md`.
See `docs/evidence/R1/r1-sprite3-frame-aggregate-2026-08-21.md`.

The ordered mapping now identifies the first concrete divergence. In the valid
post-Village1 aggregate, mobile begins with 3D TBPs `0x2b8d`/`0x2be0`, then
world `0x2d7c`/`0x2d8c`/`0x2c8d`; macOS begins with 3D TBP 9710 and world TBP
9458 (`0x24f2`). This precedes native clip/image comparison and does not
justify a TBP remap or shader change. See
`docs/evidence/R1/r1-ordered-group-resource-mapping-2026-08-21.md`.

The current source/data-root audit rules out the validated-pack selection as
the first cause: the route imported and selected the durable user root before
Metal, then reached the expected 656-byte frame and 80-byte matrix setup.
The divergence begins in the post-setup resource/phase contents. See
`docs/evidence/R1/r1-data-root-frame-setup-reconciliation-2026-08-21.md`.

The bounded post-Village1 record ledger now captures the raw producer contents:
mobile group 0 uses `0x2d8c`/`0x2c8d` records with large divergent positions and
scales, while the macOS accepted world sample uses `0x24f2` and a different
raw vector domain. This moves the first open mismatch upstream of native Metal
clip eligibility. See
`docs/evidence/R1/r1-mobile-post-setup-records-2026-08-21.md`.

The maintained `Sprite3Native.*` focused regression remains green (12/12), so
the next slice is still a live producer/resource-emission comparison rather
than a boundary or native state-policy change.
That comparison now has a stability discriminator: a fresh mobile route
repeated identical frame/camera and `0x2c8d` producer records across chains
3714–3717 with a zero-byte fault log. See
`docs/evidence/R1/r1-mobile-producer-replay-stability-2026-08-21.md`.
An additional fresh macOS run reached Village1 and logged output callback plus
real VAG stream progression; its Sprite3 trigger fired too early during title,
so it is audio/stability evidence only. See
`docs/evidence/M1/m1-macos-audio-replay-2026-08-21.md`.
The corrected Village1-boundary macOS trace now captures three Sprite3 frames;
its first world draw is `0x24f2`/9458, 64×64, 55 sprites, while the stable
mobile replay begins at `0x2c8d`/32×32. This confirms ordered source-resource
divergence but still needs an explicit same-transition route marker before
assigning ownership to game state, data-family selection, or handoff. See
`docs/evidence/R1/r1-macos-village1-producer-capture-2026-08-21.md`.
The shared GOAL route marker now compiles in the correct ARM64 mode (`(mi)`
rebuilt 292 targets), with the initial wrong-ISA and format-arity failures
recorded separately. It is source/build proof only until fresh macOS and iPad
runtime captures include the marker. See
`docs/evidence/R1/r1-route-state-marker-2026-08-21.md`.
The marker is now live at the actual `village1 display-self` boundary on both
fresh runtimes. Both report target position `(-635598.875,222551.6562,
710496.25,1)`, while macOS begins Sprite3 at `0x24f2`/64×64 and mobile remains
at `0x2c8d`/32×32. This rules out target-position mismatch as the immediate
cause; producer data-family/phase ownership remains open. See
`docs/evidence/R1/r1-same-transition-route-marker-2026-08-21.md`.

The next falsifiable slice is now instrumented: the mobile 66→68 walker logs
raw transfer count, Sprite3-header candidates, rejected candidates, and
boundary stops alongside its accepted groups. This distinguishes a producer
shortfall from a consumer validation rejection without changing rendering.
The signed diagnostic build and `Sprite3Native.*` 12/12 proof are recorded in
`docs/evidence/R1/r1-mobile-raw-span-ledger-2026-08-20.md`; a fresh route
capture is still required before assigning ownership.
The corrected trigger placement now produced a current non-Village1 span with
`headers=5`, `rejected=0`, and `boundary-stops=0` across 64 world plus 128 HUD
sprites. This rules out silent parser rejection for that phase, but the
append-only log still requires a fresh-marker-aware Village1 capture before
using the result for the R1 parity comparison.
That fresh-marker-aware retry is now complete: at `chain=25389/vsync=25390`,
the product interval accepted 10 groups / 448 sprites (`320` world, `128`
HUD) with `headers=10`, `rejected=0`, and `boundary-stops=0`. One final
32-sprite world record decoded with zero texture fields, providing the next
concrete producer/data-shape anomaly. See
`docs/evidence/R1/r1-village1-raw-span-retry-2026-08-20.md`.
That contract is now test-first and implemented in the bounded native probe:
`Sprite3Native.*` passes 13/13, TCC=1 remains on the decoded texture path, and
TCC=0 uses only a generated white texel with vertex color preserved. A fresh
probe uploaded the existing textured candidate with zero faults; the
color-only branch is source/test verified but not yet the selected live upload.
See `docs/evidence/R1/r1-sprite3-tcc0-color-only-2026-08-20.md`.
A color-only-only trigger then skipped TCC=1 candidates and reached the
repeated TCC=0 groups, but no native upload followed because those records did
not pass the existing usable native-candidate path; fault log remained 0
bytes. This keeps the next dependency at transformed visibility/phase timing,
not texture decoding.
The follow-on transform probe showed all 16 TCC=0 records had zero vectors
and `camera.w=0`; the existing denominator guard correctly rejected them. No
camera/shader relaxation is justified, and the queue returns to textured
phase/resource ownership and the missing macOS world sequence.
The current signed build then revalidated the textured native probe and
produced a nonzero Metal readback (`tcc=1`, texture `0x2bc1`, 64×64, 0-byte
fault log). This is renderer liveness only; the next experiment is ordered
phase/resource comparison against macOS. See
`docs/evidence/R1/r1-textured-native-readback-retest-2026-08-20.md`.
The fresh post-background product window now captures that comparison at
`chain=1996/vsync=1997`: mobile starts with `0x2bc1`/64×64/48 sprites, then
the empty TCC=0 group, while macOS starts its accepted world dispatch at
`0x24f2`/64×64/55 sprites. Mobile level status was still loading, so this is
structural producer evidence, not a final frame. See
`docs/evidence/R1/r1-textured-phase-resource-window-2026-08-20.md`.
The follow-on signed build now dumps the first raw ADGIF words for zero-TBP
records, capped and diagnostic-only; `Sprite3Native.*` remains 12/12 and
codesign passes. Its live ADGIF dump is still pending, so no zero-TBP fix or
texture interpretation has been accepted.
The discriminator now also runs in the normal retained product walker, so a
future zero-TBP group cannot be missed merely because the phase trigger lands
on setup-only chain 1. The rebuilt signed executable is
`987424be0184687714b327632b292ccebbdb1ae359c2450e159dc0b0b9181c3b`;
`Sprite3Native.*` remains 12/12. Live zero-TBP words are still pending.
The rebuilt probe was also run once on a fresh process (PID `13679`): it
reached the current Village1 markers but only produced an early setup-only
chain before the bounded stop, with a zero-byte fault log. The zero-TBP ADGIF
sample remains uncollected.
That sample is now captured: the supported prelaunch Village1 diagnostic route
produced repeated `UNPACK_V4_32` ADGIF transfers with valid register-address
sequences but `TEX0=0`/TCC=0. The next gate is a before-failing untextured
Sprite3/color-only contract, not a DMA offset or texture-root fix. See
`docs/evidence/R1/r1-village1-raw-span-retry-2026-08-20.md`.
The corresponding `village1.fr3`, `title.fr3`, `VI1.DGO`, rebuilt `GAME.CGO`,
and `KERNEL.CGO` hashes also match between the regenerated macOS artifacts and
the durable iPad inputs. Data-root selection is therefore no longer the leading
cause. See `docs/evidence/R1/r1-same-transition-data-identity-2026-08-21.md`.

The corrected prepared-pack route now supplies a stronger R1 discriminator:
mobile bucket 66 sees two MSCAL 211 groups (64 3D sprites) and only seven
MSCAL 3 group-0 chunks (320 world sprites, TBPs `0x2c8d` through `0x2d7c`),
whereas the same-route macOS Sprite3 trace sees 51 group-0 chunks / 2,432
world sprites beginning at `0x24f2`. A bounded bucket-table dump also shows
bucket 66 and bucket 67 entering the same Sprite3-shaped sequence, so the
mobile bucket-address ownership assumption must be proven before any texture
or shader change. See
`docs/evidence/R1/r1-prepared-route-full-sprite-phase-mismatch-2026-08-20.md`.
The first boundary experiment is rejected: changing only the stop values to
bucket-table offsets while retaining data-address starts produced zero groups.
The mobile walk must consume the current bucket-table tag before using the
desktop-style next-entry boundary. See
`docs/evidence/R1/r1-sprite3-table-boundary-falsification-2026-08-20.md`.
The follow-up entry-consuming variant also produced zero groups across twelve
successive live chains and has been reverted. The ROM-free fixtures now cover
the table/data/return contract and the actual chain-relative 66/67/68 reads;
the focused suite is 20/20. The next step is adapting the mobile consumer to
that contract while preserving the existing Direct path.
The added phase classifier now has a fresh live capture: mobile bucket 66
reported 64 MSCAL-211 3D sprites, 384 MSCAL-3 world sprites across 8 groups,
and no HUD/other groups; macOS remains 51 world groups / 2,432 sprites. This
makes phase ownership explicit without changing rendering behavior. See
`docs/evidence/R1/r1-sprite3-phase-classifier-live-2026-08-20.md`.
The phase-sequence comparison now records the remaining structural mismatch:
macOS Sprite3 owns pre-Direct, distorter, 3D, world, shadow, and HUD phases,
while the mobile capture ends after a 64-sprite 3D phase and 384-sprite world
subset with no HUD phase. The next experiment is complete DMA-chain boundary
alignment, not native consumer widening. See
`docs/evidence/R1/r1-sprite3-phase-sequence-comparison-2026-08-20.md`.
The 900-chain Direct aggregate further separates bucket 67: its Sprite3
counts were world `0`, HUD `0`, 3D `0`, other `86,400`, with no draws. Bucket
67 is therefore not a Sprite3 phase oracle for this capture; the unresolved
producer/content comparison is bucket 66 only. See
`docs/evidence/R1/r1-sprite3-complete-chain-aggregate-2026-08-20.md`.
Repeated bucket-66 captures now show the fragment is stable: five populated
chains each produced 7 world groups / 320 sprites and 64 3D sprites, totaling
35 groups / 1,600 world sprites with no HUD phase. This is a repeatable
per-call phase fragment, not yet a frame-complete producer/DMA mismatch; the
mobile calls were seconds apart while the macOS count is one complete frame.
See
`docs/evidence/R1/r1-bucket66-populated-aggregate-2026-08-20.md`.
The required next measurement is a shared mobile/macOS frame-boundary ledger;
the iOS renderer callback probe was falsified as the active mobile boundary.
The actual `ios_stubs.cpp` `sceGsSyncV` seam now joins into Sprite3 completion
logs. A fresh title-marker-synchronized Village1 route produced four stable
frame-aligned samples at `chain/vsync=62812/62813`, `67036/67037`,
`68420/68421`, and `69657/69658`, each with 320 group-0 sprites and a
0-byte fault log. This closes the numeric boundary sub-gate, not Sprite3
parity: macOS still reports 2,432 group-0 sprites / 51 blocks for its complete
frame. A post-Village1 bounded bucket dump now shows bucket 66 and bucket 67
both carrying Sprite3-shaped frame/matrix/header/vector/ADGIF streams, so
bucket 67 ownership must be classified read-only before any consumer widening.
That classifier now reports bucket 67 as 13 groups / 576 sprites: world 384,
HUD 128, 3D 64, other 0, on `chain=40111 vsync=40112`. Bucket 67 therefore
owns distinct Sprite3 phases, but no phase has been widened into Metal yet.
The ordered tuple capture is 3D `0x2be0` (48+16), world `0x2c8d` (seven
48-sprite groups) then `0x2d8c` (48), and HUD `0x2bd2`/`0x2d9c`/`0x2c8d`.
The before-failing fixture for one bucket-67 world tuple now passes and rejects
HUD/count variants. The trigger-gated native probe then reported
`chain=53052 vsync=53053 drawn=640 candidates=640 fixture-uploaded=true
cpu-product-frame=0` after a fresh Village1 route, with a 0-byte fault log.
This is upload-contract evidence only; no visible-frame or playability claim
is made. The next slice is phase/image parity, not wholesale bucket adoption.
See
`docs/evidence/R1/r1-post-village1-bucket-ownership-2026-08-20.md`.
See `docs/evidence/R1/r1-sprite3-frame-boundary-caveat-2026-08-20.md` and
`docs/evidence/R1/r1-frame-boundary-correlation-2026-08-20.md`.

**D0 attribution update (2026-08-19):** the source-defined 14-qword Jak 1 font
glyph was captured on macOS in bucket 67’s plain `DirectRenderer("debug")`.
The trace recorded `FRAME.fbp=0`, FBO 65, a 1280x960 viewport,
`offscreen=false`, a real texture hit, and one post-flush draw of 44 triangles.
This selects **D0-NORMAL** and falsifies the earlier coordinate-only offscreen
inference. The same-phase macOS title/logo frame is now recorded alongside the
dated trace in `docs/evidence/D0/d0-normal-direct-attribution-2026-08-19.md`;
D0 is **PASS**. Do not extend
the VU/software-rasterizer diagnostic path or implement an offscreen target.
The D1 generated Direct fixture contract is now present and passes its focused
tests (`0x172c927c` ordered-state hash; checksum `1020`). The D2 ordered-IR
contract passes 6/6 fixture tests, including state snapshots, flush reasons,
malformed tags, truncation, and explicit error codes. A fresh linked bucket-67
iPad replay observes the qwc14 glyph and the hardened ordered
`PRIM,TEX0,ST,RGBAQ,XYZ ×4,STATE,FLUSH,TRANSFER-END` stream with a zero-byte
fault log. D2 is **PASS** as a decoder/IR gate only; no Metal draw or
playability claim is implied. See
`docs/evidence/D1/d1-generated-direct-fixture-2026-08-19.md` and
`docs/evidence/D2/d2-generated-direct-ir-2026-08-19.md`. The first D3 native
Metal fixture passes, and a second replay now feeds the real D2 glyph XYZ
bounds into that Metal draw without consuming `g_frame` or `OttselRaster`.
D3 now proves the D0 PSMT4HL/CSM1 generated texture expansion, TEX0-keyed
Metal lookup, isolated default state (`frame/alpha/test/zbuf=0`), a
1-draw/2-triangle contract with `PRIM.ABE` source-alpha blending, and same-pass composition ownership while
preserving the TFRAG/TIE scene; the D0 sampler is now proven as
nearest/repeat. The native shader also decodes the maintained GS alpha-test
comparison fields, although D0 exercises the disabled (`TEST=0`) path. It
now retains decoded texture pages by composite GS destination/PSM key and
implements the PC_PORT font relocation seam: the Jak 1 font page 0x4fe supplies
the real 0x24/PSMT4HL and 0x2c/PSMT4HH pages at destinations 0x3800/0x3980.
The D0 0x3980/0x24 replay now resolves the real relocated 256x512 page rather
than the generated fallback. It remains open for alpha-fail/depth/color-mask/fog
semantics, broader primitive semantics, and image/counter parity; the latest
replay records a lookup hit and a zero-byte fault log. See
`docs/evidence/D3/d3-native-metal-direct-fixture-2026-08-19.md`. Continue D3 by
feeding retained per-vertex RGBA and D0 TEX0 TCC/TFX state into the native
shader; that continuation is recorded in
`docs/evidence/D3/d3-live-ir-metal-rgba-2026-08-19.log`. Direct depth ownership
is now explicit (`GEQUAL`/write) and recorded in
`docs/evidence/D3/d3-live-ir-metal-depth-2026-08-19.log`. No D4 claim is made. See
The CPU `g_frame` publication seam is now removed; a native-only replay proves
the visible TFRAG/TIE scene survives without CPU-frame presentation, while
Sprite3/title overlays remain absent. See
`docs/evidence/D3/d3-native-only-2026-08-19.log`. The next renderer boundary is
R1 Sprite3 GPU expansion, not a D4 claim. See
The first R1 native Sprite3 upload is implemented but remains trigger-gated.
The live bucket-66 parser boundary is now corrected to walk through bucket 68;
the diagnostic Village1 phase produces the expected frame/matrix/vector/ADGIF
sequence and 320 group-0 sprites (later ordered replays reached 128 and 640).
The bounded candidate ledger first reproduced edge/zero-area records. The
probe now uses the desktop Jak 1 shader-space transform, rejects candidates
outside clip space, and requires nonzero vertex/texture alpha. It selected
group 0/index 1 at `(0.053,0.718)..(0.262,0.997)` with 804 nonzero
texture-alpha pixels. Landscape inspection shows a localized translucent patch
consistent with that candidate, but no same-phase A/B image-diff proof exists;
this is native-draw/visual-consistency progress, not a Sprite3 pass. The
trigger-gated selected candidate now skips its CPU raster triangles after native
upload. Rejected candidates now fall through correctly; a fresh replay returned
`group-0 sprites=640` with no native-eligible candidate. A later replay reached
an eligible candidate and captured the live
`cpu-raster=skipped-for-native-candidate` proof; visual parity remains open.
T1 now has a live visible-overlay increment in the iPad Metal path: static
landscape movement, face-button, shoulder, and Start regions are uploaded as a
final blended pass above the rendered scene, while the existing `ShellPadInput`
bridge remains the input authority. A clean Simulator UI launch produced both
title and later-scene screenshots with the overlay visible. The first launch
attempt exposed and the next build deferred a launch-time Metal buffer race;
the clean replay produced no new crash report. This is still not a T1 pass:
custom layout editing, persistence, accessibility labels, phone layouts,
simultaneous movement/action/camera, cancellation, and lifecycle neutralization
remain open. See `docs/evidence/T1/t1-visible-overlay-2026-08-20.md`.
The follow-up source increment now gives the visible face, Start/shoulder, and
camera regions distinct per-finger canonical-button/right-stick ownership, with
release/cancel neutralization. Its updated title frame is recorded in
`docs/evidence/T1/t1-touch-region-mapping-2026-08-20.md`; a later replay still
hit the existing broad Metal title-texture-upload/Simulator-host boundary, so
no live multitouch trace is claimed.
The broad title texture-upload boundary then received a bounded stability fix:
keyed Direct texture pages are queued from the boot thread and drained eight at
a time on the presentation thread. A fresh clean replay stayed foreground
through title/Nintendo scene progression with the mapped overlay visible and no
new crash report in the follow-up window. This is a renderer-host stability
increment, not a Direct/Sprite parity or T1 pass; see
`docs/evidence/T1/t1-direct-upload-queue-2026-08-20.md`.
The follow-up TIE queue and writable-trigger increment then reached the
Sprite3 bucket-66 frame/matrix/vector/ADGIF payload without the earlier TIE
texture-upload failure. The current shader-space expansion produced
multi-screen candidate bounds (for example `(-1.091,.095)..(3.485,7.844)`),
so the bounded native probe rejected every observed candidate. No native group
or CPU-skip line was captured; the late run ended at the known Simulator
`SimMetalHost` drawable failure. This is transform-boundary progress, not an
R1 pass. See
`docs/evidence/R1/r1-tie-queue-trigger-transform-boundary-2026-08-20.md`.
Before the next behavior change, a diagnostic-only trace now records the
unnegated and desktop-negated camera-space `w` for the first Sprite3 vector;
the maintained desktop shader explicitly negates `matrix_transform(camera,
pos)` before Q. The focused regression remains 6/6 and the signed build is
`b0454ee3f0125fcf7605c7e270b5e022f55fbd18b3a8c67aa6158bb4f16780f3`; the sign
hypothesis was then live-tested and falsified for this MSCAL 3 bucket.
That sign hypothesis was then falsified for this bucket: MSCAL 3 is the
desktop `Sprites2dGrp0` path, which retains the camera sign. The TIE/TFRAG
color and mesh queues were extended, and a fresh replay reached the corrected
2D candidate ledger with representative bounds
`(13.402,.994)..(19.211,10.831)` and no eligible candidate. The queue removed
the earlier boot-thread buffer failures; the late run still ended at the known
`CAMetalLayer nextDrawable` / `SimMetalHost` failure. The preceding queue
replay build was `55337d02f7390c19b3e38addc9f87f76f8855169761cba3ec72280a4ab6366be`; see
`docs/evidence/R1/r1-2d-queue-replay-2026-08-20.md`.
An intermediate-value trace then captured the 2D Q/base/scale/basis inputs on
build `ae52c48002322a8bd9e07e039afff708820e746b00a36b970ffe3f411dbf37e0`;
the resulting values are now the source-of-truth for the next desktop
`Sprites2dGrp0` comparison. No native ownership or R1 pass is implied.
The next native-only clip conversion corrected the homogeneous-coordinate
mistake: Metal now receives post-perspective-divide x/y. A fresh replay
reduced candidate bounds to near-clip values such as
`(1.006,.518)..(1.233,.903)` and `(0.149,-.592)..(0.152,-.589)`, but this
phase still produced no eligible candidate or CPU-skip proof before the known
Simulator drawable-host failure. Build
`23aa74e8a426aad37ad6bb0f81080970558b5cac75c685bbb2fe04bbc2199378`; see
`docs/evidence/R1/r1-postdivide-clip-replay-2026-08-20.md`.
The subsequent visible-intersection gate selected a partially clipped Sprite3
candidate and the queued native upload now has live ownership evidence:
`visible=(.025,.304) usable=true`, `native group=0 index=2`, texture `0x2bc1`
`64x64`, `cpu-raster=skipped-for-native-candidate`, and nonzero color/texture
alpha. This is a partial R1 milestone, not a product-frame or parity pass;
the late replay still hit the known drawable-host failure. Build
`321ed5af0d91d749c92bc11f683eb977da6850ad05ff7406fe631e52f162decf`; see
`docs/evidence/R1/r1-native-sprite-queue-ownership-2026-08-20.md`.
The maintained Jak 1 Sprite3 default also disables depth writes while keeping
GEQUAL testing; the native probe had reused the Direct/TIE GEQUAL/write state.
A shared policy regression and dedicated Metal Sprite3 depth state now correct
that mismatch. The focused Sprite3 suite passes 4/4 and the signed build
verifies. Two fresh trigger-isolated launches now reach the same finite visible
Sprite3 candidate and submit the native six-vertex draw while skipping the CPU
raster consumer. The Simulator remained blank/non-audible, so this is native
ownership and repeatability progress only, not R1 or visual proof. See
`docs/evidence/R1/r1-sprite3-depth-policy-2026-08-20.md`.
`docs/evidence/R1/r1-native-sprite-live-draw-2026-08-20.md`.
The macOS shader comparison then exposed a concrete color-domain defect: the
native candidate was dividing already-normalized vector RGBA by 255. A focused
normalized-alpha regression now passes 5/5, and a fresh signed replay reports
`color-alpha=0.8448` and `uploaded-alpha=0.8448` with the CPU raster skipped.
This corrects the native upload domain for the proven candidate, but the
Simulator remained blank/non-audible and final image/alpha-test/blend parity is
still open. See
`docs/evidence/R1/r1-sprite3-normalized-alpha-2026-08-20.md`.
The next macOS reference comparison also found the native Sprite3 fragment
state had alpha testing disabled. Shared policy constants now wire the desktop
primary-pass GEQUAL threshold (`2/128 ~= 0.016`) into the native draw; the
focused Sprite3 suite passes 6/6 and a fresh signed replay still reaches the
same native candidate with zero fault bytes. This is state-contract progress,
not image proof; the Simulator remained blank/non-audible. See
`docs/evidence/R1/r1-sprite3-alpha-test-policy-2026-08-20.md`.
The fragment boundary now also has a ROM-free 8/8 contract suite covering the
exact GEQUAL pass/reject boundary and the source-over RGB equation used by the
native blend state. This is an executable renderer oracle only; it does not
prove Metal fragment output or image parity. See
`docs/evidence/R1/r1-sprite3-fragment-contract-2026-08-20.md`.
The contract is now live-observable at the native upload boundary: a fresh
signed replay logs `alpha-test=gequal/2 blend=source-over` alongside the
finite candidate, normalized alpha, CPU-raster skip, and zero-byte fault log.
This still proves state binding/liveness only; the Simulator remained
blank/non-audible and actual Metal fragment output/image parity is open. See
`docs/evidence/R1/r1-native-fragment-state-live-2026-08-20.md`.
To get stronger evidence than the blank Simulator surface, a one-shot
diagnostic drawable-to-PPM readback was added. The fresh longer replay reached
the native Sprite3 candidate but produced no PPM because the host crashed at
`MTLSimApplicationContext::newIOSurfaceTexture`; the app fault log stayed at
zero bytes. This is an open drawable-host/resource boundary, not evidence of
blank native pixels. See
`docs/evidence/R1/r1-metal-drawable-readback-boundary-2026-08-20.md`.
An isolation run without Sprite3/Village1 triggers then produced a `1210x834`
GPU PPM showing the shell text on the actual drawable, proving readback and a
base present work in isolation. A subsequent targeted replay recorded the
Sprite3 resource-ready marker and produced a fresh GPU PPM containing the
yellow native Sprite3 flare over the shell text. The Simulator remained
blank/non-audible; this is direct drawable evidence but not title/menu parity
or playability. See
`docs/evidence/R1/r1-metal-generic-readback-2026-08-20.md`.
`docs/evidence/R1/r1-native-sprite-gpu-readback-2026-08-20.md`.
The same trigger-isolated route was then repeated with a fresh app install. The
second 1210x834 GPU artifact was byte-identical to the first
(`8255efdb30078193fafeed9dea4d762eb86d25d1c5e08e45c202e7a09ce0bdc1`), with
the same candidate/resource/state counters and zero fault bytes. This makes
the selected native Sprite3 output deterministic, but remains a diagnostic
partial R1 result until a same-phase macOS/fixture comparison and broader
route parity pass. See
`docs/evidence/R1/r1-native-sprite-gpu-repeatability-2026-08-20.md`.
The macOS reference comparison now makes the remaining scope concrete: the
maintained desktop route records 48 Sprite3 world blocks / 2304 sprites and
multiple texture/state draw buckets, while the current iPad diagnostic submits
one selected `64x64` candidate. These are not the same identified bucket, so
the single native flare is not a parity claim. The next R1 dependency is
retained/batched Sprite3 coverage with one identified macOS TBP/state match.
See `docs/evidence/R1/r1-macos-sprite3-reference-comparison-2026-08-20.md`.
The bounded iPad catalog then logged the first 32 candidates after the initial
upload: only TBPs `0x2bc1` and `0x2bd3` appeared, while the captured macOS
reference bucket is TBP `9458` (`0x24f2`). This is a concrete route/data-phase
mismatch, so the native consumer remains first-candidate-only and no broader
batch is mislabeled as parity. See
`docs/evidence/R1/r1-ios-sprite-candidate-catalog-2026-08-20.md`.
The real title/New Game replay was then run without the Village1 shortcut. It
reached title and emitted a different usable candidate (`0x2506`), but did not
reach Village1 or emit the macOS reference `0x24f2`; the Cross trigger was still
present at teardown. The Simulator remained blank/non-audible, and a concurrent
Metal command-buffer/SimMetalHost abort means this is route diagnosis only.
Keep Sprite3 batching deferred and isolate the input/host failure next. See
`docs/evidence/R1/r1-ios-new-game-sprite-catalog-2026-08-20.md`.
The native Direct/Sprite pipeline now also declares the same `Depth32Float`
attachment format bound by its render pass. This was a narrowly falsifiable
response to the prior Simulator command-buffer mismatch. The focused Sprite3
suite passes 4/4 and strict signing verifies, but fresh `SimMetalHost`
`EXC_BAD_ACCESS` reports still terminate in `MTLSimApplicationContext::deleteObject`;
the bounded launch still emitted no Sprite3 draw. The Simulator remained
blank/non-audible, so this remains an open renderer-host diagnostic slice, not
an R1 or playability pass. See
`docs/evidence/R1/r1-metal-depth-attachment-contract-2026-08-20.md`.
The accepted real title/New Game route is
still not re-proven in this replay. See
`docs/evidence/R1/r1-sprite3-bucket-attribution-2026-08-19.md` and
`docs/evidence/R1/r1-sprite3-native-probe-2026-08-19.md`.
The mobile shell now has an explicit selected SDL gamepad owner: it enumerates
and opens one device for pad 0, filters events by its instance ID, neutralizes
on removal, and selects a replacement. The focused platform-input tests, fresh
iOS build, strict signature check, and diff checks pass. This is an I1 source
and package increment only; no physical-controller connect/disconnect/reconnect
acceptance is claimed without hardware. See
`docs/evidence/I1/i1-gamepad-ownership-2026-08-20.md`.
The touch bridge also replaced its finger-ID-zero sentinel with explicit active
ownership flags for stick, camera, and action fingers; this prevents a valid
zero-valued SDL finger from being treated as unassigned. No new live multitouch
or T1 acceptance claim is made. Foreground resume now re-enumerates a replacement
gamepad after backgrounding; hardware reconnect proof remains open.
The T1 overlay now has a normalized layout model shared by drawing and hit
testing, separate tablet/phone persistence files with validation, and an F6
editor mode (double-tap Start or F6) that drags a region, adjusts opacity, and saves on release/cancel. This is source and
build progress only; the required relaunch, multitouch, cancellation, and
accessibility replay remains open. See
`docs/evidence/T1/t1-persistent-layout-editor-2026-08-20.md`.
The signed SDL diagnostic replay then entered the editor and saved a tablet
layout with opacity `0.95`; the config survived process termination in the same
app container. The expected reload log was not captured after relaunch, so this
is only a live persistence-file increment and T1 remains open. See
`docs/evidence/T1/t1-editor-runtime-diagnostic-2026-08-20.md`.
The follow-up SDL-only replay loaded the same valid tablet layout on first
launch and after process termination/relaunch in the same app container, with a
0-byte fault log. This closes the durable layout-file reload sub-gate, but not
editor gesture, multitouch, cancellation, accessibility, phone layout, or T1.
See `docs/evidence/T1/t1-persistent-layout-reload-2026-08-20.md`.
The next normal-Metal attempt could not reach the overlay/editor interaction:
the clean app aborted at `CAMetalLayer nextDrawable` after the Simulator
`SimMetalHost` XPC service was interrupted while allocating the drawable
texture. No editor gesture or screenshot is claimed; the Simulator remains a
blank/non-audible observation surface. T1 is still open, with this attempt
externally blocked at the host boundary. See
`docs/evidence/T1/t1-editor-host-boundary-2026-08-20.md`.
F1 now has a ROM-free pre-import boundary: `scripts/validate-user-data-pack.sh`
requires a versioned Jak 1 manifest, all renderer/audio families, extracted
data rather than an ISO, complete path-safe SHA-256 coverage, and available-space
headroom. The iOS runtime now discovers `Documents/OttselUserData`, validates
the same case-sensitive `CGO/DGO/fr3/MUS/SBK/STR/TEXT/VAG/VIS` contract before
kernel setup, and transactionally copies a valid pack into Application Support.
`scripts/build-ios.sh` now bundles only source-generated `TIT.DGO`/`VI1.DGO`
and generated TEXT outputs; an equality audit found no copied files from the
ignored extracted data tree. SDL-only diagnostic runs now prove validated import,
durable-pack selection across relaunch, title-to-Village1 DGO/STR streaming, and
creation of a 67,584-byte `BASCUS-97124AYBABTU!/bank0.bin` under the durable
`OpenGOAL/jak1/saves` root. A later fresh launch selected Load Game, logged
repeated `PC PORT: Skipping setting from game save` records, loaded
`training-vis`, and reached `GAMEPLAY: enter training` with that bank intact.
The first durable relaunch exposed a validator bug
where source-generated DGO/TEXT overlays invalidated the copied manifest; the
corrected signed build now accepts only byte-identical generated overlays and
passes the import/termination/Documents-removal/relaunch sequence. This is
SDL-only diagnostic proof using host sandbox delivery; legal Files UI delivery,
normal Metal-mode visual proof, audio, and active soak remain open. See
`docs/evidence/F1/f1-user-pack-validator-2026-08-20.md`.

The first fresh normal-Metal replay against that durable pack is separately
recorded in `docs/evidence/F1/f1-normal-metal-replay-2026-08-20.md`. The signed
app reached the `presentRGBA` path at `1210x834` with `pipeline=1`, then the
Simulator reported `MTLCommandBufferErrorDomain error 1` and lost its
`SimMetalHost` XPC service; the capture returned to the Simulator home screen.
This is a bounded external Simulator/Metal failure, not a product-frame or F1
pass. The Simulator was shut down after the run; legal Files delivery, normal
Metal playability, audio, and active soak remain open.

The selected-root handoff then corrected a concrete F1/R1 boundary: mobile
Metal FR3 loading now prefers the validated durable user-data root and falls
back to bundle `iso_data` only for a clean install. A fresh pre-Metal launch
imported the pack and loaded `title` and `village1` from the selected root with
full geometry counts and no missing-level warnings; the fault log stayed empty.
This remains data-path evidence only because the Simulator was blank and
non-audible. Legal Files delivery, native image parity, and the remaining R1
renderer buckets remain open. See
`docs/evidence/F1/f1-fr3-selected-root-2026-08-20.md`.
The fresh-install route was also isolated without reusing a prior Simulator
container: the bundle reached title but repeatedly failed to resolve the
`ndi-intro` STR stream because no user-owned validated pack was imported.
Therefore `title-play received wait` never occurred and no input was injected.
The fault log stayed at 0 bytes; no protected data was copied or committed.
F1 remains open on the legal Files/import dependency, and the synchronized
Metal Sprite3 route must be repeated after that pack is supplied. See
`docs/evidence/F1/f1-fresh-install-no-pack-route-2026-08-20.md`.
The clean-install boundary now exposes an explicit remediation state in the
shell (`DATA: import OttselUserData in Files`) whenever no validated pack is
selected. The signed rebuild and strict codesign check pass, but no user pack
was available for live import proof; this is an F1 partial milestone only.
See `docs/evidence/F1/f1-no-data-remediation-boundary-2026-08-20.md`.
The pack-side workflow is now reproducible outside the checkout with
`scripts/prepare-user-data-pack.sh`; a temporary nine-family fixture prepared
by the helper passed the existing validator. This supplies the missing
preparation command without changing the ROM-safe repository boundary. See
`docs/evidence/F1/f1-user-pack-preparation-helper-2026-08-20.md`.
Using the real locally prepared pack as a host-sandbox diagnostic delivery now
proves a stronger normal-Metal boundary: validated import completed, the
Village1 shortcut returned, 32 Sprite3 candidates were catalogued, and the
fault log stayed at 0 bytes without a SimMetalHost abort. The phase still only
emits `0x2bc1`/`0x2bd3`, not the macOS `0x24f2` reference. The real Start/Cross/
Left route separately reaches title-wait but stalls on invalid pending PC
progress objects before New Game; batching remains deferred. See
`docs/evidence/R1/r1-ios-validated-pack-metal-catalog-2026-08-20.md`.
The apparent invalid-object text is only the `~A` formatter: the logged values
are valid `progress-screen` enum values `0x1b` (title) and `0x12`
(save-game-title). A current-launch SDL-only replay consumed Start/Cross/Left,
then repeated the pending transition for over 60 seconds without entering
Village1; a full timing wait did not change it. The next discriminator is the
progress transition/clock state, not another input injection. See
`docs/evidence/I1/i1-validated-pack-title-progress-stall-2026-08-20.md`.

A diagnostic-only raw probe then captured the corrected route: transition offset
advanced by `0x2d` per tick with `autosave=#f`, `enter!` returned into
`save-game-title`, a second Cross selected the save slot, and the runtime reached
`GAMEPLAY: enter village1` with a 0-byte fault log. The probe was removed after
capture; no behavior was changed. The next product gate is normal-Metal parity,
not a transition-clock fix. See
`docs/evidence/I1/i1-progress-transition-clock-probe-2026-08-20.md`.

The corrected route was then replayed with normal Metal and the same validated
pack. It reached `GAMEPLAY: enter title` after pre-Metal data preparation but
stopped before `title-play received wait`; no input or Village1 claim is made,
and the fault log remained 0 bytes. This is the existing normal-Metal startup /
drawable liveness boundary. See
`docs/evidence/R1/r1-corrected-route-metal-boundary-2026-08-20.md`.

The corresponding fresh host report is now retained: Apple `SimMetalHost`
1051.55 crashed with `EXC_BAD_ACCESS` at null in
`MTLSimApplicationContext::deleteObject`, with `consecutiveCrashCount=5` and
no Ottsel frame in the faulting stack. This makes the current normal-Metal
replay boundary externally blocked at the Simulator rendering service; it does
not close R1 or the product goal. The next experiment is a minimal no-Sprite
drawable/resource-lifetime replay. See
`docs/evidence/R1/r1-simmetalhost-deleteobject-2026-08-20.md`.

The retained no-Sprite generic readback already proves base Metal present and
drawable readback in isolation. The macOS/native Sprite3 state comparison is
also phase-attributed: macOS frame 6 begins with TBP `0x24f2`/9458 and `aref=0`,
while the retained iPad diagnostic candidate is TBP `0x2bc1` from a different
phase and uses the native probe's `aref=2` contract. No native state or batching
change is justified until one matching iPad bucket/texture phase is captured.
See `docs/evidence/R1/r1-macos-native-state-mismatch-2026-08-20.md`.
The bounded follow-up no-Sprite normal-Metal replay emitted repeated
`1210x834` drawable presents and the audio callback with a 0-byte app fault log;
the Sprite3 readback marker remained unused because no Sprite3 resource was
active. This passes base present liveness for the isolated route and narrows the
known failure to the Sprite3/game-resource route, but does not identify its
root cause or prove any visual/audio/playability result. See
`docs/evidence/R1/r1-no-sprite-present-replay-2026-08-20.md`.
The next validated-pack/game-resource replay produced a first-party host
diagnostic: `SimMetalHost` terminated with Metal code `100`, `Invalid depth
stencil state`, while submitting the command buffer; Ottsel then reported the
corresponding code-102 XPC abort. Because no native Sprite3 draw line preceded
that abort, it was not sufficient to change the maintained GEQUAL/no-write
Sprite3 contract. See
`docs/evidence/R1/r1-sprite3-invalid-depth-state-2026-08-20.md`.
The generated ROM-free Direct fixture is now activated on the retained
validated-pack route after preseeded START/Cross progression: `CHAIN 0` logged
`image=2x2 ... cpu-raster=0`. A retained unified-log query then recovered the
native Direct draw contract: `draws=1`, `triangles=2`, `depth=gequal/write`, and
`final-target=same-pass`, followed by `MTLCommandBufferErrorDomain error 1` and
the SimMetalHost XPC interruption. This proves native draw submission but no
visible result; it reclassifies the open failure as a broader Metal
command/resource or Simulator-host boundary, not a Sprite3-only no-write
defect. The Simulator remained blank/non-audible and no visual, audio, or
playability proof was obtained. See
`docs/evidence/R1/r1-direct-fixture-activation-2026-08-20.md`.

The next bounded discriminator isolated that generated Direct fixture from the
generic log triangle, TFRAG/TIE meshes, and Sprite3 draw while preserving the
same drawable, depth attachment, pipeline, generated texture, and
`GEQUAL`/write Direct contract. The isolated pass still logged `draws=1`,
`triangles=2`, then aborted with `MTLCommandBufferErrorDomain error 1` and lost
the SimMetalHost XPC service. This rules out queued scene resources as the
immediate cause and leaves the remaining command-buffer/pass resource-lifetime
boundary externally open. The Simulator remained blank/non-audible; no visual,
audio, or playability proof was obtained. See
`docs/evidence/R1/r1-direct-fixture-isolated-submission-2026-08-20.md`.

The follow-up no-depth discriminator removed the depth attachment and depth
state and used a matching no-depth Direct pipeline while retaining only the
generated vertices, texture, sampler, shader, and drawable. It still logged one
Direct draw, then produced the same Metal command-buffer error and SimMetalHost
interruption. This rules out depth compatibility as the immediate cause; the
remaining bounded suspects are the color/texture submission or the external
Simulator Metal execution boundary. No visual, audio, or playability proof was
obtained. See
`docs/evidence/R1/r1-direct-fixture-no-depth-2026-08-20.md`.

The color-only follow-up removed the generated texture and sampler as well,
using a solid fragment shader with the same generated vertices and drawable.
It still logged one Direct draw with depth disabled, then produced the same
Metal command-buffer error and SimMetalHost interruption. The failure is now
localized below depth, texture, and sampler state at the CAMetalLayer drawable/
Simulator Metal execution boundary; no renderer semantic change is justified.
The Simulator remained blank/non-audible, with no visual, audio, or playability
proof. See
`docs/evidence/R1/r1-direct-fixture-color-only-2026-08-20.md`.

The offscreen follow-up rendered that same color-only/no-depth fixture into a
private BGRA8 target and skipped `presentDrawable`. The command buffer still
aborted with Metal code `1` and completion status `5`, followed by the
SimMetalHost interruption. This rules out CAMetalLayer present ownership as the
immediate cause; the next bounded split is custom vertex-buffer/layout versus
the Simulator Metal render execution boundary. See
`docs/evidence/R1/r1-direct-fixture-offscreen-2026-08-20.md`.

A corrected-shader fresh-pack replay repeated the offscreen result: the
generated fixture was accepted, the corrected color-only/no-depth draw reached
the private target, and Metal still aborted with command-buffer code `1`,
completion status `5`, and a SimMetalHost interruption. This supersedes the
earlier provisional interpretation without changing the conclusion that
present ownership is not the immediate cause. The unactivated no-buffer probe
was removed and is not evidence. See
`docs/evidence/R1/r1-direct-fixture-offscreen-corrected-shader-2026-08-20.md`.

Metal API validation then exposed and the source corrected three concrete pass
contracts: the generic pipeline now declares `Depth32Float`, no-depth probes
omit an explicit nil depth-state setter, and the touch overlay uses an
`Always`/no-write depth state while isolated diagnostics exclude it. A fresh
validated-pack replay with validation enabled now reports repeated offscreen
command-buffer completion status `4` with no validation error, command-buffer
abort, or SimMetalHost interruption. This is a partial R1 command-contract
pass, not image or playability proof. See
`docs/evidence/R1/r1-metal-validation-contract-fixes-2026-08-20.md`.

The corrected normal drawable/present replay then reached the generated Direct
fixture and logged `draws=1`, `triangles=2`, `depth=gequal/write`, and
`final-target=same-pass` under Metal API validation without a validation error,
command-buffer abort, or XPC interruption. This is a partial R1 native
submission/present-liveness pass only: the Simulator remained blank/non-audible
and no image, audio, or playability proof was obtained. See
`docs/evidence/R1/r1-direct-fixture-normal-present-validation-2026-08-20.md`.

A trigger-scoped drawable readback then resolved the remaining diagnostic
ambiguity without changing normal presentation. With the explicit readback
trigger pre-seeded, the layer was made copyable for one run; the fresh
validated-pack replay produced a 1210x834 PPM whose expected fixture rectangle
contained 31,408 red and 31,408 black pixels, with a zero-byte fault log and no
Metal validation or command-buffer error. This is partial R1 GPU image evidence
only: the Simulator remained blank/non-audible, so it is not title/menu,
audio, playability, iPhone-parity, or physical-device proof. See
`docs/evidence/R1/r1-direct-fixture-gpu-readback-2026-08-20.md`.

The bounded macOS reference trace now closes the target-model ambiguity for the
matching 14-qword Jak 1 glyph: bucket `[67] debug` uses plain DirectRenderer,
`offscreen=false`, FBO 65, and a texture hit/non-placeholder; the post-flush
record reports one draw and 44 triangles. A same-phase desktop capture shows
the title scene with the logo and `PRESS START`. This establishes the
D0-NORMAL branch and rejects importing Jak 2's ProgressRenderer target model,
but the individual glyph's later composition event remains unisolated. See
`docs/evidence/R1/r1-d0-macos-glyph-attribution-2026-08-20.md`.

A fresh real mobile route also accepted one native Sprite3 group with CPU
raster skipped: texture `0x2bc1`, 64x64, alpha max 128, 2,615 nonzero-alpha
texels, and the maintained source-over/GEQUAL-2 diagnostic contract. Its
selected bounds were mostly outside the drawable (`0.975..1.266`), so the
1210x834 readback is liveness evidence only, not visible Sprite3 proof or a
state-parity pass. The next comparison must select a meaningfully in-bounds
real group and match it to macOS before changing mapping. See
`docs/evidence/R1/r1-native-sprite-probe-readback-2026-08-20.md`.

A follow-up with the validated pack staged before Metal selected an in-bounds
native group 0/index 0 using the same `0x2bc1` texture, bounds
`(0.437,0.484)..(0.618,0.789)`, and 8,605 non-clear pixels in the candidate
readback region. This is stronger native Sprite3 liveness, but the requested
`village1.DGO` was absent from the staged pack and the run left a 1,395-byte
fault log, so it is not clean Village1 or playability proof. Same-phase macOS
state parity and the DGO route dependency remain open. See
`docs/evidence/R1/r1-native-sprite-inbounds-2026-08-20.md`.

A fresh macOS Sprite3 trace now makes the parity boundary explicit: its first
world group is TBP `0x24f2`/9458 with `blend=2`, `ztest=2`, `zwrite=false`,
`alpha-test=2`, and `aref=0.000`, while the mobile in-bounds candidate is TBP
`0x2bc1`. The state shape is compatible, but the texture phases differ and
the mobile route was not a clean Village1 run; no alpha/depth mapping change
is justified. See `docs/evidence/R1/r1-sprite3-phase-mismatch-2026-08-20.md`.

A clean normal-Metal replay with the validated pack then proved the writable
input bridge independently: Start was consumed after
`title-play received wait`, the progress screen reached `incoming complete`
and `normal`, and later Cross/Left triggers were also consumed. Metal remained
alive through large TIE/TFRAG submissions with a zero-byte fault log, but no
New Game or Village1 transition followed the Cross presses. The next
falsifiable comparison is the identical sequence in SDL-only mode, to separate
the shared title/progress state from the normal-Metal host path. See
`docs/evidence/R1/r1-ios-metal-cross-route-boundary-2026-08-20.md`.

The follow-up isolated a second mobile dependency: the normal-Metal path was
running the diagnostic VU1/TFRAG interpreter even though native Metal owned the
scene. Empty/incomplete fragment data repeatedly hit the interpreter safety cap
with zero GIF output, starving route progress. The native path now disables that
CPU/VU diagnostic fallback by default; SDL-only and explicit
`OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1` runs retain it for investigation. A fresh
normal-Metal replay recorded `cpu-diagnostic-path=disabled`, zero VU caps, and
continued chain liveness, but the corrected two-Cross route still did not reach
Village1. This is a partial R1 liveness improvement, not a playability or visual
pass. See `docs/evidence/R1/r1-native-metal-vu-policy-2026-08-20.md`.

The follow-up route discriminator also added a writable `ottsel-press-down`
edge and delivered Start, Cross, four Down presses, and a final Cross through
the same pad seam. The runtime consumed those masks with a zero-byte fault log,
but still did not enter Village1/Training. The remaining open dependency is
therefore the progress/memory-card transition itself or its normal-Metal
interaction; missing synthetic D-pad input is ruled out. This remains blank,
non-audible diagnostic evidence, not iPad playability proof.

The 2026-08-20 Jak 2 ARM64 transfer research is supplemental here: its shared
emitter/ABI/bridge and SDL remap/teardown tests are candidates for bounded
J2R1/I1 regressions, while its MAP_JIT path, inventory-only AOT work, and
frame-clear Metal shell do not alter the first open renderer gate. No external
repository was merged and no signed-native foundation was reopened.

The documented writable synthetic-input seam was isolated from that renderer
boundary. In SDL-only mode, START and Cross trigger files were consumed,
`scePadRead` logged the corresponding button masks, and the title state logged
the START edge/progress transition with an empty fault log. A Metal launch with
the diagnostic Village1 trigger pre-seeded also consumed the trigger and called
`(bg 'village1)`, but produced no Sprite3 native line before the bounded run
ended. This is input/route diagnostic evidence only; the Simulator remained
blank and non-audible. See
`docs/evidence/I1/i1-synthetic-trigger-metal-isolation-2026-08-20.md`.

AU1 now has a real playback substrate increment. The signed iPad SDL diagnostic
run opened the output-only SDL stream, observed callbacks after 1,024 frames,
and recorded repeated 48,000-frame mixer windows. PCM remained zero because the
iOS IOP/OVERLORD sound-bank request path is still absent; two pre-existing
RAMDISK invalid-read diagnostics also remain in that run. This is not an AU1 or
P2 pass. See `docs/evidence/AU1/au1-playback-substrate-2026-08-20.md`.
The next opt-in probe loaded validated user-pack `SBK/COMMON.SBK` through the
real `snd_BankLoadEx` path at the `fake_iso` 20,480-byte offset, requested sound
0 with handle `1`, and recorded a nonzero mixer peak of `2831`. A malformed raw
`TESTTONE.SBK` probe correctly asserted before this correction, so that failure
remains part of the boundary evidence. This is still not IOP/OVERLORD or AU1
completion; see `docs/evidence/AU1/au1-user-bank-probe-2026-08-20.md`.
`docs/reports/2026-08-19-ipad-iphone-blocker-investigation.md`,
`docs/15-macos-to-mobile-goal-loop.md`, and `docs/BOT33_PROMPT.md`.

The follow-up fake-ISO probe now exercises the user-pack bank through
`FS_LoadSoundBank`, requests sound 0 with handle 1, and records PCM peak
`2831`; this remains a bounded AU1 substrate proof rather than full
IOP/OVERLORD audio completion. See
`docs/evidence/AU1/au1-fake-iso-user-bank-2026-08-20.md`.

The lifecycle increment now pauses and resumes the SDL output stream on
background/foreground, neutralizes input on the same event, and makes repeated
notifications idempotent. A Simulator replay logged pause, resume, continued
mixer windows, and a zero-byte fault log. This is still not AU1 completion;
physical route/interruption and audible acceptance remain open. See
`docs/evidence/AU1/au1-lifecycle-pause-resume-2026-08-20.md`.

The opt-in MUS probe now initializes the user-pack MUS fake-ISO root and calls
the maintained Jak 1 `FS_LoadMusic` path for `VILLAGE1.MUS`; the signed
Simulator run returned handle `2` and recorded nonzero PCM peaks through later
mixer windows with a zero-byte fault log. This remains an AU1 substrate proof,
not full IOP/OVERLORD or VAG-stream completion. See
`docs/evidence/AU1/au1-mus-user-bank-2026-08-20.md`.

The VAG probe now parses `VAGDIR.AYB`, discovers entry `FUCVICTO`, opens the
validated `VAGWAD.ENG` at offset `0`, and reads a `0x6000` first chunk through
the fake-ISO stream layer with a valid `VAGp` header. This is still only VAG
discovery/first-chunk proof; decoded voice submission and continuous stream
playback remain open. See
`docs/evidence/AU1/au1-vag-first-chunk-2026-08-20.md`.

The follow-up VAG diagnostic now submits the valid first chunk from long-form
`SA3INTRO` to the maintained `snd::Voice` ADPCM decoder at 48 kHz. Runtime
confirmed voice submission and continued mixer callbacks with a zero-byte fault
log, but the blank Simulator did not establish sustained nonzero VAG PCM or any
audible result. Chunk progression, physical routes, and human listening remain
open. See `docs/evidence/AU1/au1-vag-voice-submission-2026-08-20.md`.

The following VAG run keeps one WAD handle across eight successive
`FS_BeginRead` calls, retains 196608 bytes, and submits the concatenated
header-stripped stream to the diagnostic voice. This proves bounded multi-chunk
transport only: PCM was `1` at window 10 and `0` later on the blank Simulator,
so decoded continuity, audible correctness, and device routes remain open. See
`docs/evidence/AU1/au1-vag-chunk-progression-2026-08-20.md`.

An attempted direct `snd::Voice::Run()` preflight returned only zero/near-zero
samples and later caused a signal-11 fault log, so that unsafe probe was
removed. The retained app path submits the voice without pre-consuming it;
decoder semantics now require an isolated fixture runner or bounded streaming
voice. See `docs/evidence/AU1/au1-vag-preflight-revert-2026-08-20.md`.

The guarded VAG run corrected the signed-volume overflow and marked the finite
diagnostic buffer's final ADPCM block as non-looping. The isolated runner peaked
at `11502`; the signed Simulator run recorded mixer peaks `7670`/`7671` with a
zero-byte fault log. Later windows went silent when the finite buffer ended, so
explicit refill/loop state and all audible/device claims remain open. See
`docs/evidence/AU1/au1-vag-guarded-pcm-2026-08-20.md`.

Bank, MUS, and VAG diagnostic flags are now independent. A VAG-only fresh
Simulator launch loaded eight chunks and recorded PCM peaks `7684` and `5321`
with a zero-byte fault log. The finite buffer then exhausted, so this remains
nonzero Simulator PCM—not audible correctness or continuous stream playback.
See `docs/evidence/AU1/au1-vag-independent-probe-2026-08-20.md`.

The VAG diagnostic now sizes from the header and preloads all 175 aligned WAD
chunks for `SA3INTRO` (4298096 data bytes). The VAG-only run held nonzero PCM
through mixer window 70 with a zero-byte fault log. This is sustained decoded
PCM in a bounded preload, not true refill/looping or audible/device proof; the
next implementation boundary is a producer-consumer refill. See
`docs/evidence/AU1/au1-vag-full-preload-2026-08-20.md`.

The focused audio regression now also asserts the `0x3fff` diagnostic volume
and finite-buffer end guard (`MacHostAudioPolicy.*`, 2/2), preventing the
overflow and out-of-bounds regressions from returning while refill work stays
separate.

The maintained `snd::Voice` now has an optional sample-word bound; legacy
callers retain the prior unbounded behavior, while the VAG diagnostic supplies
the retained-buffer length. Its source regression passes with the existing
audio policy tests. This is a safety prerequisite for producer/consumer refill,
not refill completion.

The opt-in VAG refill probe now seeds eight aligned chunks, starts a guarded
diagnostic voice over a preallocated shared sample, and refills the remaining
167 chunks from one WAD handle. A fresh blank-Simulator run logged producer
completion at all 175 chunks / 4,298,096 bytes, nonzero mixed PCM through later
windows, and a zero-byte fault log. This is bounded diagnostic producer/refill
evidence only: it is not the product stream queue, audible acceptance, route,
physical-device, or playability proof. See
`docs/evidence/AU1/au1-vag-refill-probe-2026-08-20.md`.

The native Sprite3 upload now matches the maintained Jak 1 2D shader's
projected-area alpha fade (`min(sx * sy * inv_area, 1)`) through a shared
ROM-free helper. The focused Sprite3/Direct/input regression set passes 10/10,
the signed iPad build verifies, and a fresh launch has a zero-byte fault log;
that launch exited before the Sprite3 phase, so no visual or live alpha claim
is made. R1 remains open pending a stable trigger-gated Village1 replay and
same-phase native/desktop comparison. See
`docs/evidence/R1/r1-sprite3-alpha-fade-2026-08-20.md`.

A clean route comparison now removes stale-log ambiguity: SDL-only mode reaches
Village1 from the validated pack, while a fresh Metal-enabled launch records
only startup/audio lines before the bounded window ends. Both fault logs are
zero bytes; no `SDL_EVENT_QUIT` or Sprite3 phase was observed, and no lifecycle
workaround is justified. This is an open Metal/Simulator startup boundary, not
R1 visual proof. See
`docs/evidence/R1/r1-metal-startup-boundary-2026-08-20.md`.

Boot-phase markers refine that boundary: a fresh Documents pack run stops in
`select_ios_iso_data_dir`, while a durable-pack-only comparison reaches data
selection, sound-probe completion, low-EE protection, and kernel-global setup
before the existing long linker/Simulator boundary. This separates F1 pack
validation/copy cost from the later Metal/R1 route; neither run produced
Sprite3 proof or a nonzero fault log.

The same 1.5G pack validates on host in 6.6s and imports/reaches Village1 in a
fresh SDL-only Simulator run at about +8s, remaining alive at +20s. Therefore
F1 data validation is viable; the normal-Metal failure during that transaction
is a Simulator/Metal startup boundary, not evidence that the pack is malformed.

An opt-in `OTTSEL_PREPARE_DATA_BEFORE_METAL=1` probe moved validation and
durable promotion ahead of Metal creation. One fresh iPad Pro 11-inch (M4)
Simulator launch then logged the complete boot sequence through kernel globals
and save-root setup, reached `GAMEPLAY: enter title`, and emitted the native
Sprite3 candidate/ownership trace with an empty fault log. The Simulator
remained blank and non-audible, so this is diagnostic liveness only—not visual,
audible, title/menu, or playability proof. Existing missing-`title`/`village1`
FR3 warnings remain visible in the log. R1 image parity and F1 legal Files
delivery remain open; see
`docs/evidence/R1/r1-pre-metal-user-data-preflight-2026-08-20.md`.

The mobile gamepad owner now handles `SDL_EVENT_GAMEPAD_REMAPPED` by clearing
the selected pad state, closing the stale mapping, and reselecting the owner;
sentinel and stale instance IDs are covered by a portable regression. The
focused 12-test set, signed iPad build, and strict signature pass. Physical
remap/reconnect acceptance remains open and the blank Simulator is not evidence
for it. See `docs/evidence/I1/i1-gamepad-remap-2026-08-20.md`.

**Audit notes:** this reconciliation found a stale public README, an older
status date, and duplicate historical S2.2 rows that can be mistaken for the
live plan. The README and index now point here; the rows remain below for
traceability. This audit did not run a new game build or claim a new runtime
pass. The follow-up investigation also corrected one inference: the captured
packet exactly matches the Jak 1 font-glyph template, but Jak 1 bucket 67 uses
plain `DirectRenderer`; the Jak 2 `ProgressRenderer` offscreen model is not yet
attributed to this packet.

---

## Historical log — last consolidated 2026-08-17

Repo: `ottsel`
Mode: Phase 2 build loop — **strategy reset: fr3 + upstream renderers (see docs/14-roadmap-to-playable.md)**

> **2026-08-17 (BOT30): JAK IS ALIVE AND STABLE IN VILLAGE1 on macOS
> (native arm64 host gk).**  The "engine-connection crash" wall fell after
> five root causes, all ARM64 codegen/linker/kernel-mapping bugs, each
> pinned with lldb/probe ground truth and an A1.0 regression (24-27):
> 1. `add_vf` emitted integer ADD .4S instead of FADD .4S.
> 2. Scalar int<->float conversions read `Rn(dst)` instead of `Rn(src)`.
> 3. The ADRP static-ref patchers (compile-time + runtime) wrote raw lo12
>    into SCALED LDR imm12 fields — every rip float/vector constant read
>    zeros (compiled sin/cos returned 0 -> NaN camera -> a NaN camera
>    line-sphere probe flooded the 256-slot *collide-list* with 1734
>    items, trampling type method tables -> the EE 0x3075274 dispatch
>    crash BOT29 misread as engine-connection corruption).
> 4. `load8u/load16u +s32` double-applied the field offset (joint indexes
>    read from base+2*offset).
> 5. The kernel-asm reg map sent `rbp` to X29 (FP) instead of X26, so
>    thread-suspend never saved X26 — any GOAL local in x26 died at the
>    first (suspend) (title-intro spool called #f).
> Boot -> title -> `(bg 'village1)` trigger -> Jak spawns -> village1
> active: zero collide overflows, camera tracking at real world coords,
> 5-minute soak PASS.  Build discipline: after ANY goalc change run
> `rm out/jak1/obj/*.o` + `(mi)` (546 targets) — GROUP:kernel+GAME.CGO
> alone leaves TIT/VI1 DGO level code stale.  Evidence:
> `docs/evidence/M1/m1-collide-list-overflow.md`.
>
> **Retail flow (same day): VIS + STR streaming WORK** — untriggered boot
> loads VI1.VIS via the real overlord RAMDISK and streams the attract STR
> demos; synthetic input drives the title (START/X via
> /tmp/ottsel-press-start | echo hex > /tmp/ottsel-press-button).
> Retail-only blocker: the auto-save process spawn after new-game jumps
> to NULL (pc=0).
>
> **CORRECTION + root cause #6 (same day):** the user's screenshot showed
> a BLACK screen — all prior "playable/visible" language was CPU-telemetry
> only.  Chasing the screenshot found bug #6: the pext (punpck) family was
> ported as UZP (deinterleave) instead of ZIP (interleave), so
> matrix-transpose! fed GL a garbage camera matrix.  Fixed (A1.0 test 28).
> **User-verified after the fix: village1 renders — correct perspective,
> real textures (huts/palms/sea).**  Two visible defects remain and are
> the current wall: (1) everything tinted deep blue (time-of-day/color
> path), (2) no input response ("stuck" at spawn camera).  Precise next
> steps: docs/BOT31_HANDOFF.md.

> 2026-08-16: read `docs/14-roadmap-to-playable.md` first.  The renderer
> strategy changed: the software-rasterizer/VU1-interpreter track is
> retired as a product path; rendering adopts upstream's fr3 mesh assets +
> C++ bucket renderers (proven live on this Mac, native arm64, GL 4.1).
>
> **M1 PARTIAL PASS (2026-08-16): Jak 1 BOOTS TO THE DISPLAYED TITLE on
> macOS, native arm64, real renderer/IOP/audio stack, ~15 s, zero faults.**
> Three root causes fixed (icache invalidation at RX flips; per-slot stub
> sealing; low-memory PROT_READ) — `docs/evidence/M1/m1-title-boot.md`.
> The long-standing nondeterministic link-phase SIGILL is root-caused
> (missing sys_icache_invalidate) and fixed on both host and iOS runtimes.
> Remaining for full M1: input/audio verification + title→village1
> progression + perf sanity.
>
> BOT24 (same day): the 150/s text reload loop is fixed — the ARM64
> `_stack_call_arm64` trampoline clobbered C return values with saved
> arg 0 (every stack-arg builtin returned its first argument).  Text
> loads: 127,001 → 2 per boot; title boots in ~10 s, music banks load,
> village1 preloads, zero crashes.  `docs/evidence/M1/m1-text-loop-fix.md`.

Read `docs/15-progress-audit.md` before resuming. The Simulator RX-blob path is
a research transport, not the H2.5 product execution model.

## Gate board

| Gate | Title | Status | Evidence |
|---|---|---|---|
| G0–G5 | Phase 1 research (see archive below) | PASS | `docs/` 00–12 |
| **H1** | **ARM64 GOAL codegen works on host** | **PASS (2026-08-07)** | `docs/evidence/H1/` |
| **H2** | **No-emit runtime on host** | **PASS (2026-08-07, host)** | `docs/evidence/H2/` |
| **H2.5** | **Packaging form decision** | **PASS (2026-08-07)** | `docs/evidence/H2.5/`, `docs/10-code-packaging-and-signing.md` |
| H3 | Jak 1 host AOT boot proof | **PASS (2026-08-08, host)** — GOAL kernel dispatcher executes and loops under RX, no faults; evidence captured | `docs/evidence/H3/dispatcher-loop-2026-08-08.md`, `docs/evidence/H3/boot-dispatcher-loop-2026-08-08.log`, `docs/13-current-state.md`, `docs/BOT4_HANDOFF.md` |
| S1 | Simulator shell loads runtime | **PASS (2026-08-08)** — iPad Pro 11-inch (M4) Simulator launches the shell; the no-emit ARM64 runtime maps EE RW, links all 8 KERNEL.CGO objects with RW->RX flips, boots to the GOAL kernel dispatcher loop (48,200+ iterations, zero faults). Fix: register pc-prof/PC-port exports on iOS + full-table intern fallback scan; gated-error no-crash-loop safety net retained. | `docs/evidence/S1/s13-dispatcher-loop.md`, `docs/evidence/S1/s13-dispatcher-loop.log|png`, `docs/evidence/S1/s11-*`, `docs/evidence/S1/s12-*` |
| S2.0 | Metal shell spike | **PASS (2026-08-09)** — real CAMetalLayer pipeline presents the shell log surface; explicitly not a game frame | `docs/evidence/S2/s20-metal-spike.md`, `s20-*` |
| S2.1 | GAME.CGO engine integration | **RESEARCH CHECKPOINT (2026-08-09)** — all 346 objects compile; encoding validator passes; Simulator RX-blob linker reaches object 204, then deterministically ret/jumps to EE base in the `make-village1-light-kit` chain. Pause after preserving the active dirty probe; A1 is next. | `docs/evidence/S2/s21-game-cgo-arm64.md`, `docs/evidence/S2/s21-game-cgo-simboot.md`, `s21-*` |
| **A1.0** | **Semantic ARM64 regression layer** | **PASS (2026-08-09)** — 14/14 semantic assertions (load-vs-store, widths, scaled/unscaled, SP->xzr, ABI arg order, LR save/restore incl. 2-level nesting) with negative proofs; KERNEL.CGO 86,016 + GAME.CGO 3,829,760 words still validate; object-204 fault localized deterministically below the boot loop via a bounded GOAL->GOAL call trace (chain: mood-tables top-level -> 0x23d8554 -> 0x23d8004 -> 0x5ab0e4 -> 0x5fc574/0x5fd9d4 -> 0x5a9234 x3 from site 0x23d8408 -> ret/jump to EE base). | `docs/evidence/A1/a1-semantic-regressions.md`, `docs/evidence/A1/a1-object204-bounded-trace.md`, `docs/evidence/A1/a1-mood-tables-bounded-trace.log`, `docs/evidence/A1/a1-bounded-call-trace-probe.patch` |
| **A1.1** | **Real OpenGOAL code in signed Mach-O `__TEXT`** | **PASS (2026-08-09)** — real KERNEL.CGO slice (string=, name=, ref, last, nmember) linked into OttselShell __TEXT via the offline linker (tools/ottsel_a1_1), codesign verifies, all 7 checks execute on the iPad Simulator with captured output; no runtime instruction relocation. | `docs/evidence/A1/a11-signed-text-slice.md`, `a11-simulator-slice-pass.log` |
| **A1.2** | **Product execution-permission proof** | **PASS (2026-08-09)** — source audit (AOT path: no mprotect(PROT_EXEC)/MAP_JIT/code-copy/instruction-patching; runtime linking limited to writable data + function-pointer tables); negative proof: slice PASSES with KERNEL/GAME.CGO removed from the bundle; Mach-O/codesign/runtime evidence captured. | `docs/evidence/A1/a12-execution-permission-proof.md` |
| **A1** | **Signed-native OpenGOAL execution** | **PASS (2026-08-09)** — real OpenGOAL artifact executes from signed Mach-O text on the iPad Simulator with no runtime-created executable GOAL code (A1.0 + A1.1 + A1.2). | `docs/evidence/A1/*` |
| **S2.1** | **Complete game engine integration** | **VERIFIED STABLE TITLE BOOT (2026-08-15)** -- the previous deterministic enter-state fault is FIXED.  Root cause: `target-title` (title-obs.gc, a TIT.DGO object) was never linked -- the DGO loader skipped the PS2-v3 title objects as "non-GOAL", and GAME.CGO has no title-obs -- so `(go target-title)` stored 0 and enter-state called EE+0.  Fix (runtime-side): ship the recompiled TIT.DGO (no-emit title-obs/static-screen), accept the v3 "GOAL"-magic block tag in the DGO serve, and complete v3 links synchronously in link_begin.  Verified: zero faults, title-obs top-level runs, full process tree (24 nodes), dispatcher past 121k iterations, village1 load boundary handled ROM-safely.  S2.1 engine integration is at the renderer-ready boundary; S2.2 (first Jak frame via Metal) is next. | `docs/evidence/S2/s21-bot13-titlefix.md`, `s21-bot13-titlefix-*` |
| S2.2 | First real Jak 1 frame via Metal | **IN PROGRESS (2026-08-16)** — present-path regression fixed (c6b7104); the port's disabled mips2c `ln` calls are restored and GAME.CGO recompiled (7d44395a) so the game's tfrag draw pipeline runs (TFASM fires, tfrag-work draw-state set); the tfragment's stored dma-chain (the per-draw VIF stream incl. the frag-list header at VU 0x0) is located and an SPR->VIF1 scaffold parses it into VU memory.  Composed frame still needs the full VIF stream parse (DIRECT-embedded commands + far geometry UNPACKs) and the vis-list resolution (the port's draw-node-cull is disabled -> vis bit 0). | `docs/evidence/S2/s22-bot21-present-path-fixed.md`, `s22-bot21c-ln-restored.md` || S3 | Touch MVP + lifecycle | BLOCKED ON S2 | — |
| S2.2 | First real Jak 1 frame via Metal | **UNBLOCKED — LEVEL ACTIVATES (2026-08-16, BOT22)** — the "level never activates" blocker is RESOLVED and its premise disproven: the bsp write always landed (the probes read one word short — `bsp` is at ref+44, the inline kheap is 16-aligned at mem+32; 0x3fdd674 is `level-default`, not the loading level).  The real chain: the level pipeline is healthy through `'loaded`; the game was waiting for START on the title screen; no input path existed in the headless shell; and the title intro can never play (iso_data has NO STR files, so the spooled logo/ndi anims never load).  Fixes (runtime/shell only): synthetic pad bridge (taps/keys/file trigger press START), an EE-thread `(bg 'village1)` driver (the game's own debug boot-to-level entry), `play? = #f` (the genuine bg-flow state) and `*artist-all-visible* = #t` (the engine's artist toggle) for the no-VIS fallback.  Verified live, zero faults: village1 slot1 `'active` (bsp=0x2ef80d4), title discarded, background-work fills every frame (tfrag-count=1, tie-count=3 = the bsp's trees), the restored tie-ln RUNS with vis0=0xffffffff.  Remaining for the composed frame: the shell VU1 data path (VU1STAT: 2080 runs, zero GIF output — frag list empty at top=0; the tie microcode is not yet embedded) = Track B steps 2–4. | `docs/evidence/S2/s22-bot22-level-activation.md`, `s22-bot22-activation.log`, `s22-bot22-village1-active.png` || S3 | Touch MVP + lifecycle | BLOCKED ON S2 | — |
| R1 | ROM-safe handoff package | BLOCKED ON S3 | — |

## H1 result (2026-08-07)

- **PASS** — ARM64 `goalc` function codegen path works on Apple Silicon host.
- Pin: `open-goal/jak-project` @ `641fb572e876750d8618434d9f7c1a531b43b366` (unchanged from Phase 1).
- Patch: `patches/h1-arm64-goal-function-codegen.patch` (applies clean, verified).
- Proof: `ottsel-h1-proof` compiles and executes 5 GOAL functions (add/const/
  submul/branch/move) through `do_goal_function_arm64`; no NYI in exercised IR set.
- Evidence: `docs/evidence/H1/{commands,summary,arm64-abi,run-h1-proof,build-h1,cmake-configure}.md|log`
- Worktree: `out/jak-project` (build dir `out/jak-project/build/h1`, gitignored).
- Honest boundary: symbol/function-address IRs (`IR_FunctionAddr`,
  `IR_StaticVarAddr`, symbol links) remain NYI — deferred to H2's no-emit
  code model. `defun` top-level registration still needs them; H1 proves
  ordinary function bodies.

## H2 result (2026-08-07)

- **PASS (host)** — AOT ARM64 GOAL executes from RX-only mappings with
  permission + no-write evidence; `call_goal` ARM64 wired and proven;
  static C-export shim proven; listener code-receive compile-disabled under
  `OTTSEL_NO_EMIT`.
- Patch: `patches/h2-noemit-runtime-host.patch` (includes H1 changes; applies clean).
- Proofs: `docs/evidence/H2/run-h2-{proof,bridge,shim}.log` — all PASS.
- Emit-site checklist: `docs/evidence/H2/emit-site-checklist.md`.
- Also fixed in H2: ARM64 GPR/vector register-id collision (vectors now 32..63).
- Deferred to H3 (integration, not host-blocking): kernel function objects on
  the GOAL heap, mips2c static table, full EE code/data split, offline prelink
  of symbol/function links, first real GOAL boot.

## H2.5 result (2026-08-07)

- **PASS** — packaging decision recorded in `docs/10-code-packaging-and-signing.md`.
- **Decision:** product path = **generated native code compiled by clang into
  the signed app (Option 2/3)**. Option 1 (runtime RX blob) is research-only,
  not a ship path.
- Proof: real AOT GOAL bytes → `.s` → clang Mach-O (`__TEXT,__text`) → linked
  native executable → runs `aot_loop(10)=45` → code-signs. 3/3 cases.
- Evidence: `docs/evidence/H2.5/run-h25-proof.log`, `{add2,submul,loop}.{s,o}`,
  `aot_loop_native`, `commands.md`.
- Consequence for H3: AOT artifacts are self-contained generated-native images
  with offline-resolved links, not runtime-loaded executable blobs.

## H3 status (2026-08-07, first iteration)

- **Compile slice PASS:** 5 real Jak 1 kernel objects compile for ARM64
  (gcommon, gkernel-h, gstring-h, gstring, dgo-h) through the real codegen
  path with the no-emit data-slot symbol design.
- Patch: `patches/h3-jak1-kernel-arm64-compile.patch` (includes H1/H2/H2.5).
- Compiler fixes this iteration: ISA-aware `Allocator_v2`, ARM64 div/mod
  (SDIV/UDIV/MSUB), int128/vector asm IRs, int<->float, `static_addr` ADR
  semantics + offline patching, symbol data-slot relocations, SP spill asserts.
- **ISO extraction DONE:** legal ISO extracted to `out/jak-project/iso_data/jak1`
  (CGO/DGO/MUS/STR; SCUS-97124); gitignored.
- **Host runtime boots on arm64:** `gk` builds with `OTTSEL_NO_EMIT`, launches
  SDL/OpenGL (M1), stops only for missing compiled level data (fr3).
- **Historical checkpoint:** no-emit object loader in `gk` (data-only relocs,
  RX-after-load), linking full kernel GOAL against C-kernel externs, and first
  real GOAL entry were not yet done at this point. The later H3/S2 sections
  supersede this status.

## H3 status (2026-08-08, second iteration)

- **Boot reaches GOAL top-level entry:** `gk` boots with the no-emit runtime
  (RW EE map, code flipped RX post-link, kernel links via data-only relocs),
  and `call_goal_on_stack` enters the ARM64 top-level. Process then SIGILLs
  (rc=-4) on an unpatched cross-segment `mov-fa` ADR (`identity` function is in
  a different segment than the top-level; `patch_arm64_static_ref` only handles
  same-segment refs). Full detail: `docs/evidence/H3/boot-progress.md`.
- Fixed: ARM64 C-export stub bytes, `_arg_call_arm64` target read, on-stack
  helper restore, goal-stack 16-byte alignment, RW EE map + post-link RX flip
  with correct (16KB) page size.
- **Remaining:** cross-segment ARM64 function/static ADR resolution at AOT
  finalize; then the top-level can set `kernel-dispatcher`.

## H3 status (2026-08-08, fourth iteration — GOAL entry proven)

- Fixed `load32u_gpr64_gpr64_plus_gpr64` in `goalc/emitter/IGenARM64.cpp`
  (missing option bits; emitted invalid `0xb8760801` instead of
  `ldr w1,[x16,x22,sxtx]` = `0xb876ea01`).
- **PASS** — full boot: 8/8 KERNEL.CGO objects link, top-levels run under RX,
  `Got correct kernel version 2.0`, `kernel: machine started`, stub arenas
  A+B RX, and the GOAL `kernel-dispatcher` (fptr `0x70001a5384` in gkernel
  RX main code) executes and loops with zero faults. Runs ended via
  window-close EXIT, not crash.
- Patches regenerated from the pin: `patches/h3-jak1-host-boot.patch`
  (43 files, `git apply --check` verified on a fresh pin worktree).
- Operator constraints recorded: no fullscreen test windows
  (`display-settings.json` set to Windowed; source default changed), one
  `gk` process at a time.
- Evidence: `docs/evidence/H3/dispatcher-loop-2026-08-08.md` +
  `boot-dispatcher-loop-2026-08-08.log`. Honest boundary: dispatcher pool is
  idle (no listener/GAME.CGO), so no game processes yet — S1+ drives those.

## H3 status (2026-08-08, third iteration — handoff)

- Cross-segment function addresses now encode as `ADRP+ADD` (patched by the
  runtime linker), fixing the previous `adr` ±1MB range failure. The top-level
  entry now starts with valid `adrp x0; add x0,x0; sub x0,x0,x22`.
- The process still exits **SIGILL (rc=-4)** at a deeper instruction. The
  faulting PC is unknown; finding it is the next agent's first task.
- Full state, reproduction commands, and the next-bot goal are in
  `docs/13-current-state.md` and `docs/BOT3_HANDOFF.md`.
- Bot 2's session is complete; the repo is documented for continuation.

## Phase 1 archive (research)

- Verdict: CONDITIONAL GO — `docs/02-execution-model-verdict.md`.
- No game assets in git. ISO moved to `~/ottsel-user/iso/` (outside repo) on 2026-08-07.
- Upstream OpenGOAL: no mobile plans; x86_64 product path.

## S2.1 runtime linking (2026-08-09, updated)

- **PASS milestones this session (all verified on the iPad Pro 11-inch (M4)
  Simulator, no-emit runtime):**
  - GAME.CGO linking advances **55 -> 204 of 346 objects**.
  - Six runtime/emitter fixes: ARM64 stack-variable addressing (IR_GetStackAddr
    used ORR-to-xzr for `mov xd, sp`), mips2c ARM64 dispatch + pre-registration
    (jak1 table, ExecutionContext handler, jalr shim), iOS SIF RPC stubs +
    get-irx-version emulation, `_stack_call_arm64` arg-pair order (format calls),
    LDRH imm12 scaling in the 16-bit static-field load (type size/heap-base),
    and the reusable CGO stage slot (heap pressure).
  - GAME.CGO (3,829,760 code words) and KERNEL.CGO (86,016) revalidate PASS.
- **Current blocker:** object 204 (mood-tables) top-level -> `make-village1-light-kit`
  call chain faults with `signal 10 at pc=0x7000000000` (return/jump to the EE
  base).  All symbol/slot values in the chain verified valid; the deep ret-to-x22
  mechanism needs a live debugger that can breakpoint RX-flipped GOAL pages
  (lldb cannot write software breakpoints there).  Evidence:
  `docs/evidence/S2/s21-game-cgo-simboot.md` (updated 2026-08-09).

## Gate realignment (2026-08-09) — A1 active, per docs/15-progress-audit.md

The S2-first loop was stale. The signed-native execution model selected at
H2.5 must be proven before more renderer/touch work. The RX-blob Simulator
transport is diagnostic-only; it is not the product execution path.

| Gate | Title | Status | Evidence |
|---|---|---|---|
| R0 | Recover and normalize the active checkpoint | **DONE (2026-08-09)** — probes preserved as patch artifacts under `docs/evidence/A1/r0-call-trace-probe-*.patch`, stripped from product sources; docs agree on A1 | `docs/evidence/A1/r0-call-trace-probe-*.patch`, loop log |
| **A1.0** | Semantic ARM64 regression layer | **ACTIVE** — extend the H1/H2 harness with focused tests for the known legal-but-wrong defect classes; reduce the object-204 failure below the full boot loop | — |
| A1.1 | Real OpenGOAL code in signed Mach-O text | not started | — |
| A1.2 | Product execution-permission proof | not started | — |
| S2.1 | Complete engine integration (after A1) | paused at object 204 (RX-blob diagnostic) | `docs/evidence/S2/s21-game-cgo-simboot.md` |
| S2.2 | First real Jak 1 frame through Metal | not started (after A1 + S2.1) | — |
| S3 | Touch MVP + lifecycle | not started | — |
| R1 | ROM-safe handoff | not started | — |

Known semantic defect classes needing A1.0 regression tests: SP->xzr moves
(IR_GetStackAddr), loads emitted as stores (static_load_f32 STR/Q), wrong
load/store widths (LDRH imm12 scaling), scaled vs unscaled offsets, swapped
ABI argument pairs (_stack_call_arm64), LR/call/return corruption (object-204
value-0 call/return fault).
The latest active-level retry keeps R1 open at the data boundary rather than
advancing the renderer gate. A fresh signed iPad Pro 11-inch (M4) run imported
the validated durable pack, but its `DGO/` family contained `VI1.DGO` while the
runtime requested lowercase `village1.DGO`; the subsequent retry also requested
missing `beach.DGO`. `slot1` therefore stayed `loading`, no
`Displaying level village1 [display-self]` marker appeared, and no active-level
Sprite3 comparison is valid. The Simulator remained blank and non-audible.
This is a concrete pack/runtime naming dependency, not evidence for a texture,
camera, shader, or Metal remap. macOS remains visually promising but audio is
not human-audibly accepted. See
`docs/evidence/R1/r1-active-level-data-boundary-2026-08-20.md`.

The next bounded fix is now test-proven at the DGO loader seam. The iOS loader
maps symbolic Jak 1 requests `village1/village2/village3/beach` to the retail
tokens `VI1/VI2/VI3/BEA`; the focused alias test passed and a fresh signed run
resolved both `vi1.DGO` and `beach.DGO` from the validated pack. Village1
objects linked through `sequence-a-village1`, but the run then reached the
existing GOAL-version assertion at `game/kernel/common/klink.cpp:77` while
linking `beach-vis` from retail `BEA.DGO`. The fault log was 0 bytes. This
advances the route dependency without establishing active-level parity; the
next gate is exact `beach-vis` object-header/version attribution. See
`docs/evidence/R1/r1-dgo-symbolic-alias-and-beach-link-boundary-2026-08-20.md`.
The bounded linker diagnostic then recorded `object= major=0 minor=0` at the
version assertion after the final `beach-vis` response. Because the object name
and header are blank/zero, this is not yet evidence that retail `beach-vis`
itself has an incompatible GOAL version; the next experiment is pointer/name
attribution at that DGO completion boundary. The assertion remains intact.

The following fresh signed run reached and held an active Village1 state before
arming the Sprite3 ledgers: `slot0=loaded bsp=0x2481494`,
`slot1=active bsp=0x2ef8754`. The active mobile producer interval is now valid,
but it remains structurally different from the macOS oracle: mobile emits a
world group of 48 sprites at `TBP=0x2bc1`/`64x64`, plus a 16-sprite TCC=0
color-only group; macOS emits 55 sprites at `TBP=0x24f2`/`64x64` for the
corresponding first world group. Raw span parsing had zero rejected and zero
boundary-stop records, and the fault log was 0 bytes. This is a real active
producer/resource mismatch, not a loading-phase artifact; no speculative
texture remap is justified. See
`docs/evidence/R1/r1-active-village1-sprite-phase-ledger-2026-08-20.md`.

The next source-item replay consumed both Sprite3 phase triggers after repeated
`slot0=active`/`slot1=active` samples. It recorded a real mobile producer stream
of seven groups / 320 world sprites: six 48-sprite groups at `TBP=0x2c8d`,
`PSM=19`, `5x5`, `MSCAL=3`, followed by a 32-sprite zero-TEX group. Source
records had valid header/vector/ADGIF sizes and zero rejected or boundary-stop
records. This rules out the earlier 48+16 result being only a parser artifact,
but the frame-dependent 320-sprite stream is still not phase-aligned to macOS's
55-sprite `TBP=0x24f2` flush. The Simulator was blank and this remains producer
evidence, not playability proof; no texture, camera, shader, or remap change is
justified. See
`docs/evidence/R1/r1-active-village1-source-item-ledger-2026-08-20.md`.

The Sprite3 trigger is now gated to the mobile `village1` camera phase. A fresh
signed replay reached the real `village1 display-self` marker before consuming
the windows. At chain 250, mobile produced a valid 48-sprite `TBP=0x2bc1`
world group followed by a real 16-sprite zero-TEX group; both product and
bucket-67 spans had zero rejected and zero boundary-stop records. A later
stable chain retained `0x2bc1` and added `0x2c8d` 32x32 records. The first
transition matrix was stale/large before settling, so this is now narrowed to
producer/frame-state sequencing or resource-family selection. MacOS still
begins the corresponding world draw at `TBP=0x24f2` with 55 sprites. The
Simulator was blank and non-audible; no visual or playability claim is made.
No remap or renderer widening is justified. See
`docs/evidence/R1/r1-village1-gated-source-frame-state-2026-08-20.md`.

The next bounded native-world retest ran on a resumed active-Village1 process.
It examined 320 `TBP=0x2c8d` bucket-67 candidates; all failed the existing
visibility/size gate, producing `fixture-uploaded=false cpu-product-frame=0`.
No fresh PPM was written and the previous readback hash was unchanged. This
reinforces the current transform/phase attribution boundary and does not
justify relaxing clip/size policy. The Simulator was shut down afterward and
remains blank/non-audible evidence only. See
`docs/evidence/R1/r1-bucket67-native-visibility-retest-2026-08-20.md`.

The macOS-side bounded setup trace is now complete. After Village1
`display-self`, three consecutive Sprite3 frames held a stable desktop setup
and first world draw (`TBP=0x24f2`, 64x64, 55 sprites), while the mobile stable
post-transition ledger used `0x2bc1`/`0x2c8d` and a materially different matrix
camera tuple. This makes the mismatch concrete before native Metal. No camera
sign, shader, TBP remap, or visibility-gate change is justified. The next
experiment is mobile frame/matrix producer tracing immediately before the first
stable MSCAL-3 group. See
`docs/evidence/R1/r1-macos-mobile-sprite-setup-comparison-2026-08-20.md`.

That mobile producer trace is now captured. After the real Village1
`display-self` marker, chains 258–260 held `frame-transfer=9` and
`matrix-transfer=12` but used a transition camera tuple and a first 48-sprite
`TBP=0x2bc1`/64x64 resource; chain 261 changed camera/rotation state while
retaining that first resource family. The desktop reference remains a 55-sprite
`TBP=0x24f2` first world draw with different fog, area, basis, and camera
values. This confirms a producer/frame-state divergence before native Metal,
not a proven Metal visibility defect. The Simulator was blank, fault bytes were
0, and no visual, audio, or playability claim is made. See
`docs/evidence/R1/r1-mobile-producer-setup-trace-2026-08-20.md`.

The follow-up trace removed one suspected decoder issue: mobile now records the
exact `frame-transfer=9`, `matrix-transfer=12`, then first `MSCAL=3` at
`transfer=13` sequence in chains 259–262. The ordering is therefore not the
first mismatch. The next experiment moves upstream to the source frame/resource
producer and first world flush, while preserving the blank Simulator and the
macOS `TBP=0x24f2` reference. The newly rebuilt signed executable was
`36708f747dedbdde0a0d601024ef96ce940a1500016443670aa638f1db3d3b08`; focused
Sprite3 tests remain 14/14, and the mobile fault log was 0 bytes.
The byte-level follow-up narrowed R1 further. Corresponding mobile and desktop
phases have identical raw Jak 1 frame hashes (`0xd73152f7c4464110` and
`0xff7ea32dd0db8048`), but different raw 3D matrix hashes. Mobile phase A/B
used `0x94d1a3b75d400ffc`/`0x879e99b3d367f4a9`; desktop used
`0xda600b5ce07b134a`/`0x23e240c06317fa34`. Desktop still begins its first
world draw at `TBP=0x24f2` with 55 sprites, while mobile begins at
`TBP=0x2bc1` with 48. This moves the first open dependency to the matrix/camera
producer or update cadence, not frame packing, transfer ordering, texture
remapping, or native Metal visibility. The Simulator was blank; this remains
non-audible, non-playability evidence. See
`docs/evidence/R1/r1-frame-matrix-byte-fingerprint-2026-08-21.md`.

The next bounded correlation shows the mobile matrix is phase-stale relative
to the matching frame data. In one Village1 run, mobile frame hashes alternated
`0xff7e…`, `0xd731…`, `0xff7e…`, `0xd731…` across chains 249–252, while the
matrix stayed at `0x94d1…` through the first three chains and changed to
`0x879e…` only at camera-packet count 13. Desktop changed its matrix with the
corresponding frame phase. Transfer order remained 9 → 12 → 13 and the first
mobile resource remained `TBP=0x2bc1`. The open dependency is now source camera
update cadence/phase pairing; no matrix swap or renderer-policy change is
justified. See
`docs/evidence/R1/r1-matrix-camera-update-correlation-2026-08-21.md`.

The final correlation also recorded the latest camera source location: it is in
the same chain as the Sprite3 bucket but at a separate transfer position (for
example chain 252 transfer 465, chain 253 transfer 468, chain 254 transfer 427,
chain 255 transfer 281), while Sprite3 remains frame 9 → matrix 12 → MSCAL3 13.
This is now a producer sequencing dependency between the PC camera packet and
the matrix DMA emission. No Metal-side matrix swap is justified. The Simulator
was shut down after the run and remains blank/non-audible evidence only.

Source inspection confirms the intended GOAL contract: `sprite-draw` emits
frame data, then `sprite-add-matrix-data` mode 0, then 3D groups from one DMA
buffer, while `finish-background` emits the separate PC-port camera/background
packets. The next falsifiable regression must therefore exercise that shared
producer/update pairing; no renderer transform workaround is selected.

The vsync discriminator is now captured. Mobile chains 254–257 crossed vsyncs
255–258 while frame hashes alternated `0xd731…`/`0xff7e…`; the matrix stayed
`0x94d1…` for the first three vsyncs and changed to `0x879e…` on the fourth.
Transfer order remained 9 → 12 → 13 and the first resource remained
`TBP=0x2bc1`. The stale matrix therefore crosses display-frame boundaries; the
open dependency is frame association/camera update cadence in the producer
path, not a same-vsync bucket grouping issue or a Metal-side transform policy.
See `docs/evidence/R1/r1-matrix-vsync-correlation-2026-08-21.md`.
The supplied 2026-08-20 Simulator crash report was read and attributed. Its
triggered thread aborts in `link_control::jak1_jak2_begin` during
`ottsel_ios_run_boot`, matching the existing blank/zero object-header GOAL
linker boundary; the Metal `presentRGBA` call is on the unrelated main thread.
It is an older app UUID/build than the current diagnostic executable and is not
new Sprite3/Metal evidence. The assertion remains preserved. See
`docs/evidence/R1/r1-supplied-simulator-crash-attribution-2026-08-21.md`.

Identity audit correction: the raw frame hash covers the full Sprite3 frame
payload, including GIF/TBP/state fields, not only camera data. The alternating
hashes shared identical camera-derived values (`pfog0`, basis, and `inv-area`),
so stale camera/matrix association is not proven. No matrix workaround or
phase regression will be encoded until a camera-only signature or direct GOAL
producer trace falsifies the pairing. See
`docs/evidence/R1/r1-matrix-vsync-identity-correction-2026-08-21.md`.

The camera-only signature now resolves the ambiguity. Full Sprite3 payload hashes
alternated across chains 255–257, but their camera-only signature stayed
`0x6137bebdf6d07123` with identical fog/area/basis fields. When the PC camera
packet changed on chain 258, the camera-only signature stayed the same while
the matrix changed from `0x94d1…` to `0x879e…`. The earlier stale-matrix
interpretation is therefore falsified; no phase-pair regression or matrix
workaround is justified. R1 returns to the proven resource/phase divergence:
mobile first `TBP=0x2bc1` versus desktop `TBP=0x24f2`. See
`docs/evidence/R1/r1-camera-only-signature-correlation-2026-08-21.md`.
## 2026-08-21 — supplied mobile audio abort remains separate from R1

The supplied Simulator crash report `BFC94005-4B2F-4720-B685-FC2FAE80EEBA`
terminates on `SDLAudioP15` in SDL's `AudioQueueThreadEntry` (`abort` after an
Objective-C exception). The graphics worker was concurrently in
`gfx_send_chain`; the triggered stack contains no Metal/Sprite3 frame. The
recursive `GameTextFontBank` destructor frames are on separate process-exit
BackBoard threads and are not enough to call this a renderer crash. Mobile
audio/stability remains OPEN and does not supersede the active R1 first-resource
identity gate. See
`docs/evidence/M1/m1-supplied-simulator-audio-abort-2026-08-21.md`.

## 2026-08-21 — R1 content identity discriminator remains unmeasured

The signed diagnostic build adds only bounded decoded-RGBA FNV/alpha logging
for the first textured Sprite3 resource on desktop and mobile. Build/sign and
the 14-test `Sprite3Native.*` suite passed. A correctly placed iPad trigger
run reached the Village1 display boundary with a 0-byte fault log but emitted
no identity record before shutdown. Therefore the content hashes are not yet
evidence; the established mobile `0x2bc1` versus macOS `0x24f2` producer/phase
mismatch remains OPEN, and no TBP remap or native widening is justified. See
`docs/evidence/R1/r1-resource-content-identity-discriminator-2026-08-21.md`.

## 2026-08-21 — R1 decoded resource mismatch is proven

The synchronized prepared-pack route reached Village1 and auto-armed the
bounded identity ledger once at the `village1` camera level. Mobile’s first
resource was `TBP=0x2bc1`, 64x64, decoded RGBA FNV
`0xc8679915dfac0e15`, alpha max 128, 2,615 nonzero-alpha texels. The retained
same-route macOS oracle’s first accepted world resource was `TBP=0x24f2`,
64x64, decoded RGBA FNV `0x03be77a789505b65`, alpha max 95, 1,548
nonzero-alpha texels. The mismatch is content-level, not merely a TBP address
difference. R1 remains OPEN at producer/source-item ownership; no remap or
renderer policy change is justified. See
`docs/evidence/R1/r1-resource-content-identity-capture-2026-08-21.md`.

## 2026-08-21 — R1 producer correlation corrects the ownership conclusion

The new desktop group ledger shows world group 0 at `TBP=9478` (`0x2506`),
48 sprites, `MSCAL=3`, and decoded RGBA hash
`0xc8679915dfac0e15`, exactly matching mobile group 0 at `TBP=0x2bc1` (also
48 sprites and the same alpha summary). The retained macOS accepted world
oracle at `0x24f2` remains a later/different phase with hash
`0x03be77a789505b65`. Therefore a direct texture-owner defect is not proven;
the first concrete open dependency is phase selection/transition between the
shared `0x2506`-family group and the accepted `0x24f2` world group. No remap or
renderer policy change is justified. See
`docs/evidence/R1/r1-producer-group-ownership-correlation-2026-08-21.md`.

## 2026-08-21 — fresh macOS phase window is stable and excludes 0x24f2

A timestamp-selected fresh macOS log captured three Sprite3 frames after two
Village1 markers. Every frame had world group 0 as 48 sprites at
`TBP=9478`/`0x2506`, followed by a 16-sprite `TBP=0` group; the decoded group-0
hash matched mobile `0x2bc1`. The accepted desktop `0x24f2` draw did not appear
in this immediate synchronized window. This confirms a stable phase/transition
boundary rather than a direct texture-owner defect. The next experiment is a
second bounded desktop trace after the first three frames, aligned to mobile's
66->68 walk. See
`docs/evidence/R1/r1-fresh-macos-phase-window-2026-08-21.md`.

## 2026-08-21 — macOS phase transition is now captured

A second bounded trace in the same macOS runtime captured the missing boundary.
Frames 1–3 remained at world group 0 `48 @ 0x2506` plus group 1 `16 @ 0`,
matching mobile's decoded `0xc8679915dfac0e15` resource. After a 15-second
settled delay, frames 4–6 advanced to group 0 `48 @ 0x24f2`, group 1 `48 @
0x24f2`, then `0x2525` and `0x25d2` groups, completing 51 blocks and 2,432
sprites. The open dependency is now the mobile equivalent of this producer
phase transition; no remap or native renderer widening is justified. See
`docs/evidence/R1/r1-macos-phase-transition-2026-08-21.md`.

## 2026-08-21 — mobile phase coverage is the first open dependency

Aligning the new desktop transition with the existing shared-vsync mobile
aggregate shows that mobile reaches the matching early `48 + 16` producer
boundary, then closes at 9 groups / 384 sprites: 8 MSCAL-3 world groups
beginning at `0x2c8d` plus 64 MSCAL-211 3D sprites, with no HUD phase. Desktop
continues through the accepted `0x24f2` world phase (51 blocks / 2,432 sprites)
and later HUD groups. The first actionable gate is therefore an ordered
producer/DMA phase-coverage regression; texture remap and native renderer
widening remain unjustified. See
`docs/evidence/R1/r1-mobile-desktop-phase-alignment-2026-08-21.md`.

## 2026-08-21 — phase-coverage regression added test-first

The new ROM-free `Sprite3Native` contract first failed to compile because the
post-transition coverage predicate was absent, then passed after adding only
the pure predicate and two assertions. The focused suite is now 15/15. The
contract records the macOS observed bar of 51 world blocks, 3 HUD blocks, and
2 3D groups; it does not alter rendering. The producer/chain boundary that
leaves mobile at 8 world groups and 0 HUD groups remains OPEN. See
`docs/evidence/R1/r1-phase-coverage-regression-2026-08-21.md`.

## 2026-08-21 — mobile chain boundary is not the missing phase

The source audit and fresh mobile ledgers show that the retained product walk
already spans bucket 66 through bucket 68. The parser accepted all observed
groups with `rejected=0` and `boundary-stops=0`; fresh windows varied between 9
and 10 groups rather than ending at bucket 67. The missing 51-block macOS phase
is therefore upstream in the GOAL/send-chain-produced DMA contents, not a
mobile bucket boundary or parser-stop defect. The next trace moves to the
producer handoff. See
`docs/evidence/R1/r1-chain-boundary-audit-2026-08-21.md`.

## 2026-08-21 — producer table-slot anomaly falsified by diagnostic correction

A fresh signed iPad build with a writable-directory-triggered producer trace
reached the Village1 display marker and captured 64 alternating chain
submissions. The initial interpretation was wrong: the ledger advanced by 8
bytes instead of 16, so its reported even-slot zeros were VIF payload words,
not DMA tags. Corrected indexing aligns the producer's leading entries with
the renderer's same-chain decoded slots. No table-origin or off-by-one defect
is proven, and no product fix is justified. See
`docs/evidence/R1/r1-producer-table-slot-capture-2026-08-21.md`.

The attempted same-chain renderer correlation then hit a separate link-time
runtime assertion while loading an empty object (`major=0/minor=0`, expected
`1.0`, `game/kernel/common/klink.cpp:81`). That replay is invalid for R1 phase
evidence and is not attributed to Metal or the producer trace; the link/data
boundary remains OPEN and must be separated from the table-slot experiment.

Correction: the shortcut replay was invalid, but the proven title-wait input
route was then replayed successfully with the same signed build. Fresh
Village1 evidence recorded 13 groups / 576 sprites (384 world, 128 HUD, 64
3D), with rejected=0 and boundary-stops=0. The false table-slot anomaly is
retired; the next gate returns to ordered producer/resource divergence.

## 2026-08-21 — supplied crash is a separate link/data boundary

The supplied iPad Simulator crash report (`F2004949-CDA2-4C31-9544-117378B11FBA`)
crashes in `ottsel_ios_run_boot` through `jak1::link_begin` at
`game/kernel/common/klink.cpp:81` after the logged
`OTTSEL LINK VERSION MISMATCH: object= major=0 minor=0 expected=1.0` assertion.
Its `SDLAudioP15` thread is idle in `AudioQueueThreadEntry`, so this incident
does not change the separate audio-abort classification or the R1 renderer
gate. See `docs/evidence/M1/m1-supplied-simulator-link-version-assertion-2026-08-21.md`.

## 2026-08-21 — corrected producer capture confirms resource-phase divergence

The corrected signed app (`4e6f61bac9ba471bfcae7b2093c50317246d3e001f33efc88bbe35636230db7d`)
replayed the real title-wait route, reached Village1 twice, and captured 64
producer submissions with 16-byte DMA-table alignment. A fresh phase aggregate
remained `9` groups / `384` sprites (`64` 3D, `320` world), beginning with
mobile `0x2b8d`/`0x2be0` 3D and `0x2c8d` world resources. The first stable
post-setup record repeated `TEX0=0x2005a0455530ac8d` (`0x2c8d`, 32x32), while
macOS begins its accepted world phase at `0x24f2` (`64x64`, 55 sprites).
This confirms the producer/resource-phase divergence before Metal; it does not
justify a TBP remap, camera/shader change, or consumer widening. The Simulator
was blank and non-audible, and its fault log was 0 bytes. See
`docs/evidence/R1/r1-corrected-producer-resource-capture-2026-08-21.md`.

The follow-up setup-transfer trace then matched desktop's validated Direct
setup words (`0x2000000000008001`, `0xEEEE...`, `0x5126B`, `0x47`, `0x5`, `0x8`),
followed by frame transfer 9, matrix transfer 12, and `MSCAL=3`. This rules
out the preceding setup packet as the first shared defect. The remaining R1
experiment is the post-`MSCAL=3` producer/phase ownership decision that emits
mobile `0x2c8d` instead of macOS `0x24f2`; the Simulator remained blank and
non-audible.

## 2026-08-21 — fresh macOS phase ownership oracle

A fresh macOS Windowed reference reached Village1 and captured active Sprite3
frames with stable setup (`pfog0=-0.036405455`, `inv-area=0.036767285`). Its
first groups were `MSCAL=211` at `TBP=0x24f2`/64x64, a second `MSCAL=211` at
`TBP=9509`, then `MSCAL=3` at `TBP=9496`. The corrected mobile route instead
begins with `0x2b8d`/`0x2be0` 3D resources and `0x2c8d` world resources. The
first divergence is therefore phase/resource ownership before native Metal,
not the setup packet or a proven camera/shader defect. See
`docs/evidence/R1/r1-macos-mobile-phase-ownership-2026-08-21.md`.

The follow-up bucket-65 trace found no headers or groups in bucket 65→66; the
adjacent bucket 66→67 was setup-only, while bucket 67→68 contained only
`MSCAL=3` world records. This rules out the immediately preceding bucket as the
owner of the missing `MSCAL=211` phase for that route window, but does not yet
identify the other chain/phase that emitted mobile's 3D family. The next R1
experiment remains an adjacent-chain/source ownership trace, not bucket
widening or a renderer policy change.

The new ROM-safe ordered phase regression distinguishes the mobile-shaped
`ThreeD -> World2D` aggregate from the accepted macOS-shaped
`ThreeD -> World2D -> Hud2D` aggregate. It passes only when the records retain
that order and the captured coverage includes two 3D records, 51 world blocks,
and three HUD blocks. This is a falsifiable R1 boundary check; it is not a
producer fix or a visual pass claim.

The next source-boundary trace reached Village1 on the freshly signed app and
recorded concrete chain/data intervals, route marker, and frame/matrix hashes.
That window contained only ordered `MSCAL=3` world records at `TBP=0x2c8d`
(plus a zero-texture tail), across chains 2918 and 2919; no `MSCAL=211` record
appeared in this window. This confirms the trace can attribute producer
ownership and narrows the missing phase to a phase-window/source-production
question, but does not establish that the 3D phase is globally absent. See
`docs/evidence/R1/r1-source-boundary-trace-2026-08-21.md`.

The source trace was repeated after two fresh `level=village1
display=display-self` markers. Same-transition chains 12699–12700 still
contained only six 48-sprite `MSCAL=3` world records at `TBP=0x2c8d` plus a
zero-texture tail; the camera source chain matched the Sprite3 chain and the
fault log remained 0 bytes. This is valid phase evidence, not visual proof or
an authorization to remap resources. The Simulator remained blank/non-audible.

The matching macOS first-vector trace now confirms the divergence before Metal:
macOS frames 4–6 begin with `MSCAL=211` and a first vector
`(-398645.3,115862.33,296381.16,3686.4)` at `TBP=9710`, then reach `MSCAL=3`
world groups. The mobile ledger begins with a different `MSCAL=3` world vector
and `TBP=0x2c8d`. The comparison does not authorize a clip, camera, TBP, shader,
or native-consumer change; the next experiment remains producer-side handoff
tracing. See `docs/evidence/R1/r1-macos-mobile-first-vector-comparison-2026-08-21.md`.

The pre-route numeric follow-up captured chains 256–259 with the actual
frame/matrix values. Chains 256–258 repeated `TBP=0x2bc1`, 48 world sprites,
and a 16-sprite zero-texture tail; chain 259 changed the camera tuple and
matrix hash while retaining that phase. Each Sprite3 chain's camera-source
chain matched itself, ruling out stale adjacent-chain camera ownership. It
was armed before the current-boot title/New Game marker, so it is context only,
not same-transition Village1 parity evidence. See the numeric follow-up in
`docs/evidence/R1/r1-source-boundary-trace-2026-08-21.md`.

The generated-data identity audit rules out an active packaging mismatch: the
signed iPad bundle and macOS `out/jak1/iso` share exact `VI1.DGO`, `TIT.DGO`,
and `GAME.CGO` SHA-256 identities. The older ignored retail `iso_data/jak1`
copies differ, but are not what the current build script packages or what the
macOS `-fakeiso` route uses. The first same-transition Sprite3 divergence must
therefore be traced in runtime producer/phase state, not repaired by swapping
DGOs or remapping textures. See
`docs/evidence/R1/r1-generated-dgo-identity-audit-2026-08-21.md`.

The active user-data audit extends that result: the durable iPad pack’s
`VI1.VIS` and `fr3/village1.fr3` match the macOS `out/jak1/iso` renderer inputs
byte-for-byte. The iPad runtime also logged the expected selected root and
Village1 FR3/VIS load sizes. The first same-transition Sprite3 divergence is
therefore not an asset/data-root mismatch; the next gate is runtime execution
and producer state. See
`docs/evidence/R1/r1-user-data-identity-audit-2026-08-21.md`.

The iOS graphics-sync seam is now corrected: `sceGsSyncV` and `sceGsSyncPath`
delegate to the registered Metal renderer like macOS instead of returning from
stub-only implementations. A fresh signed Simulator launch logged
`renderer-delegated=true` for VSYNC calls 1–8 and 60 with a 0-byte fault log.
This is runtime timing progress, not a Sprite3 or playability pass. The next
R1 experiment is a fresh same-transition phase aggregate with this delegation
active. See `docs/evidence/R1/r1-ios-gfx-sync-delegation-2026-08-21.md`.

The post-sync aggregate replay reached the registered callback and later closed
at `5` groups / `192` sprites (`64` world, `128` HUD, no 3D), beginning at
`TBP=0x2c8d`; the fault log was 0 bytes. Sync delegation is therefore proven,
but it did not produce macOS-complete Sprite3 phase coverage or visual parity.
The next experiment remains an immediate same-transition producer capture, not
a renderer/resource remap. See
`docs/evidence/R1/r1-ios-gfx-sync-phase-replay-2026-08-21.md`.

The next timing slice added a presentation-thread VSYNC latch so the iOS game
thread waits for the shell's next frame signal, with explicit shutdown wake-up.
A fresh signed iPad Pro 11-inch (M4) Simulator launch logged delegated VSYNC
calls 1 and 8 at 51:12 and call 60 at 51:13; the runtime terminated, the
Simulator shut down, and `ottsel-fault.log` was 0 bytes. This proves bounded
presentation wake-up and shutdown behavior, but not Sprite3 phase parity,
visual output, audio, or playability. The next R1 experiment is a fresh valid
same-transition phase aggregate after the latch. See
`docs/evidence/R1/r1-ios-vsync-latch-implementation-2026-08-21.md`.

The first post-latch route retry is not a valid phase capture: after correcting
the app bundle identifier, the fresh boot produced delegated VSYNC and a
0-byte fault log, but no consumed current-boot Start/Cross/Down sequence or
valid Village1 transition. The Simulator remained blank/non-audible, so this
is recorded only as a route synchronization miss. See
`docs/evidence/R1/r1-post-latch-route-sync-miss-2026-08-21.md`.

The marker-synchronized retry then captured the first clean post-latch mobile
Sprite3 frame aggregate. After current-boot Village1 entry, the aggregate
accepted at VSYNC 1118 / chain 1117 and completed one chain later with 5 groups
and 192 sprites: 64 3D, 128 world, no HUD, and a 32-sprite zero-texture tail.
The 3D resources were `TBP=0x2b8d` (48, 64x64) and `0x2be0` (16, 32x32); the
world resources were `0x2bc1` and `0x2bd3`. The fault log was 0 bytes. This
proves a 3D-bearing mobile phase after the latch, not resource parity, visible
composition, audio, or playability; the Simulator remained blank/non-audible.
The next experiment is the corresponding macOS aggregate and source-ownership
trace against macOS `TBP=0x24f2`. See
`docs/evidence/R1/r1-post-latch-sprite-frame-aggregate-2026-08-21.md`.

The follow-up source-boundary capture, armed after current-boot Village1 entry,
recorded chains 1000–1003 at VSYNC 1001–1004. Every first group was
`MSCAL=3`, 48 sprites at `TBP=0x2bc1` (64x64), followed by a 16-sprite
zero-texture tail; frame transfer 9, matrix transfer 12, and camera-source
transfer 470 were stable. No `MSCAL=211` family appeared in this valid window.
Together with the preceding 3D-bearing aggregate, this proves phase-window
variability rather than authorizing a remap. See
`docs/evidence/R1/r1-post-latch-source-boundary-2026-08-21.md`.

The pre-armed earliest-window capture then recorded chains 142–145 / VSYNC
143–146. Every first group was `MSCAL=3`, 48 sprites at `TBP=0x2bc1`, followed
by the 16-sprite zero-texture tail; frame transfer 9 and matrix transfer 12
were stable. Chains 142–144 retained the transition camera tuple, while chain
145 changed to the stable post-transition tuple and camera-source transfer
281. No `MSCAL=211` family appeared in this earliest eligible Village1 window.
This narrows the open dependency to source chain/table and phase-state
ownership; it still does not justify a TBP remap or a visual claim. See
`docs/evidence/R1/r1-early-village1-source-boundary-2026-08-21.md`.

The GOAL-side producer discriminator now proves the mobile 3D particle source
is nonempty: after `process-particles` on a fresh marker-synchronized route,
repeated bounded lines reported `alloc-state="nonzero"`,
`valid-state="nonzero"`, and `blocks-state="nonzero"` after Village1 entry.
The signed app hash was `d10eb476...`, the fault log was 0 bytes, and the
Simulator remained blank/non-audible. This rules out an empty 3D source as the
explanation for the earliest world-only Sprite3 window. The next discriminator
is the trigger-gated `sprite-draw`/DMA chain identity that correlates the first
nonzero 3D-particle frame with the bucket containing `MSCAL=211`; no renderer,
TBP, camera, or shader change is justified. See
`docs/evidence/R1/r1-sparticle-3d-producer-ownership-2026-08-21.md`.

The combined same-boot correlation then closed the producer-to-DMA question:
with the GOAL 3D producer states nonzero, VSYNC 1001 / chain 1000 emitted
`MSCAL=211` 48 sprites at `TBP=0x2b8d`, followed by `MSCAL=3` 48 sprites at
`TBP=0x2bc1`; the aggregate completed with 64 3D and 64 world sprites. This
proves mobile can emit the 3D DMA phase. The remaining R1 mismatch is now
resource/state parity against macOS's corresponding `MSCAL=211` phase at
`TBP=0x24f2`; no TBP, camera, shader, or renderer-policy change is justified.
See `docs/evidence/R1/r1-combined-sparticle-dma-correlation-2026-08-21.md`.

The follow-up same-boot vector/state trace now compares the first mobile 3D
item directly with macOS. Mobile chain 1026 / VSYNC 1027 begins with
`MSCAL=211`, 48 sprites at `TBP=0x2b8d`, TEX0 `0x2005aa459930ab8d`, and first
vector `(-83876.28,1521.3914,469371.34,9963.493)`, then emits world
`TBP=0x2bc1`. The retained macOS first-3D oracle uses `TBP=9710` and first
vector `(-398645.3,115862.33,296381.16,3686.4)`, with different frame-state
values. This is now a concrete pre-Metal producer/resource/state divergence;
no remap or renderer policy change is justified. See
`docs/evidence/R1/r1-mobile-macos-first-3d-vector-state-2026-08-21.md`.

## 2026-08-21 — supplied Simulator audio teardown crash remains open

Incident `BE5ADBFF-F8D1-4615-97B3-E1E8D1DF740B` aborts on `Thread 6
SDLAudioP15` in `AudioQueueThreadEntry` while the main thread is tearing down
SDL/UIKit window and controller state. This is a distinct AU1/M1 audio and
lifecycle failure from the prior audio abort and GOAL link assertion. The
Simulator was blank and non-audible; no pass claim is made. It does not change
the current R1 producer/phase gate. See
`docs/evidence/M1/m1-supplied-simulator-audio-teardown-crash-2026-08-21.md`.

The next producer slice is now instrumented at the exact particle AdGif
boundary. The bounded MIPS2C trace decodes the packed source IDs before
`particle-setup-adgif`: the fresh title boot observed page `0x2`, index `0x35`
(`raw=0x00203500`) and page `0x2`, index `0x4` (`raw=0x00200400`), with GOAL
lookup hits. The source/build and strict-signing checks passed, and the fault
log stayed at 0 bytes. This replay did not reach Village1 because it was a
fresh no-pack install without an imported FR3 root; the Simulator remained
blank/non-audible. The next experiment is the same validated-pack
title-wait → Start → Cross → Down×4 → Cross route with these IDs correlated to
the first current-boot `MSCAL=211` frame. See
`docs/evidence/R1/r1-particle-adgif-producer-trace-2026-08-21.md`.

The validated-pack replay now captured the producer during the active Village1
phase. After `GAMEPLAY: enter village1`, the trigger-gated MIPS2C trace saw
texture IDs page `0x2`, indices `0xa`, `0x19`, and `0x18`; its 32-call cap
completed cleanly. The nearby same-route frame aggregate at VSYNC 3323 / chain
3322 contained `MSCAL=211` 3D records (`48` sprites at `0x2b8d` plus a `16`
sprite tail at `0x2be0`) followed by world records at `0x2c8d`/`0x2d8c`, with
`3d=64`, `world=576`, and a zero-byte fault log. The screenshot is visibly
partially composed but severely corrupted, so it is not a playability result.
The remaining discriminator is an exact producer-output stamp tying selected
texture ID to resulting AdGif/TEX0 words on the same chain; no TBP remap,
camera, or shader change is justified. See
`docs/evidence/R1/r1-particle-adgif-village1-correlation-2026-08-21.md`.

The cache-copy follow-up now closes the native-consumer uncertainty. In a
fresh validated-pack run, raw particle texture ID `0x00200a00` (page `0x2`,
index `0xa`) produced AdGif TEX0 `0x2005aa459930ab8d`, exactly matching the
first same-route native `MSCAL=211` item’s TEX0 and `TBP=0x2b8d`. Other bounded
pairs were index `0x18` → `0x20059dc59930ad8c` and index `0x19` →
`0x20059e459930ad7c`; TEX1/CLAMP/ALPHA were also captured. The trace completed
with a zero-byte fault log, while the screenshot remained partially composed
and corrupted. This rules out a native TBP remap as the first mismatch. The
next experiment is the same producer-ID/TEX0 trace on macOS at the matching
Village1 transition, followed by source/data-family reconciliation. See
`docs/evidence/R1/r1-particle-adgif-output-mapping-2026-08-21.md`.

## 2026-08-21 — iPad texture lookup divergence proven

The signed iPad lookup-trace build completed the fresh validated-pack route
title-wait → Start → Cross → Down×4 → Cross and reached Village1 twice. Its
ordered page-2 lookup sequence diverges from macOS at position 5: iPad selects
`28 → 27 → 3` where macOS selects `30`, omits macOS indices `35/31/36`, adds
`54/49/48/42/44`, and also visits non-page-2 families. Shared page-2 entries
have matching dimensions/PSM. The same-boot source boundary correlates this
with two MSCAL=211 groups (`0x2b8d`/`0x2be0`) followed by six MSCAL=3 world
groups (`0x2d7c`/`0x2d8c`/`0x2c8d`×4). This moves the first open dependency to
page-directory login/order, FR3/DGO texture ordering, and default texture-page
allocation state; no TBP remap, camera change, shader change, or Metal-policy
change is justified. The Simulator remained blank or partially corrupted and
is not playability proof. See
`docs/evidence/R1/r1-ipad-texture-lookup-divergence-2026-08-21.md`.

## 2026-08-21 — R1 lookup comparison corrected and allocator divergence isolated

The R4 replay's apparent early `15 → 0` anomaly was phase contamination: nine
of its 21 page-2 lookups occurred before the Start trigger. After alignment,
both mobile runs still select the default-allocated iPad-only family
`54/49/48/42/44` while omitting macOS's `35/31/36` family. All entries are
resident hits, so this points to differing particle-spec/runtime-family
selection upstream of texture resolution rather than failed page-directory
login or a native TBP remap. A separately supplied PID-34171 crash report at
12:01:49 predates the live PID-36291 R4 run; it remains an independent
lifecycle observation, not the R4 result. The Simulator remained blank or
partially corrupted, so no playability claim is made. See
`docs/evidence/R1/r1-phase-aligned-lookup-allocator-attribution-2026-08-21.md`.

## 2026-08-21 — platform order corrected: macOS stability is now the active gate

The user correctly rejected the operational implication of the prior handoff:
there was no visibly playable local game on either platform, and an idle
diagnostic Simulator process could be mistaken for progress. The iPad runtime
was stopped and the only booted Simulator was shut down. The R5 lookup evidence
above remains valid diagnostic history, but **it no longer defines the active
product queue.**

The active order is now explicit and supersedes any older “iPad first” text:

1. Prove macOS stable/playable on the current checkout.
2. Resume iPadOS renderer/resource parity and playable interaction.
3. Then iPhone parity and physical-device readiness.

The first macOS experiment is a clean reproducibility audit of the exact local
launch path, followed by a fresh visible run with real input, audio output,
lifecycle checks, fault scan, and a bounded soak. No new mobile build or trace
is authorized until that run either passes or identifies a concrete macOS
defect. This does not change ROM safety or signed-native/no-runtime-codegen
rules.

## 2026-08-21 — fresh macOS bounded stability increment

A fresh one-runtime macOS run now provides the first current-checkout bounded
stability increment requested by the platform-order correction. PID 44189 ran
the native arm64 executable from the pinned upstream tree with audio enabled;
no Simulator was booted. Real keyboard events drove title → New Game →
overwrite-save YES → the complete A/B/C/D1/D2 cinematic chain → Village1 →
Training. Jak visibly responded to held-W movement, followed by ten active
W/camera/jump cycles captured as `soak-01..10.png`. The process stayed alive
for more than 22 minutes, and two post-soak frames show a coherent animated
Training/water scene rather than a black frame or menu. No matching crash/fault
report was found.

This upgrades the macOS board from OPEN to **PARTIAL PASS**, not playable. The
run used keyboard events rather than a physical controller; nonzero PCM was
observed live but its raw stream was not retained and no human listener
confirmed audibility; background/resume was not explicitly exercised; and the
soak was about four minutes of active interaction, not an endurance test.
iPadOS/iPhone therefore remain paused behind those explicit macOS clauses.
See `docs/evidence/M1/m1-macos-bounded-stability-increment-2026-08-21.md` and
`docs/evidence/M1/artifacts-2026-08-21-macos-stability-gate/`.
