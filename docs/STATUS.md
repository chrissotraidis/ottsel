# STATUS — Ottsel

## Current board — 2026-09-11

`docs/BOT43_PROMPT.md` is the authoritative queue (supersedes BOT42/BOT41/BOT40). Platform order is resolved:
macOS is frozen as the accepted behavioral/visual reference, the iPad Simulator
renderer is the active engineering gate (I1), and iPhone/device work stays
behind a coherent iPad route. The 2026-08-21 self-audit below is preserved
evidence history; its "macOS first / mobile paused" ordering is superseded.

Disk: the AGENTS.md 40 GB precondition is still below the floor (Avail ~15Gi on
`/`, 0 temp packs). On 2026-09-10 the user explicitly authorized proceeding
("theres space to work, just keep working"), so the Simulator renderer lane is
active again under the repository's other rules. This is not a cleanup
authorization; nothing is deleted without a separately named action.

Measured on 2026-09-10 (read-only; nothing deleted). Authoritative volume is
`/System/Volumes/Data` (the `/` row shows a sealed snapshot and is
misleading): `df` reports `Avail 20Gi`, `diskutil` reports `Container Free
Space: 21.9 GB`. `tmutil listlocalsnapshots /` shows no local snapshots, so
this is not a purgeable-space artifact and no automatic reclaim will occur.
`/tmp/ottsel-video/` is empty, so the 2026-09-03/04 inspected frames no longer
exist; the only retained frames are `docs/evidence/I1/*-2026-08-18.png`.

Cleanup candidates, largest first: `~/GitHub/galaxypad` 77 GiB (other
project), `~/GitHub/ssbmpad` 18 GiB (other project),
`~/Library/Developer/CoreSimulator/Devices` 18 GiB, `~/.codex/sessions` 17 GiB,
`~/GitHub/paperpad` 14 GiB (other project), `~/Library/Caches` 8.8 GiB
(`BraveSoftware` 1.7 GiB, `bun` 1.6 GiB, `Homebrew` 1.4 GiB, `ms-playwright`
1.0 GiB, updaters ~1.6 GiB), `ottsel/out` 6.5 GiB (regenerable),
`~/GitHub/applyguy` 3.1 GiB (other project), `~/GitHub/goldenpad` 2.6 GiB
 (other project), `~/.codex/worktrees/{13e4,1570,d616}` 2.3 GiB (three stale
detached Ottsel worktrees at `fd69327`, dirty with R1/I1 leftovers; `1570`'s
only unique files were landed on `main` on 2026-09-10, so it is now
disposable), `ottsel/docs/evidence` 889 MiB.


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

2026-08-22 operating corrections are now permanent in root `AGENTS.md`: one
bounded SIGINT video recorder under `/tmp`, disk/tmp-pack gates, no large video
artifacts in the worktree, and concise evidence limits. The orphaned recorder
was closed and 18 temporary packs totaling about 15 GB were removed. A fresh
signed restart stayed alive with a zero-byte fault log, but the new report was
SimMetalHost XPC teardown at native Sprite3 allocation, not the original
encoder assertion. `RenderEncoderEndGuard` now closes the encoder on normal and
exception unwinding; a fresh signed PID 97598 survived 30 seconds plus a
bounded 10-second H.264 capture with zero fault bytes and no encoder/command-
buffer marker. The frame remains visibly incomplete; this is crash stability,
not playability, and the next source-defined composition gate remains open.

| Product stage | Audited status | What is actually proven | What still prevents completion |
|---|---|---|---|
| ARM64/no-emit foundation | **PASS** | OpenGOAL code runs from signed Mach-O `__TEXT` without runtime-created executable code; native host and Simulator boot evidence exists. | Nothing at this layer unless new contradictory evidence appears. |
| macOS stable reference | **PARTIAL PASS — ACTIVE QUEUE** | The fresh 2026-08-21 current-checkout run showed title → New Game → retail cinematics → Village1 → Training, real W movement, ten active interaction cycles, coherent post-soak play, and no matching fault. Keyboard-only and human-audible acceptance remain open. | Repeat cold-start reproducibility, retain raw audio evidence, obtain human audible-output acceptance, prove neutral background/resume lifecycle, and complete a longer controller/keyboard soak before calling macOS stable/playable. |
| iPadOS renderer + runtime | **PAUSED — DIAGNOSTIC ONLY** | Signed Simulator builds can boot, consume scripted input, reach Village1 markers, and emit partial/corrupted Metal output. R1 traces isolate producer/resource differences. | Blocked behind completion of all remaining macOS-stable-reference clauses. Even after unblocking, Direct/Sprite/material composition, visible touch/input/audio, lifecycle, and playable replay remain open. |
| iPhone parity | **PAUSED** | The app declares iPhone support. | Explicitly after iPadOS; then simulator parity and physical-device performance/signing acceptance. |
| Release / handoff | **BLOCKED** | Repository remains ROM-safe; current feature work is local on branch `codex/r1-macos-adgif-output-mapping-2026-08-21` at `d5e12cc`; `main`/`origin/main` remain `549508e`. | All platform playability, device, packaging, and legal user-data workflow gates. |

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

A second fresh macOS replay on 2026-08-21 retained raw stdout/stderr, reached
title-wait → overwrite confirmation → Village1 with real keyboard events, and
recorded nonzero mixed PCM windows (`pcm-peak=2174`, `984`, `415`, `413`, and
`140`). A System Events visibility false/true cycle left the process alive and
produced before/after screenshots; the bounded retained-log fault scan found no
crash, assertion, signal, or Metal command-buffer marker. This is still only a
PARTIAL M1 increment: no human-audible acceptance, physical-controller soak,
or complete neutral background/resume proof was obtained. See
`docs/evidence/M1/m1-macos-coldstart-lifecycle-replay-2026-08-21.md`.

The iPad shell control follow-up now accumulates multiple SDL relative-mouse
events within one event-loop frame before neutralizing the camera impulse. The
signed rebuild passed strict codesign (`OttselShell` SHA-256
`e162c1d42c3a7ad8bb92d3d456d38c96303b2c2b651300cf04b83de95bfd3b4c`) and the
focused input suite passed 4/4. A fresh installed-app Start/Cross/Down×4/Cross
replay reached Village1 twice with a zero-byte fault log; its screenshot is
still visibly partial/corrupted, so controls are build/route verified but not
human-playability verified. See
`docs/evidence/R1/r1-controls-and-lookup-replay-2026-08-21.md`.

## 2026-08-22 — fresh macOS cold-start/audio increment

One fresh Windowed native `gk` run from the current checkout reached
`title-wait-ready`, produced page-2 lookup hits, opened SDL output-only audio,
observed the callback after 2,048 frames, and recorded nonzero PCM windows
including peaks 2547, 1045, 170, and 40. The retained runtime log is
`out/jak-project/log/jak1.2026-08-22T05-47-49.log` with SHA-256
`f557b798663f13748e7cd06da48cbfc11e4412d9e5b3f931a47b09a97e91dd79`; its
bounded scan found no crash, signal, Metal command-buffer, or runtime-fault
marker. The iPad device was shut down and the Simulator GUI closed before the
Mac runtime started, preserving the one-runtime rule.

This is only a fresh M1 cold-start/audio liveness increment. No live keyboard
or mouse edge was delivered during this particular replay, and human
audibility, neutral background/resume, physical-controller soak, and longer
stability remain open. iPad remains diagnostic-only with the blank/partial
Simulator warning explicit. See
`docs/evidence/M1/m1-macos-coldstart-audio-2026-08-22.md`.

## 2026-08-22 — R1 pre-armed source parity branch

The signed iPad app was rebuilt with the canonical lookup trace and replayed
on the one booted iPad Pro 11-inch (M4) Simulator using the durable validated
pack. A pre-armed raw MIPS2C particle/AdGif trace captured the aligned early
families: `0x00203500 -> 0x2004d0e59930a506`,
`0x00200400 -> 0x2004cfe55530a518`, `0x00201200 ->
0x2004d0e59930a506`, and `0x00200f00 -> 0x2004c8e55530a5d2`, matching the
macOS source evidence. The post-Start lookup prefix was `54,49,48,42,44` on
both platforms; page 2 remained a 1,610-entry resident object with segment
destinations `601152/632576/633664`.

This closes the page-directory/lookup/allocation branch as the first
divergence. The later iPad native 3D family remains `TBP=0x24d2/0x2525` with
TEX0 `0x2004d2e59930a4d2`/`0x2014cd655530a525`, versus the macOS `0x24f2`
world oracle and `0x2004d1e59930a4f2`. R1 therefore remains open at producer
phase/data-family ownership and native composition. No TBP, camera, shader,
or Metal-policy remap was made. Fault log was 0 bytes; the Simulator frame
remains explicitly partial/corrupted/blank and audio remains unproven. See
`docs/evidence/R1/r1-fresh-prearmed-source-parity-2026-08-22.md`.

The follow-up replay pre-armed the phase-window trigger as well. At
`chain=146/vsync=147`, bucket 67 was world-only and its first item was
`TBP=0x2506`, TEX0 `0x2004d0e59930a506`; the same run later emitted the
recurring `0x24d2/0x2525` native family. This makes the remaining boundary
chain/vsync-dependent producer/DMA phase ownership rather than a static
lookup/allocation mismatch. The next experiment is complete phase-list and
DMA-interval alignment at the first `MSCAL=211`/`MSCAL=3` transition. See
`docs/evidence/R1/r1-prearmed-phase-owner-2026-08-22.md`.

## 2026-08-22 — macOS live route and native input increment

The next single-runtime Windowed macOS replay used the existing route seam and
accepted Start → Cross → Down×4 → Cross. It logged `GAMEPLAY: enter village1`
twice, accepted a bounded left-stick hold for 180 pad reads, and logged the
release to neutral. The focused native Sprite3/platform/keyboard suite passed
24/24 and the canonical mouse-controls patch reverse-check passed. A fresh
raw log and full-desktop screenshot pair are preserved under
`docs/evidence/M1/artifacts-2026-08-22-macos-route/`.

This remains a bounded M1 partial pass. The screenshots are not clean gameplay
frames, human audibility was not listener-accepted, physical controller and
background/resume neutrality remain unproven, and a longer soak is still
required. No Simulator was booted and no iPad playability claim follows; the
blank/partial Simulator warning remains explicit. See
`docs/evidence/M1/m1-macos-live-route-input-2026-08-22.md`.

## 2026-08-21 — camera-dependent visibility snapshot invalidation

The exact signed iPad route reached Village1 twice after native TFRAG/TIE
visibility snapshots were made camera-dependent. Fresh rebuilds varied from
12,450 to 61,192 TFRAG triangles and from 37,214 to 344,500 TIE triangles as
the frustum changed, eliminating the prior stale-snapshot top-strip/black-region
failure. Signed executable SHA-256 is
`46349ecd296294bb830dd73bd36a61c3012989952369e4c827a508b7618fbdb7`.

The fresh screenshot is
`/tmp/ottsel-cull-invalidation-route.png` (SHA-256
`9f5641022df832e09a9e2a7a1681b7b6689ac7b9c5863cae91045ecff42f3c27`); fault
log is empty. The scene is now coherent without the touch overlay, but
player/HUD/Direct coverage, audio (`pcm-peak=0`), lifecycle, human controls,
iPhone, and physical-device gates remain open. Preserve the explicit
blank/partial Simulator warning and iPad-first completion goal.

## 2026-08-21 — native TRANS/DIRT TFRAG coverage increment

The native consumer now uploads the loaded Village1 NORMAL, TRANS, and DIRT
TFRAG families and selects source-alpha/depth-write behavior from DrawMode.
Signed executable SHA-256 is
`b4134cc63319fd2cbcd156be0a55b7a5fe63889316bfdf132d20a447687c9e20`;
focused Sprite3/input/keyboard tests passed 21/21; and deep codesign passed.
Fresh evidence increased visible TFRAG output to 76,264 vertices / 53,524
triangles across 81 batches, with 2,168 TFRAG TOD colors. Fault log remained
empty.

The fresh screenshot includes the touch overlay because no native input event
had yet been delivered; it is not a clean composition comparison. The
underlying scene still has missing regions and `pcm-peak=0`; this is a partial
composition increment, not an iPad playability pass. Continue with a clean
native-input capture, material-state/order, and remaining Direct/Sprite
composition, preserving the blank/partial Simulator warning and fixed
iPad-first goal.

## 2026-08-21 — native TFRAG/TIE Y-space parity correction

After the source/resource comparison and native consumer probe produced a
falsifiable composition boundary, the Metal TIE vertex shader was aligned with
the upstream Jak 1 `tfrag3.vert` Y-space expansion (`512/448`). The signed
build passed strict codesign; executable SHA-256 is
`e7a8d74c1a05afb48771ca0b90624c397e021afc04e25cbac02cb9234839e0f6`; focused
Sprite3/input/keyboard regressions passed 21/21; and the canonical patch
reverse-check passed. This is a narrow source-side correction, not a camera,
TBP, texture, or Metal-policy rewrite.

No playability claim follows yet: the required fresh post-change screenshot,
input acceptance, audio, lifecycle, iPhone, and physical-device gates remain
open. Keep the Simulator blank/partial warning explicit and preserve the
iPad-first completion goal.

## 2026-08-21 — fresh Y-space replay and TFRAG coverage boundary

The latest signed build produced a materially more coherent fresh native scene
after the Jak 1 `512/448` Y-space correction. The host arrow-key path did not
deliver D-pad events, so the app's own writable file triggers were used to send
four Down taps and Cross through the native keyboard state path. The fresh
fault log was empty; screenshot SHA-256 is
`c955d2f9c4e7ab60be1b8cbdf25637eb6b7ca8ca9469f84dcb87d05456bd1801`; audio
still reported `pcm-peak=0`; and no clean Village1 gameplay marker was reached.

Current FR3 evidence shows Village1 has normal, TRANS, and DIRT TFRAG
families, while the native composition consumer currently uploads only normal
TFRAG geometry. The next source-side experiment is bounded TRANS/DIRT coverage
with correct alpha/depth ordering. Playability remains OPEN, and the
Simulator blank/partial warning, iPad-first goal, ROM safety, and
signed-native/no-runtime-codegen constraints remain unchanged.

## 2026-08-21 — fresh sprite-frame/producer-order discriminator

The R1 canonical trace now includes a bounded GOAL-side
`sprite-add-frame-data` handoff trace. After a full ARM64 `(mi)` regeneration
of all 546 targets, a signed iPad rebuild passed strict codesign and the
focused native suite passed 20/20. The exact validated-pack route reached
Village1 twice on both macOS and iPad.

The fresh ordered page-2 lookup streams differ in particle/spec order, but
shared page/index objects resolve to matching source-side TBP and shape values
on both platforms. The iPad source boundary begins `MSCAL=211` at
`TBP=0x24d2`, TEX0 `0x2004d2e59930a4d2`, then `0x2525`; this is a concrete
producer-phase/order mismatch against the macOS first 3D/world phase, not a
TBP allocator failure or a reason to alter camera, shader, or Metal policy.

The fresh screenshot `/tmp/ottsel-r1-sprite-frame-discriminator.png` remains
severely triangular/corrupted with a large blank region, the fault log is
empty, and audio reports `pcm-peak=0`. The Simulator warning and iPad
playability gate remain explicit. See
`docs/evidence/R1/r1-controls-and-lookup-replay-2026-08-21.md` for the full
sequence/object comparison and exact hashes.

## 2026-08-21 — narrow native Sprite3 post-divide correction

The source comparison authorized one small composition fix: the CPU
`sprite_raster_vertex` path was retaining homogeneous `w` after the reference
shader's perspective divide. A regression failed before the change and the
focused Sprite3/platform/keyboard suite passed 21/21 after it. The signed
rebuild and exact route were healthy at the lifecycle/fault level, but the
fresh frame remained largely blank/triangular and audio still reported
`pcm-peak=0`. This is a verified narrow contract correction, not an iPad
playability pass. The next blocker remains native Sprite3 composition/phase
alignment; no TBP, camera, shader, or Metal-policy compensation is justified.

## 2026-08-21 — producer-object/TEX0 trace regenerated

The R1 diagnostic now records the resolved texture object shape and generated
TEX0 immediately after `particle-setup-adgif` login. A full ARM64 `(mi)`
regeneration rebuilt all 546 targets, and the signed iPad app was rebuilt and
strictly signed. The fresh exact route consumed Start, Cross, Down×4, and
Cross, entered Village1 twice, and captured page-2 object/TEX0 state plus raw
particle/AdGif output. The fault log was empty.

This is a stronger source-side discriminator for the known lookup-hit but
producer-family/phase-divergence boundary. It still does not prove a composed
or playable iPad frame: `/tmp/ottsel-r1-producer-object-route.png` remains
partial/corrupted and audio reports `pcm-peak=0`. The next gate is the matching
macOS producer-object capture; preserve the explicit blank/partial Simulator
warning and do not alter TBP, camera, shader, or Metal policy before that
comparison.

The follow-up native-input replay also made the shell overlay input-aware: the
first keyboard/mouse event hides the diagnostic touch rectangles instead of
letting them cover the game frame. A fresh Simulator screenshot confirms the
colored blocks are gone and textured village geometry is clearer, but large
missing/rotated regions remain and the frame is still non-playable. This
narrows the visual boundary to native composition/layout; it does not close
the iPad gate. See the overlay follow-up in
`docs/evidence/R1/r1-controls-and-lookup-replay-2026-08-21.md`.

The same capture's raw Simulator framebuffer is `1668x2420` portrait despite
the signed bundle's landscape-only plist. A 90-degree rotated inspection copy
shows the scene in landscape but leaves the missing geometry unchanged, so no
SDL orientation or camera change is justified from this artifact. The runtime
retained substantial native TFRAG/TIE geometry; the remaining visual blocker
is still native composition/layout. The Simulator blank-screen and
non-playability warning remains explicit.

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

The latest trigger-gated iPad capture now preserves the full producer IDs:
`0x00200f00` maps to `TEX0=0x2005a0455530ac8d`, while the mobile-only
`0x00203600` maps to `TEX0=0x20159da4cd40abd2`; macOS maps its corresponding
producer family to `0x2004...` TEX0 values. The page entries are resident hits
and the allocator attribution remains default allocation for the mobile-only
family, so R1 is narrowed to producer phase/data-family or DMA handoff
ownership. See `docs/evidence/R1/r1-particle-adgif-same-route-capture-2026-08-21.md`.
The fresh screenshot remains visibly partial/corrupted and audio `pcm-peak=0`,
so no playability claim follows. The shared desktop input seam also now clears
stale keyboard/mouse active actions on focus loss via
`patches/r1-input-focus-neutral.patch`.

The next fresh signed iPad R1 replay added page-directory and segment-state
logging. Page 2 remained a resident hit in a 1,610-entry directory, but its
segment destinations changed from `601152/632576/633664` under allocator
selector 1 to `711424/742848/743936` under selector 6 before the Village1
lookup family. This is an allocation/order discriminator, not permission to
remap TBP or change camera, shader, or Metal policy. See
`docs/evidence/R1/r1-page-directory-state-2026-08-21.md`.
The equivalent Mac trace keeps the original page-2 destinations throughout,
while its lookup order is `4,53,4,18,15,30,0,28,3,41,24,...` versus the
iPad's reordered post-Start window beginning `54,49,48,42,44`; the source
ordering question remains open. The iPad boot now registers the native
`engine`/`art`/`common` package markers after direct GAME.CGO linking, so the
duplicate ART.CGO load is gone and page 2 relocates only once at
`601152/632576/633664`. This fixes allocation ownership but not lookup parity;
it still makes no TBP or renderer-policy changes. See
`docs/evidence/R1/r1-page-directory-state-2026-08-21.md`.

## 2026-08-21 — phase-aligned R1 raw producer parity

The prior lookup-order comparison was phase-contaminated: it compared records
before the Start edge with records after the Start edge. A fresh iPad replay
armed the particle trace before Start, and the macOS reference was captured
with the same boundary. The aligned post-Start page-2 window begins
`54,49,48,42,44` on both platforms.

The aligned raw producer/TEX0 pairs also match, including
`0x00203500 -> 0x2004d0e59930a506`, `0x00200400 -> 0x2004cfe55530a518`,
`0x00201200 -> 0x2004d0e59930a506`, and
`0x00200f00 -> 0x2004c8e55530a5d2`. The iPad page-2 object relocates once at
`601152/632576/633664`, with no duplicate `ART.CGO` load. This closes the
current page-directory/texture-object mismatch hypothesis; it does not close
R1/native composition because the iPad phase/TBP stream and visible frame are
still not macOS-equivalent. The fresh screenshot remains corrupted and audio
reports `pcm-peak=0`. See
`docs/evidence/R1/r1-phase-aligned-raw-parity-2026-08-21.md`.

The next experiment is the first same-transition iPad `MSCAL=211` source item
with frame/matrix and DMA ownership compared against macOS, followed by the
smallest before-failing native Sprite/material composition fixture. No TBP,
camera, shader, or Metal-policy change is justified before that comparison.

That source-boundary capture is now complete. With the trigger armed before
launch, the first eligible iPad Village1 item was `MSCAL=3`, 48 sprites,
`TBP=0x2506`, `64x64`, frame transfer 9, matrix transfer 12, and
`first-tex0=0x2004d0e59930a506`, using the same camera tuple and raw/TEX0
family as the macOS same-transition reference. This closes the current
R1 page/TEX0/first-world-boundary hypothesis. The fresh screenshot still has
large missing regions and diagnostic controls, so the next implementation gate
is native Direct/Sprite/material composition; audio remains silent. See
`docs/evidence/R1/r1-first-source-boundary-parity-2026-08-21.md`.

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

## 2026-08-21 — fresh exact iPad R1 replay and native composition boundary

The fixed iPad-first product goal remains in force: the current iPad result is
diagnostic and not playable. A fresh signed build from the canonical R1 trace
patch was installed into one iPad Pro 11-inch (M4) Simulator with one runtime
and a validated user pack imported through F1. The exact route title-wait →
Start → Cross → Down×4 → Cross reached Village1 twice.

The raw page-2 lookup sequence was `54,49,48,42,44`, followed later by
`24,25,10,41,30,34,9`. Same-route particle/AdGif records resolved, among
others, `0x00201200` → TEX0 `0x2004d0e59930a506`, `0x00200000` →
`0x2004c1259930a6e1`, and `0x00200f00` → `0x2004c8e55530a5d2`; native source
boundary chain 1643/VSYNC 1644 produced 512 world sprites, and the native
Sprite3 consumer was live. This is evidence against a current page-directory
or simple lookup remap failure, not proof of macOS parity for every later
producer phase.

The fresh screenshot `/tmp/ottsel-r1-exact-route.png` has SHA-256
`5b8d6820ee0e4fac8aa1b3f88694a96bda6f101198164b5ede1414045c5a466f` and still
contains large missing/triangular corrupted regions. The fault log was empty;
audio transport ran but reported `pcm-peak=0`. Therefore the iPad playability
gate remains OPEN. Preserve the explicit blank/partial Simulator warning and
do not change camera, shader, TBP, or Metal policy until a same-phase macOS
producer comparison identifies a concrete contract mismatch. Full details:
`docs/evidence/R1/r1-controls-and-lookup-replay-2026-08-21.md`.

## 2026-08-21 — fresh signed native-input route

The signed executable `46349ecd296294bb830dd73bd36a61c3012989952369e4c827a508b7618fbdb7`
was installed into the one booted iPad Simulator and replayed through
title-wait → Start → Cross → Down×4 → Cross. The route reached Village1 twice,
produced eight bounded Sprite source items (`world=512`), and uploaded one
native textured Sprite3 candidate (`texture=0x26d1`, 64×64). The fresh
screenshot `/tmp/ottsel-fresh-controls-r1.png` has SHA-256
`246e587053a160d46dd062e56b352c08c93b486f5a5da74584a857c17ba7b508`.

The Simulator image is still blank/partial and not playability proof; audio
continues to report `pcm-peak=0`, while the fault output remains empty. Native
mouse/keyboard handling is implemented and the focused Sprite3/platform/
keyboard suite passes 21/21, but human WASD/mouse acceptance remains OPEN.
Player/HUD/Direct coverage, lifecycle, iPhone parity, and physical-device
readiness also remain OPEN.

## 2026-08-21 — scene depth-state falsification probe

A trigger-gated `ottsel-trace-metal-scene-no-depth` diagnostic was exercised
on signed executable
`8c96bdbe1542f74bee6cf944d512846924816ece1a3f7d7e126b2410cee41d82`. The exact
iPad route reached Village1 twice. Normal depth testing produced an almost
empty frame even though CPU projection found `1876/4097` sampled TIE vertices
inside Metal clip space and the native backend submitted large TFRAG/TIE
meshes. Disabling only the scene depth test produced a full, though heavily
corrupted, Village1 scene in
`/tmp/ottsel-scene-no-depth-landscape.png` (SHA-256
`7e0c802cdf89c67daf512ba49064c611b04e2f392015ddb23868cc9629e2f184`).

This localizes the next source-side fix to native depth compare/depth mapping
or ordering. Normal product depth policy remains unchanged pending that
falsifiable comparison. Fault output was zero bytes and audio remained
`pcm-peak=0`; iPad playability, controls acceptance, Direct/Sprite/HUD
composition, iPhone parity, and physical-device readiness remain OPEN.

## 2026-08-21 — native forward-Z depth correction

The depth probe established that the native shader already remaps desktop
OpenGL depth into Metal's forward `[0,1]` range. Normal Metal composition now
uses `LESS_EQUAL` with a clear depth of `1.0`; the no-depth path remains a
trigger-gated diagnostic. Signed executable SHA-256:
`75d8832486032639e0bc334f95ae88ff4ec4a30627d52d268defdca4c7b09e51`.

A fresh exact route without a probe reached Village1 twice and produced the
normal-depth screenshot `/tmp/ottsel-forward-depth-route-landscape.png`
(SHA-256 `5844373b7145dfde018210a799b050415899d65b610320da00fa4809216dba9a`).
The frame now contains the full native scene rather than the prior nearly
empty image, but it remains heavily corrupted and is not playability proof.
The lookup tail remains `24,25,10,41,30,34,9`; fault output is empty and audio
still reports `pcm-peak=0`. Direct/Sprite/HUD composition, human controls
acceptance, lifecycle, iPhone parity, and physical-device readiness remain
OPEN.

## 2026-08-21 — fresh signed iPad owner-correlation replay

The current no-emit arm64 iPad app was rebuilt and passed strict deep
codesign (executable SHA-256
`c6fb92017247db7ff7d816f6fa844579adc3a3ded7fec4ccdbb099a4becc64af`). The
single booted iPad Pro 11-inch (M4) Simulator consumed the exact
title-wait → Start → Cross → Down×4 → Cross route through the native keyboard
seam and reached `GAMEPLAY: enter village1` twice. The fresh page-2 lookup tail
was `25,24,10,41,30,34`, all resident hits; fault output was 0 bytes and audio
mix windows remained non-audible at `pcm-peak=0`.

Screenshot `/tmp/ottsel-r1-signed-owner-route.png` remains severely
rotated/distorted and is not playability evidence. The iPad mips2c `/tmp`
owner trigger did not emit a separate launch-owner trace in this replay, so no
owner parity claim is made. Source/resource and native-composition gates,
human mouse/keyboard acceptance, lifecycle, iPhone, and physical-device gates
remain OPEN. See
`docs/evidence/R1/r1-launch-owner-correlation-2026-08-21.md`.

## 2026-08-21 — fresh native keyboard/mouse delivery evidence

A fresh install of signed executable
`60d2d93f22ef427146f16c8a16b438584122dcc20fa89da1c59421b3afa3663a` replayed
title-wait → Start → Cross → Down×4 → Cross and reached Village1 twice. The
post-route screenshot `/tmp/ottsel-continuation-route2.png` has SHA-256
`700d196499884210c81e4c094161c5a2f303e995b9e4ffe1bb9a4e24f7c5a7d4`; the
fault log is 0 bytes. The raw post-transition lookup tail was
`24,25,10,41,0,30,34,9`, all resident hits, and still differs from the macOS
phase/order oracle.

Actual Simulator Capture Keyboard delivery produced native `w/a/s/d` records
with left-stick states `(127,0)`, `(0,127)`, `(127,255)`, `(255,127)`, each
returning to neutral `(127,127)`. Captured pointer motion reached the native
mouse-motion path and left-click reached Cross with pressure 255. Right-click
remains unproven because this Simulator gesture synthesized touch/Cross.
The scene remains visibly distorted and audio remains `pcm-peak=0`; the
Simulator is still blank/partial relative to the playability gate. This proves
input delivery, not a playable build. HUD/Direct/3D, lifecycle, iPhone, and
physical-device gates remain OPEN.

## 2026-08-21 — native layer isolation and camera-layout falsification

Trigger-gated layer probes show the remaining corruption is shared by both
native scene families. The no-TIE frame
`/tmp/ottsel-no-tie-landscape.png` (SHA-256
`eae214c826f36a7a04197a36b3d574193e5aa5d9397b48738b5f17bb00399758`) still
contains warped TFRAG geometry, and the no-TFRAG frame
`/tmp/ottsel-no-tfrag-landscape.png` (SHA-256
`5ff6fc710551acc48662eb0b7ba938e13312c72ca36794b58fa36d6e488a638d`) still
contains warped TIE geometry. A source-backed camera storage repack was then
falsified by severe radial distortion in
`/tmp/ottsel-camera-layout-route-landscape.png` (SHA-256
`20d9d3364d8681c611c4668faf231bb5b33dd64530f31bf2baa4a57711334601`) and was
reverted. The forward-Z depth correction remains the product state; camera
policy was not changed by the failed experiment. Playability and all later
gates remain OPEN.

## 2026-08-21 — valid post-Village1 Sprite3 product ledger

The product-window, frame-aggregate, source-boundary, and bounded-record
triggers were armed only after the first fresh `GAMEPLAY: enter village1`
marker. The valid frame recorded five groups: world `48 @ TBP 0x2506` with raw
TEX0 `0x2004d0e59930a506`, a zero-text 16-sprite placeholder, then HUD groups
`48 @ 0x2517`, `48 @ 0x252d`, and `32 @ 0x21fd`. No 3D group appeared in the
frame.

The first mobile world group matches the synchronized desktop group-0 decoded
identity, including the 64×64 shape and RGBA hash
`0xc8679915dfac0e15`. The later macOS world phase continues through the
`0x24f2` / 9458 family and many more world groups. The remaining R1 gap is
therefore producer phase/packet-window ownership, not a TBP remap or texture
decode defect. Screenshot:
`/tmp/ottsel-product-window-village1-armed.png` (SHA-256
`7a4e3c40309e63c2dcd4ae4a7e9c888265f706f4a1601ef194f1f0f9c7adc9d7`). Fault
output is empty and audio remains `pcm-peak=0`; playability remains OPEN.

## 2026-08-21 — restored clean route and remaining R1 ordering mismatch

The falsified camera repack was reverted and the signed app rebuilt as
`82991f20cb1a6ae7b30d1cb20f6147cce99ebf1ca5543d4044df40c9fb73457a`. A fresh
route with no diagnostic probes reached Village1 twice. The normalized frame
`/tmp/ottsel-restored-forward-depth-route-landscape.png` has SHA-256
`ddf1ea60f37eea802ee60c4c44b4faccb82e5cc0266d846015c7c5ae6093c63d`; it
confirms the restored forward-Z scene path but remains visibly corrupted and
not playable.

The current post-transition page-2 lookup tail is
`8,30,25,10,41,24,34,9`, which differs from the completed macOS oracle's
phase/order stream. Every observed mobile entry is a resident hit, so the
remaining R1 mismatch stays upstream of TBP remapping and requires further
same-phase producer/resource-family ordering correlation. Fault output is
empty and audio remains `pcm-peak=0`; all playability and later gates remain
OPEN.

## 2026-08-21 — bounded HUD phase consumer and native mouse tap latch

The desktop Sprite3 reference confirms HUD MSCAL 109 uses a separate 0x500-byte
matrix upload, `hud_matrix`, and one of 76 HVDF offsets; it must not use the
World2D camera matrix. The iPad consumer now captures that exact HUD matrix
shape and routes only MSCAL 109 records with a captured HUD setup through a
phase-specific raster path. World2D MSCAL 3 and the source/resource lookup
path are unchanged. A native mouse Cross/Circle press also now uses the same
bounded eight-pad-read tap latch as keyboard actions, while held state remains
live.

The signed rebuild executable SHA-256 is
`60d2d93f22ef427146f16c8a16b438584122dcc20fa89da1c59421b3afa3663a`.
Strict deep codesign and the canonical R1 patch reverse-check pass. The
focused Sprite3/platform/keyboard suite remains 21/21. This is an
implementation increment, not playability proof: the fresh visual gate still
needs a new post-Village1 screenshot and human WASD/mouse acceptance, and the
scene remains visibly corrupted with audio at `pcm-peak=0`. HUD, Direct/3D,
lifecycle, iPhone parity, and physical-device gates remain OPEN.

## 2026-08-21 — first normal-product World2D Metal upload

Signed executable `6937eb1c0cb37e83cc30dfdfcb2273063ed283a49fe359dd53ab607a5c8ef83d`
was freshly installed and replayed through the required route. Without a
Sprite3 Metal trigger, the normal product path accepted the validated World2D
shape contract (`count=48`, PSM19, 64×64) and uploaded `native group=0 index=0`
using live TBP `0x2506`. No TBP remap or camera/depth/shader policy changed.

Fresh screenshot `/tmp/ottsel-native-world-product-route.png` has SHA-256
`ec65e31c8cad68e4695b2bb80511c974854c9ad07e14f5e2bbf3f51ce7d773dc`; the
fault log is 0 bytes. The route reached Village1 twice, but the app still
shows only a distorted/partial ground-and-sky scene without coherent
player/HUD composition, and audio remains `pcm-peak=0`. This is a bounded
native-composition increment, not playability proof; Direct/3D, full Sprite3,
audio/lifecycle, iPhone, and physical-device gates remain OPEN.

## 2026-08-21 — mixed-TEX0 World2D atlas upload

The validated 48-sprite World2D group contains three live TEX0 identities and
color-only placeholders, so the single-texture upload boundary was widened to
assemble a transient 512×512 atlas and submit all 48 quads as 288 native Metal
vertices. A stale-request guard also prevents a later 16-sprite zero-text
placeholder from being uploaded as product content.

Fresh signed executable SHA-256:
`4ab393d28e14ae48b23ff1d7b1e30304d731454d3e49f7740bfcf6851a7d1284`.
The fresh route reached Village1 twice and logged
`native World2D atlas vertices=288 sprites=48 textures=3 atlas=512x512`.
Screenshot `/tmp/ottsel-native-world-atlas-route.png` has SHA-256
`b9510a2109ce3a5a0fc0b1678f9860354b5ec350ebe8b89df96ca6d44d895886`; fault
output is 0 bytes. The frame remains distorted/partial without coherent
player/HUD composition and audio remains `pcm-peak=0`; playability and all
later Direct/3D, lifecycle, iPhone, and physical-device gates remain OPEN.

## 2026-08-21 — native HUD atlas composition and fresh route

The native Metal Sprite3 presenter now retains the validated World2D batch and
appends HUD batches for the current present, expiring only transient HUD data
after encoding. MSCAL 109 uses the existing 0x500-byte HUD matrix, selected
HVDF offset, live TEX0 decode, and a transient 512×512 atlas; no TBP remap,
camera, shader, or depth-policy change was made.

Fresh signed executable SHA-256:
`291b28902ffa7c27d543ad728a91c9e1e171414e016400c158d008a5ce78e37f`.
The fresh title-wait → Start → Cross → Down×4 → Cross route reached Village1
twice and logged native HUD batches of 48/48/32 sprites. Raw lookup tail was
`54,49,48,42,44,25,10,41,24,30,34,9`, all resident hits and still divergent
from the completed macOS order. Screenshot `/tmp/ottsel-hud-route.png` has
SHA-256 `02db39251b7f2c3987e097b4a8cafe726bdda634b7ef6d680e005ce83f102fad`;
fault output is 0 bytes and audio remains `pcm-peak=0`.

The frame is still visibly corrupted and lacks coherent Jak/player/HUD
composition, so this is a native-composition increment, not playability proof.
Direct/3D/material completion, audio/lifecycle, iPhone parity, and
physical-device gates remain OPEN. The Simulator blank/partial-screen warning
therefore remains explicit.

## 2026-08-21 — phase-window TEX0 ledger

The next source-side ledger now records phase-item AdGif TEX0, `tex0_addr`,
and first vector alongside TBP/PSM/size. A fresh signed replay with the exact
route reached Village1 twice. Its phase window saw bucket 66 empty and bucket
67 world-only (11 groups/512 sprites), first TBP `0x25d2`, TEX0
`0x2004c8e55530a5d2`; lookup entries remained resident hits. A prior
same-checkout window captured the alternate bucket-67 prefix of 48 3D sprites
at `0x24d2`, 16 at `0x2525`, then world `0x25d2`, while macOS begins at
`0x24f2`. This establishes chain/timing-dependent producer phase ownership,
not a stable TBP mapping defect.

Fresh executable SHA-256:
`2b162c85701ca99afb4d3607a064e3b04c9e64e9fa7c30839eaff183600210b4`.
Screenshot `/tmp/ottsel-r1-phase-tex0-route.png` has SHA-256
`b0e51cab700270fcb5c68a201208de684334e9bc58bb21f7a2bd5191d32704eb`;
fault output is 0 bytes and audio remains `pcm-peak=0`. The frame is still
corrupted/partial and non-playable, so Direct/3D/material, lifecycle, iPhone,
and physical-device gates remain OPEN. See
`docs/evidence/R1/r1-phase-window-tex0-ledger-2026-08-21.md`.

The follow-up fresh particle-AdGif trace aligned raw page-2 IDs with the
native world item: `0x00203500 -> 0x2004d0e59930a506`, `0x00200400 ->
0x2004cfe55530a518`, `0x00201200 -> 0x2004d0e59930a506`, and the `0x30/0x31`
family. The current phase window remained world-only; the prior chain-4965
window showed the alternate 3D prefix. This confirms producer TEX0 continuity
for the world family while leaving the chain-dependent 3D owner unresolved.
Fresh screenshot `/tmp/ottsel-r1-particle-phase-route.png` has SHA-256
`da17573fd3e499fad6d58e33986853eb8cc5faac159ff0d5ccd77c861de72dac`;
fault output remains 0 bytes and audio remains `pcm-peak=0`.

## 2026-08-21 — inherited bucket-67 Sprite3 pass

The product parser now exports bucket-66 frame/matrix setup and performs a
bounded bucket-67 Sprite3 pass with that inherited setup. MSCAL=3/109 remain
the only product consumers; MSCAL=211 remains diagnostic-only pending a proven
3D material contract.

Fresh signed executable SHA-256:
`dded8ca510462bcf0b06f739c2f0186ae5bd575282d2201ca837a83f16137883`.
The exact route reached Village1 twice and logged bucket-67 Sprite3
consumption (`consumed=64`, inherited frame/matrix/HUD setup). Screenshot
`/tmp/ottsel-bucket67-pass-final-route.png` has SHA-256
`4b38a869947d489fca6ff1f859dc0cebb8f1e03ef78bc06efff6d2c00fee18be`;
fault output is 0 bytes and audio remains `pcm-peak=0`.

The screenshot remains corrupted/partial and is not playability proof. The
Simulator blank/partial-screen warning remains explicit; Direct/3D/material,
lifecycle, iPhone, and physical-device gates remain OPEN.

## 2026-08-21 — MSCAL=211 native consumer source-contract correction

The first bounded native consumer for the proven `MSCAL=211` 48/16 Sprite3
tuple now executes live TEX0/CLUT decoding on the signed iPad build. The
source-side comparison found and corrected two CPU-port contract errors: the
quaternion matrix was transposed relative to the maintained GLSL column-major
`mat3`, and projected-area fade used `Q*Q` instead of the source shader's one
`Q` before its final alpha multipliers. No TBP remap, camera, shader, or Metal
policy change was made.

Fresh executable SHA-256:
`b9840c49aea9c90631ccf645e74524a73884731ce3df3cbceff33af31895672d`.
Focused Sprite3/input tests passed 21/21 and strict deep codesign passed. The
fresh screenshot `/tmp/ottsel-native-equation-route.png` has SHA-256
`86cfb2228efe700ed930340dd37eb9210ecb862f72f01cdbb0d2293ecb562ebc`; it shows
more decoded village geometry but remains severely miscomposed with missing or
rotated regions and diagnostic blocks. This is not playability proof. Audio,
iPhone parity, lifecycle, and physical-device gates remain OPEN. See
`docs/evidence/R1/r1-native-composition-consumer-boundary-2026-08-21.md`.

The converged-camera follow-up then captured chain 299/VSYNC 300 with the
macOS-matching `pfog0=-0.036405455`, `inv-area=0.036767285`, and basis
`(0.25105703,0.14644994)`, but the groups remained world-only `MSCAL=3`; no
same-chain `MSCAL=211` followed that packet. This rules out treating the
earlier 3D phase as merely a stale camera scalar. A separate native-z/layout
experiment regressed to diagnostic blocks and was reverted. The next R1 step
is producer phase/data-family ownership, not another native depth or camera
change. Full log: `/tmp/ottsel-converged-phase-route-1787368217.log`.

## 2026-08-21 — Sprite3 depth compare and producer-phase follow-up

The native Sprite3 Metal state now preserves Jak 1's source packet contract:
`GEQUAL` depth testing with depth writes disabled. TIE remains on its separate
forward-Z `LessEqual` state. This was a narrow state correction; no TBP,
camera, shader equation, or resource-selection remap was made.

Fresh signed executable SHA-256:
`70eb453331663ec8046906c95c085aca703d7bf7450c0614df69dd1df942789b`.
Codesign passed and focused Sprite3/platform-input/keyboard tests passed 21/21.
The fresh screenshot `/tmp/ottsel-depthfix-route.png` has SHA-256
`308aae9e6c4addca4e3d2ffe87d5183bd1cc34d2816380dfbcd9f29970a848b`.
The frame is materially less corrupted and has no prior diagnostic color
blocks, but still lacks coherent Jak/player/HUD composition and remains
non-playable. Fault output was 0 bytes; audio remains unproven/non-audible.

The same run captured early world-only Sprite3 chains with
`pfog0=-0.046546843`, `inv-area=0.10231715`, basis
`(0.41880882,0.24430515)`, and `TEX0=0x2004d0e59930a506`. Later camera packets
converged to the macOS scalar values `pfog0=-0.036405455` and perspective
`(-0.25105703,-0.14644994,...)`. This localizes the next R1 experiment to
timing/phase-owned producer/frame state: capture the first `MSCAL=211` group
after the converged packet and compare its frame/matrix hash and vector with
macOS before expanding native composition further. See
`docs/evidence/R1/r1-native-composition-consumer-boundary-2026-08-21.md`.
### 2026-08-21 — producer-vector trace regenerated and replayed

The documented stale-object refresh plus ARM64 `(mi)` completed all 546 targets
and the signed iPad app was rebuilt. Fresh title-wait → Start → Cross → Down×4
→ Cross reached `village1` and now logs the compiled producer vector before
DMA (`valid=64`, first TBP 9458, first xyz `-575829.5625,147080.3750,
857026.1250,655.3599`). Lookup/TEX0 pairs remained page 2 with indices 30,
24, 25, 10, and 41 in the captured route window. The native source-boundary
consumer did not arm on this replay, so producer→DMA equality is OPEN; no TBP,
camera, shader, or Metal policy remap was made. The fresh image remains a
partial composition with blank regions and diagnostic blocks, so it is not
playability proof. See `docs/evidence/R1/r1-native-composition-consumer-boundary-2026-08-21.md`.
## 2026-08-21 — 3D producer-to-DMA boundary closes handoff hypothesis

Fresh signed iPad replay with the source-boundary trigger restricted to MSCAL=211
captured an exact producer/DMA match: producer first TBP `9478`, vector
`(-553754.5000,199062.4062,879162.4375,24576.0000)`, and native boundary
TBP `0x2506` with the same vector, flags, RGBA, and TEX0
`0x2004d0e59930a506`. The selected iPad family is therefore reaching the native
consumer intact. The completed macOS family begins at TBP `9458` (`0x24f2`),
and the raw page-2 lookup stream diverges earlier: iPad `18,15,28,27,3...`
versus macOS `54,49,48,42,44...`. iPad page-directory metadata and segment
destinations remain identical across these entries, so this is now a
phase/particle-family selection problem upstream of native Metal; FR3/DGO
ordering and allocation remain the next trace. No TBP, camera, shader, or
Metal-policy remap was made. The fresh image remains partial/blank with
diagnostic blocks, fault log 0 bytes, and audio `pcm-peak=0`; playability and
all later gates remain OPEN. See
`docs/evidence/R1/r1-first-source-boundary-parity-2026-08-21.md`.
## 2026-08-21 — lower-level 3D launch-owner result

The GOAL `sp-queue-launch` wrapper produced no 3D records on the validated
route, so the trace moved to the actual Jak 1 mips2c
`sp-launch-particles-var` call immediately before `particle-adgif`. The first
3D launch IDs were page-2 indices `53,4,18,0,15,28`; the first active output
was index `18`, TBP `0x2506`. The native MSCAL=211 boundary matched its
producer vector/TEX0 exactly. The completed macOS reference’s first active 3D
output is index `30`, TBP `0x24f2`. The source divergence is therefore now
localized to lower-level 3D launch/particle-family selection before AdGif/TEX0
generation. `patches/r1-sparticle-mips2c-launch-owner.patch` reverse-checks;
it is diagnostic-only. The fresh image remains partial/blank, fault log is
empty, audio remains `pcm-peak=0`, and playability/later platform gates remain
OPEN.

## 2026-08-21 — level-remap ledger closes remap-result hypothesis

The bounded `level-remap-texture` trace was regenerated into all 546 GOAL
targets and included in a fresh signed iPad build. Both the current-checkout
macOS run and the validated-pack iPad replay sampled page-2/index-1 remaps as
identity mappings: input page 2/index 1 → output page 2/index 1. The iPad
route reached Village1 twice; its later lookup records remained resident hits
at indices 24, 25, 10, 41, 0, 30, 34, and 9. Fault output was 0 bytes and
audio remained `pcm-peak=0`.

This falsifies a differing `level-remap-texture` table result as the cause of
the raw 3D family divergence. The remaining R1 boundary is particle/data-family
selection and launch ordering after remap and before AdGif/TEX0/native
composition. The Simulator screenshot remains distorted/partial and is not
playability proof. See
`docs/evidence/R1/r1-level-remap-ledger-2026-08-21.md`.

## 2026-08-21 — particle texture init boundary isolated

The next diagnostic was added immediately after the launcher `spt-texture`
init-spec is applied by `sp-init-fields!`, before `particle-adgif` consumes the
initialized field. A fresh native macOS runtime capture showed declared and
initialized values agreeing for representative 3D families page 2/index
`53,4,18,41` (`0x203500`, `0x200400`, `0x201200`, `0x202900`). This keeps the
remaining hypothesis at launcher/DGO allocation or ordering versus later
texture-object/data-family state. The same boundary still needs the fresh
signed iPad replay; this is not an R1 parity or playability pass. See
`docs/evidence/R1/r1-particle-init-texture-boundary-2026-08-21.md` and
the iOS-sandbox AdGif trigger remains in the intentionally dirty generated
upstream worktree alongside the maintained R1 trace patches.

The owner-index follow-up added a bounded scan of the GOAL
`*part-id-table*` at the launch call boundary. The fresh signed iPad replay
selected indices `336,334,335,331,332,333,341,340,339,338,342,347,346,337`,
while the same macOS route selected platform-local indices
`1951,1950,1949,1975,1974,1973` for its initial `0x2035/0x2004` family and
`485,483,481,480,479,414,510,1972,1971,1970,1969` later. These are not stable
identities; the differing table positions are a direct launcher/DGO
registration-order or allocation discriminator. No renderer policy or TBP
mapping has changed.

The source definitions make the split concrete: iPad indices `331–347` are
progress/HUD `defpart` entries, while macOS initial indices `1949–1951` and
`1973–1975` are weather/sun entries; later macOS indices `479–485` and
`1969–1972` are Village1 particle definitions. This is now a content
selection/order mismatch before the native Sprite3 consumer. The retained
macOS owner log is `/tmp/ottsel-owner-id-mac-route2.log`.

The fresh signed iPad replay then added an iOS-sandbox AdGif trigger so the
source ID, AdGif TEX0, and native Sprite3 boundary could be captured together.
The route again reached Village1 twice. Its raw page-2 prefix was
`4,53,4,18,0,15,28,27,3,54,49,48,42,44`; sampled entries were resident hits,
and declared/initialized particle texture values agreed. Raw `0x00201200`
resolved to `TEX0=0x2004d0e59930a506`, while the first eligible native
`MSCAL=211` group was `TBP=0x24d2` / `first-tex0=0x2004d2e59930a4d2`.
This keeps R1 at producer phase/order and data-family selection before native
composition. Fault output was 0 bytes, audio remained `pcm-peak=0`, and the
fresh screenshot remained partial/corrupted; no playability claim follows.

### Phase-aligned owner correction

The startup owner-index comparison was phase-contaminated. A fresh replay armed
the owner and AdGif traces after the current-boot Village1 marker. iPad then
selected the same macOS launcher IDs `1951`, `1950`, and `1949` for raw
`0x00203500`, `0x00203500`, and `0x00200400`, with matching AdGif values
`0x2004d0e59930a506` and `0x2004cfe55530a518`. This closes the earlier
progress/HUD-versus-weather interpretation and the matched particle/data
family for the Village1 phase. R1 now advances to native Sprite3/material
composition; the iPad screenshot remains corrupted/partial and audio remains
silent, so playability is still OPEN.

The final phase-aligned iPad replay armed the native source boundary before
launch and owner/AdGif traces after Village1. It captured the macOS-comparable
Sprite3 groups `MSCAL=211 count=48 TBP=0x24f2 first-tex0=0x2004d1e59930a4f2`
and `count=16 TBP=0x2525 first-tex0=0x2014cd655530a525`, while retaining the
matched owner/TEX0 pair `0x00203500 -> 0x2004d0e59930a506`. This closes the
current R1 source/resource parity slice. The screenshot remains
partial/corrupted and audio remains silent, so native composition and the P2
playability gate remain OPEN.
## 2026-08-22 — native mouse/keyboard correction and shared-composition probe

The signed iPad Simulator app was rebuilt after a narrow shell correction. Mouse
buttons remain Cross/Circle actions and no longer inject a forward left-stick
direction when both are held; native mouse input also enables SDL relative mode
for camera motion. The executable hash is
`dec641e5fc776aaada46d67745da78710c166acc87fc2be19d52b61c2b543144`, strict
deep codesign passed, and the focused Sprite3/platform-input/keyboard suite
passed 21/21.

A fresh install on the single booted iPad Pro 11-inch (M4) Simulator replayed
title-wait → Start → Cross → Down×4 → Cross; `GAMEPLAY: enter village1`
appeared twice and the fault log was 0 bytes. The fresh screenshot
`/tmp/ottsel-controls-fixed-route.png` has SHA-256
`81635093b4c750ef1e9c6d7e1380dac00980ca2d7aa8ebb4d88da381bf1e6cbc`.
It remains partial/corrupted and is explicitly not playability proof.

The existing trigger-gated no-TIE and no-TFRAG probes were also replayed on
fresh app boots. Each isolated consumer still produced the lower/inverted
geometry, so neither consumer alone explains the shared distortion. No camera,
TBP, shader, or Metal policy change was made; the native composition source
gate remains open.
## 2026-08-22 — shared-composition culling probe falsified

The maintained desktop TFRAG/TIE transform was compared against the native
Metal vertex equation and the source matrix packing; they match the upstream
`tfrag3.vert` contract. A trigger-only Metal back-face-culling probe was then
run on a fresh signed iPad install through title-wait → Start → Cross →
Down×4 → Cross. It did not remove the inverted/triangular geometry and instead
produced a different corrupted frame (`/tmp/ottsel-scene-cull-back.png`,
SHA-256 `96ef5351b78664e1f97e213eba63a7065e391867142483a0ef34a608179c8f6`).
The probe was removed; normal product culling policy is unchanged. This
falsifies missing back-face culling as the shared composition cause. The fresh
route still reached Village1 twice with a 0-byte fault log; the Simulator
remains explicitly blank/partial and non-playable.
The final no-probe rebuild was installed after the diagnostic was removed. A
fresh exact route again reached `GAMEPLAY: enter village1` twice with a 0-byte
fault log. Screenshot `/tmp/ottsel-final-no-probe-route.png` has SHA-256
`95943f547d485896536e3438fea63952375046eb1b5d3ffb03b75f8b975c432d`.
Audio remained `pcm-peak=0`; the frame is still visibly partial/corrupted and
not playability proof.
The final lifecycle-polished executable (`eebaaf2454b326d85144640cb99b5aac0d5775a4265ed5a97c96fe59b9c84785`)
was installed into the single booted iPad Pro 11-inch (M4) Simulator. The
fresh exact route reached Village1 twice, hid the overlay on native input, and
left a 0-byte fault log. Screenshot `/tmp/ottsel-final-installed-route.png`
has SHA-256 `0b3357d8dfab7fd54c78cbc64f152d288d3c1e5aa9ddf10be2a0f2456c7066ec`;
audio remained `pcm-peak=0`, and the image remains partial/corrupted rather
than playable.

## 2026-08-22 — newest pending native mesh/color snapshot experiment

The fresh pre-change runtime repeatedly queued camera-dependent TFRAG/TIE mesh
and color uploads faster than the presentation thread drained its FIFO budget.
The shell now coalesces pending uploads independently by TFRAG/TIE family so a
newer camera snapshot supersedes stale pending geometry and its matching color
buffer. This is a source-side queue-consistency experiment only; TBP, camera,
shader, culling, and Metal policy were unchanged.

The signed iPad build passed deep codesign, the focused Sprite3/platform-input/
keyboard suite passed 21/21, and the exact validated route after
`title-wait-ready` reached `GAMEPLAY: enter village1` twice. The post-transition
lookup tail was `24,25,10,41,30,34` (resident hits), the fault log was 0 bytes,
and the executable SHA-256 was
`68481f6659d8786d3bb395d7520278fe297d78438f500b2e19f74e822eb6d838`.
Screenshot `/tmp/ottsel-coalesced-exact-route.png` has SHA-256
`b3074f046f5e2b00a50b9c087ffab282eae5ca46b27b6637e334380d179223e0`.

The frame changed but remained visibly dislocated/partial and audio remained
`pcm-peak=0`. This falsifies queue backlog as the complete composition cause;
the iPad playability gate remains OPEN and the Simulator blank/partial warning
still applies.

## 2026-08-22 — synchronized native camera-uniform snapshot

The native presenter previously copied the 32-float TIE/TFRAG camera/fog block
on the game thread while the presentation thread read it during Metal encoding.
The shell now protects the update and snapshots the complete block once per
render pass, ensuring both scene families use one stable matrix/fog set. The
shader equation, camera values, mesh selection, texture identity, depth,
culling, and draw order were unchanged.

The signed executable SHA-256 was
`546b283b61c22cf4d7cef7099dd553ae71b8b3f255de431bf4efa8ff40b21bd2`; deep
codesign passed and the focused Sprite3/platform-input/keyboard suite passed
21/21. After `title-wait-ready`, the exact validated route reached
`GAMEPLAY: enter village1` twice, with resident lookup tail
`24,25,10,41,30,34`, a 0-byte fault log, and native input hiding the overlay.
Fresh screenshot `/tmp/ottsel-uniform-snapshot-route.png` has SHA-256
`45481d23b46bdffa9c58e1a8b8e52f2fa776c640a55f4ca98d5079a3ebe83976`.

Rotated landscape inspection still shows severe oversized/dislocated geometry
and audio remains `pcm-peak=0`. The snapshot removes a data-race hazard but is
not sufficient to close native composition or the iPad playability gate.

## 2026-08-22 — native-equation projection range ledger

The bounded CPU companion now records the native TIE equation's NDC range after
the Jak 1 `512/448` Y expansion and Metal depth remap. On the fresh Village1
route it sampled `4097/4097` finite vertices, with
`gl-clip-visible=1876` and `metal-clip-visible=1876`. Full sampled ranges were
`ndc-x=(-422.4563,438.0270)`, `ndc-y=(-851.0743,1606.2456)`, and
`ndc-z=(-3.9074,2.6576)`.

This confirms finite source data and agreement between the CPU clip predicate
and the Metal depth-range predicate, but the selected mesh includes very broad
out-of-range geometry. It does not authorize a camera remap or prove a
playable frame. Fresh screenshot
`/tmp/ottsel-native-projection-ledger-route-final.png` has SHA-256
`14a8ea18f27437d871bde2f039fa05858dfb86c53bbd001716498a02a0d4db9d`; the
route remained fault-free, visually corrupted, and audio remained
`pcm-peak=0`. The next composition experiment is the broad mesh's
material/index/visibility contract, not TBP or camera policy.

## 2026-08-22 — TIE topology contract correction

The first-batch and TIE-only probes showed the malformed frame survived family
and depth isolation. The maintained FR3 contract identifies Jak 1 TIE trees as
`use_strips=false`, but the native TIE consumer had been expanding both static
and visibility-filtered indices as triangle strips. The consumer now honors
that existing flag and emits direct TIE triangle lists in groups of three;
strip trees retain the strip path. Camera, TBP, texture lookup, shader,
culling, and Metal policy were unchanged.

The signed iPad build passed deep codesign and the focused
Sprite3/platform-input/keyboard suite passed 21/21. Executable SHA-256:
`cb14908b7c28fca8d3f9d517938892c7e0be7d9d9b4e0c9e0470ec09814f9356`.
The fresh route followed `title-wait-ready` through Start, Cross, Down four
times, and Cross; the fault log remained 0 bytes. Screenshot
`/tmp/ottsel-tie-topology-exact-route.png` has SHA-256
`45a1fa3b912987970206377e503d1906efad30c4aa696c943cdc27112e3c820e`.

The change materially removed the fragmented-triangle symptom and made terrain,
foliage, bridges, and the player region identifiable. The Simulator frame is
still rotated/dislocated with large blank regions and `pcm-peak=0`; it remains
partial and is not playability proof. Native composition and iPad playability
remain OPEN. The next experiment is the remaining shared
transform/material/visibility contract, not a camera or TBP remap. The blank/
partial Simulator warning remains explicit.

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
Start, Cross, Down four times, and Cross; fresh screenshot
`/tmp/ottsel-link-guard-exact-route.png` has SHA-256
`56a15266c17f185e638c40338313630e576446cac28e51e14154f89a4e26019c`, also
with a 0-byte fault log.

This fixes the reported boot/link crash, but it does not close native
composition or playability. The Simulator blank/partial warning remains
explicit, and iPhone/device work remains gated on an honestly playable iPad
build.

## 2026-08-22 — visibility-group direct-list correction

The TIE topology correction removed strip expansion for Jak 1 direct-list
trees, but the next fresh frame still showed quadrant-like fragmentation. The
visibility path was compared against the maintained TFRAG implementation:
invisible groups must be omitted for direct triangle lists, because inserting
`UINT32_MAX` shifts all later groups when indices are consumed in triples.
The native TIE path now inserts that sentinel only for `tree.use_strips=true`.
Camera, TBP, texture identity, shader, culling, and Metal policy remain
unchanged.

The signed iPad build passed deep codesign and the focused
Sprite3/platform-input/keyboard suite passed 21/21. Executable SHA-256:
`83529274e65a029fdbd37aa5b7b7489869922a4ef0a004bf7d3a5d17d07e360d`.
The fresh route followed `title-wait-ready` through Start, Cross, Down four
times, and Cross; the fault log was 0 bytes. Screenshot
`/tmp/ottsel-tie-visibility-exact-route.png` has SHA-256
`06fb01119e94b2ca17e6dd9b013f00356c8bf938312920dd6e5131d630074151`.

The direct-list grouping fault is no longer visible and the frame remains
stable after the camera settles. Large blank regions and a detached horizontal
geometry band remain, with `pcm-peak=0`; this is still a partial Simulator
diagnostic, not playability proof. Native composition and iPad playability
remain OPEN. The blank/partial Simulator warning remains explicit.

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
falsifying TRANS/DIRT as its sole source. The common NORMAL-TFRAG/TIE
transform, visibility, or material contract remains OPEN. The probe was
trigger-gated and is not product behavior.

## 2026-08-22 — controlled TIE/TFRAG family isolation

The same fresh validated route was replayed twice with a family-isolation
trigger armed before launch: once with TIE disabled and once with TFRAG
disabled. TIE-off produced `/tmp/ottsel-family-no-tie.png` with SHA-256
`f48535d5c33741df4a3ff9236b0ae7ce5142726b33587d97aa359bd3956de342`; TFRAG-off
produced `/tmp/ottsel-family-no-tfrag.png` with SHA-256
`404c186351226f78b67c38a25c374e61a6d73843945ed94a9b0720227995013b`. Both
fault logs were 0 bytes on the single booted iPad Pro 11-inch M4 Simulator;
audio remained `pcm-peak=0`.

TIE-off becomes a giant TFRAG close-up, while TFRAG-off still shows the
detached band and dislocated TIE geometry. Neither family alone explains the
failure. This rules out a single-family upload fix and keeps the shared
camera/viewport/material consumer boundary as the next R1 target. No TBP,
camera, shader, or Metal depth policy was changed.

## 2026-08-22 — current-checkout macOS route and neutral movement increment

One fresh Windowed native `gk` was launched with audio enabled and retained
stdout/stderr at `/tmp/ottsel-m1-current3.stdout.log` and
`/tmp/ottsel-m1-current3.stderr.log`. It reached `title-wait-ready`, consumed
the documented desktop Start/Cross/Down×4/Cross button masks, and logged
`GAMEPLAY: enter village1` twice. The current `gk` SHA-256 is
`5ed65423602db7565ac3ec603f63582fe5455dfcd4d36a20a04a965553fc1533`.

Fresh route and movement captures are `/tmp/ottsel-m1-current3-route-correct.png`
(`c759a8f7ad4ff39249e952fb8f25723a3aedecdc95057e1dbec730e171b24590`),
`/tmp/ottsel-m1-current3-before-move.png`
(`a16844ae041ada81f1261849d2f7e5fd5dfb3ad16799abb6862c8c3415c02b4e`), and
`/tmp/ottsel-m1-current3-after-neutral.png`
(`f2c8a8648a94f7e92babfe4e050cd495ed71b948f4377cc7dc9d4c8e5caa8146`). The
left-stick hold was accepted for 180 reads and released to neutral. Audio
showed route peaks including 2101 and 2499; targeted crash/signal/panic/assert
scanning found no matches. This remains an M1 partial increment: human
audibility, physical-controller soak, longer stability, and complete lifecycle
proof remain open. The iPad output remains explicitly partial/non-playable.

## 2026-08-22 native mouse fallback and exact lookup comparison

The native shell now falls back from zero SDL `xrel/yrel` to the delta between
successive absolute mouse positions, clearing that baseline on neutralization.
Signed executable SHA-256:
`2a8eac5049a0da1285d05b706cfd5c598485ed2ff785408aa0baa14c60d4ca45`;
focused Sprite3/platform-input/keyboard tests: 21/21.

The fresh exact route reached Village1 twice with a 0-byte fault log and
screenshot `/tmp/ottsel-controls-route.png` (SHA-256
`da214f6c433f5b6e205845662476e71ed558731eb1b5c32224ee24475161606`). Live
W/A/D samples were `(127,0)`, `(0,127)`, `(255,127)` with neutral releases;
Space produced Cross pressure 255. Pointer events reached the native seam, but
the first captured motion was neutral, so human non-neutral camera acceptance
remains open.

The post-Start lookup window in this iPad run is
`54,49,48,42,44,24,25,10,41,0,30,34`. That ordered list is not a proven
iPad-only mismatch: `/tmp/ottsel-r1-particle-phase-runtime.log` from the same
source era also contains page-2 index `0` in the corresponding later macOS
route phase, while `/tmp/ottsel-r1-phase-tex0-runtime.log` omits it in that
later window. Capture timing differs. The decisive sampled source-side object
matches on both platforms: page 2/index 0 is 64x64 PSM19 with generated TEX0
`tbp=9953` (`0x26e1`), `tw=6`, `th=6`, `tcc=1`. R1 therefore has no proven
page-directory/lookup-resource divergence for this family; trace
texture-object/data-family and native Sprite3 consumer state next. No TBP remap
is authorized. The Simulator frame is still visibly partial/corrupted and
audio remains `pcm-peak=0`.

## 2026-08-22 — native MSCAL=211 data-family ledger

The signed iPad build now has a trigger-gated ledger directly at the native
`MSCAL=211` Sprite3 consumer. It records raw vector/AdGif payload hashes,
frame/matrix hashes, first-vector values, and decoded texture identity without
altering uploads or renderer policy. Focused Sprite3/platform-input/keyboard
tests remained 21/21, deep codesign passed, and the executable SHA-256 is
`687456a2327ebcb566128d1679a5c150916e76d0e291f610c4bac9eb3255366f`.

The fresh exact route reached Village1 on the single booted iPad Pro 11-inch
(M4). The first captured family was `TBP=0x2506` / TEX0
`0x2004d0e59930a506`, 64x64 PSM19, decoded texture hash
`0xc8679915dfac0e15`; later groups retained the known
`0x24f2`/`0x2004d1e59930a4f2` and `0x2525` families. These match the
macOS source-boundary/phase families already captured. The remaining R1
question is therefore native Sprite3 composition/state consumption, not a
proven lookup/page-directory/TBP mismatch. No TBP remap, camera, shader, or
culling change was made.

Fresh screenshot `/tmp/ottsel-r1-3d-family-hash-route2.png` has SHA-256
`6819f93bf50c2ab9561e8f4ff658e650150429a6d525ed024b1f7b2bc082655d`; it is
still severely portrait/partial and explicitly not playability proof. Fault
output was 0 bytes and audio remained `pcm-peak=0`.

## 2026-08-22 — native macOS mouse/keyboard controls

The current Mac input audit found the concrete reason the earlier WASD result
was unreliable: the persisted profile loaded `keyboard_enabled=false`, while
the GOAL mouse settings loaded `mouse-enabled? #f` and `mouse-camera? #f`.
The native input path now enables WASD/actions by default with an explicit
`OTTSEL_ENABLE_KEYBOARD=0` opt-out, supplies left=Cross/right=Circle defaults
for an empty mouse map, enables the existing mouse option defaults, and latches
short mouse button down-edges for eight pad polls. Focus-loss cleanup remains
bounded and neutralizing.

The focused `KeyboardEventEdge.*:PlatformInput.*:Sprite3Native.*` suite passed
23/23 after an ARM64 `(mi)` regeneration of 1,068 targets and a fresh `gk`
link. A fresh no-environment-flag Windowed Mac run logged native keyboard
enabled; a real `Up` key event moved the menu selection from Load Game to New
Game. The game-side mouse seam logged `enabled=true camera=true movement=false`.
However, the available Computer Use pointer action generated no SDL mouse event,
and the System Events fallback was denied by macOS assistive-access policy, so
human/native mouse acceptance remains OPEN. This evidence is a controls
increment, not a complete M1 playability pass. See
`docs/evidence/M1/m1-native-desktop-controls-2026-08-22.md`.

## 2026-08-22 — fresh signed iPad R1 lookup replay

The fresh signed iPad build was installed with one booted iPad Pro 11-inch
(M4) Simulator and one runtime. The validated user-data pack passed the F1
manifest/family/hash validator outside the repository. The exact
title-wait → Start → Cross → Down×4 → Cross route logged the current-boot
title marker, incoming completion, and Village1 entry twice. The fresh
post-route screenshot remains visibly corrupted/partial and is explicitly not
playability proof; the fault log is 0 bytes and audio mix windows remain
`pcm-peak=0`. See
`docs/evidence/R1/r1-fresh-ipad-lookup-replay-2026-08-22.md`.

The complete iPad page-2 stream was
`4,53,4,18,0,15,28,27,3,54,49,48,42,44,24,10,41,25,30,34,9`.
The phase-aligned post-Start window `54,49,48,42,44` matches macOS, and page
2 remains a resident hit with the corrected directory/segment state. The
first native 3D producer family still differs: iPad `0x24d2` /
`0x2004d2e59930a4d2`, versus the completed macOS reference `0x24f2` /
`0x2004d1e59930a4f2`. R1 therefore stays at the producer phase/data-family
handoff; no TBP remap, camera, shader, or Metal-policy change is justified.

The follow-up iOS sandbox owner trace correlates the selected launcher
instances with raw 3D IDs. The post-Start iPad route selects `0x00203600`,
page `0x408` records, `0x00203100`, `0x00201200`, and `0x00203000` under
launcher IDs `336`, `341`, `347`, and `337`; the completed macOS reference
selects the accepted first world family `0x00201e00` under a different owner
sequence. This identifies producer launch/phase ownership as the next source
boundary before native Sprite3. See
`docs/evidence/R1/r1-fresh-ipad-owner-correlation-2026-08-22.md`. The fresh
owner replay remains diagnostic-only: the frame is corrupted/partial, fault
output is 0 bytes, and audio is not audible.

## 2026-08-22 — native mouse-motion latch and fresh signed replay

The native shell now routes WASD by physical SDL scancode and maps left/right
mouse buttons to Cross/Circle. Relative mouse motion is held across the
event-loop/`scePadRead` seam by a bounded `MouseMotionLatch`, fixing the path
where motion was published and immediately neutralized before the GOAL sample.
The focused Sprite3/platform-input/keyboard suite passed 24/24, including the
before-failing motion-lifetime regression, and
`patches/r1-native-mouse-controls.patch` reverse-checks against the current
dirty nested checkout.

A fresh signed iPad replay on the single booted iPad Pro 11-inch (M4) consumed
the scripted native keyboard route and reached Village1 twice. Fault output is
0 bytes and audio remains `pcm-peak=0`. The fresh screenshot is still severely
corrupted/partial, so this proves neither human mouse acceptance nor
playability. Evidence is in
`docs/evidence/R1/r1-native-mouse-latch-and-fresh-ipad-replay-2026-08-22.md`.

## 2026-08-22 — TFRAG composition isolation

The existing trigger-only scene isolation probes were replayed on the single
booted iPad Pro Simulator. Disabling TIE left the oversized textured world
present; disabling TFRAG removed that world and exposed only the remaining
diagnostic Sprite3/font/color blocks. The normal path remains partial and
corrupted. This narrows the next source boundary to TFRAG or its composition,
without authorizing a camera, shader, culling, TBP, or Metal-policy rewrite.
Fault output remained 0 bytes and audio remained non-audible. See
`docs/evidence/R1/r1-tfrag-composition-isolation-2026-08-22.md`.

The existing first-batch TFRAG probe also showed fragmented geometry in the
earliest TFRAG draw. This rules out a defect introduced only by later material
batches; the next experiment is the first TFRAG mesh/index/transform boundary.
The diagnostic was cleared and the clean signed app relaunched on the same
single booted Simulator.

A trigger-only Metal-side integrity check on the first TFRAG draw reported
`indexCount=3984`, `vertexCount=76264`, index range `592..2921`, and
`outOfRange=0`. The valid raw mesh positions remain large world coordinates;
the next boundary is TFRAG transform/material interpretation, not an
out-of-range index read. The temporary probe was removed after capture.

The widened trigger-only clip probe found finite, bounded projected
coordinates for every captured TFRAG draw (`x` about `-0.53..1.60`, `y` about
`-1.47..0.77`, positive finite depth). Together with the valid index range,
this rules out a gross vertex-transform or out-of-range-index failure. The
next boundary is triangle connectivity/material submission or composition
state; the widened probe was removed.

## 2026-08-22 — fresh source-boundary replay and supplied Metal crash attribution

The single booted iPad Pro 11-inch (M4) Simulator replayed the exact
title-wait → Start → Cross → Down×4 → Cross route with the source-boundary
trigger armed before launch. At chains 129–130 the native ledger captured the
same early producer family already seen in the macOS phase: `MSCAL=211`, 48
sprites, `TBP=0x2506`, and `first-tex0=0x2004d0e59930a506`, followed by the
16-sprite zero-texture record. Frame/matrix transfers were `9/12` (and an
earlier setup `4/7`); the source trace also retained the camera-source chain.
Page-2 samples were resident hits and the fault log remained 0 bytes. This
does not prove that iPad reaches the later macOS `0x24f2` transition and does
not identify a lookup/page-directory defect. R1 remains open at ordered
producer-phase coverage and native composition/data-family consumption. No
TBP, camera, shader, culling, or Metal-policy remap was made.

Fresh screenshot:
`docs/evidence/R1/artifacts-2026-08-22-ipad-r1-source-boundary-r2/route.png`
(`a627e18552bb30cf66adf978676ffe85d1514fa5558cb3b990d29f968673e67b`). It is
still visibly rotated/dislocated with large blank regions, so the Simulator
blank/partial warning and non-playability boundary remain explicit. The
supplied crash report is older (`OttselShell` PID 41979, app UUID
`c78b4a3e-948f-35a2-8e2b-1a85cf0367d9`) and aborts in Metal's render-encoder
deallocator from `presentRGBA`; the current PID 43158 replay did not reproduce
it. Treat it as historical Metal-stability evidence, not a current R1 fault.
See `docs/evidence/R1/r1-fresh-source-boundary-replay-2026-08-22.md`.

The source-boundary diagnostic was then widened from eight 3D-only records to
32 recognized 3D/world/HUD records. The fresh signed rebuild and exact route
captured both `MSCAL=3` world and `MSCAL=211` 3D phases, but all 32 remained in
the early `TBP=0x2506` / `first-tex0=0x2004d0e59930a506` family; the later Mac
`0x24f2` transition was not reached in that bounded window. This is stronger
ordered producer evidence, not a complete phase-transition proof.

Per the visual-evidence requirement, the same run retained a blank pre-input
screenshot, a live H.264 exact-route video, and an after-route screenshot.
The after-route frame is visibly rotated/dislocated with detached vertical
geometry and large blank regions. Artifacts:
`docs/evidence/R1/artifacts-2026-08-22-ipad-r1-source-boundary-r4-video/`.
The signed executable SHA-256 is
`37286db2d68df0080bc0ccf7529e6ebdcfbe9a97f3adda805deba73bd35bdc7e`; the
fault log is 0 bytes. The Simulator remains explicitly blank/partial and
non-playable; no renderer-policy remap was made.

## 2026-08-22 — fresh raw particle/AdGif/native producer correlation

The next single-runtime replay armed both the raw particle/AdGif and expanded
source-boundary diagnostics before the exact validated-pack route. Nonzero raw
pairs included `0x00200400 -> 0x2004cfe55530a518`,
`0x00200f00 -> 0x2004c8e55530a5d2`, `0x00201200 ->
0x2004d0e59930a506`, and `0x00203500 -> 0x2004d0e59930a506`. Native
consumption repeatedly remained world `MSCAL=3` / 3D `MSCAL=211`, 48 sprites
at `TBP=0x2506` with `first-tex0=0x2004d0e59930a506`, followed by the
16-sprite zero-texture record. The frame/matrix hashes changed, but the
resource family did not transition to the macOS `0x24f2` family in the
128-record/settled window.

This closes the captured page/lookup/resident-allocation and raw
particle-to-AdGif branches. R1 remains open at producer phase/data-family
selection or DMA handoff after source resolution. No TBP, camera, shader,
culling, or Metal-policy remap was made. Fresh r6 screenshots and logs are in
`docs/evidence/R1/artifacts-2026-08-22-ipad-r1-source-particle-correlation-r6/`;
the after-route frame remains visibly rotated/dislocated with large blank
regions and the fault log is 0 bytes. See
`docs/evidence/R1/r1-source-particle-correlation-r6-2026-08-22.md`.

## 2026-08-22 — route-valid Village1 owner correlation

A fresh exact-route replay waited for Village1 before arming the particle
launch-owner trace, then captured paired before/after Simulator frames. The
active owners were launcher IDs 29 (`0x043c14b4`), 28 (`0x043c1384`), and 27
(`0x043c11d4`); each repeatedly emitted raw `0x00200f00` (page 2/index 0xf)
for `is3d=yes`. No route-valid owner emitted the accepted macOS later raw
family `0x00201e00`, and no native `TBP=0x24f2` /
`first-tex0=0x2004d1e59930a4f2` transition appeared. This is stronger
producer launch-owner/phase-selection evidence, not a page-directory,
allocation, TBP, camera, shader, or Metal-policy result.

The paired frames and a fresh settled H.264 route video remain visibly
rotated/dislocated with a detached vertical band and large blank/black
regions. The fault log is 0 bytes. R1 remains open at producer phase/data
family selection or DMA handoff; see
`docs/evidence/R1/r1-route-valid-owner-correlation-r8-2026-08-22.md` and
`docs/evidence/R1/artifacts-2026-08-22-ipad-r1-owner-correlation-r8/`.

## 2026-08-22 — bounded launch timing trace and fresh visual replay

The signed iPad app was rebuilt with a new trace-only patch,
`patches/r1-sparticle-launch-timing-trace.patch`, and its reverse-check passed.
The clean route segment on the single booted iPad Pro Simulator logged
synthetic START, Cross, Down×4, final Cross, and `GAMEPLAY: enter village1`
twice. After Village1, the bounded owner trace saw launcher IDs 978/977/974/973
with raw 3D IDs `0x00000000` and `0x00200000` (page 2/index 0). The sampled
`*sp-frame-time*` words were stable at `0x0080000c` and `0x41400000`.

The newly read launch-control object offsets produced implausible clock values
and are explicitly untrusted until independently validated; no timing fix was
made. The result remains at the producer phase/data-family boundary and does
not support TBP, camera, shader, culling, or Metal-policy changes.

Fresh initial/Village1 screenshots and a live H.264 capture show the same
rotated/dislocated, oversized-texture and blank/black visual failure. The fault
log is 0 bytes. See
`docs/evidence/R1/r1-launch-timing-trace-r9-2026-08-22.md` and
`docs/evidence/R1/artifacts-2026-08-22-ipad-r1-launch-timing-r9/`.

## 2026-08-22 — R10 launch-owner seam typing correction

The generated `sp-launch-particles-var` signature proves that the owner trace
entry receives an `sparticle-launcher` in `a1`; it does not receive the
`sparticle-launch-control` whose `local-clock` and spawn fields were sampled
by the temporary R9 timing probe. `inline-array-class` reserves the first
`0x10` bytes, so the control offsets are known (`local-clock=0x18`,
`last-spawn-frame=0x24`, `last-spawn-time=0x28`) but must be logged at the
typed `spawn` seam. The invalid timing probe and temporary patch were removed;
no product renderer/resource policy changed.

R10’s fresh signed iPad replay again reached Village1 twice. It captured the
transition from title-side owner IDs 1951/1950/1949 and raw
`0x00203500`/`0x00200400` to Village1 owners 29/28/27 and raw `0x00200f00`,
which is useful producer-phase evidence but not a launch-control timing
result. Fresh frames remain visibly non-playable and the fault log is 0 bytes.
See `docs/evidence/R1/r1-launch-owner-seam-typing-r10-2026-08-22.md` and
`docs/evidence/R1/artifacts-2026-08-22-ipad-r1-launch-timing-r10/`.

## 2026-08-22 — typed launch-control correlation

The next signed iPad build traced the fifth `sp-launch-particles-var` argument
(`t0`), the actual `sparticle-launch-control`, using the `inline-array-class`
layout. Title-side owners 1951/1950/1949 used control `0x00212734`; Village1
owners 29/28/27 used `0x00212694`. Both control families reported length 3,
stable frame-time words `0x0080000a` / `0x41200000`, and the expected raw
producer transition from `0x00203500`/`0x00200400` to `0x00200f00`. The
control address changes at the phase boundary, but no timing-policy mismatch
is established. No renderer, TBP, camera, shader, culling, or Metal-policy
change was made.

Fresh before/after Simulator frames remain visibly rotated/dislocated with a
detached vertical band, oversized rectangles, and large blank/black regions;
fault log 0 bytes. See
`docs/evidence/R1/r1-typed-control-correlation-r11-2026-08-22.md` and
`docs/evidence/R1/artifacts-2026-08-22-ipad-r1-control-timing-r11/`.

## 2026-08-22 — AdGif/native consumer parity

A fresh post-Village1 capture armed the existing AdGif and native source
boundary traces on the one active iPad runtime. For raw `0x00200f00` page 2 /
index `0xf`, AdGif emitted `TEX0=0x2004c8e55530a5d2`; the native source
boundary consumed the same TEX0, `TEX1=0x120`, and clamp family with
`TBP=0x25d2`, `MSCAL=3`, and 48 sprites. Page lookup was a hit. The only
captured state discrepancy at this boundary is alpha (`0x44` AdGif vs `0x48`
native), which is now the narrow composition/material follow-up; no TBP,
camera, shader, culling, or Metal-policy remap was made.

The fresh post-trace frame remains visibly rotated/dislocated with detached
geometry, oversized rectangles, and large blank/black regions; fault log 0
bytes. See `docs/evidence/R1/r1-adgif-native-consumer-correlation-r12-2026-08-22.md`
and `docs/evidence/R1/artifacts-2026-08-22-ipad-r1-consumer-correlation-r12/`.

## 2026-08-22 — active Simulator visual replay

The one active iPad Simulator was inspected directly through its UI and a
fresh screenshot was captured after enabling keyboard capture and sending
W/A/S/D. The landscape UI view confirms the current failure visually: the
world is present but split by a horizontal seam with dark/offset sections and
missing or incorrectly composed geometry. Keyboard capture removed the touch
overlay, but this is not playability proof. A fresh `simctl io recordVideo`
attempt was blocked by the host's existing `Resource busy` / `Host recording
is already in progress` recorder state; no second Simulator or restart was
used. See `docs/evidence/R1/r1-visual-runtime-replay-r13-2026-08-22.md` and
the R13 artifacts.

## 2026-08-22 — TIE/TFRAG projection falsification

A signed build containing a bounded desktop-style TIE/TFRAG perspective,
HVDF, and separate camera-sign experiment was replayed on the same one
booted iPad Simulator. After Start, the game surface became fully blank. The
experiment was reverted and the restored source was rebuilt, signed, and
reinstalled on that same Simulator. R1 remains open; the next step is a CPU
clip ledger for the actual `pc_camera`/HVDF/fog values before another shader
change. See `docs/evidence/R1/r1-tie-tfrag-projection-falsification-r14-2026-08-22.md`.

## 2026-08-22 — native mouse accumulation

The native mouse camera latch previously overwrote earlier SDL motion events
before the next asynchronous pad read. It now accumulates the bounded motion
impulse. The focused keyboard/platform/Sprite3 suite passed 25/25, the
canonical mouse patch reverse-check passed, and a fresh signed iPad replay
logged native mouse Cross (`buttons=0x4000`, pressure 255) and release on the
single active runtime. W/A/S/D live logs continue to show the expected
opposing analog states. This is input-boundary proof only; the fresh
Simulator frame remains a diagnostic/title surface and playability is not
claimed. See `docs/evidence/R1/r1-native-input-accumulation-r15-2026-08-22.md`.

## 2026-08-22 — TIE-only projection correction

The CPU clip ledger showed the first Village1 TIE vertex at native clip
`(68.374,-14.092,0.036,34.744)` versus the desktop-equation result
`(-0.012,-0.005,-0.034,34.744)`. A bounded signed build corrected only the
TIE Q/HVDF/GS projection and left TFRAG unchanged. The one active Simulator
replay did not blank; the clean live frame is more recognizable, but still
has visibly incorrect geometry/material composition and is not playable. The
next boundary is TFRAG projection/sign/depth and material ordering. See
`docs/evidence/R1/r1-tie-only-projection-r16-2026-08-22.md`.

## 2026-08-22 — TFRAG sign falsification

A signed build applying the validated TIE camera sign to TFRAG was actively
inspected in the one booted iPad Simulator. The fresh post-W frame was almost
entirely black with one stretched strip, despite ongoing TFRAG/Sprite/audio
logs. The hypothesis that TFRAG shares the TIE projection sign is falsified;
only that latest source change was reverted. R1 remains open. See
`docs/evidence/R1/r1-tfrag-sign-falsification-r17-2026-08-22.md`.

## 2026-08-22 — TFRAG strip-run boundary correction

The native TFRAG builder now preserves OpenGL's separate visible
triangle-strip runs by inserting a restart between visible groups. A fresh
validated-pack route on the one booted Simulator reached Village1 twice. The
direct live frame no longer shows the prior long cross-group stretch, but still
has severe blue/black missing regions; audio remains `pcm-peak=0`, so this is
composition progress only and not playability proof. See
`docs/evidence/R1/r1-tfrag-strip-restart-r18-2026-08-22.md`.

## 2026-08-22 — TIE strip-run boundary correction

The same OpenGL-visible-run restart rule was applied to native TIE strip
groups. Focused Sprite3/platform/keyboard tests passed 25/25, and a fresh
F1-imported validated-pack route reached Village1 twice on the single booted
Simulator. The fresh frame remains severely incomplete with no demonstrated
visual improvement over R18; this is retained source-parity work, not a
playability pass. See
`docs/evidence/R1/r1-tie-strip-restart-r19-2026-08-22.md`.

## 2026-08-22 — TIE category coverage falsification

A trigger-gated experiment included Village1 NORMAL/TRANS/WATER TIE ranges;
the category ledger confirmed substantial non-normal ranges, but the fresh
validated-pack Simulator frame was unchanged with the same missing blue/black
regions. The temporary probe was removed. R1 remains open at material/depth
state or another missing bucket. See
`docs/evidence/R1/r1-tie-category-probe-r21-2026-08-22.md`.

## 2026-08-22 — native composition CPU-base probe

The signed iPad build was replayed on the single booted iPad Pro Simulator
through Start → Cross → Down×4 → Cross. A one-shot diagnostic trigger skipped
the shell's full-screen CPU `presentRGBA` base while leaving native
TFRAG/TIE/Sprite3 submissions unchanged. The no-CPU frame removed the debug
text/flat CPU content and showed a more coherent textured Village, proving
that the CPU base contributes visible artifacts; large native black/missing
regions remain. This is composition evidence, not playability proof. Audio
still reports `pcm-peak=0`, fault output is empty, and video capture remains
host-blocked by `Host recording is already in progress`. See
`docs/evidence/R1/r1-native-composition-cpu-base-probe-r22-2026-08-22.md`.

The same live route then isolated the native families: no-TIE retained
substantial Village geometry, TIE-only produced the known stretched/radial
output, and disabling both native families produced a blank drawable. The
next falsifiable composition experiment is therefore TFRAG material/strip
state; no TBP, camera, or global Metal policy change is justified by this
isolation alone.

## 2026-08-22 — TIE reference-projection probe

The maintained OpenGL path confirms normal TIE uses `ShaderId::TFRAG3` and
consumes `pc_camera` directly. A signed trigger-gated iPad build tested that
direct projection for TIE only. The prior TIE-only radial/stretched output was
not reproduced; the fresh frame retained textured geometry, but the camera was
a close-up and full Village/playability parity was not established. The
product default remains unchanged pending a same-phase normal-vs-reference
replay. See
`docs/evidence/R1/r1-tie-reference-projection-probe-r23-2026-08-22.md`.

## 2026-08-22 — native all-geometry-slot composition experiment

The native TFRAG/TIE visibility builders now cover every loaded geometry slot,
matching the maintained OpenGL renderer's `GEOM_MAX` traversal instead of
hard-coding slot zero. A fresh signed build and exact title-wait → Start →
Cross → Down×4 → Cross replay reported `TFRAG geos=3` and `TIE geos=4`, but
fresh no-CPU Simulator frames still showed detached/missing geometry and
incorrect close framing. R24 is source-aligned composition progress, not
playability proof. See
`docs/evidence/R1/r1-native-all-geometry-slots-r24-2026-08-22.md`.

## 2026-08-22 — native TFRAG/TIE alpha-contract experiment

The native material shader now matches the maintained OpenGL time-of-day alpha
contract: RGB is doubled and alpha is doubled a second time. A fresh signed
route with the CPU base suppressed showed more visible terrain/material detail
than the prior baseline, but the frame remains a close-up with detached and
missing composition. R25 is partial composition progress, not playability
proof; audio remains unproven and the host video recorder remains busy. See
`docs/evidence/R1/r1-native-tfrag-alpha-contract-r25-2026-08-22.md`.

## 2026-08-22 — native per-draw fog/decal contract experiment

The native TFRAG/TIE material path now honors OpenGL's per-draw fog and decal
bits while retaining the corrected alpha and all-geometry traversal. A fresh
signed route reached Village1 twice on the one booted Simulator; the actively
inspected frame and 4-second video remain materially incomplete and close
framed, so R26 is not playability proof. Fault output was empty and mobile
audio remains unproven. See
`docs/evidence/R1/r1-native-fog-decal-contract-r26-2026-08-22.md`.

R26 is superseded: its first binary duplicated the alpha/RGB scale while the
combined shader expression was being introduced. The corrected R27 rebuild
removed that duplicate and reproduced the exact route; its frame remains
close-framed and non-playable, with a zero-byte fault log and unproven audio.
See `docs/evidence/R1/r1-native-fog-decal-contract-r27-2026-08-22.md`.

## 2026-08-22 — native alpha-fail/depth-write contract experiment

The native Metal material loop now reproduces OpenGL's bounded `FB_ONLY`
alpha-fail behavior: a depth-writing pass followed by a no-depth-write pass,
plus the `NEVER + FB_ONLY` depth-write exception. The live TFRAG ledger
confirmed the targeted modes during a fresh exact route, but the actively
inspected Simulator frame showed no visual/playability improvement. Fault
output was empty, audio remains unproven, and video capture was host-blocked.
See `docs/evidence/R1/r1-native-alpha-fail-depth-contract-r28-2026-08-22.md`.

The supplied encoder crash now has an exception-safe `RenderEncoderEndGuard`;
signed PID 97598 survived a bounded live window and H.264 capture with zero
fault bytes. The next D0-NORMAL increment added a named native Direct-product
activation using the existing live IR/TEX0 path. Focused tests passed 31/31 and
the signed PID 98914 stayed alive, but the retained Village1 phase emitted no
title/progress Direct packet, so Direct composition remains OPEN. Fresh visual
artifacts remain partial and are not playability proof.

The fresh pre-armed iPad route now accepted native Direct at chain 1, reached
title-wait-ready, replayed Start → Cross → Down×4 → Cross, and entered Village1
twice with a 0-byte fault log. Post-Start lookup order `(2,54),(2,49),(2,48),
(2,42),(2,44)` matches the completed macOS route and its observed TEX0/TBP
families; source parity is supported for this slice. Direct composition remains
OPEN: fresh screenshot/video evidence is still visibly incomplete and non-playable.

The pre-armed consumer ledger now shows a post-lookup family mismatch: iPad
native 3D repeatedly draws `0x24d2/0x2004d2e59930a4d2` plus `0x2525`, while the
phase-aligned reference starts `0x24f2/0x2004d1e59930a4f2` plus `0x2525`.
This is recorded as producer/data-family identity OPEN, not a TBP-remap result;
the next experiment traces launcher/AdGif/allocation identity before native
composition changes. Fresh exact-route visuals remain incomplete/non-playable.

The lower-level producer trace now makes the remaining R1 divergence explicit:
macOS active 3D uses page 2/index 30 and TBP 9458 (`0x24f2`), while current
iPad Village1 particle setup uses page 2/index 10 and TBP 9426 (`0x24d2`).
The iPad producer vector/TEX0 matches its native MSCAL consumer exactly, so the
remaining boundary is launch-owner/phase-family selection before Metal, not a
TBP or renderer remap.

The texture-login ledger closes the allocation branch for the accepted route:
iPad/macOS match resident page 2, directory/entry/page lengths 1610/55/55,
segment sizes `31424/1088/4352`, destinations `601152/632576/633664`, and
`alloc=1` for indices 54,49,48,42,44. Remaining R1 work is Sprite3 producer /
AdGif/TEX0 family selection after lookup residency, not FR3/DGO allocation.

The existing scene no-depth discriminator was consumed on the active Village1
runtime. Fresh frame/video evidence shows cross-group stretched strips becoming
more prominent, falsifying depth ordering as the primary malformed-TFRAG cause;
no global depth workaround was retained. Next composition boundary remains
TFRAG strip/material/projection state.

Normal TIE source audit corrected native camera policy to the OpenGL TFRAG3
derived-pc-camera path; raw camera is only for wind TIE. Fresh iPad frame/video
show recognizable hut/tower/palm geometry, but malformed bands/rectangles,
missing regions, and no Jak remain. Playability is still OPEN.

Fresh signed iPad build now selects the canonical single `lod_tie`/`lod_tfrag`
slot rather than overlaying all geometry slots; runtime reports 3 TIE and 3
TFRAG trees in LOD 0, zero faults. Fresh frame/video still show malformed TIE
bands and no Jak, so composition/playability remain OPEN.

TIE-only first-batch and no-depth probes show the malformed band appears after
the first TIE batch and survives depth removal; depth ordering is falsified.
Normal mode was restored, with fresh screenshot/video captured and zero faults.
Next R1 composition boundary is later TIE batch/index/material state.

A bounded numeric draw-range probe did not reproduce the normal-mode band
reliably in isolated TIE or TFRAG frames, so no batch/material change was
promoted. Normal mode was restored with fresh screenshot/video; combined
TIE/TFRAG phase state remains OPEN.

OpenGL TFRAG3 source multiplies TOD alpha once; native TIE incorrectly used 4x.
Corrected native factor to 2x, rebuilt/signed/installed, and verified 0 faults.
Fresh frame/video show a changed but still malformed seam; no playability claim.
Native W/D replay hid touch controls and logged left-stick values; input tests 8/8.
Composition remains OPEN; no camera, TBP, depth-policy, or ROM-safety workaround
was promoted. Evidence: `docs/evidence/R1/r1-tie-alpha-source-parity-2026-08-22.md`.

Fresh stale-marker-controlled route created a new title-wait boundary before
Start/Cross/Down×4/Cross. Post-Start page-2 lookup prefix was `54,49,48,42,44`,
all resident hits, matching the macOS prefix. Fresh frame/video remain visibly
malformed with no Jak; post-route Sprite3/AdGif consumer capture remains OPEN.
Evidence: `docs/evidence/R1/r1-fresh-valid-route-lookup-prefix-2026-08-22.md`.

Fresh post-title source trace resolved page-2 `54,49,48,42,44` and raw
particle/AdGif IDs as resident, with matching page-directory/segment state.
The producer/native family in the validated Village1 window is `0x2506` /
`0x2004d0e59930a506`, while the macOS world oracle is `0x24f2` /
`0x2004d1e59930a4f2`; ordering/phase ownership remains the R1 discriminator.
Fresh Simulator screenshot/video still show a large seam and missing regions;
the build is diagnostic and not playable. See
`docs/evidence/R1/r1-post-title-producer-family-2026-08-22.md`.

Fresh post-`GAMEPLAY: enter village1` trace now correlates live owner `2895`
and raw page-2 index `10` to AdGif/native `TBP=0x24d2`,
`TEX0=0x2004d2e59930a4d2`; macOS begins the corresponding world phase at
index `30` / `0x24f2` / `0x2004d1e59930a4f2`. The divergence is producer/DGO
ordering before Metal. Fresh frame/video remain non-playable; audio peak is 0.
See `docs/evidence/R1/r1-world-launch-owner-correlation-2026-08-22.md`.

Clean `(mi)` removed 518 stale objects and rebuilt 546 targets; signed iPad replay still
produces launcher 2895 → page2/index10 → `0x24d2`/`0x2004d2e59930a4d2`, not macOS
index30 → `0x24f2`/`0x2004d1e59930a4f2`. Fresh Simulator screenshot/video remain
non-playable; R1 stays a source DGO/link/FR3 ordering investigation. See
`docs/evidence/R1/r1-clean-dgo-replay-2026-08-22.md`.

Native WASD/mouse input now uses physical scancodes plus a bounded digital latch;
the focused suite passes 9/9. A fresh one-Simulator iPad replay reaches village1
and resolves MIS.DGO, but the captured frame remains visibly non-playable with
missing geometry. See `docs/evidence/I1/i1-native-mouse-keyboard-route-2026-08-22.md`.

Full ARM64 `(mi)` plus a signed one-Simulator replay added a bounded level-ID
ledger: village1 IDs are present/stable, while post-world page-2 consumer order
differs from macOS. R1 remains a producer/link/login or consumer-family issue;
fresh screenshot/video remain non-playable. See
`docs/evidence/R1/r1-level-login-owner-ledger-2026-08-22.md`.

Generic-VU probe now caps at 50,000 instructions with zero XGKICK/GIF output;
the first live VU draw also has zeroed input memory. This confirms the missing
Jak actor is upstream of Metal presentation; R1/native composition remains open.

Cold single-runtime input verification passed: W logged `(127,0)` then neutral
on key-up; mouse motion and Cross down/up reached the native bridge, and the
view changed. Input is not the current visual blocker; fresh frame remains
malformed with no Jak. Evidence: `docs/evidence/I1/i1-native-mouse-keyboard-route-2026-08-22.md`.

The existing reference-camera probe was wired into the signed Metal build and
falsified: it removed the scene, while restored native derived-pc-camera again
showed malformed TIE/TFRAG geometry. No camera policy was promoted; composition
remains OPEN. Evidence: `docs/evidence/R1/r1-native-composition-cpu-base-probe-r22-2026-08-22.md`.

Fresh Cross replay reached Village; five taps changed the live frame but left a
large missing band and no Jak. Draw-limit=1 produced coherent partial TFRAG;
no-TIE preserved it, narrowing the next work to full-scene material/coverage.
Fresh frame: `/tmp/ottsel-video/normal-before-cross-20260822-1703.png`.

Native Merc consumer now parses real FR3 models and PC_PORT bone matrices; the
signed build submitted `ndi-lod0` meshes up to 67,554 vertices/4,430 triangles
with zero faults. Exact replay still showed no Jak packet and remains visibly
non-playable. Evidence: `docs/evidence/R1/r1-native-merc-consumer-2026-08-22.md`.

Unique-model PC_PORT tracing now reaches `GAMEPLAY: enter village1` and sees
medres/warp-gate/balloonlurker packets; the native consumer accepts those
world meshes, but no player/Jak packet is emitted. Fresh Simulator frame
remains malformed/no Jak; fault log is 0 bytes. The trace cap now ignores
repeated title packets. Evidence: docs/evidence/R1/r1-native-merc-consumer-2026-08-22.md.

The first cold run of the Jak producer-boundary trace exposed an audio/logger
mutex stall before title. Atomic PCM telemetry moved callback logging to the
non-audio pump; two fresh signed cold launches reached title/bootstrap with
output-only playback and 0-byte fault logs. Full audio remains OPEN. The live
Simulator still shows stretched/fragmented Village geometry with no Jak.

2026-08-23 fresh signed R1 replay: post-Start lookup prefix `54,49,48,42,44`
and page-2 segments `31424/1088/4352 -> 601152/632576/633664` match macOS.
The first 3D family still diverges before Metal: iPad index 10/TBP `0x24d2`
(`0x2004d2e59930a4d2`) versus macOS index 30/TBP `0x24f2`
(`0x2004d1e59930a4f2`). Corrected owner tracing resolves village1 launchers
29/28/27 to raw `0x00200f00` (page 2/index `0xf`) and AdGif TEX0
`0x2004c8e55530a5d2`; the later index-10 owner remains open. No TBP/camera/
shader change was made. Fresh frame remains non-playable; fault log is 0 bytes.

2026-08-23 crash-boundary regression: Apple SDL playback opener is now
joinable and teardown destroys late streams before SDL shutdown; platform pad
state now has process lifetime so exit-time mutex destruction cannot race a
GOAL reader. Focused input regression is 5/5 and full goalc-test is 733/733.
Fresh signed iPad launch on the single booted iPad Pro stayed alive through
30 seconds with callback/mix logs and a 0-byte fault log. Screenshot remains
diagnostic/non-playable; audio PCM peak is still 0, so audible proof is open.

2026-08-23 unique-owner R1 trace removed the repeated-raw cap: fresh route
reached Village1 twice and captured later raw page-2/index `0x1e`/`0x22`, both
AdGif TEX0 `0x2014cd655530a525`, matching native `0x2525`. The first native
family remains `0x24d2/0x2004d2e59930a4d2`, so producer/DMA ownership is still
OPEN. Fault log was 0 bytes; fresh frame remains rotated/dislocated and audio
PCM peak 0. Evidence: `docs/evidence/R1/r1-unique-owner-trace-2026-08-23.md`.

2026-08-23 Mac acceptance replay: ARM64 `(mi)` rebuilt all 546 targets,
`goalc-test` passed 750/750 after immediate analog key-up release was fixed,
and a fresh cold start reached coherent title,
Village1, and Training frames. WASD, action, mouse camera/buttons, neutral
release, minimize/restore, and five-minute stability evidence passed with no
crash markers; the SDL callback and nonzero mixer peaks are now routed to the
active `Jump Desktop Audio` output for this session. M1 remains unpromoted
pending the user's audible confirmation. The desktop control map now includes
WASD movement, mouse camera, face-action mouse buttons, and Return/KP Enter/Escape
Start aliases, with Q/Shift/C/X reserved for L1/R1/L2/R2 within left-hand reach.
Evidence: `docs/evidence/M1/m1-native-controls-stability-2026-08-23.md`.

2026-09-03 BOT36 audit reconciliation: accepted (a)-(h) against current source,
logs, and the retained raw-MERC/no-MERC frames; the projection_mode change stays.
The audit's R18/R19 strip-restart explanation is accepted as a no-op, and the
portrait-encoded simctl screenshots are not a render defect.
Reordered experiments: depth -> level ownership -> Merc bucket ledger -> audio
RPC -> pacing/TOD alpha. Camera math, TBP/lookup, and strip-restart remain frozen;
I1/I2 are OPEN and no playability claim is made.

2026-09-03 I1 Village1 bucket census: live DMA carries Sky/Ocean, generic,
shrub, alpha/trans, shadow, prism/water/depth, and Sprite3 payloads beyond the
currently implemented native TFRAG/TIE/Merc subset. The fresh frame remains
malformed, so this is OPEN; next work is ordered bucket dispatch/draw-list
coverage, starting with Sky. Evidence: `docs/evidence/I1/i1-jak1-bucket-coverage-2026-09-03.md`.

2026-09-04 I1 Sky product boundary: a fresh signed run reached 11 Sky
transfers (6 DIRECT, 24 GIF tags) but 0 PRIM/XYZ callbacks and 0 submissions;
the native product walk is OPEN and the frame remains malformed. Next session
must reconcile its bucket start/tag forms with the SKY IR trace before adding
generated Sky textures. Evidence: `docs/evidence/I1/i1-sky-native-capture-boundary-2026-09-04.md`.

2026-09-10 I1.1 SKY_DRAW root cause: bucket 3 carries PRIM after all. The packed
sky tags are `pre=1 prim=0x5d` = `TRI_FAN`, which the native `push_vertex`
switch never handled, so 16-18 prim starts accumulated to the 8-slot cap and
produced 0 candidates; upstream handles it at `DirectRenderer.cpp:1296`. Adding
the case moves the packed population from `candidates=0 strips=0` to
`candidates=34..40 rejected=0 strips=34..40` with `unhandled-packed=0`. The
completions still do not render because all of them sample `tbp0=0x1fa0`
(64x64 PSMCT32) with no VRAM source, so they are pruned as texture misses; that
source is the unimplemented SkyBlend bucket 32. Sky is still black; no
playability claim. Evidence: `docs/evidence/I1/i1-sky-draw-tri-fan-2026-09-10.md`.

2026-09-11 BOT40 opens (`docs/BOT40_PROMPT.md`, supersedes BOT39) under the
user's standing disk-gate override (Avail 14Gi, 0 temp packs). I1.1c settles
the disputed sky draw path: a magenta probe through `skyDebugFillPipeline`
drawn at the END of the encoder paints 49.7% of the frame, and redrawing the
captured `_skyBatches` there with the real product pipeline paints textured sky
geometry. The sky draw path is ALIVE; BOT39's "the draw path is dead" and the
stale-binary "floods cyan" claim are both refuted. The real defect is placement:
the native Direct/sky NDC conversion (`metal_gfx.mm:2659-2671`) is the suspect,
though that placement reading is NOT settled: same-binary launches at t=45 s
differ on 39.5% of pixels and the camera is live, so single-screenshot A/Bs are
inside the noise floor (`docs/evidence/I1/i1-frame-determinism-2026-09-11.md`).
One fresh frame does show recognizable Village1 huts/palms/water. Sky is still
black; no playability claim. Evidence:
`docs/evidence/I1/i1-sky-draw-path-alive-2026-09-11.md`.

2026-09-11 (I1.1f, PASS structural): the Direct texture registry was never
populated — 4 entries against 478 records — so every Direct draw and all three
sky sources fell back to a raw GS-VRAM decode that takes the CLUT base from the
ADGIF rather than the game's texture record. Populating it in the
`handle_upload_now` loop raises it to 486 and all three sky sources now resolve
from it (`key-present=1`, fault log 0 bytes). Sky content is still not a
gradient, so I1 stays OPEN; next suspect is `g_direct_texture_metadata`, keyed
by `dest` alone, letting a page reusing `dest=0x20` alias the sky record
(`docs/evidence/I1/i1-direct-texture-registry-2026-09-11.md`).

2026-09-11 (BOT43, REFRAME): the BOT42 framing is refuted by measurement. The
camera and scene are LIVE (screenshots 8 s apart differ on 5.34% of pixels;
cam-accepted rises 1:1 with chain; merc-submits rises ~90 per 90 chains), so the
scene is not deduplicated or latched. The visible defect is the Sprite3 layer:
with `ottsel-trace-metal-scene-no-sprite` armed every flat rectangle disappears
and a correct textured training-level village remains. Two sprite data defects
are measured: `tbp=0x24f2` 64x64 PSM19 decodes to alpha-max=0, and Sprite3
groups arrive with `tex0=0`. Evidence: `docs/evidence/I1/BOT43-camera-live-sprite-defect.md`.

2026-09-11 (BOT44, REFRAME): the BOT43 'Sprite3 overlay' headline is withdrawn -
the flat rectangles are the app's own touch-control overlay (`build_touch_overlay`
in `src/shell/main.cpp`, drawn at `metal_shell.mm:1678` with a 1x1 white texture
and flat per-vertex colour). Fresh launch: `-scene-no-sprite` alone leaves every
rectangle; only `-scene-no-overlay` clears them, and that arm disables sprites
too (`metal_shell.mm:1592`) - the confound behind BOT43. Gate V1: make the layer
probes orthogonal. Evidence: `docs/evidence/I1/BOT44-touch-overlay-not-sprite3.md`.
