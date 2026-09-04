# R1 native composition consumer boundary — 2026-08-21

## Scope

This is a fresh bounded probe after the phase-aligned R1 page-directory,
particle, AdGif TEX0, and first-world-boundary comparison. It asks whether the
native Sprite3 consumer is absent, or whether the remaining Simulator image
failure is broader composition/material coverage.

## Fresh signed replay evidence

- One iPad Pro 11-inch (M4) Simulator remained booted; no second runtime was
  started.
- The existing signed app was left in the village route, then armed with the
  writable `ottsel-trace-mobile-sprite-metal` and
  `ottsel-dump-native-sprite-metal` triggers.
- The runtime accepted the probe and reported candidate 11 as a native group:
  `tbp=0x2506`, PSM 19, bounds `(0.467,0.641)..(0.650,0.899)`, 64x64,
  blended, `cpu-raster=skipped-for-native-candidate`, texture alpha max 128,
  nonzero alpha 2615, uploaded alpha 1.
- The native present-state artifact was written and the Metal readback was
  `/.../ottsel-native-sprite-metal.ppm`, 1210x834. It contains substantial
  village geometry and the native sprite, while still showing large missing
  regions and diagnostic colored blocks.
- The fresh fault log remained zero bytes. This is not playability proof.

## Decision

The native Sprite3 consumer is live for the selected candidate. Therefore the
remaining R1 blocker is native Direct/Sprite/material composition coverage and
ordering, not absence of the first source-boundary texture or page-directory
lookup. The screenshot/readback remains visibly corrupted and the build is not
honestly playable.

The next falsifiable experiment is to compare the first same-transition
MSCAL=211 Direct/material records and then expand the native consumer only for
the proven record family. Do not remap TBP or change camera, shader, or Metal
policy without that comparison.

## Bucket-67 inherited Sprite3 pass — 2026-08-21

The DMA ownership seam was narrowed: the normal product parser walked the
bucket-66 interval while bucket 67 was sent only through the Direct tracer.
The parser now exports the frame/matrix setup from bucket 66 and performs a
bounded bucket-67 Sprite3 pass using that inherited setup. MSCAL=3/109 remain
the only product consumers; MSCAL=211 remains diagnostic-only pending its
proven material contract.

Fresh signed executable SHA-256:
`dded8ca510462bcf0b06f739c2f0186ae5bd575282d2201ca837a83f16137883`.
The exact title-wait → Start → Cross → Down×4 → Cross route reached Village1
twice. The final rebuild logged `OTTSEL SPRITE BUCKET67: Sprite3 pass
consumed=64 frame/matrix-inherited=1 hud-inherited=true` during the early
transition. Screenshot `/tmp/ottsel-bucket67-pass-final-route.png` has SHA-256
`4b38a869947d489fca6ff1f859dc0cebb8f1e03ef78bc06efff6d2c00fee18be`; runtime
log is `/tmp/ottsel-bucket67-pass-final-runtime.log`; fault output is
`/tmp/ottsel-bucket67-pass-final-fault.log`, 0 bytes. Audio remains
`pcm-peak=0`.

The screenshot is still visibly corrupted/partial and not playability proof.
This pass establishes bucket-67 setup ownership but does not prove a correct
3D material/composition result. iPhone parity, lifecycle, audio, and physical
device gates remain open.

## MSCAL=211 native consumer and source-contract correction — 2026-08-21

The next source-side experiment promoted only the proven `MSCAL=211` 48/16
Sprite3 tuple into the native Metal consumer. The implementation preserves the
source `sprite3_3d.vert` equations, live TEX0/CLUT decoding, and existing
forward-Z/depth policy. During the fresh signed replay it consumed native 3D
groups including `48 sprites`, `TBP=0x2506`, and
`TEX0=0x2004d0e59930a506`, without a fault.

The first result exposed two CPU-port contract errors rather than a resource
lookup mismatch: the quaternion matrix had been transposed relative to GLSL's
column-major `mat3`, and the projected-area fade used `Q*Q` although the
source shader uses one `Q` before its final two alpha multipliers. Both were
corrected directly from the maintained shader; no TBP remap, camera, shader,
or Metal policy change was made.

The corrected app built and passed strict deep codesign. Focused Sprite3/input
tests passed 21/21. Executable SHA-256:
`b9840c49aea9c90631ccf645e74524a73884731ce3df3cbceff33af31895672d`.
The fresh Simulator screenshot `/tmp/ottsel-native-equation-route.png` has
SHA-256
`86cfb2228efe700ed930340dd37eb9210ecb862f72f01cdbb0d2293ecb562ebc`.
It shows more decoded village geometry, but remains severely miscomposed with
large missing/rotated regions and diagnostic blocks; it is not playability
proof. Audio remains unproven/non-audible, and iPhone parity, lifecycle, and
physical-device gates remain open.

The next falsifiable boundary is native Direct/material composition and draw
ordering around this corrected 3D consumer. Do not broaden the consumer or
alter camera/TBP/depth policy without a source-side tuple and visible evidence.

## Sprite3 depth-compare correction and producer-phase capture — 2026-08-21

The native Sprite3 Metal state was then compared with the maintained Jak 1
packet contract. TIE uses the native forward-Z `LessEqual` state, but Jak 1
Sprite3's GS prefix uses `GEQUAL` with depth writes disabled. The native path
had reused the TIE compare function; it now creates a separate
`GreaterEqual`/no-write Sprite3 state while leaving TIE unchanged.

Fresh signed executable SHA-256:
`70eb453331663ec8046906c95c085aca703d7bf7450c0614df69dd1df942789b`.
Codesign passed and the focused Sprite3/platform-input/keyboard suite passed
21/21. The fresh Simulator screenshot `/tmp/ottsel-depthfix-route.png` has
SHA-256
`308aae9e6c4addca4e3d2ffe87d5183bd1cc34d2816380dfbcd9f29970a848b`.
The village composition is materially less corrupted and no longer shows the
prior diagnostic color blocks, but it still lacks coherent Jak/player/HUD
composition and has large missing regions. It remains non-playable evidence;
the blank/partial Simulator warning is still active. Fault output was 0 bytes;
audio remained unproven/non-audible.

The same run captured the upstream phase boundary. Early chain 142/143 Sprite3
setup used `pfog0=-0.046546843`, `inv-area=0.10231715`, basis
`(0.41880882,0.24430515)`, and world-only `MSCAL=3` records at
`TEX0=0x2004d0e59930a506`. Later camera packets converged to the macOS scalar
values `pfog0=-0.036405455` / perspective `(-0.25105703,-0.14644994,...)`.
This is a timing/phase-owned producer/frame mismatch, not evidence for a TBP
remap. The next experiment is to capture the first `MSCAL=211` group after
the converged camera packet and compare its frame/matrix hash and vector to
the macOS phase before any further native composition expansion.

## Converged-camera phase capture and rejected native-z expansion — 2026-08-21

After the early transition, a fresh signed replay armed the same source-boundary
trace only after the camera ledger reached the macOS-matching perspective
scalars. The log is `/tmp/ottsel-converged-phase-route-1787368217.log`.
Chain 299/VSYNC 300 recorded `pfog0=-0.036405455`, `inv-area=0.036767285`,
basis `(0.25105703,0.14644994)`, and stable frame/matrix hashes, but its
captured groups were still world-only `MSCAL=3` at
`TEX0=0x2004d0e59930a506`; no same-chain `MSCAL=211` followed the converged
packet in this window. This proves that the earlier `MSCAL=211` phase is not
simply a stale camera scalar in the native consumer; phase ownership remains
the open producer boundary.

A bounded follow-up added explicit native Sprite3 z coordinates and a separate
Metal vertex layout so `GEQUAL` could consume depth. The fresh frame regressed
to the colored diagnostic blocks and the phase was not deterministic enough to
attribute a visual improvement to that change, so the z/layout expansion was
reverted. The retained final executable remains
`70eb453331663ec8046906c95c085aca703d7bf7450c0614df69dd1df942789b`.
## 2026-08-21 — regenerated producer-vector discriminator

The stale generated artifact was removed with the documented object-cache refresh and `(mi)` completed all 546 targets in 8.644s. The signed iPad Simulator app was rebuilt and verified. App executable SHA-256: `65ad649d5dcb4b84433dfb6a6d3bb6af97fda54d149ac9d7d69651429ac4047a`; bundled `GAME.CGO` SHA-256: `ed171577e58765a7de92338b7f22a8194c103a0890debd0f391ff78acbe5b48a`.

Fresh route replay used the file-trigger controls through title-wait → Start → Cross → Down×4 → Cross. The route reached `GAMEPLAY: enter village1` and logged the native source producer before DMA:

```text
OTTSEL SPARTICLE 3D: ... valid=64.0000 first-prims3-reg=20.0000 first-tbp=9458.0000 first-size=64.0000x64.0000
first-xyz=-575829.5625,147080.3750,857026.1250,655.3599
first-flag=0.0370,0.2862,-0.0088,655.3599
first-rgba=16.0000,108.9822,127.0000,124.4400
```

The same route logged lookup/TEX0 tuples `(page 2, index 30, TBP 9458)`, `(24, 9937)`, `(25, 9921)`, `(10, 9426)`, and `(41, no subsequent TEX0 object in the captured window)`. The native source-boundary consumer trace did not arm on this run, so producer→DMA equality remains OPEN rather than inferred. No TBP remap, camera rewrite, shader policy, or Metal policy change was made from this result.

Fresh visual artifact: `/tmp/ottsel-sparticle-vector-route.png`, SHA-256 `86a6899e706628ae92e846b9d4a5836c9f01278f52c949c2991bfdaac59fae9d`. It is still a partial/blank-region composition with diagnostic color blocks and is explicitly not playability proof. Fault log was empty for this capture; lifecycle/audio/playability gates remain OPEN.
## 2026-08-22 — shared transform and culling discriminator

The native Metal TFRAG/TIE vertex equation was compared with the maintained
Jak 1 `tfrag3.vert` shader and `make_new_cam_mat` packing. The common source
contract matches: camera translation, row-grouped PC matrix, Y expansion
`512/448`, and Metal-only depth remapping are all accounted for.

A trigger-only `MTLCullModeBack` probe was run on a fresh signed iPad route.
It did not remove the inverted/triangular geometry and produced
`/tmp/ottsel-scene-cull-back.png` (SHA-256
`96ef5351b78664e1f97e213eba63a7065e391867142483a0ef34a608179c8f6`). The
probe was removed without changing product state. Missing back-face culling is
therefore falsified as the shared cause; the Simulator remains partial and the
composition/playability gate remains OPEN.
The final no-probe signed rebuild was installed after the culling diagnostic was
removed. The exact route again reached `GAMEPLAY: enter village1` twice with a
0-byte fault log. Screenshot `/tmp/ottsel-final-no-probe-route.png` has SHA-256
`95943f547d485896536e3438fea63952375046eb1b5d3ffb03b75f8b975c432d` and the
runtime retained `pcm-peak=0`; the frame remains partial/corrupted and is not
playability proof.
The final lifecycle-polished executable
`eebaaf2454b326d85144640cb99b5aac0d5775a4265ed5a97c96fe59b9c84785` was
installed into the single booted iPad Pro 11-inch (M4) Simulator. The exact
route reached Village1 twice, native input hid the overlay, and the fault log
was 0 bytes. Screenshot `/tmp/ottsel-final-installed-route.png` has SHA-256
`0b3357d8dfab7fd54c78cbc64f152d288d3c1e5aa9ddf10be2a0f2456c7066ec`;
`pcm-peak=0` and visible composition/playability remain open.

## 2026-08-22 — TIE topology contract correction

The first-batch and TIE-only probes showed the malformed frame survived family
and depth isolation. A source-side comparison with the maintained FR3 data
contract found that Jak 1 TIE trees are generated with `use_strips=false`,
while the native TIE consumer expanded both static and visibility-filtered
indices as triangle strips. The consumer now honors the existing flag: direct
triangle lists are emitted in groups of three, while strip trees retain the
strip path. No camera, TBP, texture lookup, shader, culling, or Metal policy
was changed.

The signed iPad build passed deep codesign and the focused
Sprite3/platform-input/keyboard suite passed 21/21. Executable SHA-256:
`cb14908b7c28fca8d3f9d517938892c7e0be7d9d9b4e0c9e0470ec09814f9356`.
The fresh route was launched after `title-wait-ready` and replayed through
Start, Cross, Down four times, and Cross; the fault log remained 0 bytes.
Screenshot `/tmp/ottsel-tie-topology-exact-route.png` has SHA-256
`45a1fa3b912987970206377e503d1906efad30c4aa696c943cdc27112e3c820e`.

This corrected the severe fragmented-triangle symptom: terrain, foliage,
bridges, and the player region became identifiable. The frame is nevertheless
rotated/dislocated with large blank regions and `pcm-peak=0`; it remains a
partial Simulator diagnostic, not playability proof. The native composition
gate and iPad playability gate remain OPEN. The next experiment is the
remaining shared transform/material/visibility contract, not a camera or TBP
remap.

## 2026-08-22 — visibility-group direct-list correction

The topology correction removed strip expansion for Jak 1 TIE trees, but the
fresh frame still contained quadrant-like fragmentation. The visibility path
was then compared against the maintained TFRAG implementation. For direct
triangle-list trees, an invisible visibility group must be omitted; inserting
`UINT32_MAX` shifts every later group when indices are consumed in triples.
The native TIE path now inserts the sentinel only when `tree.use_strips` is
true, matching the TFRAG path. This is a source-side index/visibility fix;
camera, TBP, texture identity, shader, culling, and Metal policy remain
unchanged.

The signed iPad build passed deep codesign and the focused
Sprite3/platform-input/keyboard suite passed 21/21. Executable SHA-256:
`83529274e65a029fdbd37aa5b7b7489869922a4ef0a004bf7d3a5d17d07e360d`.
The fresh route followed `title-wait-ready` through Start, Cross, Down four
times, and Cross. The fault log was 0 bytes. Screenshot
`/tmp/ottsel-tie-visibility-exact-route.png` has SHA-256
`06fb01119e94b2ca17e6dd9b013f00356c8bf938312920dd6e5131d630074151`;
the rotated landscape inspection is `/tmp/ottsel-tie-visibility-settled-landscape.png`
with SHA-256 `50ae0d0a3ba5f21411441be714d955e5d2cf77ce1f38c88db2cc3b71485ca005`.

The direct-list grouping fault is no longer visible and the frame remains
stable after the camera settles. However, large blank regions and a detached
horizontal geometry band remain, audio remains `pcm-peak=0`, and the result is
still a partial Simulator diagnostic rather than playability proof. Native
composition and iPad playability remain OPEN; the next experiment is the
remaining shared transform/material/visibility contract.

## 2026-08-22 — zero-length link-begin crash guard

The supplied Simulator crash report was a boot-thread `SIGABRT` in
`private_assert_failed -> link_control::jak1_jak2_begin -> jak1::link_begin`.
The older binary entered the GOAL object-header parser with a zero-length
object, producing the version assertion. `link_and_exec` already guarded this
case, but the GOAL `link-begin` wrapper did not. The wrapper now returns the
same fast-complete result for `args[2] <= 0` and logs a warning, without
reading the empty buffer. The nested dirty upstream source and canonical
`patches/h3-jak1-host-boot.patch` both contain this guard.

The rebuilt signed executable SHA-256 is
`cfbac6b9a2463a443006c95eddee256d8e9e1d920280264ccd711a1ec768c4b3`; deep
codesign passed and the focused Sprite3/platform-input/keyboard suite passed
21/21. A fresh launch reached `title-wait-ready` with a 0-byte fault log and
did not reproduce the reported abort. The required route was replayed through
Start, Cross, Down four times, and Cross; its fresh screenshot
`/tmp/ottsel-link-guard-exact-route.png` has SHA-256
`56a15266c17f185e638c40338313630e576446cac28e51e14154f89a4e26019c`, also
with a 0-byte fault log.

This fixes the reported boot/link crash, but it does not close the native
composition or playability gates. The Simulator blank/partial warning remains
explicit, and iPhone/device work remains gated on an honestly playable iPad
build.

## 2026-08-22 — newest pending native mesh/color snapshot experiment

Before this change, the fresh route repeatedly queued camera-dependent TFRAG
and TIE mesh/color uploads while the presentation thread drained only a small
FIFO budget per frame. The shell now coalesces pending uploads independently
for TFRAG and TIE, retaining the newest mesh and color snapshot for each
family. This is a source-side queue-consistency fix; it does not remap TBP or
change camera, shader, culling, or Metal policy.

The signed iPad build passed deep codesign and the focused native-input/Sprite3
suite passed 21/21. The exact validated route completed after the
`title-wait-ready` marker and reached `GAMEPLAY: enter village1` twice. The
post-transition lookup tail was `24,25,10,41,30,34`, all resident hits; the
fault log was 0 bytes. The executable SHA-256 was
`68481f6659d8786d3bb395d7520278fe297d78438f500b2e19f74e822eb6d838`.

Fresh screenshot `/tmp/ottsel-coalesced-exact-route.png` has SHA-256
`b3074f046f5e2b00a50b9c087ffab282eae5ca46b27b6637e334380d179223e0`.
Coalescing changed the corrupted frame but did not restore coherent play;
large dislocated/partial geometry remained and audio windows retained
`pcm-peak=0`. The experiment is insufficient to close native composition or
playability; the shared geometry/material consumer boundary remains open.

## 2026-08-22 — synchronized native camera-uniform snapshot

The native presenter previously copied the 32-float TIE/TFRAG camera/fog block
from the game thread while the presentation thread read the same block during
Metal encoding. The shell now protects the update and snapshots the complete
block once per render pass, so both scene families use one stable matrix/fog
set. The shader equation, camera values, mesh selection, texture identity,
depth, culling, and draw order are unchanged.

The signed executable SHA-256 was
`546b283b61c22cf4d7cef7099dd553ae71b8b3f255de431bf4efa8ff40b21bd2`; deep
codesign passed and the focused Sprite3/platform-input/keyboard suite passed
21/21. After `title-wait-ready`, the validated route reached
`GAMEPLAY: enter village1` twice, with resident lookup tail
`24,25,10,41,30,34`, a 0-byte fault log, and native input hiding the overlay.

Fresh screenshot `/tmp/ottsel-uniform-snapshot-route.png` has SHA-256
`45481d23b46bdffa9c58e1a8b8e52f2fa776c640a55f4ca98d5079a3ebe83976`.
Rotated landscape inspection still shows severe oversized/dislocated geometry;
audio remains `pcm-peak=0`. The snapshot removes a data-race hazard but does
not close native composition or the iPad playability gate.

## 2026-08-22 — native-equation projection range ledger

The bounded CPU companion now records the native TIE equation's NDC range after
the Jak 1 `512/448` Y expansion and Metal depth remap. On the fresh Village1
route it sampled `4097/4097` finite vertices, with
`gl-clip-visible=1876` and `metal-clip-visible=1876`. The full sampled ranges
were `ndc-x=(-422.4563,438.0270)`, `ndc-y=(-851.0743,1606.2456)`, and
`ndc-z=(-3.9074,2.6576)`.

This confirms finite source data and agreement between the CPU clip predicate
and the Metal depth-range predicate, but the selected mesh includes very broad
out-of-range geometry. It is not evidence for a camera remap or a playable
frame. The fresh screenshot `/tmp/ottsel-native-projection-ledger-route-final.png`
has SHA-256
`14a8ea18f27437d871bde2f039fa05858dfb86c53bbd001716498a02a0d4db9d`;
the route remained fault-free but visually corrupted and audio remained
`pcm-peak=0`. The next composition experiment must isolate the broad mesh's
material/index/visibility contract rather than changing camera or TBP policy.

## 2026-08-22 — valid TFRAG NORMAL-only discriminator

The TFRAG data-family probe was corrected to arm before launch, before the
first camera-dependent visibility snapshot. It excluded TRANS and DIRT trees
while preserving the NORMAL tree, TIE submission, camera, texture identity,
shader, culling, and Metal policy. The fresh route followed
`title-wait-ready` through Start, Cross, Down four times, and Cross; the fault
log remained 0 bytes.

Screenshot `/tmp/ottsel-tfrag-normal-only-exact-route.png` has SHA-256
`d67ad931c733a1db58c3a82ebfdd9e3120fc50aaf7fb55d4a78f845849cdb099`.
The runtime logged `NORMAL-only data-family probe enabled` and one TFRAG tree
in the resulting visibility snapshot. The detached horizontal band remained,
so TRANS/DIRT is falsified as its sole source. This leaves the common
NORMAL-TFRAG/TIE transform, visibility, or material contract open. The probe
was trigger-gated and is not product behavior.

## 2026-08-22 — controlled TIE/TFRAG family isolation

To separate a family-local upload fault from the shared consumer boundary, the
same fresh validated route was replayed twice with the diagnostic trigger armed
before launch: once with TIE disabled and once with TFRAG disabled. The TIE-off
route produced `/tmp/ottsel-family-no-tie.png` (SHA-256
`f48535d5c33741df4a3ff9236b0ae7ce5142726b33587d97aa359bd3956de342`); its
fault log was 0 bytes. The TFRAG-off route produced
`/tmp/ottsel-family-no-tfrag.png` (SHA-256
`404c186351226f78b67c38a25c374e61a6d73843945ed94a9b0720227995013b`); its
fault log was also 0 bytes. Both routes used one booted iPad Pro 11-inch M4
Simulator and one runtime process, and both retained `pcm-peak=0`.

The TIE-off frame becomes a giant TFRAG close-up, while the TFRAG-off frame
still contains the detached band and dislocated TIE geometry. Therefore neither
family is sufficient to explain the failure in isolation. This is a falsifiable
negative result for a single-family upload fix; the remaining target is the
shared camera/viewport/material contract consumed by both families. No TBP,
camera policy, shader equation, or Metal depth policy was changed.
