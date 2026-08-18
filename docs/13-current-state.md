## 2026-08-18 update — cross-platform loop resumed; iPad input seam verified

The product is now tracked as one macOS/iPadOS/iOS loop. macOS remains the
working rendering/gameplay reference, but it no longer blocks the mobile
input/platform work. The one-runtime rule remains strict: macOS `gk` was
stopped before the iPad Pro 11-inch (M4) Simulator was booted.

The new mobile platform bridge feeds the same completed DualShock snapshot
that desktop `PadData` reaches through `scePadRead`: canonical buttons, sticks,
and pressure. A live Simulator keyboard Space press produced Cross `0x4000`
and pressure `255`, then an all-neutral release; see
`docs/evidence/I1/i1-platform-input-shell-2026-08-18.md`. The bundle also now
declares `UIApplicationSupportsIndirectInputEvents`, which the Simulator had
required for mouse input. This establishes the iPadOS/iOS external
keyboard/controller seam and lifecycle-neutralization implementation, not
mobile game playability.

The first iPad keyboard attempt exposed the same short-tap race previously
fixed on macOS: SDL delivered Return down/up before the independent GOAL poll
could sample it. The shared platform-input bridge now latches digital keyboard
downs for eight `scePadRead` samples. A fresh Simulator Return tap emitted the
canonical Start transition and the game logged `TITLE: start edge in
title-wait`; Space likewise emitted Cross `0x4000` with pressure `255` and
then neutral release. This is mobile input acceptance at the title boundary,
not proof of visible menu/gameplay because the UI bucket renderer remains
incomplete.

The iPad now has a narrow real scene-rendering pass: the shared FR3 loader,
PC-port camera packet, and normal-TIE Metal renderer visibly produce textured,
time-of-day-colored Village1 geometry. It has a one-time visible-tree snapshot
and fog-color transport, but does not yet compose opaque TFRAG/background or
the remaining TIE material semantics, so it is not a playable visual pass.
The mobile product path remains the desktop streaming/bucket-renderer
architecture; the old VU/software-rasterizer shell remains diagnostic-only. Mac continues to require a physical
keyboard/controller/mouse acceptance replay in Training, while output-only
audible audio remains a product gate on each platform. `-nosound` is allowed
only for a bounded visual/input test and never implies microphone access is
required or acceptable.

### 2026-08-18 iPad composition retest — fog arrives; scene remains incomplete

A fresh signed one-Simulator run advanced from title to `village1` and
received four live `FOGCOL` updates from the game's DMA stream. Its normal-TIE
renderer selected three trees and submitted 119 textured batches (511,138
vertices / 252,888 triangles). A follow-up run added one visibility-culled,
opaque-TFRAG tree (77 batches / 53,304 triangles), producing the Village1
hill, tower, and foreground terrain. The captured display nevertheless
remains mostly black above that geometry. This verifies fog-color delivery
and the first opaque background pass but still fails the composition gate:
iPad lacks Direct/Sprite sky/effects, transparent/dirt/ice TFRAG, and
remaining TIE material semantics. The next bounded implementation maps the
Direct/Sprite bucket contract before enabling it. See
`docs/15-macos-to-mobile-goal-loop.md`.

### 2026-08-18 iPad TIE geometry/transform gate

A single iPad Pro 11-inch (M4) Simulator run loaded the compressed desktop
`village1.fr3` data and uploaded the first normal TIE tree to Metal: 319,546
vertices and 253,196 expanded triangles. The first presentation was black;
the bounded CPU projection probe then showed 1,876/4,097 sampled vertices
inside the desktop OpenGL clip volume but zero inside Metal's `[0,w]` depth
volume. The shared desktop shader targets OpenGL `[-w,w]` depth, so the Metal
vertex shader now applies only `z = (z + w) / 2`. Computer Use then captured
the expected visible flat-green Village1 geometry. This passes the first
FR3/world-to-clip/Metal submission gate. It does not pass textures,
time-of-day colors, fog, culling, depth/blend modes, title rendering, input
gameplay, iPhone parity, or device acceptance. See
`docs/evidence/I1/i1-tie-geometry-transform-2026-08-18.md`.

### 2026-08-18 iPad textured normal-TIE milestone

The first normal-TIE tree now renders as 30 separate material batches using
the level's 18 referenced FR3 textures, with a 5,376-entry time-of-day palette
calculated from each live PC-port packet. A fresh Computer Use run visibly
showed textured Village1 terrain rather than the earlier flat-green geometry.
The palette trace is bounded to its first three updates and every 120th later
update. This passes texture and color delivery for that one uncullled tree; it
does not establish correct tree selection, depth/fog/blending, other TIE
categories, TFRAG, Merc, title rendering, or playability. See
`docs/evidence/I1/i1-tie-texture-color-2026-08-18.md`.

The macOS reference remains verified by
`docs/evidence/M1/m1-retail-single-runtime-retest-2026-08-18.md`: the real
title/menu/New Game and A/B/C/D1/D2 flow reaches rendered Training; movement,
Cross, Circle, and a five-minute soak passed. ARM64 sky blending and the PC
particle capacity have focused regressions and live replays. The newest
cross-platform iteration rules are in `docs/15-macos-to-mobile-goal-loop.md`.

### 2026-08-18 iPad renderer reorientation — active scene, absent PC bucket renderer

A fresh, single iPad Pro 11-inch (M4) Simulator run built from the current
signed local bundle remained visibly black except for the shell indicator.
This was nevertheless a real game scene: `village1-vis` loaded, both level
slots reported `active`, and `BGWORK` reported one TFRAG plus three TIE trees.
The existing mobile VU diagnostic ran TFRAG microcode and occasionally decoded
small GIF output, but that output does not represent the active TIE scene.

The decisive source comparison is that normal TIE emission is intentionally
disabled in the PC-port GOAL source: `tie-methods.gc` comments out
`draw-inline-array-instance-tie` and `draw-inline-array-prototype-tie-asm`
because the macOS C++ renderer handles normal TIE directly. The iOS shell has
no corresponding PC bucket renderer, so the next product change is a
platform-neutral bucket-renderer seam based on the macOS renderer's inputs and
per-bucket semantics. Do not promote the diagnostic VU/software raster or a
texture upload as a composed-frame pass. See
`docs/15-macos-to-mobile-goal-loop.md` for the replacement loop.

### 2026-08-18 iPad renderer retest — live dispatcher, missing transfer boundary

After a signed rebuild, one iPad Pro 11-inch (M4) Simulator launch reached
the live game dispatcher and continued streaming (`village1` and `title`
active), but the visible surface remained black. This is not a Simulator
launch failure: a real nonzero TFRAG dispatcher entry (`MSCAL 0x6`) was
observed with the corrected VU register state. It then capped at 50,000
instructions with zero XGKICK/GIF output, and the per-window aggregate was
5,886 capped VU runs out of 5,976.

The producer is therefore no longer the first blocker. The restored
`draw-inline-array-tfrag` does perform its scratchpad transfer, but the iOS
bridge was reading the wrong field (`tfragment+32`) as a DMA-chain pointer.
The real mips2c call copies 64 qwords from `a1` to fake scratchpad `0x1d0010`.
A fresh one-shot trace sees that exact copied block and shows TFRAG metadata
and pointers, not VIF/DMA data. A second bounded trace follows the existing
mips2c builder to its output buffers: those buffers contain valid-looking VIF
DMA headers and `MSCAL 0x6`, but the shell reaches that call without the paired
frag-header upload at VU address zero. The next renderer change is therefore
output-buffer ordering/VIF-state lifetime, with a live nonzero GIF proof. It
is not a reason to promote the diagnostic rasterizer as the iPad renderer. The
run was terminated before any desktop runtime work resumed. A pasted
`OttselShell` dyld report from a direct desktop launch is separately explained
by the Simulator environment and is not an Ottsel game crash.

### 2026-08-18 macOS keyboard edge repair

The macOS keyboard mapping had a real short-tap compatibility failure: SDL
received down/up, but because it was drained after the frame's keyboard poll,
the next poll could see only release and never populate `scePadRead`. Bound
down edges now latch through a bounded eight-poll window. A focused regression
and a fresh live title replay prove Space reaches Cross `0x4000` with pressure
`255`, and Return reaches START `0x8`; title-wait consumed the rising edge and
opened the visible normal title menu. See
`docs/evidence/M1/m1-keyboard-edge-2026-08-18.md`. Physical controller and
mouse acceptance are still open P0 requirements, as is output-only audio.

### 2026-08-18 output-only audio boundary retested

One bounded explicit-audio app launch and one direct-`gk` contrast both select
`MacBook Air Speakers`, complete Cubeb initialization/latency enumeration, and
then block in `AudioComponentInstanceNew → AudioDeviceCreateIOProcID → CoreAudio
mach_msg`. No input device or input stream parameters are passed, and no
microphone prompt was accepted or required. This disproves the local shell
wrapper as the immediate cause but does not make audio a host-only exemption:
the product still needs a working output session. Preserve `-nosound` only as
test containment and use the captured boundary to evaluate a different backend
or non-blocking recovery path. See
`docs/evidence/M1/m1-output-audio-stream-create-2026-08-18.md`.

## 2026-08-17 update — iPad Simulator boot boundary under investigation

A fresh, ad-hoc-signed `OttselShell.app` installs and launches on the iPad
Pro 11-inch (M4) Simulator. The former `art-group-load-check` SIGBUS was a
real C/GOAL ABI breach: the following GOAL type access received raw zero
instead of canonical `#f` (`s7`) and dereferenced `EE-4`. Live disassembly
showed the immediately preceding phase-A no-emit native export stub, while
`*file-temp-string*` was valid and nonzero.

An attempted `jak1::loado` zero conversion was falsified and reverted: the
same post-title SIGBUS recurred and its zero-only line never fired. The
resolved native mapping explains why: the observed slot `0x04f00cf4` is the
stack-argument `_format` export, not `loado`; `make-file-name` calls it while
building the art-group filename, and `format` deliberately returns zero when
its destination is a string. The next probe is therefore the ARM64-generated
`make-file-name` return path, which must discard that zero and return
`*file-temp-string*` before the actual `loado` call.

Visual inspection still shows a small diagnostic raster, not a Jak title.
The iPad trace reaches eight `display-sync`/VSync/DMA submissions, then faults
at the same art-group check before a later VSync checkpoint. Reaching title is
useful boot evidence, not a surviving loader, renderer, or iPad playability
pass.

The screen currently shows the shell diagnostic surface, not a Jak title:
the raw-texture preview was removed because a decoded texture page is asset
data, not a composed frame. The retained VU1/software renderer is debug
tooling only. The iPad product gate remains one upstream bucket renderer plus
one `.fr3` level through a supported iOS backend, with a captured recognizable
frame; IOP/streaming, full local user-supplied data, and touch/controller
input follow that renderer boundary.

## 2026-08-17 update — macOS title-to-Village1 integration pass

The macOS-first gate has now passed for the native arm64 `gk` path using
the real title/menu/save flow and the real streamed intro, not `(bg ...)`.
On a fresh `-boot -fakeiso -nosound` run, the game reached `target-title-wait`,
opened the normal New Game/save UI, then completed:

`sage-intro-sequence-a -> sidekick-human-intro-sequence-b ->
sidekick-human-intro-sequence-c -> sage-intro-sequence-d1 ->
sage-intro-sequence-d2 -> GAMEPLAY: enter village1 -> training`.

The former B freeze was a source-level no-progress binary search in
`curve-evaluate!`: with adjacent knot bounds `[6,7]`, its lower-bound
update reused midpoint `6` forever.  Both curve searches now advance the
lower bound past the midpoint.  The focused `ottsel-a1-sem` regression and
the full 546-target ARM64 GOAL rebuild pass.  The same live replay reached
rendered Village1 and a bounded synthetic left-stick hold changed Jak's
position, proving the game input path controls gameplay.

This is a **core macOS playability pass**, not final platform closure.
Audio remains intentionally contained by `-nosound`: the host CoreAudio
output-unit issue is still separate and must be fixed/verified without
accepting any microphone permission.  Next macOS work is a short stability
soak with normal movement/actions and visual cleanup of remaining lighting/
framing artifacts.  Only after those checks should the same evidence loop
move to iPadOS, then iPhone: renderer backend, full bundled user-supplied

### 2026-08-18 host-audio containment

The macOS Jak 1 executable now adds `-nosound` unless
`OTTSEL_ENABLE_HOST_AUDIO=1` is explicitly set; the local window launcher
also supplies `-nosound` as a second guard. This is a containment measure,
not a claim that microphone access is needed: the `Player` stream passes null
input device and input parameters to Cubeb, while output-only CoreAudio
startup under the app bundle remains unverified. A standalone statically
linked binary did start output-only CoreAudio and reach the title sequence,
but the same binary hung before stream creation when launched through the
bundle. A fresh bundled launch with no wrapper `-nosound` argument proved the
new runtime policy injected it, reached the visible Naughty Dog intro, and
showed no microphone prompt. Do not approve a microphone prompt as part of
this product path.

An output-only default-device control also blocked at Cubeb stream creation
before graphics initialization, just like the explicit physical-speaker path.
The issue is therefore not selection of the HAL output device and not any
input/capture request. The current fallback remains silent until macOS
CoreAudio can create an output stream under the bundled runtime.

A static-SDL foreground-exec control also blocked at exactly the same point,
so neither dynamic SDL linkage nor the wrapper's background-child behavior is
sufficient to explain the launched-app failure. The successful standalone
audio process is retained only as a narrow control, not product evidence.

### 2026-08-18 TFRAG platform boundary

Mac Training now has live far-terrain provenance: three traced frames carried
populated TFRAG lists through scratchpad transfer and rendered 12,764 plus
1,732 terrain triangles per frame. The legacy iOS-only scratchpad stash was
writing into macOS TFRAG wait-statistics fields, so it is now guarded by
`OTTSEL_IOS`; the focused regression and a fresh canonical Training replay
both pass with no macOS stash record. The remaining host-audio gate is
separate from renderer/input playability.
data, IOP/audio, touch/controller input, lifecycle, and device performance.

Fresh standalone evidence pins the audio boundary precisely: an output-only
Cubeb stream reaches `AudioComponentInstanceNew`, then waits in
`AudioDeviceCreateIOProcID`/HAL IPC before a stream exists.  It reproduces
with both Cubeb's default output and the explicitly selected `MacBook Air
Speakers`; it is not microphone capture, a GOAL/IOP deadlock, or a default
device-selection bug.  The bundle has no microphone usage key or entitlement.
The Player now retains explicitly enumerated Cubeb devices through synchronous
stream creation (instead of retaining a dangling device ID) and emits bounded
component-stage diagnostics for the next viable-host test.

## 2026-08-17 update — native macOS title and first gameplay are verified

This supersedes the older host-specific diagnosis below where it conflicts.
The macOS fake-ISO installation contains and loads the retail title assets:
`NDINTRO.STR`, `LOINTRO.STR`, and `VI1.VIS`.  A fresh native arm64 launch
reached `target-title-wait`; one subsequent START edge opened the normal
title menu.  Selecting New Game reached the normal save-slot flow, entered
village1, then Misty, and a synthetic left-stick pulse changed Jak's logged
position while the scene continued rendering.  This is real title/menu/game
flow, not the diagnostic `(bg 'village1)` bypass.

Two ARM64 duplicate-lane swizzle defects (`.ppach` halfwords and VF
32-bit swizzles) were fixed with focused semantic regressions.  The title is
now visibly composed rather than the earlier warped red/black geometry.

The default host CoreAudio path remains externally blocked during
`AudioComponentInstanceNew`; this reproduces in the native `sndplay`
control, so it is not an IOP coroutine or game input failure.  The normal
macOS launcher uses the game's native `-nosound` option as a temporary
containment: it reaches a live title screen without opening a Cubeb stream
or requiring microphone input.  Audible output must be revalidated on a
host where CoreAudio can create an output unit.

This historical checkpoint is superseded where it says iPadOS work has not
started or that `SAISB.STR` is missing.  The current macOS retail-flow pass
and the iPad loader-boundary repair are recorded at the top of this document.
See `docs/evidence/M1/m1-title-logo-forensics-2026-08-17.md` for the
contemporaneous title investigation.

## 2026-08-16 update (BOT23) — Jak 1 boots to the title on macOS (native arm64)

M1 partial pass.  The host gk now boots to the displayed title screen in
~15 s and keeps running (real GL renderer + IOP/overlord + no-emit AOT
GOAL code, zero faults).  Three root causes fixed with lldb/crash-report
evidence: missing icache invalidation at every RW->RX code-page flip
(this WAS the long-standing nondeterministic link-phase SIGILL), a
stub-arena boot-order dependency (fixed with per-slot page sealing across
all five stub writers), and upstream's PROT_NONE low-memory guard (now
PROT_READ in no-emit builds — the game reads null-ish bone transforms by
design; sidekick's title-boot path hit it).  All fixes are compiled into
the iOS runtime archive as well.  See docs/evidence/M1/m1-title-boot.md.
Remaining for full M1: input/audio verification, title→village1
progression, perf sanity.

## 2026-08-16 update (BOT22b) — strategy audit: the smart path to playable is in the tree

Full project audit + external review (see docs/14-roadmap-to-playable.md).
Key facts established live: the fork base is upstream 2026-07-31 (the ARM64
emitter exists UPSTREAM; upstream is landing ARM64 itself, jak1 "in strong
shape", but says "no plans to ever make a mobile release" — iOS is our
moat).  The complete upstream stack is in-tree and works on this Mac:
the fr3 level extractor produced all 25 renderer asset files in 5.5 s
(`decompiler ... --config-override '{"decompile_code": false}'`), the full
`out/jak1/iso` (321 files incl. STR/VIS/audio) built in 18 s
(`goalc --isa arm64 ... (mi)`), and the native arm64 host `gk` launches
with the real OpenGL renderer (GL 4.1 on Apple M1), SDL3, and the real
IOP/overlord thread — while linking KERNEL.CGO through the no-emit AOT
path.  The iOS bundle's "no STR files" wall was a hand-pruned bundle, not
missing data (iso_data/jak1 holds the full 1.4 GB extraction).
Consequence: the S2.2 software-rasterizer/VU1-interpreter track is retired
as a product path (kept as debug tooling); rendering adopts the fr3 +
C++ bucket-renderer pipeline (ANGLE or Metal port for iOS).  Known issue
carried forward: the nondeterministic no-emit link-phase fault also kills
host boots (~1-in-3) — now a top-priority runtime bug since it gates every
platform.

## 2026-08-16 update (BOT22) — village1 ACTIVATES; the S2.2 "level never activates" blocker is resolved

The blocker's premise was false: the bsp-header relocate's write always
landed (earlier probes read one word short — `bsp` is at ref+44 because the
level's inline kheap is 16-byte aligned at mem+32; the "loading-level"
0x3fdd674 with the zero heap is the `level-default` slot).  The live status
trace (corrected offsets) shows village1 completing `'loading -> 'login ->
'loaded` with the bsp set; it then waits for START on the title screen.
The headless shell had NO input path (scePadRead's input manager is null),
and the title intro can never play because iso_data contains no STR files
(the spooled logo/ndi animations never reach 'active).  Fixes (runtime and
shell only, no game-source changes): a synthetic pad bridge
(taps/clicks/keys + file triggers press START; verified `rel0=0x8` edge on
cpad0 in GOAL), an EE-thread `(bg 'village1)` driver (the game's own
debug boot-to-level entry) once village1 is preloaded, `(-> *level* play?)
= #f` (the genuine bg-flow state; with play? #t the no-VIS "in between
vis" branch leaves vis-bits zero forever), and `*artist-all-visible* = #t`
(the engine's artist toggle; the camera sits inside village1's boxes, so
cam-update otherwise takes the update-vis! branch that cannot succeed
without VIS data).  Verified live, zero faults: village1 `'active`
(bsp=0x2ef80d4), the title level discarded, background-work fills every
frame (tfrag-count=1, tie-count=3 — the bsp's trees), the restored tie-ln
runs with vis0=0xffffffff.  The remaining S2.2 gap is renderer-side only:
the VU1 interpreter runs the tfrag chains (2080 runs/period) but emits
zero GIF output (frag list empty at top=0), and the tie microcode
(tie.txt) is not embedded yet — Track B steps 2–4 in s22-reorientation.md.
Evidence: docs/evidence/S2/s22-bot22-level-activation.md.

## 2026-08-16 update (BOT21c) — mips2c ln restored; the game's tfrag draw pipeline now runs

The far `(draw-inline-array-tfrag ...)` calls in goal_src tfrag-methods.gc
are RESTORED (the port had commented them out) and GAME.CGO is recompiled
(7d44395a).  Live verification (one boot, zero faults): the TFASM probe
inside draw_inline_array_tfrag::execute now fires (a2=1 far tfragment), the
mips2c writes *tfrag-work* +0xb0 (dma-buffer), and the tfragment's stored
dma-chain (0x2297920, 128 qwords) contains the per-draw VIF stream incl.
the frag-list header UNPACK to VU 0x0.  The far tfragment's vis bit is 0
(the port's draw-node-cull is disabled -> vis-list never set), so ln skips
it without a diagnostic force.  The shell now has an SPR->VIF1 scaffold
(parses the stashed dma data, UNPACKs -> VU mem); the composed frame still
needs the full VIF stream parse (the DIRECT-embedded commands + the far
geometry UNPACKs) and the vis-list resolution.  Evidence:
docs/evidence/S2/s22-bot21c-ln-restored.md.


## 2026-08-16 update (BOT21) — black-window present regression fixed; frag-list blocker root-caused

The BOT19-BOT20 black window is FIXED and verified (one boot, one Simulator,
Windowed, zero faults; committed c6b7104).  The presents were always
reaching the layer; the BOT20 "present every decode" gate let uniform
(empty) tpages -- tpage 0x2 tex 43 (128x128 all-zero), 0x100 tex 0 (64x64
all-zero), 0x370 tex 0 (64x64 all-0x80) -- overwrite `g_frame`, so the
window showed the last decoded black page (614,400 px all (0,0,0)).
`gfx_texture_upload_now` now samples ~256 pixels and skips uniform pages
("keeping the last real frame"); the real village tpage 0x1cf tex 44 stays
visible (s22-bot21-texture-visible.png).  The simulator's floating-window
("Move & Resize") mode was ruled out as a red herring (it blanks every app
in the framebuffer capture, and the layer geometry was always correct).

S2.2 composed-frame blocker root cause (s22-bot21b-fraglist-rootcause.md):
the ported `goal_src/.../tfrag-methods.gc` comments out the mips2c
`(draw-inline-array-tfrag ...)` calls that the retail game makes (the
retail reference has them), so the recompiled GAME.CGO's
draw-drawable-tree-tfrag (live disassembly: init-buffer -> perf-stats ->
end-buffer -> bucket-insert, no `ln` call) never builds the frag-list
header (VU words 0-4).  The VIF emulation is correct (TOP=0; matrix lands
at VU 0x5 and tfrag-data at 0x290, exactly where the microcode reads
them); the game-side frag-list construction is simply absent.  Next:
restore the `ln` calls, recompile GAME.CGO, and feed the frag-list into
the shell's VU1.


## 2026-08-15 update (BOT16) — S2.2 texture decode verified; composed frame next

The BOT15 "pixel noise" frame is FIXED and verified (one boot, one Simulator,
Windowed, zero faults).  Root cause: Jak textures are pre-scrambled for a
128-px PSMCT32 GS upload, so the tpage segment data is not linear texels and
the CLUT is not found by a heuristic.  Fix (runtime-side only): replay the
GS upload into a 4 MB fake VRAM (`psmct32_addr(x,y,128) + seg.dest*4`) and
un-swizzle with the texture's real `clutpsm`/`clut_dest`
(download_rgba8888 logic).  Real game textures now present through Metal
(128x64, 128x128, 256x512; on-screen 256x512 tpage 0x408 tex 3 is a coherent
Jak image — `docs/evidence/S2/s22-bot16-texture-frame.png`).  Added the
renderer-core VIF/GIF draw-state decoder (register tracking + prim building);
the title direct bucket draws framebuffer-copy quads and the 3D buckets use
VIF UNPACK (title-vis-tfrag tpage 0x1a0 uploads, mode=2).  S2.2 full gate
(composed title frame) needs the direct-bucket rasterizer + the 3D bucket
renderers; see `docs/reports/2026-08-15-bot16-handoff.md`.

---

## 2026-08-15 update (BOT14) — S2.2 Metal backend wired; first correct frame pending

S2.1's stable title boot is committed (3d15997).  S2.2 progress this loop: a
Metal GfxRendererModule (`src/shell/metal_gfx.mm`) is registered into the
runtime's Gfx backend -- the game's texture uploads now route through Metal
and present through the CAMetalLayer (the first game-driven present on the
Simulator; evidence `docs/evidence/S2/s22-bot14-metal-backend.*`).  The
decoded frame is not yet a correct Jak image: the GS texels arrive via the
DMA chains (GIF IMAGE packets) into the converter's VRAM, not directly in
the tpage, and the PSMT8 CLUT needs the correct palette region.  The renderer
texture-data flow + the direct-draw rasterization (title backdrop) is the
next step (see `docs/reports/2026-08-15-bot15-handoff.md`).

---

## 2026-08-16 update (BOT21d) — VU1 entry + ILW component fixes; far path reaches the output phase

Two falsifiable VU1-interpreter fixes, verified against the running app:
(1) the tfrag MSCAL entry is pc=8 (`b L3 | xtop vi14`), not pc=0 (the L11
hardcoded-0x2a0 header) -- with the correct entry the far path reads the
frag-list at VU 0-4, the matrix at VU 5-8 and the tfrag-data at 0x290; (2)
the ILW/ISW integer loads ignored the 16-bit component (always .y) -- the
component is the dest-mask bits 21-24 (reversed bit0=w..bit3=x).  The far
path now runs into the strip-output loop (run#10 exits pc=1707 vs the skip
path before).  gif_out is still 0: the frags' referenced page/vertex data
beyond the 128-qword stored stream is not yet uploaded.  Evidence:
docs/evidence/S2/s22-bot21d-microcode-fixes.md.


## 2026-08-16 update (BOT21g) — per-draw renderer attribution corrected; composed frame blocked on the game-data level

The per-draw VIF groups (0x160/0x3d4/0x384/0x290/0x381 + MSCALF 0) are the
TFRAG program at pc0/L11 (vi14 = 0x2a0), NOT the generic tie/merc renderer.
Verified two ways: (1) an offline full-VIF replay tool (correct VIF
semantics: UNPACK addr flag = bit 15, BASE/OFFSET/TOP=0 from the live
capture) runs every reference microcode over all 661 MSCALFs -- the tfrag
pc0 program is the only one with any output, and with a 400k cap every
tfrag mscal exits cleanly with gif_out=0; (2) a fresh live boot of the
fixed shell (0 faults, PID 95944): every per-draw run is `mscal imm=0x0
top=0x0 pc=1382/1070/1414/141/1506/313/1706 gif_out=0 frag[0..2]=0x0` --
exit pcs match the offline replay exactly, and the "OTTSEL GENERIC" runs
are gone.  Shell fixes: UNPACK addr flag bit 15 (was bit 21), tfrag pc0
per-draw entry (was pc8), generic-microcode dispatch removed (the 0x381
const c0=0x7f7fffff is the tfrag per-draw path's own const).  The
composed-frame blocker is now precisely attributed on the game-data level:
the frag-list at 0x2a0 is never built (ln skips the tfragment, vis=0; the
port's goal_src disables draw-node-cull), the far LOD is genuinely empty
(63 (0,0,0,-1792) markers + LOD offset table, verified byte-by-byte), and
the near path is unavailable (dma_level1 = 0x13131310 garbage,
draw-inline-array-tfrag-near unlinked, near draw code commented).  Next:
restore draw-node-cull in goal_src tfrag-methods.gc, recompile GAME.CGO,
verify ln builds the frag-list.  Evidence:
docs/evidence/S2/s22-bot21g-perdraw-attribution.md.

## 2026-08-16 update (BOT21g–u) — S2.2 BLOCKED: the level never activates; the compose-frame roadmap

The S2.2 composed-frame blocker is now precisely attributed and blocked:
the bsp-header relocate RETURNS SUCCESS (`RELOC7RET: arg=0x2ef80d4
ret=0x2ef80d4` — the goal `(else ... this)` branch ran), yet the level
slots end `'inactive` with bsp=0 and NO bsp-header reference (0x2ef8xxx)
anywhere in the loading-level (0x3fdd674) or the level0/level1 slots
(full-object scans, BOT21u).  The served-object buffer at 0x2ef80d0 reads
zeros right after the relocate (the v2 link moved the object and the
double-buffer churns — earlier served-buffer reads may be churned data,
BOT21t).  The background-work list stays empty every frame
(tfrag-count=0, tie-count=0), so the bsp's 11 drawable trees — including
the tie trees with real instance data (6+42, 2+14) — are never added and
never drawn; the tfrag VU1 chains that appear come from a loading-state
path, not the bsp's trees.  The tie-ln (draw-inline-array-instance-tie)
is restored in goal_src + recompiled GAME.CGO (md5 4e33a7fb, `--isa
arm64`) but never runs.

Roadmap (docs/BOT8_HANDOFF.md + docs/evidence/S2/s22-reorientation.md):
Track A = decode the relocate's x22-based bsp-write target (the port's
codegen "off" register semantics) or trace the level status transitions
(loading → loaded → alive → active) to pin where the level dies after
login-begin.  Track B = compose the S2.2 evidence frame from the loaded
tie geometry through the shell's renderer (tie instances + tie.txt
microcode + the proven VU1/GIF/rasterizer path) — the more direct route
to the gate.  Constraint: one Simulator, one runtime, Windowed; verify
against the running app, bundle logs, and compiled ground truth.


## 2026-08-15 update (BOT13) — stable title boot; enter-state fault fixed

The previous deterministic blocker is FIXED and verified (one boot, one
Simulator, Windowed, zero faults).  Root cause, evidence chain, and fix are
in `docs/evidence/S2/s21-bot13-titlefix.md`; short version:

- The BOT12 "state-symbol mislink" reading was disproven by in-process
  probes: `target-continue` -> 0x19818c -> value 0x4624074 (correct, no
  duplicates) right up to the fault.
- The fault was `enter-state` (gstate+0x2d4) entering the TARGET process
  (pid 12) with `pp->state = pp->next-state = 0`: the second `go` in
  target-continue's `:code` is `(go target-title)`, and `target-title` had
  value 0 because its defining object (title-obs.gc) was never linked.
- Why: title-obs lives in TIT.DGO.  The port served the raw ISO TIT.DGO,
  whose GOAL objects use the PS2 v3 header (first word 0x0); the DGO serve
  skip test (`tag == 0xffffffff`) skipped them as "non-GOAL".  GAME.CGO does
  not contain title-obs (upstream packs it in `dgos/tit.gd`).
- Fix (runtime-side, no game source patched): build + ship the recompiled
  TIT.DGO (no-emit v3 static-screen.o/title-obs.o), accept the "GOAL" magic
  (0x4c414f47) in the DGO serve skip test, and make `link_begin` complete the
  v3 link synchronously (the goal-side multi-frame resume path never fired
  for the v3 DGO objects).

Verified outcome: zero faults; `link finish: static-screen` / `title-obs`;
the target process executes title-obs code (pc 0x492a9fc in the title state
machine); `GAMEPLAY: enter title` twice; the boot then requests village1
(`begin load village1-vis [vi1.DGO]` -- not in the bundle, the ROM-safe
boundary the game tolerates); full process tree (24 nodes: target, camera,
display, HUD, subtitle, etc.); dispatcher stable past 121,000 iterations.
The only repeated activity is the STR subtitle/text RPC emulation returning
the ROM-safe no-data response.

Next gate: S2.2 -- first real Jak frame via Metal (the Metal shell still
presents the log surface; the game's GfxRendererModule seam is the
connection point).  See `docs/reports/2026-08-15-bot14-handoff.md`.

---

# 13 — Current state (handoff snapshot)

## 2026-08-11 update (BOT12) — boot reaches the title screen

The engine-integration boot now advances past every earlier boundary to the
game's title state machine: KERNEL.CGO (8) + GAME.CGO (346) link; ART.CGO
(21) + TIT.DGO (15) serve from the bundle `iso_data`; title-vis loads; the
dispatcher runs; **"GAMEPLAY: enter title"** prints (the target's
level-enter handler).  This loop's verified fixes:

1. `src/shell/ios_boot.cpp`: low-EE guard `PROT_NONE` -> `PROT_READ`
   (zeroed).  The PS2 has no MMU; game code legitimately reads low memory
   through default-initialized pointers (`vector<-cspace!` null-bone read;
   its `w == 0` guard returns `{0,0,0,1}`).  Writes/execute still fault.
2. `goalc/emitter/IGenARM64.cpp` `msub_gpr32`: MSUB base lacked the "o" bit,
   so `(mod a b)` compiled to `a + (a/b)*b` (update-wind array index fault
   at 0x41d83c4).  Fixed + clang-verified (`msub w0,w0,w1,w17 = 0x1B01C400`).
3. Same file `min_vf`/`max_vf`: FAMIN/FAMAX (ARMv9.2 FEAT_FAMINMAX) raise
   SIGILL on the M4 (bones.gc at 0x42308c8); replaced with ARMv8 FMIN/FMAX
   (`fmin.4s v1,v0,v1 = 0x4EA1F401`, `fmax = 0x4E21F401`).

**Current deterministic blocker (DIAGNOSED)**: `enter-state` (gstate.o)
calls the target's first state (`init-target` ends `(go target-continue
arg0)`) and the state symbol value is garbage (0x42b4000 — shrub-work's
zeroed static region).  The target-death state objects are correctly linked
(0x4624074, 0x46252d4) and the linker's ADRP+ADD static patch is correct
(verified with a temporary LINKSTAT diagnostic); the failure is in the
state-symbol value write/read path (the `(sym - s7)` slots live in the
transient top-level segment).  See
`docs/evidence/S2/s21-bot12-state-mislink.md` and
`docs/reports/2026-08-12-bot13-handoff.md` for the exact next probes.

Evidence: `docs/evidence/S2/s21-bot12-*` (protre-advance, title-enter,
topdump, state-mislink).  The canonical patch `patches/h3-jak1-host-boot.patch`
was regenerated and clean-applies to the pin (reverse-apply OK).

---

Date: 2026-08-09. Updated by the operator-requested repository audit.
This is the authoritative state document. Read it before doing anything.
Read `docs/15-progress-audit.md` first for the corrected execution order.

## Bottom line

- Gates H1 (ARM64 goalc codegen), H2 (no-emit host runtime), H2.5 (packaging
  decision) are **PASS** with evidence.
- Gate H3 (Jak 1 host AOT boot proof) is **PASS (2026-08-08, host)** — the
  GOAL **kernel dispatcher executes and loops** under RX with zero faults.
- Gate S1 (Simulator shell boots the no-emit runtime to the dispatcher
  loop) is **PASS (2026-08-08)**.
- Gate S2 (first frame, Metal): **S2.0 PASS (2026-08-09)** — the shell now
  presents its log surface through a real Metal (CAMetalLayer) pipeline on
  the iPad Pro 11-inch (M4) Simulator. Declared sub-gate: not yet a frame
  from game systems.
- S2.1 is a research checkpoint: GAME.CGO compiles completely, and the
  Simulator RX-blob linker advances to object 204 before a deterministic
  ret/jump-to-EE-base fault. An active dirty debugger experiment is present.
- **Gate A1 is now active before further S2 expansion.** The current app's
  CGO RW→RX path is a Simulator research vehicle. It does not prove H2.5's
  selected product path: real generated GOAL code inside signed Mach-O text
  with no runtime-created executable code.
- Committed OpenGOAL work is captured by the canonical
  `patches/h3-jak1-host-boot.patch`, which clean-applies to the pinned commit,
  and by `docs/evidence/`. The active dirty object-204 trace experiment is
  newer and intentionally not yet captured in that patch.
- **Operator constraints (binding):** (1) test apps must never go fullscreen
  — game window must stay Windowed (fixed: `display-settings.json`
  `display_mode: 0`, and source default in `game/settings/settings.h` is now
  Windowed; rebuild `gk` for the source change to take effect, the settings
  file fix is immediate); (2) at most one `gk`/runtime process at a time.

## Environment

- Host: macOS 26.5.2 (arm64, Apple M1). Xcode toolchain, CMake 4.4.0, Ninja.
- Worktree: `out/jak-project/` (gitignored), pinned to
  `641fb572e876750d8618434d9f7c1a531b43b366` (upstream open-goal/jak-project).
- Build dir: `out/jak-project/build/h1/` (configured `-DOTTSEL_NO_EMIT=ON`,
  `-DCMAKE_OSX_ARCHITECTURES=arm64`).
- Legal ISO: `~/ottsel-user/iso/... .iso` (never in git). Extracted to
  `out/jak-project/iso_data/jak1/` (gitignored).
- Disk: ~17 GB free as of this snapshot. Builds are slow (10-20 min per
  compiler/runtime rebuild); plan around it.

## Gate board

| Gate | Status | Evidence |
|---|---|---|
| H1 ARM64 goalc codegen | **PASS** | `docs/evidence/H1/` (run-h1-proof.log: 5 cases) |
| H2 no-emit host runtime | **PASS** | `docs/evidence/H2/` (RX-only exec, bridge, shim) |
| H2.5 packaging decision | **PASS** | `docs/evidence/H2.5/` + `docs/10-code-packaging-and-signing.md` |
| H3 Jak 1 host AOT boot | **PASS (2026-08-08, host)** | `docs/evidence/H3/dispatcher-loop-2026-08-08.md`, `docs/evidence/H3/boot-dispatcher-loop-2026-08-08.log` |
| S1 Simulator shell boot | **PASS (2026-08-08)** | `docs/evidence/S1/` (s13-dispatcher-loop.*, s11-*, s12-*) |
| S2.0 Metal shell spike | **PASS (2026-08-09)** — game frame still pending | `docs/evidence/S2/s20-metal-spike.md` |
| S2.1 GAME.CGO integration | **RESEARCH CHECKPOINT** — compile pass; RX-blob link reaches object 204 | `docs/evidence/S2/s21-*` |
| **A1.0 semantic ARM64 regressions** | **PASS (2026-08-09)** — 14/14 assertions; CGOs still validate; object-204 localized by bounded call trace | `docs/evidence/A1/a1-semantic-regressions.md`, `a1-object204-bounded-trace.md` |
| **A1.1 real GOAL in signed `__TEXT`** | **PASS (2026-08-09)** — real KERNEL.CGO slice executes on the Simulator; codesign verifies | `docs/evidence/A1/a11-signed-text-slice.md` |
| **A1.2 execution-permission proof** | **PASS (2026-08-09)** — AOT path audited clean; slice passes without CGO bundles; codesign/Mach-O evidence | `docs/evidence/A1/a12-execution-permission-proof.md` |
| **A1 signed-native execution** | **PASS (2026-08-09)** — real OpenGOAL artifact executes from signed Mach-O text, no runtime-created executable code | `docs/evidence/A1/*` |
| **S2.1 GAME.CGO engine integration** | **ACTIVE (2026-08-10/11)** — AND encoder fixed regression-first; all 346 GAME objects link; the kernel dispatcher loops on the Simulator with GAME.CGO loaded; no-emit main segments live in a dedicated region above the global heap (`klink.cpp`, OTTSEL_CODE_BASE 0x3ebc000); the code/heap-overlap root cause is DISPROVEN. **Camera stack corruption ROOT CAUSE FIXED**: the ARM64 call shim pushes two 16-byte slots (incoming x30 + synthetic post-blr continuation); `thread-suspend` read the continuation with an advancing `.pop`, and the resume's post-blr then popped both slots — a net +0x10/dispatch sp climb (the WRITER-SP measured 0x1d7fd0 -> 0x202000 over 10755 iterations) that drove the camera thread's stack into the *debug-dead-pool* region and corrupted process type tags (dispatcher called the code word `0x8b36e010` -> SIGILL).  Fix: new `.load` asm form (`IR_AsmLoadSp` = `ldr reg, [sp]`, no post-index on ARM64) + `thread-suspend` uses it; A1.0 test 26 asserts 0xf94003e0 / rejects 0xf84107e0; full suite PASS; emitted kernel starts `ldr x0, [sp]`.  Boot verified: camera sp constant at 0x1d7fc0, zero REGION-CHANGE, 213k+ subtitle-load iterations with no dispatcher fault.  S2.1 remains ACTIVE: the boot spins on `load-subtitle-text-info` (no ISO data, expected ROM-safe boundary); no renderer-ready boundary or Jak frame yet. | `docs/evidence/S2/s21-andfix-progress.md`, `s21-fix-spstable-runtime.log`, `s21-tracer-writersp2-*`, `docs/reports/2026-08-10-bot8-handoff.md` |
| S2.2 First game frame | blocked on S2.1 | — |
| S3 Touch MVP + lifecycle | blocked on S2 | — |
| R1 Handoff package | blocked on S3 | — |

## What works (verified)

1. ARM64 `goalc` compiles the full Jak 1 GOAL kernel: `gcommon`, `gkernel-h`,
   `gkernel`, `pskernel`, `gstring-h`, `gstring`, `dgo-h`, `gstate` →
   `out/jak1/obj/*.o` and `out/jak1/iso/KERNEL.CGO` (new object format with
   per-segment `code_size` in the header, ~404 KB).
2. ISO extraction: `extractor` tool extracts the legal ISO into
   `iso_data/jak1/` (CGO/DGO/MUS/STR, SCUS-97124).
3. `gk` (game runtime) builds for arm64 with `OTTSEL_NO_EMIT` and boots:
   - EE memory mapped RW-only (W^X respected, no RWX).
   - Missing `fr3` level data tolerated (empty common level) so boot proceeds.
   - IOP/OVERLORD emulation starts; `KERNEL.CGO` loads via the real linker.
   - `gcommon` links with data-only relocations.
   - Code pages flip to RX after link (16KB page size on Apple Silicon);
     main-segment code pages stay RX permanently, static/data pages stay RW
     (real code/data page split), top-level pages flip RX only for the
     duration of each top-level call (transient), then back RW.
   - `call_goal_on_stack` enters the ARM64 GOAL top-level with correct
     `st`/`offset` and a 16-byte-aligned goal stack.
4. ARM64 C-export stubs (in `make_function_from_c`) emit valid ARM64 bytes
   (previously wrote x86 bytes on aarch64).
5. `_arg_call_arm64` and `_call_goal_on_stack_asm_arm64` fixed (target read,
   stack restore, alignment).
6. Cross-segment function addresses now encode as `ADRP+ADD` (patched by the
   runtime linker), fixing the previous `adr` ±1MB range failure.
7. ARM64 encoder fixes this session: `cmp_gpr64_gpr64` (was dropping the
   first operand; countdown loops spun forever) and
   `load32u_gpr64_gpr64_plus_gpr64` (missing option bits; emitted invalid
   `0xb8760801` instead of `ldr w1,[x16,x22,sxtx]` = `0xb876ea01`).
8. `InitListener` in no-emit mode interns the C/GOAL shared symbols
   (`kernel_dispatcher`, `ListenerFunction`, etc.) so the dispatch loop can
   find the kernel dispatcher.

Evidence log: `docs/evidence/H3/boot-dispatcher-loop-2026-08-08.log` shows the
full arc to the dispatcher loop:

    Got correct kernel version 2.0, loaded in 13 ms
    kernel: machine started
    OTTSEL no-emit: stub arena B flipped RX (8568 bytes used)
    ... dispatcher loop runs for minutes, zero faults ...
    GOAL Runtime Shutdown (code 2)   # graceful window-close EXIT, not a crash

Per-iteration dispatch lines (`call_goal_on_stack: fptr=0x70001a5384 ...
returned 1375532`) go to stderr (PTY), verified in both runs.

## Next steps (S1 and beyond — see `docs/BOT4_HANDOFF.md`)

- H3 is proven. Before starting S1, the next agent should do one clean
  verification run capturing stderr too (`2>&1`) so the durable log includes
  the dispatcher-loop lines, and rebuild `gk` so the Windowed source default
  is in the binary.
- **S1 is PASS (2026-08-08)** — the shell boots the no-emit runtime to the
  GOAL kernel dispatcher loop on the iPad Pro 11-inch (M4) Simulator
  (`docs/evidence/S1/s13-dispatcher-loop.md`; 48,200+ iterations, zero
  faults). The key fix: the kernel dispatcher's first call is the C export
  `pc-prof`, which an OTTSEL_IOS guard had left unregistered (value 0 ->
  jump to EE 0); registering the PC-port exports + a full-table fallback
  scan in `find_symbol_from_c` (order-dependent intern could create
  duplicate symbol entries) resolved it.
- **Gate S2 (first frame, Metal) is next** — see `docs/BOT5_HANDOFF.md`.

## S2 status (2026-08-09)

- **S2.0 PASS** — Metal spike: `src/shell/metal_shell.{h,mm}` render the
  shell's log surface through a CAMetalLayer pipeline (device, command
  queue, fullscreen textured triangle, per-frame texture upload, present).
  `src/shell/main.cpp` sizes the CPU surface to the drawable each frame
  (the simulator's windowed presentation keeps a 480x320 drawable; the
  surface adapts on resize/rotation) and presents via Metal; SDL software
  surface remains as fallback. Evidence + pixel verification
  (title 1746/1746, GPU line 1566/1566 vs the font table):
  `docs/evidence/S2/s20-metal-spike.md`.
- **S1 log-font bug found and fixed:** `font5x7.h` rows are 7 bits wide
  (bit 6 = rightmost) but the draw loop used `kFontW = 5`, clipping every
  glyph's right edge in all S1/S2 screenshots. Fixed `kFontW` to 7.
- **S2.1 progress (2026-08-09):** GAME.CGO — the full Jak 1 game engine,
  346 objects / 22 MB — **compiles for ARM64** and all 3,801,088 emitted
  code words validate (decode + round-trip + assembler fallback; zero
  invalid). Evidence: `docs/evidence/S2/s21-game-cgo-arm64.md` +
  `s21-game-cgo-build.log`. The remaining 15-IR NYI list is now closed for
  compile: the engine exercised and we implemented BlendVF/SplatVF/
  SwizzleVF/SqrtVF, VPSHUFLW/VPSHUFHW, and fixed the vector-shift
  encodings, static vector loads, IR_RegValAddr stack addressing, and a
  STR Q opcode-width bug that corrupted 2-vector prologue stores. The
  renderer seam (`GfxRendererModule`) read-ahead is recorded there; the
  first real drawable is the background path via the game's renderer
  process -> sceGraphicsInterface -> Gfx.
- **S2.1/S2.2 next:** link + boot GAME.CGO on the Simulator (the no-emit
  linker must link the game objects and run their top-levels; the game
  process tree then starts), then implement the minimal Metal
  GfxRendererModule (make_display / texture_upload_now / send_chain) for
  the first real frame.
- **S2.1 runtime linking (2026-08-09):** the shell bundles GAME.CGO and
  links it on the Simulator after the kernel. 36 of 346 objects link; the
  first runtime fault is a symbol-value call in `pad`'s top-level
  (`lr=pad main+0x294`) that resolves to `st+0x20c0` (inside the GOAL heap,
  not code) — the game's first exercised symbol-value resolution. Fixed en
  route: cross-segment LDR-literal overflow (static loads now ADRP-based;
  GAME.CGO revalidates 3,825,664 words). The gated handler logs
  pc/lr/st/offset/faulting-words for the next fault. Evidence:
  `docs/evidence/S2/s21-game-cgo-simboot.md` + `s21-simboot.log`.
  Next: identify the symbol at `st+0x20c0` and fix the value-field
  resolution (mirroring the S1 canonical-intern fix), then continue linking
  the remaining 310 objects.
- Reproduce S2.0:

      ./scripts/build-ios.sh
      xcrun simctl boot <iPad Pro 11-inch (M4) UDID>
      xcrun simctl install <udid> out/jak-project/out/ios/app/OttselShell.app
      xcrun simctl launch <udid> com.ottsel.shell
      xcrun simctl io <udid> screenshot docs/evidence/S2/s20-metal-frame.png

  Expected: `ottsel S2.0: Metal surface active (CAMetalLayer)` on the
  console; the window shows the log surface rendered through Metal
  (title `ottsel S2.0 - Metal`); the runtime boots to the GOAL kernel
  dispatcher loop (`s20-runtime.log`).

## Known non-goals / boundaries

- Physical device proof is not claimed from Simulator/host evidence.
- No game assets in git; ISO stays at `~/ottsel-user/iso/`.
- The old 15-IR compile blocker is closed: GAME.CGO compiles completely.
  Semantic correctness remains open; legal-but-wrong ARM64 instructions and
  ABI behavior now require focused regression tests under A1.0.
- The `make` system and `gk` were modified directly in the worktree; all
  changes are captured in `patches/h3-jak1-host-boot.patch` (and the earlier
  H1/H2 patches are supersets; apply the newest one).

## Repo layout (current)

- `docs/` — plans/status/audits (00–15) and gate evidence
- `patches/` — h1/h2/h3 patches; `h3-jak1-host-boot.patch` is canonical
- `ref/` — research corpus (unchanged from Phase 1)
- `out/` — gitignored build tree + worktree
- `src/`, `scripts/` — iOS shell/Metal sources and build/validation tools

## How to reproduce the boot

    cd out/jak-project
    # (worktree already has all patches applied)
    cmake -S . -B build/h1 -G Ninja \
      -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 \
      -DCMAKE_APPLE_SILICON_PROCESSOR=arm64 \
      -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
      -DSTATICALLY_LINK=OFF -DINSTALL_GTEST=OFF -DOTTSEL_NO_EMIT=ON
    ninja -C build/h1 gk goalc extractor
    ./build/h1/goalc/goalc --isa arm64 -c \
      '(load-project "goal_src/jak1/game.gp") (make "GROUP:kernel")'
    ./build/h1/game/gk -fakeiso -boot -v

Expected today (with the load32u/cmp fixes): boots to the GOAL kernel
dispatcher loop —

    Got correct kernel version 2.0, loaded in 13 ms
    kernel: machine started
    OTTSEL call_goal_on_stack: fptr=0x70001a5384 ... returned 1375532   (loops)

Use `-- -nosound` (host coreaudiod is wedged). Keep the window Windowed
(no fullscreen) and one `gk` at a time. Under lldb, `process launch --
-fakeiso -boot -v -- -nosound` and interrupt after `kernel: machine started`
to snapshot the EE thread PC inside the RX kernel code.

## Session history (short)

- H1: ARM64 RegisterInfo + function codegen + core IRs; fixed encoder bugs.
- H2: RX-only AOT execution, call_goal bridge, static shim, no-emit flag,
  emit-site checklist.
- H2.5: packaging decision (generated-native, Option 2/3) with Mach-O proof.
- H3: kernel compiles ARM64, ISO extracted, `gk` boots with no-emit runtime,
  reaches GOAL top-level entry; cross-segment ADR fixed to ADRP+ADD; encoder
  fixes (cmp, load32u); **GOAL kernel dispatcher executes and loops** —
  H3 PASS (2026-08-08, host).

## 2026-08-09 late — S2.1: linking 55 -> 204; mood-tables fault (checkpoint)

- **GAME.CGO on-device linking advanced 55 -> 204 of 346 objects** with six
  verified fixes: (1) ARM64 stack-variable addressing (IR_GetStackAddr used
  ORR where register 31 = xzr, so `mov xd, sp` became xd = 0); (2) mips2c
  ARM64 no-emit dispatch + jak1 table + pre-registration + jalr shim;
  (3) iOS SIF RPC stubs + get-irx-version emulation; (4) `_stack_call_arm64`
  arg-pair order (format); (5) LDRH imm12 scaling in 16-bit static-field
  loads; (6) reusable 512KB CGO stage slot (was staging the whole 22MB from
  the global heap).
- GAME.CGO revalidates 3,829,760 code words PASS; the app reproduces the same
  fault deterministically.
- **Current blocker:** object 204 (mood-tables) top-level -> `make-village1-light-kit`
  call chain: `signal 10 at pc=0x7000000000` (jump/return to the EE base =
  x22).  All symbol/slot values in the chain verified valid; the deep
  ret-to-x22 site needs a live call tracer or a debugger that can breakpoint
  RX-flipped GOAL pages (lldb cannot).  Gated handler now prints pc/regs and a
  GOAL-stack LR walk via raw stderr.
- **Audit sequencing correction:** preserve the current dirty ret-to-x22 probe
  and its result, but do not continue broad GAME.CGO/renderer work from this
  checkpoint. Execute A1.0 semantic regressions and A1.1/A1.2 signed-native
  integration first. After A1 passes, return here, identify the ret-to-x22,
  and continue objects 205-346.

## Product-path boundary (2026-08-09 audit)

- `scripts/build-ios.sh` currently bundles KERNEL.CGO and GAME.CGO; the linker
  copies and patches their code in the EE mapping and flips code pages RX. This
  is **Simulator research infrastructure only**.
- H2.5 selected generated native code compiled by clang into the signed app.
  A1 must demonstrate that with a real OpenGOAL artifact in Mach-O `__TEXT`,
  offline instruction relocations, and no runtime `mprotect(PROT_EXEC)` GOAL
  path before the project invests further in the renderer or touch UI.
- The encoding validator proves A64 legality, not semantics. Recent legal but
  incorrect instructions make focused semantic regression tests mandatory.
- Current continuation prompt: `docs/BOT6_PROMPT.md`.

## 2026-08-09 — realignment to Gate A1 (signed-native execution)

The active gate is now **A1** per docs/15-progress-audit.md and BOT6_PROMPT.md:
prove real OpenGOAL code executes from signed Mach-O __TEXT on the iPad
Simulator before any further renderer/touch work. The RX-blob RW->RX loader is
Simulator-only diagnostic infrastructure (oracle), not the product execution
model.

- **R0 done:** the object-204 call-trace probe experiment was captured
  (`docs/evidence/A1/r0-call-trace-probe-{shell,goalc}.patch`: goalc
  IR_FunctionCall recorder shim, kscheme ring buffer, handler dumps), then
  stripped from product sources. The shell gated handler retains the
  stderr-based pc/regs/GOAL-stack-LR-walk diagnostics. Scratch .o/.s probes
  removed. The app builds clean.
- **A1.0 next:** extend the smallest H1/H2 harness with semantic regression
  tests for the known legal-but-wrong defect classes (SP->xzr, load-as-store,
  wrong widths, scaled offsets, ABI arg-pair swap, LR/call/return), and reduce
  the object-204 value-0 call/return fault below the full boot loop.

## 2026-08-09 late — A1.0 PASS: semantic regressions + object-204 localized

- **A1.0 semantic regression layer PASS.** Harness
  `out/jak-project/tools/ottsel_a1/semantic_regressions.cpp` (target
  `ottsel-a1-sem`): 14/14 assertions — emitter-unit (static_load_f32 is
  LDR-s not STR-Q; load16u +s8 is unscaled LDURH; store16 STURH;
  `_stack_call_arm64` pushes (x6,x7)(x4,x5)(x2,x3)(x0,x1)) and goal-compile
  (SP->xzr fixed via ADD; u16 LDURH; non-leaf x30 save/restore; 2-level
  nesting).  Negative proofs captured (STR-Q/LDRH reintroduction fails 4;
  asm pair swap fails the source-scan check).
- **Object-204 localized below the boot loop.**  Temporary goalc
  IR_FunctionCall recorder shim + 256-entry ring + gated-handler dump
  (preserved as `docs/evidence/A1/a1-bounded-call-trace-probe.patch`,
  stripped from product sources).  One boot reproduces the fault
  deterministically: trace-count 30,422; chain mood-tables top-level ->
  0x23d8554 -> 0x23d8004 -> 0x5ab0e4 -> 0x5fc574/0x5fd9d4 -> 0x5a9234
  (called 3x from site 0x23d8408 loop) -> `signal 10 at pc=0x7000000000`
  (x8 = lr = 0x7000000000 = x22).  The 0x5a9234 target is real SIMD matrix
  code, so the corruption is call/return state around it (S2.1 will
  root-cause after A1).  Key probe fixes: save x8-x15 across the recorder
  (C-call clobbers; a first version destroyed the fn pointer in x8), and add
  the EE-base offset before the symbol value read.
- **Encoding validation:** product CGOs rebuilt clean — KERNEL.CGO 86,016
  and GAME.CGO 3,829,760 code words PASS.
- **Next: A1.1** — real KERNEL.CGO dispatcher slice in signed Mach-O
  `__TEXT` via the proven H2.5 `.word`->clang route.
