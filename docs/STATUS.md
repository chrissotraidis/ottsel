# STATUS — Ottsel

## Continuation board — 2026-09-21
Authority: `RECOVERY_GOAL_LOOP.md` (September 21 update); evidence `docs/evidence/A1/a11-signed-game-dispatch-fault-2026-09-21.md`.
Stage 0 is green again for this source: the nested streamed `link-begin` signed hook is now `patches/a11-streamed-link-begin.patch`, so `verify-link-begin-patch.py` reconstructs all three files byte-for-byte (`klink.cpp` sha256 3eb8cd27); encoder-guard and link-begin-args checks PASS.
Host signed-GAME activation is green on this source: `test-a11-gstate-loader.py --module-list config/signed-game-full-control.json` ran 313/313 modules ENTER/RETURN including `time-of-day` and `default-menu`, immutable text, data RW, code RX; the 09-15 host `time-of-day` SIGBUS does not reproduce, so emission/activation is not the blocker.
The `pp=0` crash replays in every strict run (strict shell-only build `signed-game-cgo-tit-vi1`, banks 1, OttselShell 22723728 B) and the fault text goes to the app's `ottosel-fault.log`, not `ottosel-runtime.log`; renderer threads keep logging frames after the gated handler stops the faulting thread, so a growing runtime log is not liveness.
Named reading (2026-09-21): `pc=x30=0x181674` is the `village-cam` Symbol object address (its value is Type `0x34d0bf4`; `village-cam` is a `deftype` of the signed `villagep-obs`), `x20(pp)=0`, `x21`=s7 (the symbol-table base), `__PAGEZERO` covers `0..0x100000000` so no base was added, and the value sits at CPU-stack +0 and +0x50 (an argument slot).
Frame-level reading: the fault is a `.ret`-style `ldr x30, [sp]` whose slot held a frame local - `[sp]` = the `village-cam` Symbol address, `[sp+8]` = 0x1bfe04, `[sp+0x10]` = low32(sp+0x60), `[sp+0x38]` = its Type object base 0x34d0bf0; module-resolved stack words are `path+0xac8` (sp+0x20) and `villagep-obs+0x9d24` (sp+0x98, whose `+0x9d20` is the function Type tag, i.e. a method value). GOAL frames store their caller sp as the low 32 bits of the host address.
Working baseline: `OTTSEL_SIGNED_MODULE_LIST=config/signed-kernel-full.json` (banks 1) does **not** fault - `LINKBEGIN: name=oracle` twice, 68 `DGO RPC: continue` objects, two `GAMEPLAY` markers and live level activity (`OTTSEL STR: loaded LOLOOP.STR`). GAME/streamed code runs clean whenever it is legacy-linked, so the defect is in the signed path's execution of GAME modules.
Executable frame chain (dladdr + VM-protection filter): `signed_gstate::link` -> `call_goal_on_stack_asm_arm64` -> `villagep_obs_s1_code` -> `gkernel_s0_code` -> `jak1::method_set` -> `villagep_obs_s1_code` -> `arg_call_arm64` -> `gkernel_s0_code` -> `intern_type_from_c` -> `alloc_heap_object`: the fault is inside the signed loader's activation of `villagep-obs`, in the GOAL code that defines the `village-cam` type and installs its methods, with a Symbol address where a Type object belongs.
Fix landed and inert for now: `.ret` fails safe (`IR_AsmRet::do_codegen_arm64` selects `[sp]` vs the incoming x30 by the port address split; `scripts/test-a11-asm-ret-guard.sh` PASSes; `patches/a11-asm-ret-fail-safe.patch` reproduces IR.cpp, sha256 a949d3b5). It cannot reach the app yet: the emitter `--module` path rewrites prebuilt `out/jak1/obj/*.o` from an earlier goalc, so emitter-level codegen needs the affected GOAL objects regenerated.
Measured blocker: the stream stops at `obj 1/55` with no `LINKBEGIN: name=oracle` and `drawn=0` on every frame.
Landed diagnostics in `src/shell/ios_boot.cpp`: address-region classifier, symbol-slot scan without the legacy window filter, exact-value slot attribution, signed-module text attribution, and an enter-state claim gated on legacy-code lr.
Refuted: the emitter dropped no type record (`villagep-obs.o` has kind-1 symbol records with initial word 0 for those five references, and both loaders write `sym - s7`); the consumer at `villagep-obs.s` seg2 `0xd64` does dereference the slot (`adrp/add` slot, `ldrsw` displacement, `add` st, `ldr w` value); and the C->GOAL bridge fix does not change this fault.
Measured 2026-09-22 (app): export banks refuted (banks=0 faults identically), loader writes correct (`sym - s7` with the Symbol undefined until its top-level runs), both emitted consumer sites dereference, and a bounded `method_set` log for symbol-table-window type arguments produced no hits - four independent refutations.
Mechanism changed: the documented GOAL regeneration (`goalc --isa arm64 -c '(load-project "goal_src/jak1/game.gp") (mi)'`, 546 targets in 8.2 s) put the `.ret` guard into `gkernel`/`gstate` (villagep-obs.o byte-identical, sha256 c271c70f), and the strict run no longer faults at 0x181674 - it now faults in `gkernel` text at GOAL 0x801d554 (nearest symbol `execute-process-tree`, `lr` = gkernel+0x55b0) on a data access to 0x172f28000, stopping earlier (14 continues, no `GAMEPLAY`). The guard thus converts a branch into GOAL data into a return with a corrupt process state, confirming the `.ret` synthetic slot as the mechanism and putting the origin upstream.
Instrument: the bounded GOAL call trace is env-gated at GOAL compile time (`OTTSEL_TRACE_GOAL_CALLS=1`), so the a11 slice stays clean; two traced strict runs recorded 58927 calls each and the fault handler dumps the last 40 (site/target/caller-lr/pp) entries. Two readings were corrected 2026-09-22: `site` is the recorder's own host address (GOAL site = `site_low32 - ee_base_low32`, so `0x09abe774` is `main+0x12774`), `target` is the GOAL callee, and the fourth field is `x20` - the port's GOAL process register (`get_process_reg()`), not a pp copy - which is 0 at all 128 recorded calls (the earlier "sane pp" claim was wrong).
Ring audited end to end (ring-audit v2 in `src/shell/ios_boot.cpp`, gated on `idx > 0`; evidence `docs/evidence/A1/a11-goal-ring-audit-2026-09-22.md`): all 128 entries classify `target[mod-fn=90, bank-fn=38, BAD=0] caller[host=111, zero=17, BAD=0]`, where the 38 are export-bank trampolines from `0x8fe4004` (the earlier `fn=NO` hits were that instrument gap, not a defect) and every other target is a `signed_gstate` function entry; caller LRs are module host text or exactly 0. Neither hunted class exists, and the last entry `main+0x12774 -> font+0x4` (the streamed module's DGO-completion activation) is a registered entry, so the `main -> gkernel+0x43f4`-class corruption lead is retired.
Current strict app (guard on, `.ret` keep-mask fix, no trace) faults where this ring ends - `font` seg0 `+0x6864`, `str w5,[x16]` with `x16 = arena + 4` - so the ring's last call is the DGO-completion activation preceding the fault, not a trace artifact. Next (one variable): take the corrupted-object question to `font+0x6864` (a null game-data pointer: `ldr w0,[x2+0xbd0]` with a heap `x2` whose field is 0) and close the streamed signed lane (`locate_member` scan scope plus the value-0 intern) so level code stops splitting between arena and heap.
Renderer lane unchanged and still queued behind that: per-batch ALPHA0x48 additive clouds, then dynamic eyes.
Disk at this board: `/` Avail 51 GiB, zero `.git/objects/pack/tmp_pack_*`

2026-09-22 (A1.4, RING DECODER): the bounded GOAL call trace is now decodable. Three anchors were
missing and are all measured: the run's arena base (nm on the built shell + the log), the process
ASLR slide (recovered from the fault log's own host-frame lines, every frame agreeing), and per-module
signed-text ranges (nm s0/s2 + the emitted .json spans, which cross-check each other). Entry validity
uses the runtime's own predicate - the word before a target must be the function type 0x1bfec4 - and
the 279 signed export-bank stubs count as entries at bank+64k+4. Tool: scripts/a11-goal-ring-audit.py.

2026-09-22 (A1.4, RING AUDITED - BOTH LEADS REFUTED): traced guard-on strict run (installed shell
sha256 206662cf, arena 0x104f80000, slide 0x4588000, 58927 calls, emission modules.vLhp7r, guard word
lsr x17,x17,#32 present 34 times, i.e. the inert pre-fix form). 40/40 ring targets are real entries
- 28 module functions (gkernel, main, math, text, gstring, progress, hint-control, depth-cue, font)
and 12 calls into
export-bank stubs 61/163/277 - and 22/22 non-zero caller-LRs are inside signed module text, so
"target that is not a module entry" and "EE-valued caller LR" are both refuted for this ring. The 17
caller-lr=0 entries are calls from frames entered through the export-stub synthetic-return path, where
X30 is not a return address by design: uninformative, not corruption. The A1.3 board's quoted
main+0x14e50 -> gkernel+0x43f4 belongs to a different (guard-off) emission; against that build's own
tables its target is the tag at 0x43f0, a real entry.

2026-09-22 (A1.4, CRASH MOVED PAST DGO COMPLETION): the same run entered 337/348 modules - all but
village_obs, fishermans_boat, village1_part, village1_part2 and sequence_a_village1 - so this
configuration now runs past the DGO-completion class the A1.3 board stopped at, and faults later in
font seg0 +0x6864 - see the A1.5 lines below: that store is draw-string's last one and what is null
is the DMA buffer the font path was called with, not a Symbol address.
Evidence: docs/evidence/A1/a11-goal-ring-audit-2026-09-22.md
Next: run the auditor first on every traced run, then take the corrupted-object question to
font+0x6864 rather than to the call ring. Product state (guard on, no trace) unchanged; a sibling task
owned the trace build, so nothing was rebuilt here - the audit used its artifacts read-only plus a
snapshot of the installed shell. Disk at this board: / Avail 69 GiB, zero .git/objects/pack/tmp_pack_*.

2026-09-22 (A1.5, CRASH SITE IDENTIFIED): the ring's last call main+0x12774 -> font+0x4 is a call
into draw-string. The font module's five immutable tags map one-to-one by construction onto
font.gc's five top-level forms in order (0x4 draw-string, spanning 0x4..0x68c0 from ~875 source
lines; 0x68c4 draw-string-adv; 0x6a34 get-string-length; 0x7434 draw-string-xy; 0x7734
draw-string-xy-scaled). The fault pc font+0x6864 is draw-string's last store before its own
epilogue: add x16,x2,x22; add x16,x16,#0xbd0; ldr w0,[x16]; add x16,x0,x22; add x16,x16,#4;
str w5,[x16] - a 4-byte store through a NULL pointer, so the address is EE 4, the protected first
page of the EE mapping.

2026-09-22 (A1.5, NULL BUFFER, NOT A TARGET): that store implements the function's final source
statement, (set! (-> (the-as (pointer pointer) v1-6) 1) dma-out) with v1-6 = (-> fw buf), and
draw-string writes fw.buf from its own context argument at font.gc:791 - so the null is the font
path's DMA buffer, not a module entry and not the A1.2/A1.3 Symbol-address class. The caller is the
main module's largest function, entry main+0xb2c4 (0xb2c4..0x14f40); main has 14 tags against 13
top-level forms in engine/game/main.gc, so the entry is pinned and the name is not.

2026-09-22 (A1.5, CHAIN AND CAVEAT): the ring tail (entries 17-39) is the text/HUD chain
main -> drawable/progress/hint-control/text/gstring/depth-cue -> font, and the same frame shows
x20(pp)=0 with x19/x23/x24/x25/x28=0. The trace probe is compiled into this build, so an identical
failure in the no-trace product state is NOT claimed - that re-run is the next measurement.
Evidence: docs/evidence/A1/a11-font-null-dma-buffer-2026-09-22.md

2026-09-22 (A1.5, CALLER SIDE DECODED): the call into draw-string is well formed - at main+0x127ec
main pushes its own x30, sets the continuation with adr x17, main+0x12800 (exactly the lr in the
fault log) and blr's the callee - and the buffer argument is set four instructions earlier by
mov x1, x25. x25 is written only twice in that function, both mov x25, x0, the later at main+0x70a4
through the chain ldrsw x0,[x19+0x22c]; lsl x0,#5; add x0,x19+0x234; ldur w0,[x0+0x10];
ldur w0,[x0+0x24]. So the null is a value main read out of that object graph, and the open question
is which object that chain walks - not the call ring, which A1.4 cleared.

2026-09-22 (A1.5, SCOPE): this run is the inert-.ret build, and the font null survives the .ret mask
fix the sibling gate landed (its A1.6/A1.7 record the same store after that fix), so the two defects
are independent. The board's G1.7 premise is narrowed to the caller's field chain.
Evidence: docs/evidence/A1/a11-font-null-dma-buffer-2026-09-22.md

## Completion-plan board — 2026-09-14
Authority: `RECOVERY_GOAL_LOOP.md`; end-to-end implementation guide: `PROJECT_COMPLETION_PLAN.md`.
Documentation review only: original PRD, BOT history and recovery evidence audited by root plus three read-only subagents; no fresh runtime/test acceptance claimed.
Product execution STOPPED: `/` available 10 GiB, common `.git/objects/pack` temporary packs 0; current AGENTS.md requires 40 GB. No cleanup, build or Simulator launch.
Next after preflight clears: current crash/reconstruction checks, authenticated GAME/streamed signed-code extension; preserve eight-module KERNEL proof.
Renderer next: per-batch ALPHA0x48 additive clouds, then dynamic eyes; normal-route script ends before intro/Training verification.
I0/I1, whole-game strict AOT, I2/I3, P1, asset-free reconstruction/import and D1 remain OPEN; follow the plan through progression coverage and real devices.
Stage 1B (A1, 2026-09-14): whole-corpus signed-module census reproduced read-only via `scripts/a11-corpus-census.py` (pure-Python port of `a11_module_emitter.h`). 28 containers, 1506 members = 872 code + 634 art; emitter accepts 381/872. KERNEL.CGO 8/8 and matches `config/signed-kernel-full.json` order; GAME.CGO 183/346, ENGINE.CGO 178/306, all 24 region DGOs 12 OK. Evidence: `docs/evidence/A1/a11-whole-corpus-census-2026-09-14.md` (+ .log).
Stage 1B (A1, 2026-09-14): the 491 rejections have exactly four causes — 315 hardcoded type/method whitelist, 96 distance32 ADRP+LDR Q (`add=0x3dc00000`), 76 data-only main segment, 4 pointer target outside static data. No other error string occurs.
Stage 1B (A1, 2026-09-14): corpus-wide ADRP consumers are only `0x91000000` x232665 (accepted), `0xbd400000` x46435 (accepted), `0x3dc00000` x2014 (LDR Q), so one validated 16-byte SIMD-LDR-Q consumer class plus a widened data-side `(name, methods)` type guard covers the known gap. All four restrictions are now implemented and host-verified (872/872 residual 0); no GAME list is emitted, linked or activated and no product build ran. Disk gate (10 GiB free, 0 tmp packs) still stops product work.
Stage 1B (A1, 2026-09-14): `--identity` measures the container member **name** as a bijection to the loose object, not a payload/type scheme — 872 code entries reduce to 518 distinct names, 512 bodies and 518 `.o` files with chosen stem == member name for every one; 325 names repeat across containers with byte-identical bodies, no name collides after the `-`/`_` label fold and no container repeats a code name, so the name is a valid aggregate/profile key (the aggregate's duplicate-module guard otherwise fires 354 times, so name-keyed dedup is required); body SHA, not the name, is the ambiguous key (seven declaration-only names share one body); the art half is enforced too (0 of 634 art members match >1 `.go`, so the tiebreak is code-only, 472 taking a `<name>-ag` actorbank). `scripts/signed-module-build-profile.py` still hardcodes KERNEL.CGO and the `full`/three-module list; its KERNEL guard already passes `preflight` for both canonical lists and all eight KERNEL.CGO members are byte-equal to their loose objects, so the GAME widening (allow-list, count 8, canonical order, owning container, arena name, placement) is a scope change, not a bug fix. Not compiled; disk gate holds.
Stage 1B (A1, 2026-09-14): the narrow kind-5 pointer path is the last link-entry gap — `python3 scripts/a11-corpus-census.py --links` counts 295 members / 41380 kind-5 records, 1255 of them data->code pointers (patch in static data, target below `text`, tagged `&7==4`) in six objects; after the type table + LDR Q exactly 11 members still fail only there.
Stage 1B (A1, 2026-09-14): `--types` counts all 872 code members carrying kind-2 records, 66154 records over 117 distinct `(name, methods)` pairs, 356 needing the guard relaxed; every one of the 17217 records patching inside signed text (518 members) is `function`/9, so the type generalization is a widened data-side `(name, methods)` guard resolved at load by genuine `intern_type_from_c` (klink.cpp:200), not an invented tag table; 32 pairs differ from 9 (`babak` 76). The name is a primary key for its count (117 names / 117 pairs, none duplicated, none at 0/1), so the `size_of_type(existing) < size_of_type(requested)` assert (`kscheme.cpp:1176`) is unreachable at any link order and `--types` now fails closed on it. Not compiled; disk gate holds.
Stage 1B (A1, 2026-09-14): each of the four restrictions is enforced in three product-path places — `tools/ottsel_a1_1/a11_module_emitter.h` (data-only :98-99, kind-2 :139-140, distance32 LDR Q :178, kind-5 :209-214), `scripts/emit-signed-module-arena.py` (type :100-106, distances :107-115, code target :125-130, arena :156-159; called by `scripts/build-ios.sh:346`), and runtime `game/kernel/common/ottsel_signed_gstate.cpp` (data-only :88-107, type slots :125-130, code pointer :147-152) — so an emitter-only change emits modules that still fail at generation or load; the four bootstrap type names stay pinned at methods 9 (no corpus pair contradicts that), which keeps `test/a11_kernel_pointer_test.py`'s method-count controls valid, while its `pointer-target-in-code` rejection must flip with the kind-5 widening. Spec: `docs/SIGNED_AOT_RECOVERY.md`.
Stage 1B (A1, 2026-09-14): the arena/address budget is not a blocker — `python3 scripts/a11-corpus-census.py --budget` packs all 872 code members' static data into 3615776 B (3.45 MiB; exact aggregate cursor 3615768 B) of the 64456128 B (61.47 MiB) heap-tail budget (32228064 B / 30.74 MiB on the BIG_MEMORY=false floor), and 33767424 B (32.20 MiB) of signed text sits in the 3.88 GiB u32 window above the 128 MiB arena; KERNEL.CGO contributes 11104 B, matching the documented `SIGNED_AOT_RECOVERY.md` figure. Predictor only, nothing compiled; disk gate holds.
Older disk overrides and historical PASS claims below do not supersede this board or current user instructions.

## Recovery board — 2026-09-12
Authority: `docs/RECOVERY_GOAL_LOOP.md`; source/evidence audit: `docs/reports/2026-09-12-recovery-review.md`.
M0 remains the macOS reference; I0/I1 playability, whole-game signed AOT/data-free delivery, I2 audio/lifecycle, and I3 PS2 frontend OPEN; P1 iPhone and D1 devices queued.
Focused crash regressions/reconstruction PASS; restored shader baseline installed and normal route reached Training. Forward movement/release observed; severe scene corruption remains. Ownership/MERC W/TOD, retained terrain, Direct UV/state/depth defaults and exact FR3 texture identity corrected with regressions and fresh normal-route runs. Jump/forward/reverse/release recorded. ARM64 vector preservation fixed, independently reviewed and full build e94bd33e reached Training; multi-level atomic ownership now passes regressions and fresh recorded controls (7 stable snapshots); explicit-empty MERC frames remove stale title logo with fresh controls, while scene/material acceptance remains open. Sprite page-residency plus HUD depth/matrix/color/coverage fixes now show an intact menu frame and all six labels in build1b81b902; Direct presentation retention passes13 regressions plus stable menu/cleared gameplay text in buildcdd37658. Audio pause/open regression plus real Home/resume passed; sound ownership/spatial/bank checks pass and buildb34ad619 loads Training ambient banks with real handles and nonzero PCM. Default-off signed Gstate loader and regenerated valid? pass host tests; active ARM64 objects rebuilt, mode2 build399dea23 proves signed Gstring/Gstate tops plus exact Gstate references and normal Training controls; build02315601 also proves279 signed export banks and Training controls; mode3bf7ac085 adds signed Gcommon entry/return and normal Training controls, fault0. Full eight-module KERNEL host631/combined-bank657 checks now pass; explicit-list app9ea8a4ca now proves all eight signed tops/279 banks, normal Training and recorded controls, fault0; actual app codewords pass. MERC lighting/alpha and Sprite homogeneous corrections pass focused/live checks. Sky75d25504 immutable batch0 renders273906 pixels through real production material; normal composition remains open, blanket sampler failure refuted for that batch. Actual eye_id0/1 require missing dynamic eye textures. Whole-game AOT remains open.
No accepted control proof comes from a camera pan, scene-level, title graphic or image hash. See reviewed images and refuted hypotheses in the audit.
Disk-floor override confirmed by the user; preflight remains mandatory, no cleanup authorization, one Simulator maximum.
All boards/numbered BOT queues below are historical where they conflict with this recovery board; preserve their observations, recheck their conclusions.

## Historical board — 2026-09-11

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

2026-09-11 (BOT44, FIX): the empty numeric prints are root-caused and fixed. The
iOS kernel-subset init in `src/shell/ios_boot.cpp` never called
`kprint_init_globals_common()`, so `ConvertTable` stayed zeroed and `~D`/`~X`/`~B`
wrote NUL bytes while `~A`/`~S`/`~F` worked. The old infinite `loader stall on art
logo-intro-2` is now gone and fields read `abs=8 rel=8`, `transfers=64 glyphs=0`,
`master=progress`. START was stolen by a leftover Mac `game/gk` eating the shared
`/tmp/ottsel-press-*` triggers, and the progress screen does load - only its text
and logo fail to draw. Evidence: `docs/evidence/I1/BOT44-kprint-and-trigger-race.md`.

2026-09-11 (BOT45, CORRECTION): "the Mac gets past the intro, the iPad stalls" is
confounded - the Mac log never pressed Start, the iPad log did. Clean launch, no
input: 15/15 `LOI2.STR` parts, `logo-loop` reached, `loader stall on art`=0.
Start injected at `title-wait-ready`: `loader stall on art logo-intro-2 12`=309
and `logo-loop` never reached, because `activate-progress` takes the two
`external-art-control` buffers the spool holds across `loader.gc:692`.
Evidence: `docs/evidence/I1/BOT45-intro-spool-start-stall.md`.

2026-09-11 (BOT45, CORRECTION): the `OTTSEL SKY TEXEL` probe clamps uv on the CPU,
so it cannot report what the GPU samples; the default sampler is `Repeat`
(`metal_shell.mm:671`), where `uv=(-3.844,-3.688)` is legal. The
`g_direct_texture_metadata`-keyed-by-`dest`-alone sky lead is not confirmed
(`key-present=1 meta-same-dest=1`, `SKY BLEND produced copies=3 misses=0`).
Evidence: `docs/evidence/I1/BOT45-sky-probe-misleading.md`.

2026-09-11 (BOT46, REFUTATION): the progress menu DOES draw text on iPad.
Restoring upstream Start behaviour in `title-obs.gc` and injecting Start at
title-wait gives a screenshot with "PRESS START" on the title prompt and
"OPTIONS" on the menu, with `OTTSEL PROGRESS: normal screen=27 state=27` and a
0-byte fault log. The BOT44 claim "only its text and logo fail to draw" is
refuted. Evidence: `docs/evidence/I1/BOT46-menu-text-renders.md`.

2026-09-11 (BOT46, CORRECTION): BOT45 Gate V2 is withdrawn. The title loader is
busy for the full ~54 s logo intro (15 parts at ~4 s each in both the iPad clean
run and the Mac reference), so gating Start on
`(= (-> *art-control* active-stream) #f)` would drop the press, not fix it.
The "309 stalls vs 0" contrast measured the menu being open.
Evidence: `docs/evidence/I1/BOT46-menu-text-renders.md`.

2026-09-11 (BOT46, OPEN): Gate G1 is now "why do 3 of the 4 `*title*` entries
not draw". Only `OPTIONS` of `NEW GAME / LOAD GAME / OPTIONS / BACK` renders and
there is no menu backdrop. Gate N1 (drive NEW GAME into Village1) follows.
Next: `docs/BOT46_PROMPT.md`.

2026-09-11 (BOT48, ROOT CAUSE): the earlier G1 instrumentation never ran.
`pc/progress-pc.gc` shadows the engine progress path — `draw-options` at :2972 and
`(set! (-> progress-normal post) ...)` at :3453 replace `progress-draw.gc:841` and
`progress.gc:1152`. The BOT46 probes in `engine/ui/progress/` are dead code on this
build; the installed GAME.CGO contains them twice and the log produced 0 lines from
them. Instrument `pc/progress-pc.gc`. Evidence: `docs/evidence/I1/BOT48-g1-pc-progress-path.md`.

2026-09-11 (BOT48, REFUTATION): the title screen is the PC menu `*title-pc*`
(`pc/progress-pc.gc:747`), six entries `NEW GAME/LOAD GAME/OPTIONS/SECRETS/QUIT
GAME/BACK` — not the four-entry `*title*`. All six resolve a string and draw every
frame at `tpi=1000 sa=1000 a=128` with the scroll window fully open. "Only OPTIONS
renders" is refuted; the menu layer submits correctly.

2026-09-11 (BOT48, OPEN, Gate G1): the real defect is glyph legibility. On a static
scene (0.30% of pixels differ between frames) one frame shows "LOAD GAME"+"OPTIONS"
and another "SECRETS"+"QUIT". Every label draws twice, light glyph plus black drop
shadow (`pc/progress-pc.gc:3011`); the light pass drops intermittently, leaving the
shadow or nothing. G1 becomes "why does the light glyph pass drop per frame", in the
sprite/text draw path (`print-game-text`, sprite TEX0/alpha), not in menu logic.

2026-09-11 (BOT48, PARTIAL, Gate N1): `NEW GAME` + Cross advances the route to the
save-game-title screen (`str="CONTINUE WITHOUT SAVING"`), fault log 0 bytes,
`scene-level='village1' merc-submits=4812 eichar=294`. Village1 gameplay with Jak
visible and input-accepted is still unproven.

2026-09-11 (BOT48, CORRECTION): `docs/BOT46_PROMPT.md` Gate N1 is wrong — there is no
`/tmp/ottsel-press-button`. The seams are `src/shell/main.cpp:983-1025`:
`ottsel-press-start`->RETURN, `ottsel-press-cross`->SPACE, `ottsel-press-left`->LEFT,
`ottsel-press-down`->DOWN, `ottsel-bg-village1`, polled every 30 frames and unlinked
after firing. Inject with `: > "$W/ottsel-press-start"`. `simctl install` recreates
the data container, so re-resolve it or every press is silently swallowed.

2026-09-11 (BOT48, BUILD): 546 targets in 34.2s. GAME.CGO
`d5a09f0d59816f90b893b37ea72fc38f6c628b8c3667f9b983924cd507f467df` (identical in
`out/jak1/iso/` and the installed bundle, carrying the live G1 probe), TIT.DGO
`7421fc02714448e47c30995878f03449b5138025a40c4983ebc69a2a385b0588` unchanged.

2026-09-11 (BOT48, DEVIATION): `df -h /` reports Avail 11Gi with 0 `tmp_pack_*`,
below the AGENTS.md 40 GB floor. The operator explicitly authorized working in
whatever space exists, so work continued; any `tmp_pack_*` or a drop below 5 GiB
remains a hard stop. Next: `docs/BOT48_PROMPT.md`.

2026-09-11 (BOT49, REFUTED): the BOT48 handoff blamed the hardcoded count gate in
`append_mobile_sprite_hud_native` for the menu-text fragments. Measured live: every
group logs `orig_pass=1` and counts are only ever 48 or 32, so the gate never fired.
The second proposal (`clearSpriteBatches` inside `setSpriteMeshNow` wiping earlier
groups) also logged zero non-empty clears. See evidence doc BOT49-direct-text-retention-fix.

2026-09-11 (BOT49, FIX, Gate G1 progress): the menu text was erased, not mis-drawn.
`presentRGBA` ended every frame with `clearTransientSpriteBatches`, dropping sprite and
Direct/GIF groups the game thread appended during encode. Retained groups measured
`drawn=1` in 3,681 of 5,433 frames while the HUD submits 3 groups per frame. Now the
store tags each append and `erase_tags()` removes exactly what was encoded. Retained
Direct groups rose to 18-22 per frame and `NEW GAME` renders complete and stable
across consecutive frames (`/tmp/b49/s6_rot.png`). Fault log 0 bytes.

2026-09-11 (BOT49, ROUTE): Start -> Cross drives the PC title menu, but Cross on the
menu reaches the loading screen (`/100`, `9%`) rather than Village1 gameplay. Gate N1
(Jak visible and accepting input) remains unproven; the other five entries do not all
appear in one frame yet.
+
2026-09-11 (BOT50, REFUTED): the BOT49 framing that the game runs at ~1 fps with a
~1.01 s fixed wait per frame is wrong. Measured live, `SUBMITSTAT: chain` advances 90
per ~9-10 s, i.e. ~9.3 chains/s, and the per-frame wait is `gfx_vsync`'s
`__psynch_cvwait` at ~10 ms, not ~1 s. See docs/evidence/I1/BOT50-perf-baseline.md.

2026-09-11 (BOT50, FIX, measured +28%): per-batch `newBufferWithLength:` was pure
Simulator XPC (170 + 142 samples, ~18 ms/chain); sky/Direct now borrow from a recycle
list refilled from the command buffer's completion handler. `cachedMeshTexture:` was
hashing every byte of every tile every frame (249 samples, 10.2%); the key hash is now
head-512 plus a 64-byte stride while the hit path still memcmps the retained bytes.
Live rate rose ~9.3 -> ~12.0 chains/s and the mesh-texture hit rate held at 98.9%.

2026-09-11 (BOT50, FIX, instrument): `++g_vram_decode_evicted` sat outside its
eviction loop, so it counted invalidations rather than evictions and always equalled
`changed` (998), which made the CLUT-window split look decisive. Corrected counters
show ~26.4 decode memos evicted per changed page (evicted 71506 / invalidations 2730).

2026-09-11 (BOT50, FINDING): the decode cache is genuinely ~99.5% hitting
(hits=1566571), so its ~169 misses/chain are real work on distinct textures rather than
a cache defect. The 236-sample `access()` cost is the game's own file probes under
`sp_launch_particles_var`, not the shell's trigger poll.

2026-09-11 (BOT50, STATE): the frame is verified coherent and animated (Village1
fly-through, screenshot sha256 a78fa32e...); the stray rectangles are the frozen touch
overlay. Gate N1 is still unproven — Start -> Cross reaches the PC title menu and Cross
lands on loading `/100` at `9%`. Next: docs/BOT50_PROMPT.md.

2026-09-11 (BOT52, FIX, confirmed): the mobile PC_PORT walker's bucket candidate set
omitted the terrain/TIE buckets carrying `add-pc-tfrag3-data`, so the 400-byte camera
packet was never scanned and `cam-entries` froze at 6994. The predicate now scans
`bucket_id < 70`; `PC_PORT CAMERA: chain=3 bucket=6 n=11` proves capture in tfrag-0.

2026-09-11 (BOT52, STATE): `cam-entries` climbs 604 -> 12941 with zero level rejects and
the frame is live (eight screenshots 1.5 s apart gave eight distinct md5s, ~17 chains/s
in village1), but `eichar` is frozen at 722 while `merc-submits` passes 25,000. Gate N1
unproven. Next: docs/BOT52_PROMPT.md.

2026-09-11 (BOT53, MEASUREMENT): the presented frame is not frozen and not blank. On the
live training scene (`scene-level='training'`) the renderer advances `chain` 8730 -> 9270
in 51 s (~7 chains/s) and the game loop `scePadRead` #34001 -> #35001 in 33 s (~30/s)
while `eichar` climbs past 6285. Consecutive captures are nonetheless frequently
bit-identical because the content is a mostly-static HUD pose. Frame SHA is therefore
not a liveness test; use a per-pixel diff.

2026-09-11 (BOT53, CORRECTION): the earlier "three distinct frame SHAs = live and
animating" reading was wrong. Those SHAs differed only by the status-bar clock.

2026-09-11 (BOT53, FIX/ISOLATION, proven): the intermittent full-screen yellow quad is
emitted by the mobile 2D sprite/HUD path, not by TFRAG/TIE/Sky/depth/camera. A/B on the
existing `ottsel-trace-metal-scene-no-sprite` probe: baseline 4 of 23 captures showed
35.3-35.5% solid yellow spanning the whole drawable; armed, 0 of 30 captures did.
See docs/evidence/I1/i1-hud-sprite-giant-quad-2026-09-11.md.

2026-09-11 (BOT53, FINDING): informative runtime logging stops after ~[10:48] while the
frame loop keeps running (`SUBMITSTAT`/`VU1STAT` last at `chain=8190`, `chain` now
past 9700). Treat stale counters as budget-capped, not as a stopped engine.

2026-09-11 (BOT53, STATE): `ottsel_metal_gfx_game_frame()` is still a stub returning 0,
so the presented image is the Metal TFRAG/TIE/Sprite mesh over the (8,10,18) base. Gate
N1 unproven; no playability claim. Next: docs/BOT54_PROMPT.md.

2026-09-11 (BOT57, Q1 ANSWERED, branch A): the game's own VIF -> VU1 -> GIF path is viable
but unwired. With SIMCTL_CHILD_OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1, per 90-chain period:
vu1-runs 3485/10206/8538, gif-words 433564/496580/190744, last-pc 1694. Early run# lines are
mscal imm=0x0 top=0x0 pc=79 gif_out=0 (empty frag list, spins to the cap by design).
metal_gfx.mm:6711 gates this behind !g_metal || getenv, so vu1-runs=0 was the shell's own
switch; lifting it does NOT change the frame (matched black fraction product 19-42% vs
diagnostic 14-55%). BOT56 Q2 refuted: eichar-attempts 13168, not 4. N1 unproven; next: BOT57_PROMPT.md.
BOT57 Q3 2026-09-11: the presented frame is the Metal pass, not the CPU g_rgba fill. ottsel_metal_gfx_game_frame
is `return 0` (metal_gfx.mm:8754), so main.cpp:1081 always presents g_rgba; the black backdrop is the pass
clear colour (0.03,0.04,0.07) = (8,10,18), measured pixel-for-pixel across the sky region.
Sky submits 40 single-triangle batches, blend=1, a=0.502, real 32/64 textures, geometry covering the drawable.
A/B: -sky-debug-fill (opaque magenta, alpha 1.0) gives 0.00% magenta in the sky region, while the
-sky-debug-all local reference triangle through the same pipeline paints the whole screen.
Depth/blend/winding/descriptor/pool/pass-structure exonerated. Next: one-batch sky-buffer fixture or GPU capture.
Evidence: docs/evidence/I1/BOT57-q3-sky-drawn-but-no-fragments.md

2026-09-11 (BOT58, FIX-PATH): the blocker is the intro stream, not the renderer.
The game loops its logo/title spool forever -- LOLOOP.STR chunks 3/4 reload 587 -> 655 times in
20 s (~3.4/s), with LOI2/LOINTRO/NDINTRO loaded and model='logo-cam-lod0' level='title'. In that
state consecutive frames are byte-identical, eichar=4 eichar-attempts=4 never moves, and injected
input is delivered but inert. Input is exonerated: OTTSEL MOBILE INPUT decodes START (buttons=0x8),
CROSS (0x4000) and four DOWN (0x40) presses -- the Gate I0 route title-wait -> Start -> Cross ->
Down x4 -> Cross reaches the app intact and changes nothing. Driving the game's own (bg 'village1)
unblocks it: eichar 4 -> 35 -> 125 -> 215 -> 305, one submit per game frame, and the frame becomes a
ground-level gameplay camera at 93.9% drawn / 6.1% clear with the sky region going 7.6% -> 88.4%
painted. So the renderer, camera, player-submit path and frame loop already work in village1
gameplay; what blocks playability is the state machine staying in the intro stream.
2026-09-11 (BOT58, CORRECTION): audio is NOT zero. PLAYER RPC loaded COMMON bank sounds=461,
VILLAGE1 bank sounds=43, named fly7/bird-2 plays, and 'mixed 48000 frames' windows ramping from
window 1 pcm-peak=0 to window 260 pcm-peak=8113 (sustained 7000-10000). The zero-PCM inherited
from BOT35/BOT37 is stale. Also: SKYFRAME/SKYRGB are NSLog, absent from ottsel-runtime.log by log
target, not by failure; read them via simctl spawn log show with predicate 'eventMessage CONTAINS
"ottsel metal"'. The RGBAQ decode is verified correct against DirectRenderer.cpp:1127-1132 and
:923-928 -- do not chase a decode fix. Gate N1 unproven; no playability claim. Next: docs/BOT58_PROMPT.md.
Evidence: docs/evidence/I1/BOT58-title-spool-blocks-gameplay.md

2026-09-11 (BOT59, GATE I1): JAK IS ON SCREEN. The MERC vertex path applied `transformed.z -= 1.0` on
top of the hvdf_offset the pc_camera path already normalised, so z_merc = z_world - 2; every MERC
vertex sat behind the near plane and GEQUAL rejected it. Frozen camera, one variable: mode 0 drew no
player, modes 1-4 all drew him; eichar unclogged from a frozen 4 to 382 -> 472.
2026-09-11 (BOT59, CORRECTIONS): BOT58's "sky region painted 88.4%" row measured the yellow HUD
banner, not sky, and "the player-submit path works" is refuted -- eichar climbing was submission,
not visibility. Jak is still unlit, sky still black, raster-draws=0. Not playable; no playability
claim. Next: docs/BOT59_PROMPT.md Q1. Evidence: docs/evidence/I1/BOT59-merc-z-near-plane.md

2026-09-11 (BOT60, GATE I1): THE ROUTE CLOSES VIA THE GAME'S OWN FRONT END. Title -> NEW GAME ->
save-file screen -> CONTINUE WITHOUT SAVING -> Village1, by real pad input: accept screen=27 index=0,
then edge screen=18 index=0..4, accept screen=18 index=4, GAMEPLAY: enter village1, CAMERA START:
cp "intro-start", INTRO: preloading misty before sequence A. 2026-09-11 (BOT60, THE FINDING): the
Village1 frame is FROZEN -- 8 of 423000 scene pixels change per second; only the corrupted top strip
and status bar move. The EE/GOAL loop is healthy at ~60 Hz (chain 44100->45360 in 20 s), so the
freeze is in the simulated state, not pacing. D-pad, a full-left synthetic stick ("0 128 700"), and
START/CROSS/DOWN holds all leave Jak's silhouette identical to 0.1 px: input reaches the game (it
closed the menu route) but there is nothing moving to observe. Not playable; no playability claim.
Next: docs/BOT60_PROMPT.md Q1. 2026-09-11 (BOT60, 60 s WINDOW): the freeze is slow drift, not zero --
scene pixels change 2.47% over 60 s (a few px of camera/TOD drift), but zero CAMERA START or INTRO
lines appear in that minute, so the intro sequence never advances and never hands over control.
Evidence: docs/evidence/I1/BOT60-q1-frozen-cutscene.md

2026-09-11 (BOT64, GATE N3 PRE-WORK): the 20:24 fault was DIAGNOSTIC-INDUCED, not product. A control
run with NO probes armed ran 210 s of Village1 with ottsel-fault.log at 0 bytes and the process alive,
and the scene changed across the window. Four cumulative sky probes armed together (each allocating a
fresh MTLBuffer per frame in the SKYCOPY path, metal_shell.mm:1532-1550) caused the GOAL-tag fault.
RULE GOING FORWARD: one diagnostic probe per run.
2026-09-11 (BOT64, THE FINDING): the shell's VU1 interpreter produces ZERO in gameplay. Same installed
binary, SIMCTL_CHILD_OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1: title/logo chains 90-180 give xgkicks=108391
gif-words=433564 draws=177, but Village1 chains 270/360/450 give vu1-runs=7290 capped=5670
xgkicks=0 gif-words=0 draws=0. BOT57's "the interpreter works" numbers were the TITLE SPOOL, and
BOT63's premise (game-accurate producer exists, merely unwired) is REFUTED for gameplay. Wiring
gif_out would present nothing. Evidence: docs/evidence/I1/BOT64-vu1-zero-in-gameplay.md
2026-09-11 (BOT64, THE ARCHITECTURE): the desktop renders correctly because it CALLS mips2c VU1
programs (game/mips2c/jak1_functions/tfrag.cpp, generic_tie.cpp, generic_merc.cpp, sky_tng.cpp …)
from an OpenGLRenderer bucket runner. The shell instead EMULATES microcode in tools/ottsel_vu1/vu1.cpp
(microcode loaded at metal_gfx.mm:6990) and re-derives transforms per class. build-ios.sh already
compiles the desktop's mips2c programs into libottsel-runtime.a; it does NOT compile
game/graphics/opengl_renderer/* (the runner). That inversion, not any one constant, is why 60 rounds
did not converge. New lane: run the desktop's VU1 programs; port the runner. docs/BOT64_PROMPT.md
2026-09-11 (BOT64, SKY SCOPE): sky submission is healthy and was never the whole defect.
SKYFRAME batches=44 (6x1x1, 6x32x32, 32x64x64) stable over six seconds, pre-world block at
metal_shell.mm:1465 IS entered, SKYBOUND shows the 1x1 fans reaching the drawable at
ndc=(-4.000,-4.009)..(4.000,3.991). But SKYRGB 1x1=(0.000,0.000,0.000) and the 20:35 frame is 29.9%
black plus a 26.1% pure-yellow hard-edged wedge. Do not re-litigate submission; it is the per-class
transform/texture/blend math.
2026-09-11 (BOT64, GROUND TRUTH): the macOS oracle was run and driven to Village1 for the first time
(Return=START, Space=CROSS, Down=DOWN): /tmp/ottsel-diag/mac/village1.png shows correct blue sky,
correct terrain and Jak on the ground. Also refuted: BOT60's "Village1 is frozen" -- the 20:28 and
20:32 frames differ (propeller angle, HUD banner cleared). Not playable; no playability claim.
2026-09-11 (BOT65, LANE CORRECTION): BOT64's "run the desktop's mips2c VU1 programs; port the runner" is refuted for world geometry. Desktop world meshes are prebuilt out/jak1/fr3/*.fr3 (tfrag3::Level, Loader.cpp:249, drawn by TFragment/Tie3/Merc, which contain zero Mips2C refs); the shell already loads the same files (metal_gfx.mm:1342-1360) and draws NORMAL/TRANS/DIRT. VU1/mips2c covers dynamic effects only. BOT65 lane: close the sky, then whole-frame parity vs the macOS oracle. docs/BOT65_PROMPT.md
2026-09-11 (BOT65, SKY BLEND POPULATED): OTTSEL SKY BLEND dest tbp=0x1f80 32x32 nonzero=4087 peak=254 mean=134; dest tbp=0x1fa0 64x64 nonzero=16384 peak=252 mean=119. The blended sky is not black, so with SKYFRAME batches=44 and SKYBOUND ndc=(-4.000,-4.009)..(4.000,3.991) the residual sky defect is fan texture identity or fan UV, not submission or blend.
2026-09-11 (BOT65, ANOMALY): sky source tbp=0x10 cbp=0x50 reads an all-zero CLUT block from the shell VRAM mirror; tbp=0x14 (cbp=0x4c) and tbp=0x20 (cbp=0x40) read real CLUTs. Unresolved.
2026-09-11 (BOT65, PROBE RULE): arm ONE diagnostic probe per run -- four cumulative sky probes caused the 20:24 GOAL type-tag fault, while zero probes ran 210 s at fault=0.
2026-09-12 (BOT66, FRAME STATE CORRECTED): RETRACTED "iPad is stuck at a blank frame" (BOT64/BOT65). With -press-start the iPad boots to village1 and renders lit textured terrain, foliage, palms, a thatched hut, the water plane, distant mountains and the Jak model; SEPARATE frames show a camera pan, i.e. live input reaches the game loop. mac build behaves the same on the same content.
2026-09-12 (BOT66, SKY EXONERATED): armed -sky-end, which redraws the captured sky batches at the END of the pass through the real product pipeline with nothing left to overdraw them. Result is 99.3% exact pass clear rgb(8,10,18) in the top 40%. Per that probe's documented matrix this refutes pass position/state residue and isolates the sampled texture content.
2026-09-12 (BOT66, SKY ISO): a fragment that SAMPLES the texture writes no fragments; a fragment returning a constant paints 99.5% magenta from the same buffers, same descriptor, same depth state. The only unshared step is the setFragmentTexture/setFragmentSamplerState/setFragmentBytes triple. NEXT: rewrite direct_fs_debug_tex to return fract(in.uv) to split "texture bind is the defect" from "draw is dropped".
2026-09-12 (BOT66, LANE): docs/BOT66_PROMPT.md. Close the sky, then whole-frame parity vs the macOS oracle, then the P1 input/camera exit bar. Still no playability claim.
2026-09-12 (BOT67, ZOOM-OUT): the sky lane is bounded and has a positive control, so it is not what blocks iPad. A fresh 06:56 frame is the INTRO/logo state, not village1: there is no navigation past the intro, so nothing after it can be measured. The app is also not running (kernel machine shutdown 19:56:44) and the log container is 2.3 GB on 11 GiB free.
2026-09-12 (BOT67, PROCESS): 715 lines of uncommitted diagnostics and 60 rounds sit on top of the product path, all in service of one bucket. The shell boots and draws the world; the gap to the oracle is scope of coverage, not one constant. Stop probing; publish the diagnostics or revert them.
2026-09-12 (BOT67, POSITIVE CONTROL): with -sky-debug-fill the same batch0 that yields zero fragments paints 99.5% magenta. So the draw, the vertex buffer, the pipeline, the depth state and the pass position all execute; only the sampled value differs. That is the whole sky result and it has been stable for two days.
2026-09-12 (BOT67, NEXT): (1) navigate intro->village1 deterministically and assert the scene; (2) one bounded BEFORE/AFTER of one bucket against the oracle; (3) only then the sky sample. Full lane in docs/BOT67_PROMPT.md. Still no playability claim.
2026-09-14 (RECOVERY, EMITTER SITE COUNT): docs/SIGNED_AOT_RECOVERY.md said three goal_offset sites; there are five. The emitter's own manifest emission (a11_module_emitter.h:276, patch a11-kernel-module-emitter.patch:91) is a separate site and scripts/emit-signed-module-arena.py:121 re-asserts its expression, so the kind-5 code-target change must branch there too. Doc corrected, still 56 lines (cap 60).
2026-09-14 (RECOVERY, ASSEMBLY GAP - CLOSED IN TREE): the emitter now has the third assembly case. It classifies the object word as quad_load when (add & 0xffc00000) == 0x3dc00000 and emits ldr q<n>, [x<m>, ref@PAGEOFF] (a11_module_emitter.h:333-338), with the class detected at :178 and a 16-alignment/whole-quad guard at :194-196; the class is SIMD&FP LDR Q (assembler scale 16), not the 8-byte LDR D encoding 0xfd4 that the original note named.
2026-09-14 (RECOVERY, MACH-O SCALE - CLOSED IN TREE): both oracles now scale the LDR Q class by 16 (scale = 4 if op == 0xBD400000 else 16 if op == 0x3DC00000 else 1, test/a11_module_macho_check.py:78, test/a11_aggregate_macho_check.py:73), so the earlier scale-4-only codeword check no longer mis-resolves; the 16-byte class is LDR Q, not an LDR D scaled by 8.
2026-09-14 (RECOVERY, MODEL FAITHFUL): the census port parse_signed_module (scripts/a11-corpus-census.py:59-219) matches a11_module_emitter.h:49-196 clause for clause and each relaxation inverts exactly one throw, so the relax-all/types/links predictions are sound.
2026-09-14 (RECOVERY, GATE + SCOPE): df -h / | tail -1 -> 460Gi 12Gi 12Gi 50% / (12 GiB free, AGENTS.md rule 2 needs 40 GB); .git/objects/pack tmp_pack_* count 0. Nothing built, no Simulator, no product source changed. Docs amended only; no cleanup performed.
2026-09-14 (RECOVERY, TEST SITES): the kind-5 code-target flip also breaks test/a11_kernel_manifest_test.py:39 (pointer-target-code), test/a11_gstate_loader_test.cpp:333-336 (actual==goal_offset && lowtag2, unaffected only while the corpus has zero code targets) and scripts/test-a11-kernel-emission.py:45 with test/a11_kernel_pointer_oracle.cpp, whose translation base data_arena_offset-text_size is the data-form premise. Doc line 54 now names all four sites; nothing compiled.
2026-09-14 (RECOVERY, ATTRIBUTION): new census mode --attribution names each failing member's unique minimal relaxation set, so the four fixes are separately falsifiable instead of only jointly proven: type 141, ldr_d 96, seg0 35, pointer 4, type+ldr_d 167, type+seg0 41, type+pointer 4, type+ldr_d+pointer 3 = 491, and only nine of fifteen subsets add anything. Implementing the pointer relaxation alone must flip exactly ENGINE/GAME default-menu and default-menu-pc and touch nothing else; independently cross-checked against --links, which names the same 11 member entries.
2026-09-14 (RECOVERY, LDR-D POLICY GAP): the scalar-float template rejects a load whose source segment loads while its target sits in the omitted debug segment (emitter :163); the ADRP+ADD class instead resolves it to the arena label (target_label :230-237). The corpus has 3619 such records, all ADRP+ADD, and zero scalar or LDR-D, so nothing decides the new class's policy and the census models no guard there. Mirrored into doc item 2; choose reject unless omitted segments get a placement rule.
2026-09-15 (RECOVERY, DISK CLEAR + FAIL-CLOSED): Avail 120 GiB, tmp_pack 0. Stage 0 encoder/link-begin/verify PASS. Find-only slots FALSIFIED at gcommon delete-car!. Diagnostic find-only + intern table-full abort landed. KERNEL 631, math 199, GAME prefix 31/379, GAME deep 78/802 PASS. GAME full 315 SIGSEGV at gsound ENTER (host iop). No Simulator. Evidence: docs/evidence/A1/a11-loader-fail-closed-2026-09-14.md
2026-09-15 (RECOVERY, GSOUND THEN TOD): GAME fixture links iOS sif_ee; gsound returns after IRX 2.0. GAME full SIGBUS in time-of-day s0+4824 calling ottsel_module_arena. 202 members returned. No Simulator.
2026-09-15 (RECOVERY, GAME FULL HOST): gstate after dgo-h. time-of-day was calling enter-state before gstate. Host GAME full 315 members 2935 PASS. No Simulator, not playable. Next: streamed locate_member.
2026-09-15 (RECOVERY, TIT/VI1): locate_member scans *.DGO. Isolated TIT tests PASS. Real preflight title-obs/VI1 PASS. Host GAME+14 level members 329/3061 PASS. No Simulator.
2026-09-15 (RECOVERY, LINK-BEGIN): signed hook on jak1::link_begin. GAME full 315 members via streamed begin 3565 PASS. KERNEL link_and_exec 631 unchanged. No Simulator.
2026-09-15 (RECOVERY, SIGNED IOS GAME): build 65a63fbb / 01480677 348 CGO-order modules. App signed-links GAME.CGO 346 objects, TIT static-screen and title-obs ENTER/RETURN. Then SIGSEGV enter-state pp=0 while serving VI1 oracle. Direct/sprite drawn=0. Not playable.
2026-09-22 (A1.2, DISPATCH LOCALIZED + SCAN): strict signed GAME faults identically at three ASLR bases: gkernel seg0+0x5554 `ldr w1,[x0,x22]`, this(x24)=0x3db0fb4 (the static *kernel-context* at the arena's first bytes, gkernel seg0 data base 0x3db0fb0+4), x0=0x70004000, si_addr=ee+0x70004000, frame entered from the recursive call at seg0 0x55ac (x30=0x55b0). Fault-path EE scan: only two non-stack words hold the value - the *kernel-context* Symbol slot 0x18adfc and pooled word 0x1f66e0 (owner block carries a Type pointer, three signed-module code addresses, 0x803c2d4 and a pointer into zeroed pool memory). Evidence: docs/evidence/A1/a11-recursive-dispatch-kernel-context-2026-09-22.md, docs/evidence/A1/a11-walk-link-owner-2026-09-22.md
2026-09-22 (A1.2, REFUTED): heap/arena overlap is out - the app logs `gkernel: global heap 0x0013fd20 to 0x03db0000` (clamped to reservation_begin under OTTSEL_SIGNED_GSTATE_EXPERIMENT); *active-pool* as the source is out - `active-pool-sym=0x4f4504` at dispatcher start in a run that crashed with 0x3db0fb4.
2026-09-22 (A1.2, OPEN): x19/x23 are not preserved across the indirect GOAL call at seg0 0x5518: x19 returns as that call's host continuation 0x801d51c instead of the lambda 0x801d724, and x23 comes back holding the lambda. Next iteration separates rotated-argument setup from a poisoned cell; one variable, shell-only build. The app now carries a fault-path-only EE scanner/fault-handler owner-block dump (src/shell/ios_boot.cpp); shell-only builds keep the product state.
2026-09-22 (A1.3, HOLDER LOCALIZED): only two non-stack EE words hold the faulting 0x3db0fb4 - the `*kernel-context*` Symbol slot 0x18adfc and pooled word 0x1f66e0, whose owner block carries a Type pointer, three signed-module code addresses, 0x803c2d4 (`execute-process-tree`'s function value) and a pointer (0x1cb850) into zeroed pool memory; `*active-pool*`'s own child chain (0x4f4504 -> 0x4f45a4 -> 0x1f4364 -> '()) is healthy. The host stack one frame up still holds (func, context) = (lambda, *kernel-context*) while the faulting frame's `this` is the context value, so the rotated argument group at the indirect-call edge is the leading candidate. Evidence: docs/evidence/A1/a11-walk-link-owner-2026-09-22.md
2026-09-22 (A1.4, .RET MASK FIX LANDED): IGen's shr_gpr64_u8 shifts its own register, so every shipped guarded .ret site emitted `lsr x17, x17, #32` and the keep-mask came from the pushed synthetic continuation, making the fail-safe inert exactly when the slot held an EE value (the A1.1 0x181674 bad-call-target). Fix: one instruction in goalc/compiler/IR.cpp (`mov x17, x30` after the slot load, sha256 e65e821c); overlay patches/a11-asm-ret-fail-safe.patch regenerated and verified byte-for-byte; `python3 scripts/verify-asm-ret-guard-patch.py` PASS.
2026-09-22 (A1.4, REGRESSION + EFFECT): scripts/test-a11-asm-ret-guard.sh now requires the slot load at every guarded site - FAIL `8 of 8 ... stale register` on the pre-fix objects, PASS `8 guarded .ret sites compute the keep-mask from the slot` after regenerating (546 targets) and rebuilding the app. The strict run now serves the TIT DGO plus `villagep-obs`/`oracle` and fails later: signal 10 in signed module `font` seg0 0x6864, `str w5, [x16]` with x16 = g_ee_main_mem+4, x20/pp=0, drawn=0. Evidence: docs/evidence/A1/a11-asm-ret-guard-mask-2026-09-22.md
2026-09-22 (A1.5, NEXT BARRIER NAMED): the font fault is signed `draw-string` (nearest symbol 0x852c004) doing `ldr w0,[x2+0xbd0]; str w5,[x0+ee+4]` with x0 = 0 - a null game-data pointer in a heap object (x2 = 0x3da7140, below the arena reservation), not a missed loader slot. The level load is still mixed: `signed took` = static-screen/title-obs/villagep-obs while 13 streamed objects fall back to legacy (tpage-*, logo*, ndi*, title-vis). Next: close the streamed signed lane (`locate_member` scope + the value-0 intern).
2026-09-22 (A1.6, CONTROL RUN): the same tree/emitter with `config/signed-kernel-full.json` (GAME legacy, 6.9 MB app) leaves `ottsel-fault.log` at 0 bytes and loads village1 (legacy fallback village1-vis/windspinner/yakow/water-anim-village1/warpgate, 2 x GAMEPLAY), while the strict CGO registry (27.4 MB, 335 modules, all ENTER+RETURNED) dies in signed `font`/`draw-string` on the null field.  So the objective's bad-call-target class is fixed at the .ret site and the remaining barrier is the signed-GAME lane itself. Follow-up (host + live): x2 is `font-h` module data + 0x50 (aggregate.json puts font-h seg0 data at 0x3db9940) and the field it reads is font-h data + 0xc20 - a template zero with no emitter record. Live reads now confirm the loader DID copy the segment (the arena matches the template word for word at the segment start and at x2) and the word is legitimately 0, so the defect is the pointer: signed `font`/`draw-string` treats font-h's static data as a live object. Next: name the producer of x2. Follow-up: font-h's emitter record set has no type-pointer slot at all (17 records), so font-h data + 0x50 is not an object start; the only pre-fault write to x2 in font seg0 is the `*font-work*` slot pattern at 0x320 and the only branch into the fault block is the loop-exit beq at 0x6838, so x2 stays live from that slot read, yet the live slot content resolves to a symbol whose storage is zero - the producer is named: the game global `*font-work*` (a static `font-work` GOAL structure in font-h seg0 data + 0x50, symbol value 0x3db9990 live), and the null field is its `buf` pointer at +0xbd0 = font-h data + 0xc20 (template 0, no emitter record, 0 live). Nothing in goal_src/jak1 sets `(-> *font-work* buf)` and the initializer does not set `:buf`, so the control's working font path means a runtime setter ran there and not in strict. The emitted code stores it correctly (@str w1, [x16]@ at code 0x350 with x2 = *font-work*'s value and offset #0xbd0, unconditionally), so the faulting invocation was entered with a NULL dma-buffer: the caller is the defect site; the loading path goes through draw-string-xy, and progress-pc.gc:1904 draw-progress passes `(-> *display* frames (-> *display* on-screen) frame global-buf)`, so read that expression next; done: the chain was decoded (@*display*@ + 0x22c, x32, +0x234, then +0x10/+0x24/+0x4) and read live (display 0x509d34, frame 0x509f88, buffer 0xce8400 - nonzero), so that caller path is NOT the fault; the caller is still unnamed, and the next tool is the emitter's GOAL call trace (@OTTSEL_TRACE_GOAL_CALLS=1@ + the ring-audit script); the fault's GOAL-stack scan names villagep-obs+0x16914, which does not call draw-string in source, so re-check that attribution next. Evidence: docs/evidence/A1/a11-font-work-buf-null-2026-09-22.md Decision step: read the legacy copy of font-h data + 0xc20 in the KERNEL-only control to settle whether the emitter dropped a record. Evidence: docs/evidence/A1/a11-signed-game-vs-legacy-ab-2026-09-22.md
2026-09-22 (A1.7, CALLER NAMED): strict lane faults at font seg0 +0x6864 = font.gc:1462 in draw-string ((set! (-> (the-as (pointer pointer) (-> fw buf)) 1) dma-out)), called from display-loop's (draw-string *stdcon0* s3-1 *font-context*) at engine/game/main.gc:513 - return address main+0xB090, live draw-string symbol value 0x84BC004 = font+4, and every slot the call site loads (+3988..+4032) resolves to that exact line. Evidence: docs/evidence/A1/a11-font-buffer-caller-named-2026-09-22.md
2026-09-22 (A1.7, NULL ARGUMENT): the invocation's dma-buffer argument was 0 - live *font-work* (arena+0x3DB9990) has buf@+0xBD0 = 0 while str-ptr@+0xBD4 = 0x4F4DF4 = the live *stdcon0* value, so the prologue (set! (-> fw buf) context) ran and stored null. x25 is callee-saved (goalc/emitter/Register.cpp m_saved_gprs = X19,X23,X24,X25,X26), draw-string has no bl/blr and never writes x25, and the pause block is skipped (*master-mode* 0x1992D4 != 'pause 0x1993EC), so the null is the on-screen frame field the chain loads (emitted debug-buf +0x20 = 0, global-buf +0x24 = 0xCDCFD4). No playability claim.
2026-09-22 (A1.7, TRAP CORRECTED): the SIGBUS is a store to the readable-but-unwritable low-EE page - ldr of ee+4 returns 0 (dma-out = x5 = 0 at the fault) and only the final str traps, superseding the A1.5 "PROT_NONE guard read" reading. The post-fault snapshot does not reproduce the crash (*debug-segment* reads 0x18FE04 = the x21/#f value, selecting the global-buf path) because the gated handler holds only the faulting thread while the streamed activation keeps writing globals.
2026-09-22 (A1.7, NEXT): G1.13 - one bounded in-process fault-handler probe (symbol values for *debug-segment*/*master-mode*/*cheat-mode*/*display*, then the on-screen index, vframe, frame and frame+0x20/+0x24/+0x28), then rerun the strict profile to decide between allocating the debug frame buffers and fixing the activation/loader flag. G1.14 needs two clean strict runs.
2026-09-22 (A1.7b, ROOT CAUSE CANDIDATE): a null buffer is only reachable through the debug branch - display.gc:236-238 allocates a frame's debug-buf only (when *debug-segment* ...), display-frame's new starts it at 0, and global-buf is always allocated; *debug-segment* is written exactly once at boot (kscheme.cpp:2213, from DebugSegment) with false = exactly s7 (set_fixed_symbol(FIX_SYM_FALSE, "#f", s7.offset + FIX_SYM_FALSE); kboot.cpp:483: "an #f link equals s7.offset (0x18fe04)"), so any other value, including a fail-open intern's 0, is truthy for the emitted cmp flag,x21 / b.eq pair.
2026-09-22 (A1.7c, OPEN): the post-fault frame read (+0x20 = 0, +0x24 = 0xCDCFD4, +0x28 = 0x50C8A0) is not the state at the crash under the deftype's 36/40 offsets, and the flag reads #f now. G1.13 = one bounded in-process fault-handler probe (flag values + *display*/on-screen/vframe/frame + frame+0x20/+0x24/+0x28 read at the fault), then land the fix and rerun the strict profile twice (G1.14). No playability claim.
2026-09-22 (A1.7d, INSTRUMENT LANDED, NOT RUN): src/shell/ottsel_fault_state.h (ottsel_fault_state_read) plus the fault-handler call in src/shell/ios_boot.cpp print two bounded a17 lines - the flag value against the x21 register, then on-screen/vframe/frame/+0x20/+0x24/+0x28 read at the fault. The strict build (OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 OTTSEL_SIGNED_MODULE_LIST=config/signed-game-cgo-tit-vi1-control.json OTTSEL_SIGNED_EXPORT_BANKS=1 bash scripts/build-ios.sh) exits 0 and the probe string is in the linked bundle. Next: install and run the strict profile once, read the a17 lines, land the fix, then G1.14's two clean runs.
2026-09-22 (A1.7, PROBE RAN): the strict profile reproduces in about a minute. At the fault, read in process by the new handler probe: *debug-segment* = 0x18fe04 = s7 = #f (FIX_SYM_TRUE = 8 per tools/ottsel_a1_1/a11_slice_emitter.cpp; kboot.cpp:483 "an #f link equals s7.offset"), *display* = 0x509d34, on-screen = 1, vframe = 0x50a114, frame +0x20 = 0 / +0x24 = 0xcdcfd4 / +0x28 = 0x50c8a0, ee = 0x1016d8000; fault registers x25 = 0 (the dma-buffer argument), x24 = 0 ((-> s3-1 base)), x19 = 0x1013e0100 (a host address), x21 = s7, x22 = ee. main's own *debug-segment* slot resolves to the same canonical cell (lldb, and it holds #f), so there is no duplicate symbol.
2026-09-22 (A1.8, ROOT CAUSE, FIX LANDED): draw-string writes no x19/x24/x25, so those values are the caller's (display-loop, LR = main+0xB090 => main.gc:513); the emitted selection (cmp flag,x21(=#f); b.eq <+0x24>) would pick the non-null slot, so the chain's disp (x19) had been destroyed. GOAL's register file here is x19-x28 + v8-v15, but _call_goal_asm_arm64 and _call_goal8_asm_arm64 saved only x20/x21/x22 + x29/x30 - the same defect A1.2/A1.3 recorded as "x19 returns as that call's host continuation". Both bridges now preserve the whole set (LIFO, balanced), mirroring _call_goal_on_stack_asm_arm64; the fix is verifiably present in the linked binary (lldb disassembly of _call_goal_asm_arm64).
2026-09-22 (A1.8, EFFECT + REGRESSION): overlay patches/a11-goal-bridge-regfile.patch (4 hunks, reverse-applies clean). Regression scripts/test-goal-bridge-regfile.py: PASS on the fixed tree, FAIL naming the 16 missing push/pop pairs per bridge on a pre-fix copy. Same strict profile after the fix: 335 signed modules, 32 LINKBEGINs (title-vis/title-obs/static-screen/tpage-*/ndi-*/villagep-obs/oracle), renderer frames past n=4400, process alive, no fault log written - the run that used to die within a minute now runs past the old crash point.
2026-09-22 (A1.8, OPEN/NEXT): drawn=0 is unchanged (renderer lane, not this defect). Continue the strict run and read otsel-runtime.log for the next blocker before any level or playability claim.
2026-09-22 (A1.7, CORRECTION - the crash is NOT closed): run 2 with the same fixed binary faults at the same font site within minutes, so the earlier "no fault log written / runs past the old crash point" lines describe run 1 only. Run 1 (15+ min clean) and run 2 (fault) used the same binary, so this crash is data-dependent. The held run-2 process identifies the clobbered value: x19 = ottsel::signed_gstate::villagep_obs_manifest (a __DATA_CONST.__const loader static), and the fault's native backtrace root C frame is ottsel_ios_run_boot, i.e. the boot/loader path is in the chain; at least one more x19 clobberer exists on this lane. The bridge fix and its regression stand (a real defect, independent of this datum). Next: breakpoint on the chain (_ottsel_module_main_s0_code + 0xAE0C) under lldb, print x19 per frame, and bisect the frame body's calls.
2026-09-22 (A1.7c, FONT CRASH CLOSED, VERIFIED): the GOAL->C++ trampolines _arg_call_arm64/_stack_call_arm64 now save and restore GOAL's register file (x19-x28 + v8-v15, LIFO, balanced), so a C++ callee that returns with a changed x19 can no longer corrupt GOAL's register. Two runs of the fixed code (pids 48047 and 53279) never fault at the font/draw-string site, where every earlier run faulted within a minute. The A1.7b counter named the violators: jak1::method_set (42 leaks in 7268 GOAL->C++ calls, pre-guard) and, contained afterwards, jak1::asize_of_basic (4 in 1933). Regression scripts/test-goal-bridge-regfile.py now covers all four GOAL<->C++ boundaries (PASS fixed tree / FAIL pre-fix); overlay patches/a11-goal-bridge-regfile.patch regenerated and listed in verify-asm-synthetic-return-patch.py; test/a11_call_goal_asm_ret_test.cpp supplies the counter storage that harness needs.
2026-09-22 (A1.7d, NEXT GATE): both fixed runs now die deterministically at ottsel_module_rpc_h_s0_code + 2232 (GOAL 0x83b48b8, module base 0x83b4000), SIGBUS with fault address ee+0xC - a null-object field write on the same readable-but-unwritable low page. G1.16 chases that site. Stage 0 is green: verify-link-begin-patch, verify-asm-synthetic-return-patch, verify-asm-ret-guard-patch, test-a11-call-goal-asm-ret, test-a11-asm-ret-guard and test-goal-bridge-regfile all PASS.
2026-09-22 (A1.8, NEXT GATE DIAGNOSED - SOUND IOP-RPC): the deterministic post-fix fault is ottsel_module_rpc_h_s0_code + 2232 (GOAL 0x83b48b8, module base 0x83b4000): str w23,[x19+0xC] with x19 = 0, i.e. a null-object field write on the readable-but-unwritable low page, called from gsound_s0_code + 988. That is the sound module's IOP RPC path (goal_src/jak1/engine/ps2/rpc-h.gc: rpc-buffer-pair current/last-recv-buffer writes in the call/sync tail; gsound.gc allocates *sound-loader-rpc*/*sound-player-rpc* via (new 'global 'rpc-buffer-pair ...) and calls add-element/call). The A1.7 probe extension reports *sound-loader-rpc* = 0x1549294 and *sound-player-rpc* = 0x15441b4 (valid heap objects) and the pair dump gives type 0x15492b4, +4 = 0x1549364, +8 = 0x15492b4, +0xC = #f, +0x10 = 1 (rpc-port = RPC-SOUND-LOADER): the pair exists and the port is right, but current is not a buffer object, so the write the source expects ((set! (-> this current) (-> this buffer 0))) did not land.
2026-09-22 (A1.8, NEXT): decide between the inner (new 'global 'rpc-buffer ...) returning 0 and the field write missing: read the pair's type symbol / the emitted new rpc-buffer-pair code, or extend the A1.7 probe, then fix with a bounded regression. Keep the trampoline guard (two runs, no font fault) and its regression; Stage 0 green.
2026-09-22 (A1.8, DECISIVE CONTRAST): the gsound *symbols* are correct (the in-process probe reads *sound-loader-rpc* = 0x1549294, *sound-player-rpc* = 0x15441b4, both live heap objects) while the *module-data slots* the code reads are 0: _ottsel_module_gsound_s0_data + 700/704/712/732/740/744/764/788 all read 0 in the held process (data base taken from the faulting caller's own adrp, cross-checked against lldb's symbol comment), and the fault's x0 at the call site is 0, i.e. gsound's code loaded a zero slot and passed this = 0 into the rpc-buffer code. So the strict loader's slot patch for gsound did not take effect even though link() applies its writes before the entry call and the same pass works for main (whose *display* slot reads 0xffff78a8 and resolves to the canonical cell). Next: why the write is 0 - the intern result (sym.offset - s7.offset == 0 means the lookup landed on s7 itself, the #f slot) or a later overwrite of the arena page.
2026-09-22 (A1.7c-fix, ROOT CAUSE + FIX LANDED): the rpc-h/gsound null-object fault was not the loader slot - it was a trampoline save/restore ORDERING defect. _stack_call_arm64 pushed the A1.7c GPR block (x19,x23-x28) AFTER the vector block (q15q14/q13q12/q11q10/q9q8) but its epilogue still popped the vectors first, so after every GOAL->C call through the `stack` export-bank stub x19-x28 were restored from the vector save area and v8-v15 from the GPR slots. Measured at rpc-h seg0 +0x8b8: the frame's own prologue save [sp+0x60] held 0x1549300 (a live rpc-buffer-pair) while live x19 = 0, x23-x26 = 0; the A1.7b counter read in == out == 0x1549294 because it samples x19 either side of blr, before the corrupting epilogue. The GPR block now sits immediately after `stp q15, q14, [sp, #-32]!` so the pop order is the exact reverse of the push (the other four bridges were already correct).
2026-09-22 (A1.7c-fix, REGRESSION + PATCH): scripts/test-goal-bridge-regfile.py no longer only checks presence/LIFO-of-blocks - it now simulates the stack offset by offset and requires every pop to read the slot its push wrote: FAIL with 13 named mismatches on a pre-fix copy, PASS on the fixed tree. patches/a11-goal-bridge-regfile.patch regenerated from pin 641fb572e + h3 + vector + synthetic-return; scripts/verify-asm-synthetic-return-patch.py reconstructs game/kernel/asm_funcs_arm64.s byte-for-byte (sha256 4a76368454d2efb4f8ca978cfa043449616923ed1e79bf5adcbacbcffbec99fb).
2026-09-22 (A1.7c-fix, VERIFIED, TWO RUNS): both strict runs (OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 OTTSEL_SIGNED_MODULE_LIST=config/signed-game-cgo-tit-vi1-control.json OTTSEL_SIGNED_EXPORT_BANKS=1) report 337 signed modules RETURNED and 32 LINKBEGIN (signed took static-screen, title-obs, villagep-obs; legacy fallback tpage-1609/416/415/397/1499, logo, logo-black/cam/volumes, ndi, ndi-cam/volumes, title-vis) and no longer fault in rpc-h. The rpc-h/gsound class is closed for the trampoline part; drawn=0 is unchanged (renderer lane). No playability claim.
2026-09-22 (G1.17, NEXT GATE): the strict lane now dies returning into 0x50ffffffff (pc = lr = x30 = 0x50ffffffff, region-host, no GOAL offset) on the villagep-obs type/method-install path: signed_gstate::link -> call_goal_on_stack_asm_arm64 -> signed villagep-obs +0xfe4 -> signed gkernel +0x6128 -> jak1::method_set -> arg_call_arm64 -> jak1::intern_type_from_c. Deterministic in both runs; the A1.7b counter again reports the true C-side violations (42 leaks in 7208 calls, target jak1::method_set) instead of 4 in 1933. Keep the trampoline guard, its regression, the A1.7b counter and the A1.9 probe; name the bad return target next. Evidence: evidence/A1/a11-stack-call-regfile-order-2026-09-22.md.
2026-09-22 (A1.8, ROOT CAUSE + FIX LANDED): the post-A1.7c-fix fault (pc = lr = x30 = 0x50ffffffff, region-host) was the .ret fail-safe's slot test. The A1.1 guard keeps the slot when its high half is nonzero; during the strict oracle serve the slot held a GOAL frame local 0x00000050ffffffff (high half 0x50), so the guard kept it and ret left the image. Measured at the fault: x16 = the guard's own 'x16 = x30' = ottsel_module_main_s0_code+0xBF0C, a valid continuation, and resuming at pc = lr = x16 advanced the boot past the fault - so the fallback is this site's correct return.
2026-09-22 (A1.8, FIX + REGRESSION): IR_AsmRet::do_codegen_arm64 now keeps the slot only when its high half names this port's executable window [0x1_00000000, 0x9_00000000) and otherwise falls back to the incoming x30 (mov x9,x17; sub x9,x9,#9; asr x9,x9,#63; mov x10,#0; sub x10,x10,x17; orr x10,x10,x17; asr x10,x10,#63; and x9,x9,x10; x30 = x16 + (([sp]-x16) & keep)). test/a11_asm_ret_guard_test.cpp mirrors the sequence and adds both measured non-code slots (0x50ffffffff, 0x0f41210f24); scripts/test-a11-asm-ret-guard.sh PASS and a pre-change copy fails the new cases. Overlay patches/a11-asm-ret-fail-safe.patch regenerated pin->current; verify-asm-ret-guard-patch PASS.
2026-09-22 (A1.8, BUILD REQUIREMENT): the guard bytes are baked into out/jak1/obj/*.o and the slice emitter copies them, so a compiler change only ships after 'goalc --game jak1 --isa arm64 -c "(mi)"' (546 targets, ~9 s, also rebuilding KERNEL/GAME/ENGINE.CGO, which the signed preflight requires to match the loose objects) and then 'bash scripts/build-ios.sh'. Verified byte-wise afterwards: all 8 guarded .ret sites (aligner 1, gkernel 6, gstate 1) carry the new test.
2026-09-22 (A1.8, VERIFIED, THREE RUNS + NEXT GATE): runs 1-2 (7/8 sites regenerated) and run 3 (8/8) each report 32 LINKBEGIN, signed RETURNED for title-obs and villagep-obs, 'served obj 1 (oracle)', cbridge calls=7268/leaks=42, and no ret-into-data fault; the ret-into-0x50ffffffff crash is closed. All three end at the same new fault (G1.18): executing code at GOAL 0x88ba328 with lr = 0x181674 (the village-cam Symbol) and a bad memory access, right after oracle is served - the A1.1 'GOAL data used as a call target' class with pc inside code. Stage 0 green: verify-link-begin-patch, verify-asm-synthetic-return-patch, verify-asm-ret-guard-patch, test-a11-call-goal-asm-ret, test-a11-asm-ret-guard, test-goal-bridge-regfile all PASS. Evidence: evidence/A1/a11-asm-ret-window-2026-09-22.md.
2026-09-22 (G1.18, IN PROGRESS): the post-A1.8 fault in the held run is x30 = lr = 0x181674 (a GOAL Symbol address) with x20/pp = 0 and a bad load at x16+0x10, executed inside signed main text at main+0xa328. That block is the *display*-relative chain (fields 0x22c/0x234, stride 32, then +0x10/+0x20/+0x24/+0x4 - the shape the A1.12 note attributed to draw-progress) and it runs with x19 = x10 = sp, i.e. a host value where a GOAL object offset belongs; the live GOAL slots on the stack hold Symbol addresses (e.g. [sp+0x10] = 0x1f53d4) rather than code addresses. Same 'GOAL data used as a code/link value' class, one step earlier than the A1.8 .ret slot.
2026-09-22 (G1.18, NEXT): intern_type_from_c+0xf8 and alloc_heap_object appear on the fault stack only as stale words (alloc_from_heap/alloc_heap_object are pure C++ and never call GOAL), so the live entry into the faulting function still has to be named. Next step: walk the GOAL frames at the fault - the pushed (synthetic return, x30) pairs and the old-sp stash from the 'str x9, [sp, #-16]!' bridge - and print each frame's return slot with its module and offset, then fix the producer of the data return address / host-value x19. Keep the trampoline guard, the .ret window guard, the A1.7b counter and the A1.9 probe; two clean strict runs before this class is retired.
2026-09-22 (PROBE LIMIT, CORRECTED): the handler's above[]/below[]/sp-words lines print two 32-bit halves per address by design (safe_read_u32), so the log alone cannot tell a host address (high half 1) from a small GOAL value. The host-frame / classify lines do carry full 64-bit addresses - use those, or lldb, when reconstructing a frame chain.
2026-09-22 (G1.18, FRAME STRUCTURE): the faulting pc 0x10d22e328 is main seg0 +0xa328 (main host base = ee + 0x88b0000 = 0x10d224000, so the pc is inside main's signed text, not a stale host word). The fault stack shows three live call_goal_on_stack_asm_arm64 frames (each +0x4c = the bridge's pushed synthetic return), i.e. three nested GOAL activations under signed_gstate::link, and the C++ frames above the fault are alloc_heap_object (saved x30 = intern_type_from_c+0xf8, the return address of the bl at intern_type_from_c+0xf4) and method_set (saved x30 = arg_call_arm64+0x5c). jak1::method_set is pure C++ - it never calls GOAL - so the C++->GOAL caller in this chain is still to be named.
2026-09-22 (G1.18, NEXT): kscheme.cpp contains the call_goal(..., type->get_method(method_id), arg, a1, a2, s7.offset, g_ee_main_mem) helper (call_method_of_type-shaped) - the obvious C++->GOAL entry to check, together with klink.cpp's two module-entry calls (one with goal_stack, one with rsp=0). Next: identify which of those entered the faulting main function (break on the three bridge entry points and log x0/x1/x2 plus the target, or add the frame walk described above), then fix the producer of the data link register / host-value x19.
2026-09-22 (G1.18, CORRECTED CHAIN): the C++ words above the fault sp are not the live entry. jak1::method_set (kscheme.cpp:1336) is pure C++ - it walks the symbol table and writes method tables, never calling GOAL - so alloc_heap_object/method_set on the stack are stale or saved-register words, not the caller of the faulting main function. The only live C->GOAL bridges in the scan are three call_goal_on_stack_asm_arm64 frames (+0x4c each), i.e. the loader's module-entry calls (klink.cpp passes goal_stack), so the faulting main function was entered inside a GOAL activation, not from the allocator.
2026-09-22 (G1.18, CANDIDATE DISPATCHERS): the concrete C++->GOAL method dispatchers are call_method_of_type (kscheme.cpp:1464, call_goal(type->get_method(id), arg, 0, 0, s7.offset, g_ee_main_mem)) used by asize_of_basic (kscheme.cpp:1796) and copy_basic (kscheme.cpp:1764, which reads the type tag at obj-4), plus call_method_of_type_arg2 (klink.cpp:912, the relocate path) and kprint (kscheme.cpp:342/363). They match the objective's shape: a bogus obj/type makes get_method(id) return a GOAL data value and the dispatch jumps into data. Negative result for this fault: no _call_goal_asm_arm64 frame appears in the scan (only call_goal_on_stack), so copy_basic/asize_of_basic are not the live entry here; the next break should target the three bridge entries and the klink.cpp activation call to name which activation reached main+0xa328.
2026-09-22 (G1.18, FUNCTION NAMED): the faulting function is display-loop in main. main.json's immutable function tag for seg0 sits at 0x7d20 (entry 0x7d24), and the A1.7 record already documented that display-loop's entry is main seg0 +0x7D24/+0x7DA4 and that its entry loads disp into x19 - the same offsets, so the pc main+0xa328 is inside display-loop. Disassembly of main+0x8000..+0xa328 (1450 instructions) shows no ret and no x19 save/reload at all: display-loop's body is one long stretch, so the x19 seen at the fault is not a body value that was reloaded - it is the register as it was when the function started running.
2026-09-22 (G1.18, ENTRY LINK REGISTER IS DATA): x30 at the fault is 0x181674 (the village-cam Symbol address) and display-loop's body saves/restores x30 around every call, so x30 is still its entry value: display-loop was ENTERED with a data link register. Together with x19 = x10 = sp (a host value) this is the same 'GOAL data used as a code/link value' shape as the objective, and it points at the call that entered display-loop rather than at anything inside it. Next measurement: hardware-breakpoint main+0x7d24 (display-loop's entry) in a fresh run and log x19/x20/x21/x30/sp plus the caller's slots, to name the site that entered display-loop with x30 = 0x181674 and a host-valued x19; then fix that producer and re-run twice.
2026-09-22 (G1.18, ENTRY MEASURED - FRESH RUN): hardware-breakpointed display-loop's entry (main seg0 +0x7d24; fresh run pid 78652, app base 0x100ccc000, main host base 0x109edc000). Entry state: x19 = 0x109ee3d24 = the entry address ITSELF, x20 (pp) = 0x1f53d4 (a GOAL symbol-table address, i.e. NOT a process), x21 = 0x18fe04 = s7, x22 = the arena, lr = gkernel_s0_code+0x1cb4 (+7348), x0 = 0x801fb74, x1 = 0x1f437c, x2 = 0x1f53d4 (== x20), x3 = s7, x4 = 4. So display-loop was reached by a tail call through x19 (x19 still holds the target and lr still holds the caller's own link), and pp already held a Symbol address before display-loop ran.
2026-09-22 (G1.18, CALLING SITE DECODED): the gkernel code at +7336 is a guarded .ret of the applied A1.8 shape (mov x16,x30 / ldr x30,[sp] / mov x17,x30 / lsr 32 / mov x9,x17 / sub x9,#9 / asr / mov x10,#0 / sub / orr / asr / and / mov x2,x30 / sub / and / mov x30,x16 / add x30,x30,x2 / ret - byte-identical to the new compiler output, confirming the 8 guarded sites ship it). +7340/+7344 are padding (udf #0x0 and an undecodable word), so lr = +7348 cannot be a blr continuation: it is the caller's own link register, i.e. gkernel entered display-loop with a tail call (br through x19). The next function starts at +7348 and is a GOAL method dispatch ((-> pp -4) type tag, (-> type 0x38) method, then blr).
2026-09-22 (G1.18, NEXT): the corruption is upstream of display-loop: pp (x20) already held a Symbol address (0x1f53d4) at display-loop's entry, so find the GOAL code that set pp from a Symbol-window value (and the tail call into display-loop). Break at main+0x7da4 (the disp load into x19) and at main+0xa328 in the same run to see whether x19 is already wrong there, and break on the gkernel tail-call site to name its caller.
2026-09-22 (G1.18 + A1.7 SAME ROOT, FRESH REPRODUCER): the fresh run (pid 78652) hit the A1.7 font crash instead of the oracle-serve variant - EXC_BAD_ACCESS at ottsel_module_font_s0_code+26724 'str w5, [x16]' with x16 = arena+4 (the low page), x0 = x5 = x25 = 0 (the null dma-buffer argument), lr = ottsel_module_main_s0_code+45200 = main+0xB090 = main.gc:513 (display-loop calling draw-string), x19 = 0x10962be10 (a stack address, NOT disp), x20/pp = 0. That is byte-for-byte the A1.7 crash the trampoline guard was supposed to close, so both the oracle-serve variant and this variant reduce to one cause: x19 (the display object) is clobbered inside display-loop before display code uses it. The A1.7c guard restores x19 across the counted GOAL->C boundaries (_arg_call_arm64/_stack_call_arm64, four C->GOAL bridges, mips2c), so the surviving clobberer is a boundary or a GOAL store that none of those cover.
2026-09-22 (NEXT - BISECT x19 INSIDE display-loop): with a hardware breakpoint at display-loop's entry (main seg0 +0x7d24), at the disp load (+0x7da4), and at the draw-string / draw-progress call sites, read x19 at each and bisect to the call that leaves it wrong; the run that crashed is a clean reproducer (the app is held at that fault after detach). Then land a source-level fix plus a regression and verify with two clean strict runs.
2026-09-22 (G1.18/A1.7, x19 WRITE SITES): disassembling display-loop's whole body (main+0x7d24 onward, 3400 instructions covering past the +0xa328 fault site and the +0xb08c draw-string call) shows exactly ONE write to x19 in the entire function: 'mov x19, x0' at main+0x7da4 (the entry load of the display argument); everything else is a read (mov x0,x19 / add x3,x3,x19). display-loop's prologue saves x19 (str x19,[sp,#-0x10]! at +0x7d24). So the compiler keeps the display object in x19 for the whole function and x19 can only change through a callee that fails to preserve it.
2026-09-22 (G1.18/A1.7, SPLIT): at the font crash x19 = sp+0x200 (a frame-local address, not the display object). Together with the single write site there are exactly two explanations: (a) x0 was already wrong at +0x7da4, i.e. the call at main+0x7d70 (the first blr, which runs before the load) failed to preserve x0 - x0 is caller-saved but the emitted sequence appears to expect it - or (b) some callee between +0x7da4 and the draw-string call clobbers x19. Measured x0 at display-loop's ENTRY was 0x801fb74, so the discriminator is to break at main+0x7da4 and read x0: unchanged means (b), changed to a stack address means (a). Then land a source-level fix plus a regression and verify with two clean strict runs.
2026-09-22 (A1.7/G1.18, DISCRIMINATOR ANSWERED - CASE (b)): hardware-breakpointed display-loop's single x19 write in a fresh run (main+0x7da4 'mov x19, x0', main host base 0x10b5ac000). x0 there = 0x509d34, which is exactly the *display* value the a17 probe reports, so the load of disp into x19 is CORRECT and case (a) (a corrupted x0 at the load) is refuted. At the entry x0 was 0x801fb74 and the first blr (main+0x7d70) reloads it from the *display* symbol before +0x7da4. Therefore a callee between +0x7da4 and the draw-string call leaves x19 changed - case (b) - and the first call after the load is at main+0x7e20.
2026-09-22 (NEXT - BISECT BY CONDITIONAL BREAKPOINT): set breakpoints on the blr sites between main+0x7e20 and main+0xb08c with the condition $x19 != 0x509d34 (lldb accepts conditions, and software breakpoints are safe here because validate_layout ran at boot). The first hit in program order is the first call reached with a wrong x19, so the preceding call is the clobberer. That names the boundary, then a source-level fix plus a regression and two clean strict runs.
2026-09-22 (A1.7/G1.18, SOFTWARE BREAKPOINTS INVALID): setting 109 software breakpoints on __GOAL text (main+0x7e20..+0x7ebc, conditioned on x19 != 0x509d34) made the loader abort: validate_layout/protection runs at boot AFTER the breakpoints are installed, so its page-protection check fails and the app dies with SIGABRT before display-loop. Hardware breakpoints (or post-boot inspection only) are required on this lane - a limit worth remembering for every future bisection.
2026-09-22 (A1.7/G1.18, LAST BOUNDARY VERIFIED, CONCLUSION CHANGES): scripts/test-goal-bridge-regfile.py now simulates _mips2c_call_arm64's stack offsets as well (modeling 'sub sp, sp, #n' for the 1280-byte ctx and the stub's 32-byte entry slack, ENTRY_SLACK[_mips2c_call_arm64]=32). It PASSes, so all six GOAL<->C boundaries (_arg_call_arm64, _stack_call_arm64, _mips2c_call_arm64 and the four C->GOAL bridges) are machine-verified LIFO-balanced and none of them can be the clobberer. Combined with display-loop writing x19 exactly once (correctly, from the *display* value) and the crash x19 being the faulting frame's sp+0x200, the remaining explanation is a GOAL callee that writes x19 without saving it - a codegen/emitter defect in a signed module, not a trampoline bug.
2026-09-22 (NEXT): add a static check over the emitted signed modules for functions that write x19 without a matching prologue save (and whose body does not restore it), starting with display-loop's callees; that yields the exact function and offset to fix, then a regression and two clean strict runs.
2026-09-22 (A1.7/G1.18, WHERE THE CODE COMES FROM): tools/ottsel_a1_1/a11_module_emitter.h is only 387 lines and contains no register-save, prologue or epilogue logic and no reference to x19 at all. So the signed modules' instruction streams - prologues, GOAL register-file saves, call shims, .ret sites - are copied and relocated from the goalc-produced out/jak1/obj/*.o, not synthesized by the emitter. A 'writes x19 without saving it' defect must therefore already exist in those objects.
2026-09-22 (A1.7/G1.18, OBJECT STALENESS IS THE NEXT TEST): goalc's rebuild decision is source-content based, and (mi) reports 'all 546 targets' in about 9 s, which is consistent with a checked set rather than 546 real compilations - so objects compiled by an earlier compiler revision can survive a compiler change (the A1.8 change altered only IR.cpp, which no .gc file references). Experiment: move out/jak1/obj aside, run goalc --game jak1 --isa arm64 -c "(mi)" for a genuine full recompilation, rebuild the app, and run twice. If the x19 clobber disappears the objects were stale; if it persists, the discipline defect is in current goalc output and the next step is to identify the specific clobbering callee (static x19-write scan over the emitted modules, or a hardware-breakpoint bisection with 4 sites per run).
2026-09-22 (A1.7/G1.18, FORCED FULL RECOMPILE - STALENESS REFUTED): moved out/jak1/obj aside (1039 files, 237 MB, kept at /tmp/ottsel-obj-backup-1790070218) and ran goalc --game jak1 --isa arm64 -c '(mi)' for a genuine full recompile: 'Successfully built all 1068 targets in 10.451s', 518 fresh .o files. Rebuilt the app with OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 OTTSEL_SIGNED_MODULE_LIST=config/signed-game-cgo-tit-vi1-control.json OTTSEL_SIGNED_EXPORT_BANKS=1 (exit 0) and confirmed all 8 guarded .ret sites still carry the A1.8 window test after the recompile (aligner 1, gkernel 6, gstate 1 - so the guard is not object-staleness dependent). The strict run then reproduced the IDENTICAL fault: pc = main+0xa328 (0x10bffe328), lr = 0x181674, GOAL offset 0x88ba328, 32 LINKBEGIN. Object staleness is therefore refuted: the x19/return-slot corruption comes from current goalc output or from GOAL source semantics, not from stale objects.
2026-09-22 (A1.7/G1.18, NEXT - NAME THE CLOBBERING CALLEE): the (a)/(b) split is already resolved to (b) - display-loop's single x19 load is correct - and the trampolines/bridges are all machine-verified. What remains is naming the callee that leaves x19 wrong between main+0x7da4 and the draw-string call. Use hardware breakpoints only (software breakpoints on __GOAL text abort the loader), four sites per run, bisecting the blr sites listed in /tmp/blr_main.txt (110 total, 109 after the load); or scan the emitted modules for a function whose prologue does not save x19 while its body writes it. Then a source-level fix plus a regression and two clean strict runs.
2026-09-22 (A1.7/G1.18, SHIPPED BINARY VERIFIED): disassembled the installed app directly (otool -arch arm64 -tV) to check that last session's trampoline-ordering fix is really in the artifact, not just the source. _stack_call_arm64 at 0x1001c0770 ships the corrected order: prologue stp q15,q14 / stp x19,x23 / x24,x25 / x26,x27 / str x28 / stp q13,q12 / q11,q10 / q9,q8 / arg array, and the epilogue pops ldp q9,q8 / q11,q10 / q13,q12 / ldr x28 / x26,x27 / x24,x25 / x19,x23 / q15,q14 / x29,x30 then ret - the exact reverse, with the A1.7b counters present. So that boundary is correct in the shipped binary as well as in source and regression.
2026-09-22 (A1.7/G1.18, NEXT - SCAN MODULE CODE FOR AN UNSAVED x19 WRITE): with all six asm boundaries now verified in source, in regression and (for _stack_call_arm64) in the binary, the remaining candidate is a goalc-produced function in a signed module that writes x19 without saving it. Next step: disassemble each emitted module's text and flag every x19/w19 write that has no enclosing prologue save since the nearest preceding ret (function boundary), starting with main and its callees; that yields the exact function and offset, then a source-level fix plus a regression and two clean strict runs.
2026-09-22 (TOOLING NOTE): otool -tV disassembles only __TEXT,__text, so it cannot reach the signed modules' code (they live in __GOAL,__text). Scanning module code statically therefore has to go through lldb's disassembler on a live process ('disassemble --start-address <module base> --count N'), or through a raw ARM64 decoder over 'otool -s __GOAL __text'. The tm, w19 write/unsaved-save scan script should read that lldb output.
2026-09-22 (A1.7/G1.18, MAIN IS ABI-CLEAN - CLOBBER IS OUTSIDE MAIN): disassembled main's whole seg0 through lldb on the live app (83592; app base 0x102de4000, main seg0 base ee+0x88b0000 = 0x10bff4000, 12288 instructions = 0xc000 bytes) and scanned for x19/w19 destination writes with no enclosing prologue save since the nearest preceding ret: 84 x19 writes, all 84 inside a save, zero unsaved. So every function in main saves x19 before using it, display-loop included, and the clobberer cannot be a main function. Since the six asm boundaries, the trampolines and the objects are all cleared too, the remaining candidate is a NON-main function that display-loop reaches through a slot (another signed module, a streamed/legacy object, or a C/asm path).
2026-09-22 (NEXT - SCAN THE OTHER MODULES): repeat the same lldb disassembly + save scan for the modules display-loop calls into, starting with gkernel (it is in the chain and is the kernel's asm-func carrier) and the loading-screen path (progress, gsound, dgo/rpc-h), naming any function whose body writes x19 with no enclosing save. Then a source-level fix, a regression, and two clean strict runs.
2026-09-22 (A1.7/G1.18, MODULE SCAN + TAIL-CALL CONVENTION): ran the same lldb disassembly + save scan over gkernel, progress, gsound and rpc-h. Results: progress 66 writes/0 unsaved, gsound 60/0, rpc-h 17/0, gkernel 75 writes with 5 heuristic flags - and all 5 gkernel flags are false positives from resetting the save state at ret: three are 'ldr x19, [sp], #0x10' restores that follow the guarded .ret sites, and 'mov x19, x0' at gkernel+0x6aa8 is a normal assignment. So no signed module scanned has a genuine unsaved x19 write.
2026-09-22 (A1.7/G1.18, TAIL-CALL CONVENTION FOUND - EXPLAINS x30): decoding gkernel+0x7b38..0x7b5c shows this port's GOAL tail call: 'ldr w0, [slot]' (the symbol value) / 'add x0, x0, x22' / 'str x0, [sp, #-0x10]!' / 'mov x30, x0' / 'add x19, x19, x22' / 'br x19'. So a tail-called GOAL function starts with x19 = its own entry address (the branch register) and x30 = the caller continuation - exactly what the earlier entry measurement showed at display-loop (x19 = the entry, x30 = 0x181674). Therefore the 0x181674 in x30 is a CALLER CONTINUATION value: some thunk set x30 from a slot whose value is a GOAL offset (0x181674 = a Symbol address) instead of a host code address, which is precisely the objective's 'GOAL data used as a code target'. Next: find the thunk that tail-called display-loop (the caller is gkernel code whose lr was gkernel+0x1cb4 / +0x1cb4-0x1c) and check how it computes x30 - the mov x30, x0 shape above suggests either a symbol whose value is data or a missing +ee.
2026-09-22 (A1.7/G1.18, x30 WRITE SITES IN gkernel; GUARD CONFIRMED IN THE ARTIFACT): scanned every instruction in gkernel's first 0xc000 bytes that writes x30. Only two shapes appear: (1) the A1.8 guard epilogue 'mov x2,x30 / sub x2,x2,x16 / and x2,x2,x9 / mov x30,x16' at SIX sites (gkernel+0x7316, +0x7512, +0x8376, +0x27240, +0x27588, +0x32860) - an independent confirmation that the six gkernel guarded .ret sites ship the A1.8 window guard in the installed app; and (2) the correct tail-call thunk shape 'ldr w0,[x16] / add x0,x0,x22 / str x0,[sp,#-0x10]! / mov x30,x0' at +0x7712 and +0x31544, which dereferences the slot and converts to a host address. No thunk in that region computes x30 from a symbol offset without the +ee/deref, so the missing-dereference shape is not there.
2026-09-22 (A1.7/G1.18, NEXT - LOCATE THE 0x181674 SOURCE): at display-loop's entry x30 was a CODE address (gkernel+7348) yet the crash frame reports x30 = 0x181674 (a GOAL symbol-table address), so x30 became data somewhere inside the display path rather than at the entry. Next: (a) scan the remaining modules and main for x30 writes (not only mov x30,xN - include ldr x30,[...], the .ret slot reads, and the shim pushes) and (b) search the GOAL symbol-table region for any slot whose value is 0x181674, since a symbol whose value is data is the exact shape the objective describes ('signed GAME text calling into the module-arena data region').
2026-09-22 (A1.7/G1.18, SYMBOL-VALUE HYPOTHESIS REFUTED): 'memory find -e 0x181674' over the GOAL symbol-table region (ee+0x100000..ee+0x1a0000, ee = 0x103744000 in the current run) found nothing, so no symbol's value is 0x181674. 0x181674 is the village-cam Symbol's OWN address, which emitted code produces transiently as 'slot + s7' (the intermediate of a symbol_offset slot read, before the '+ee' and 'ldr w,[x16]' deref). So the leak is code that consumes that intermediate as a function/continuation without the '+ee' and dereference pair - a missing-dereference shape rather than a bad symbol value.
2026-09-22 (A1.7/G1.18, main x30 WRITES CLEAN): every x30 write in main's first 0xc000 bytes is the normal post-call shim restore ('ldr x17,[sp],#0x10 / ldr x30,[sp],#0x10') or a guarded epilogue return; there is no 'mov x30, xN' fed from a slot in that region. Next: search the emitted modules for the missing-dereference shape - an 'add xN, xN, x21' (s7-relative) followed closely by 'mov x30, xN' or a branch/br using it, i.e. a slot value consumed without the '+ee' plus 'ldr w,[x16]' pair; a Python driver over lldb disassembly of all 335 modules can do it, starting with the streamed/level modules and font (the crash frame).
2026-09-22 (A1.7/G1.18, PATTERN-SCAN ATTEMPTS + TOOLING CORRECTION): three word-level scans over the emitted .s files were tried and none is trustworthy yet. (1) 'add xD,xD,x21 without a following x22 add' returned 5105 hits - too loose, because that arithmetic is ordinary GOAL use of s7 in x21, not a slot read. (2) Restricting to a preceding 'ldrsw xD,[slot]' returned 49639 hits, because the emitter emits this s7/ee arithmetic pervasively and my deref window was one instruction too small (the correct shape continues 'add xD,xD,x22 / eor x17,x17,x17 / mov x16,xD / add x16,x16,x17 / ldr wK,[x16]'). (3) Filtering on the rare tail-call form 'add x19,x19,x22' returned 0 sites, which contradicts the live disassembly at gkernel+0x7b58 - and the reason is a tooling fact: gkernel.s holds only 15058 .long words plus SYMBOLIC instructions (the adrp/add pairs are textual), so a .long-only scan both mis-maps indices to offsets and MISSES any symbolically emitted instruction. Module code must therefore be scanned through lldb disassembly, which is uniform, not through the .s words.
2026-09-22 (A1.7/G1.18, NEXT): redo the missing-dereference search over lldb disassembly (one pass per module: 'disassemble --start-address <ee+module offset> --count N'), looking for a slot value that reaches a branch or x30 without the '+x22' and 'ldr wK,[x16]' pair - specifically any 'add x19, x19, x22' (tail-call branch register) whose x19 came from a raw slot rather than a dereferenced symbol value, and any 'mov x30, xD' fed from an s7-relative load. The .s-word approach is retired.
2026-09-22 (A1.7/G1.18, DISPATCH-THROUGH-x19 IS THE OBJECTIVE'S SHAPE): decoding the gkernel tail-call thunk at +0x7b14..+0x7b5c end to end shows the port dispatches through x19 with an inherited value: the thunk loads a slot, dereferences it, adds s7 and ee, reads the symbol VALUE, adds ee, pushes it and sets x30 to it, then does 'add x19, x19, x22 / br x19' WITHOUT ever setting x19 itself. So x19 is the caller-supplied dispatch target offset; if a caller passes a DATA offset (a Symbol address rather than a function offset) the thunk branches to arena+offset, i.e. straight into the module-arena data region. That is exactly the objective's 'signed GAME text calling into the module-arena data region' with x20/pp=0, and it also explains the measured display-loop entry state (x19 = its own entry because the thunk had already added ee). The defect is therefore a CALLER that computes the x19 dispatch target from a raw slot value without the 'ldr wK,[x16]' dereference.
2026-09-22 (A1.7/G1.18, NEXT - FIND THE RAW-SLOT DISPATCH): search lldb disassembly (not the .s words) for the dispatch callers: a sequence that sets x19 from an s7-relative slot load ('ldrsw xD,[slot] / add xD,xD,x21') and then branches or calls through x19 WITHOUT the '+x22' plus 'ldr wK,[x16]' dereference pair in between; the gkernel thunk at +0x7b58 is the model of the correct tail-call and it never sets x19, so the bad value comes from the code that reaches it.
2026-09-22 (A1.7/G1.18, DISCRIMINATOR BETWEEN THE TWO x19 SHAPES): scanning lldb text disassembly of gkernel, main and progress for 'add x19, x19, x22' shows two distinct shapes. (i) The SLOT-READ sequence, pervasive in main and progress: 'adrp x19,<slot> / add x19,x19,#off / add x16,x19,#0 / ldrsw x19,[x16] / add x19,x19,x21 / add x19,x19,x22 / eor x17,x17,x17 / mov x16,x19 / add x16,x16,x17 / ldr w19,[x16]' - here x19 is the slot ADDRESS and the value is dereferenced, so it is correct. (ii) The DISPATCH form, found once (gkernel+0x7b58): 'str x0,[sp,#-0x10]! / mov x30,x0 / [args] / add x19,x19,x22 / br x19' with NO dereference in between - x19 here is the caller-supplied dispatch target, so a data offset makes it branch into the arena data region. The discriminator is therefore an 'add x19,x19,x22' followed by 'br x19' with no 'ldr w19,[x16]' deref between them.
2026-09-22 (A1.7/G1.18, NEXT): enumerate the dispatch-form sites ('add x19,x19,x22' + 'br x19', no deref) across ALL modules via lldb disassembly, then for each find the callers and where they set x19 - the bad caller sets it from an s7-relative raw value with no deref. Only then a source-level fix, a regression and two clean strict runs.
2026-09-22 (A1.7/G1.18, MODULE MAPPING CONFIRMED - .s OFFSETS UNRELIABLE): verified the module base mapping directly: the first eight words of emitted gkernel.s (0x1bfec4, 0xd65f03c0, 0, 0, 0x1bfec4, 0xf81f0ff3, ...) match the live memory at 0x10B75C000 exactly, so the base (image lookup on ottsel_module_gkernel_s0_code + slide) is right and the emitted .s does correspond to the running code. But the .s holds only 15058 .long words PLUS symbolic instructions (its adrp/add pairs are textual, and neither 'br x19' nor 'add x19, x19, x22' appears as text or as the expected .long), so a code offset derived from a .long index is WRONG and symbolic instructions are invisible to word scans. Consequence: any offset in my earlier notes computed from .s word indices (notably the guard-site offsets 0x1954/0x1a10/0x1d48/0x6120/0x627c/0x75d4 recorded for gkernel) is unreliable; the lldb '<+N>' offsets are the trustworthy ones, and the live guard epilogues were seen at gkernel+0x7316, +0x7512, +0x8376, +0x27240, +0x27588, +0x32860.
2026-09-22 (A1.7/G1.18, x19'S BAD VALUE IS A FRAME-LOCAL ADDRESS): at the font crash x19 = the faulting frame's sp + 0x200 (measured: x19 = 0x10962be10 with the fault sp = 0x10962bc10 in that run), i.e. a stack-slot address rather than any GOAL object. Combined with the static result that display-loop writes x19 exactly once (correctly, from the *display* value), the clobbering callee must be code that puts an sp-derived address into x19 and then fails to restore the caller's value - the classic frame-pointer style store. This is a specific, searchable clue: look for 'mov x19, sp' / 'add x19, sp, #imm' / a restore of x19 from a slot that holds an sp-derived address, in the modules on display-loop's call path.
2026-09-22 (A1.7/G1.18, NEXT - MECHANICAL BISECTION): the fastest way to localise it is a hardware-breakpoint bisection of x19 inside display-loop, which needs no further static guessing: put four hardware breakpoints at spread sites in main (for example +0x7da4 as the known-good control, +0x8c00, +0x9d00 and +0xb08c the draw-string call) each conditioned on '\$x19 != 0x509d34', continue once, and read x19 at the first that fires. That halves the search each run; two or three runs localise the clobbering call, then a source-level fix, a regression and two clean strict runs. The 110 blr sites for the range are already listed in /tmp/blr_main.txt.
2026-09-22 (G1.18/A1.10, ROOT-CAUSED + FIXED, display-loop class retired): display-loop's x19 was never clobbered inside the function.  The loop-end (suspend) at main+0xbf08 returned into its own continuation main+0xbf0c through thread-suspend's guarded .ret: the guard's slot held 0x00000050ffffffff (a GOAL frame local), the A1.8 window test correctly rejected it, and the fail-safe fell back to the incoming x30 - which for an asm-func entered by a GOAL call is the caller's link register, not the kernel's return address - so the loop resumed with the kernel's register file (pp=0, x19 = a kernel-stack address) and faulted at the next x19 use.  Breakpoint traces show thread-resume running for every good dispatch and not at all for the failing one.  thread-suspend returns by reading [*kernel-sp* + 0x50], exactly where its five .pop s4..s0 end - a slot that only holds a continuation when the kernel left a GOAL synthetic there; measured, it can hold plain frame data (x30 at thread-resume's entry is the real continuation, gkernel+23892).  Fix: thread-resume and reset-and-call push their incoming x30 as the first kernel slot, and thread-suspend/return-from-thread/-dead pop that sixth slot into lr and leave with (.jr lr).  Overlay patches/a11-kernel-continuation-slot.patch (snapshot of goal_src/jak1/kernel/gkernel.gc, reverse-applies cleanly).  Evidence: docs/evidence/A1/a11-kernel-continuation-slot-2026-09-22.md.
2026-09-22 (A1.10, VERIFIED): goalc -c '(load-project "goal_src/jak1/game.gp") (mi)' exit 0 (objects rewritten) and the strict signed-GAME build exit 0; the shipped __GOAL,__text carries the new prologue at exactly two sites (reset-and-call, file 0x108979dac; thread-resume, 0x10897a0d4).  A fresh strict run serves all 15 DGO objects (title-vis last), links the level, reports OTTSEL TEX REMAP and runs 6131+ display frames at drawn=0, where before it lost x19 inside its first four loop iterations.  The display-loop x19 class is retired.
2026-09-22 (A1.10, FIRST ATTEMPT REGRESSED - NOT SHIPPED): pushing the sixth slot without a matching sixth pop left the kernel stack 0x10 below each dispatch and the run died in a stack-guard region ~2 minutes in; the shipped form pops the slot and returns with .jr lr so the kernel resumes at exactly the sp its caller left.
2026-09-22 (NEXT GATE, pp=0 class still open): a later .ret still targets a GOAL data address with pp=0 - pc = lr = ee + 0x7fffe10 (the *kernel-sp* symbol slot), fault frame gkernel+0x60a8 - the documented A1.1 "GOAL data used as a code target" class.  Two clean strict runs are not yet achieved, so this class stays open; the trampoline guard, its regression, the A1.7b counter, the A1.8 window guard and the A1.9 probe stay in place.
2026-09-22 (A1.11, ROOT-CAUSED + FIXED - the ret window accepted a GOAL stack address): with the A1.10 stash in place the display class was gone and the loop ran 6131+ frames, but the run then died on the boot/loader thread at pc == lr == ee + 0x7fffe10 (a GOAL *stack* address), pp = 0, x19 = the address of the string "village-cam", sp = pc - 0x20. The A1.8 keep-test (slot >> 32 in [1,8]) accepts any host address, so a frame slot holding a stack address was kept and `ret` left the image; the A1.10 stash was populated correctly (thread-resume's entry x30 is the kernel continuation), so the escape was the window. Fix: IR_AsmRet::do_codegen_arm64 now keeps a slot only inside the module block [x22 + 0x8000000, x22 + 0x8c30000) (ee = x22; ~0xc205c0 bytes of emitted modules), so the GOAL heap, module data, app image/stubs and every stack fall back to the incoming link register; the A1.10 stash stays and the suspend-side asm-funcs went back to five pops plus the guarded .ret, which now keeps the stashed module continuation when it is real code and rejects a stashed stack address (the thread-start path then falls back to its trampoline). Overlays regenerated: patches/a11-asm-ret-fail-safe.patch (verify-asm-ret-guard-patch PASS) and patches/a11-kernel-continuation-slot.patch. Evidence: docs/evidence/A1/a11-ret-window-stack-2026-09-22.md.
2026-09-22 (A1.11, VERIFIED): libcompiler.dylib rebuilt (cmake --build out/jak-project/build/h1 --target ottsel-a11-slice), goalc (mi) exit 0, strict build exit 0; a byte scan of out/jak1/obj/*.o shows all 8 guarded sites (aligner 1, gkernel 6, gstate 1) carry the new window constants and the old A1.8/A1.6 words (mov x10,#0, lsr x17,x17,#32) are gone. The guard regression now mirrors the new sequence with ee as an argument and covers 14 cases: module slots kept (ee+0x8018000, ee+0x8810000), low bound inclusive, high bound exclusive, and the measured escapes rejected - ee+0x7fffe10 (the A1.11 stack address), the module-data slot ee+0x3db9940, the heap slot ee+0x13fd20, an app-image address, 0x181674 and 0x50ffffffff - plus the zero-link 'no address invented' cases. bash scripts/test-a11-asm-ret-guard.sh PASS. A fresh strict run serves all 15 DGO objects (title-vis last), links the level, reports OTTSEL TEX REMAP and keeps the display loop alive at drawn=0.
2026-09-22 (A1.11, NEXT - the objective's class is still open): the lane is back at the documented G1.18 blocker: executing signed gkernel text at gkernel+0x55e4 with pp = 0 and x0 = 0x5f746c75 ("ult_", a static string read as a GOAL object) - the A1.1 `ldr w1,[x0,x22]` 'GOAL data used as an object' class in the loader/execute-process-tree path. Two clean strict runs are still not achieved; the trampoline guard, its regression, the A1.7b counter, the A1.8/A1.11 window guard and the A1.9 probe all stay in place.
2026-09-22 (A1.12, fault site and clobber class named): the post-A1.11 fault is `execute-process-tree` (gkernel GOAL entry 0x54a4, nearest-symbol offset 0x801d4a4) at entry+0x140 = `ldr w1, [x0, x22, sxtx]` (file 0x10897D5E4, word 0xB876E801, matching the recorded gkernel+0x5554 site), fault addr = ee + x0 with x0 = 0x5f746c75 (the ASCII bytes "ult_"). The live code shows the shape: a pool/lambda walk loop at entry+0x140..+0x1b0 whose object comes from `*(x24 + ee + 0x10)` and whose back-edge is `b.ne <loop>`; x24 is a GOAL saved register (s3) and at the fault it holds 0x10d3695ac = the *return address of the indirect call at entry+0x104* (`mov x16, x19; ... blr x16`), while x19 holds 0x3db0fb4 (*kernel-context*) and x20 (pp) is 0 - i.e. callee-saved GOAL registers come back from that indirect call holding the call's own continuation/context instead of their pre-call values (the September-22 note recorded the same for x19/x23). A static gkernel scan for written-but-unsaved callee-saved registers found no genuine offender in that function, so the defect is a save/restore imbalance across the call (a callee that saves but restores from the wrong slot), not a missing prologue save.
2026-09-22 (A1.12, NEXT): chase the callee of the indirect call at execute-process-tree+0x104 (x19 + ee) and its register-frame save/restore balance, then a source-level fix plus a regression over the emitted code; two clean strict runs are still required before the objective's pp=0/data-target class can be retired.
2026-09-22 (A1.12, frame-level ground truth for the pp=0 data fault): held a fresh strict run under lldb at the fault (pc = gkernel+0x55e4 = entry 0x54a4 + 0x140, `ldr w1,[x0,x22,sxtx]`, fault addr = ee + x0, x22 = ee, x20/pp = 0). `execute-process-tree`'s prologue is `str x19/x23/x24/x25/x30` (5 slots, so [sp]=x30, +0x10=x25, +0x20=x24, +0x30=x23, +0x40=x19) and it maps arg0->x24, arg1->x19, arg2->x23; its two calls are at entry+0xb8 (x16 = a method slot of arg0's object) and entry+0x104 (x16 = x19, the arg1 function). Reading the frame at the fault: the SAVED slots are intact (x30 = gkernel+0x5640, x25 = a host address, x24 = s7+8, x23 = s7/#f, x19 = *kernel-context*) and the repetition of gkernel+0x5640 through [sp+0x60]/[sp+0x70]/[sp+0x80] shows a deep chain of recursive frames all entered from the call at entry+0x19c whose continuation is +0x1a0. So the live x24 (0x10b7bd5ac = the entry+0x104 call's own continuation) and the nonsense entry values mean the arguments handed to this walk are already wrong when the invocation starts: arg0 reads as s7+8 and arg1 as *kernel-context* - the September-22 'rotated argument group at the indirect-call edge' hypothesis, now measured at the register level. The producer is therefore upstream of the faulting frame (the argument setup of the recursive call at entry+0x19c / the first invocation from the loader), not a missing prologue save in this function.
2026-09-22 (A1.12, NEXT): trace the argument setup of the recursive site (entry+0x19c, `x0 = *(x0+ee)` from the walk object, x1 = x19, x2 = x23) back to the first `execute-process-tree` activation from `call_goal_on_stack_asm_arm64` in `signed_gstate::link`, and find where arg0/arg1 stop being the tree/lambda; then a source-level fix plus a regression and two clean strict runs.
2026-09-22 (A1.13, PRODUCER FOUND - the A1.10 stash leaks one kernel-stack slot per suspend): a hardware breakpoint on `execute-process-tree`'s entry (gkernel+0x54a4) with live arguments shows the walk being entered correctly four times - ET#1 (x0=0x4f4504, x1=0x801d7b4, x2=0x3db0fb4 = tree/pool, func, *kernel-context*), ET#2 (x0=0x4f45a4), ET#3 (x0=0x1f4364) - and then ET#4 with the group *rotated*: x0=0, x1=0x3db0fb4 (the *context* in the func slot), x2=0x1f4364 (the previous arg0), pp=0. A breakpoint on the function's own call site (gkernel+0x55a8) shows it calls gkernel+0x57b4 (via x16 = x19 + ee) with x0=0x1f4364, x19=0x801d7b4, x23=0x3db0fb4 - and that callee's prologue is `str x19/x23/x24/x30` (4 slots) then `mov x19, x0`, i.e. a normal goalc-emitted frame. The mechanism that explains the rotated group is the A1.10 stash: `thread-resume` now pushes SIX kernel slots (its incoming x30 plus s0..s4) and points *kernel-sp* at the six-push level, while `thread-suspend` still pops five and returns through the guarded .ret, so after every dispatch the kernel resumes with sp = *kernel-sp* + 0x50 = entry_sp - 0x10: the kernel's stack is left 0x10 LOW and drifts by 0x10 on every suspend/resume, so after minutes of dispatches the kernel frames shift and read each other's slots, which is exactly the stale/rotated argument group measured here (and why the pp=0 data fault appears only late and deep in the recursion).
2026-09-22 (A1.13, NEXT - two balanced shapes, then two clean runs): either (a) pop the sixth slot too and jump through a *validated* value (the module-block window must decide, so the guard needs a way to test the popped register rather than [sp]) or (b) do not push an extra slot at all: have thread-resume/reset-and-call write their incoming x30 over the caller's synthetic slot at [entry_sp] (a normal GOAL call only pops and discards it, so that is harmless) and leave the suspend side at five pops plus the guarded .ret. Both keep sp == entry_sp and need a regression over the emitted epilogues; then two clean strict runs before the objective's pp=0/data-target class can be retired.
2026-09-22 (A1.13, LANDED - the kernel stack is balanced): the three suspend-side asm-funcs pop the resume side's sixth (A1.10 stash) slot into x30 before the guarded `.ret`, so sp lands on the caller's resume point instead of 0x10 low and the drift is gone; the stash doubles as the `.ret` fallback. Guards: `scripts/verify-kernel-continuation-slot.py` (source tails + exactly three emitted guarded `.ret` sites preceded by `ldr x30,[sp],#16`), overlay `patches/a11-kernel-continuation-slot.patch`.
2026-09-22 (A1.14, ROOT CAUSE FOUND AND FIXED - the kernel stack was shared with C->GOAL activations): the post-A1.13 strict fault was `pc = lr = fault addr = ee + 0x7FFFE10` (the kernel stack top) with SIGBUS right after `served obj 1 (oracle)`. Live read at the fault: x16 = x30 = the stack address (the `.ret` fallback), x9/x10 = the guard's module-block bounds, x11 = x12 = 0 (slot rejected), `[sp] = 0x00000050ffffffff` and the stash below it a stack address; `*kernel-sp*` = ee + 0x7FFFD90, so the six resume slots live at [ee + 0x7FFFD90, ee + 0x7FFFDF0]. The kernel (kboot's goal_stack) and every C->GOAL activation (klink's `link_and_exec`, the signed loader) anchor at the SAME top-of-EE address, and the deep signed villagep-obs type/method install (~0x1e0 frames) ran while the kernel was suspended and overwrote those slots. Fix: kboot anchors the kernel 64 KiB below the top (`kActivationStackReserve = 0x10000`); overlay `patches/a11-kernel-stack-separation.patch`, guard `scripts/verify-kernel-stack-separation.py`, evidence `evidence/A1/a11-kernel-stack-separation-2026-09-22.md`.
2026-09-22 (A1.14, VERIFIED - two clean strict runs, pp=0/data-target class retired for the strict lane): both runs have a 0-byte fault log, serve all 55 village1 DGO objects, reach `LINKBEGIN: name=oracle` + `signed took oracle`, balance 346 ENTER = 346 RETURNED, and report `scene-level='village1'` (cam-accepted 4138/3373, 0 rejects, merc-submits 10525/9684, eichar=4) with `DIRECT FRAME ... drawn=44` and `SPRITE FRAME ... drawn=23`; screenshots show the title screen with its rendered village background. NEXT (I0/I1): the title -> New Game -> Village1 -> Training route with real input, then the renderer items (ALPHA 0x48 additive clouds, dynamic eyes), I2 audio/lifecycle/saves, I3 frontend, P1 iPhone, D1 devices. Visible gameplay/audio/lifecycle are NOT claimed; the host build shares the kboot change and has not been re-run there.
2026-09-22 (STAGE 0 GREEN, post-fix baseline reconciled): preflight 64 GiB free / 0 `tmp_pack_*`; the three Stage 0 commands PASS for this source - `test-metal-encoder-guard.sh` (encoder scope, explicit end, unwind, exactly-once, nil), `test-link-begin-args.sh` (6 malformed/valid cases), `verify-link-begin-patch.py` (pin + h3 + linker + signed-gstate reconstruct all three files) - and the supporting guards PASS in the same pass (`verify-asm-ret-guard-patch.py`, `verify-asm-synthetic-return-patch.py`, `test-a11-call-goal-asm-ret.sh`, `test-a11-asm-ret-guard.sh` 8/8 sites, `test-goal-bridge-regfile.py`).
2026-09-22 (STAGE 0, overlay reconciliation + new guard): 180 nested dirty entries, 178 covered by maintained overlays, 2 documented unreferenced strays (`--help/` stray slice output dir and the 0-byte `goal_src/jak1/kernel/aligner.gc`; `game.gp` builds `anim/aligner.gc`). Two real gaps closed with `patches/a11-diagnostic-traces.patch` (the bounded BOT62 target-position trace in `shadow.gc` and the title-screen option trace in `progress-draw.gc`, both diagnostics). New guard `scripts/verify-overlay-coverage.py` fails on any new uncovered nested source delta; the A1.14 guard now also checks the numeric invariant (reserve >= 16 KiB and 16-byte aligned).
2026-09-22 (STAGE 0, identity + stability): tested build matches the installed executable (`OttselShell` sha256 035f4d9a... in build output and in the installed bundle), `GAME.CGO` sha256 7da4305e...; profile `OTTSEL_SIGNED_GSTATE_EXPERIMENT=0`, `config/signed-game-cgo-tit-vi1-control.json`, `OTTSEL_SIGNED_EXPORT_BANKS=1`. The A1.14 run 2 is still live after several minutes of observation (0-byte fault log, `chain=2070`, `cam-accepted=17246`, 0 rejects, `merc-submits=27860`, `eichar=4`, `scene-level='village1'`). Evidence: `evidence/A1/stage0-baseline-inventory-2026-09-22.md`.
2026-09-22 (A1.15, HOST LANE REPAIRED - the macOS oracle could not be built at all): `ninja -C out/jak-project/build/h1 gk` failed at link with `Undefined symbols: _arg_call_arm64`, because the ARM64 trampolines in `game/kernel/asm_funcs_arm64.s` write eight `ottsel_cbridge_*` diagnostics that only the iOS product shell and the assembly-only test harness defined; the checked-in `gk` was a stale Aug 23 binary. Fixed: `game/kernel/jak1/kscheme.cpp` now defines the eight counters for every non-iOS build under `#ifndef OTTSEL_IOS` (no duplicate symbol on iOS). Overlay `patches/a11-host-cbridge-counters.patch`, guard `scripts/verify-host-cbridge-counters.py`. The host now links and boots the kernel.
2026-09-22 (PARITY REVIEW, measured - the iPad lane runs at 9 fps and the macOS lane is broken, not slow): the iPad game's own vsync counter advanced 180 frames in 20 s of wall time (9 fps) while ~92% of one core is busy; `sample` attributes ~41% of the main thread to the present path (`ottosel_metal_present` -> `presentRGBA:` -> `MTLSimTexture replaceRegion` -> a synchronous XPC round trip in MTLSimDriver plus the frame memmove) and ~30% to the loop's 60 Hz `SDL_SYS_DelayNS` budget, with the rest in game/renderer work, so a full drawable-sized RGBA upload per present is the biggest single lever. The freshly built macOS lane links 216 top-levels and then faults in the `IR_AsmRet` guard (`sig=11`, slot `x17` an EE value outside the module window, fallback `x16` a host address, `si_addr` in the host mapping) and stalls before the title; the same crash block exists in the Aug 23 binary, so it predates A1.13/A1.14.
2026-09-22 (PARITY LOOP WRITTEN - L0-L6): `docs/RECOVERY_GOAL_LOOP.md` now carries the macOS/iOS parity loop: L0 measurement harness (frames/s + phase wall-times from each lane's own log, one lane at a time), L1 restore the macOS oracle (A1.15 done, A1.16 next), L2 clock/loading contract (is the iPad game clock tied to its 9 fps?), L3 iPad frame-time parity (present path first), L4 visible correctness parity on matched frames, L5 route/input then I2/I3/P1/D1. Evidence: `evidence/A1/macos-ios-parity-review-2026-09-22.md`. No playability/audio/lifecycle claim.
2026-09-22 (L1, MEASURED - the macOS lane's `.ret` guard rejects every legitimate return): the host lane maps EE at 0x7000000000 and places ALL GOAL code in the "dedicated code region 0x3ebc000..0x4ee0000" (klink.cpp:45, logged once; kscheme.cpp:211 hardcodes the same band), while the `.ret` guard baked into the shared objects keeps `[sp]` only inside the iPad signed arena `[x22+0x8000000, x22+0x8c30000)` (ARENA_SIZE = 128 MB, module code offsets >= arena_size, ottsel_signed_gstate.cpp:109). Measured live at gkernel+0x6c00..0x6c48: x9 = 0x7008000000, x10 = 0x7008c30000, slot x17 = 0x7003ed79b4 (a real gkernel continuation), keep = 0, so the guard returned through x16. The deterministic fault reproduced three times: pc = gkernel seg0+0x6d54 `ldur w0,[x16,#-4]`, x16 = x24+x22 with x24 = 0x1003b95a4 = &EnableMethodSet and x23 = &s7, sp = ee+0x7fffe50, under `InitMachineScheme` (kmachine.cpp:675, right after `*EnableMethodSet = *EnableMethodSet + 1`) -> `load_and_link_dgo_from_c("game",...,true)` -> `link_and_exec` -> `call_goal_on_stack`; the enclosing GOAL function's frame holds bare EE offsets at [sp]/[sp+0x50] and none of its saved x19/x23/x24/x30, so the block was reached with x24 already the C++ value its prologue would have overwritten with #f. A1.7b counters read at the fault: calls = 70423, leaks = 5, last target jak1::print_string (kscheme.cpp:1745). Evidence: evidence/A1/macos-host-lane-ret-guard-2026-09-22.md.
2026-09-22 (L1, NEXT - one variable): emit the guard keep-test as the two lane code bands `[ee+0x3ebc000, ee+0x4ee0000)` and `[ee+0x8000000, ee+0x8c30000)` - both exclude the iPad lane's module data (measured 0x3ea8000..0x3eb8000) and the stack top ee+0x7fffe10, so a single widened range would be wrong - keep scripts/test-a11-asm-ret-guard.sh in step, re-emit with goalc, then require the macOS lane at the title with a 0-byte fault log AND the iPad lane's two clean strict runs before the class is retired.
2026-09-22 (A1.16, LANDED + both lanes verified - the .ret guard now accepts either lane's code band): IR_AsmRet::do_codegen_arm64 computes two keeps (`[ee+0x8000000, ee+0x8c30000)` iPad signed arena, `[ee+0x3ebc000, ee+0x4ee0000)` macOS no-emit region) and adds them; the clobber set is unchanged and the selector reads the slot copy so one band cannot feed the next. Overlay regenerated (verify-asm-ret-guard-patch PASS), harness now 21 cases, objects re-emitted (546 targets, 8.1 s) and all 8 guarded sites carry both bands; validate-arm64-emission.py PASS on the rewritten KERNEL.CGO; Stage 0 named checks re-run PASS. macOS lane: 3 runs, 0 crash dumps, 348 top-levels (was 216), OpenGL 4.1 window, title-wait-ready, pad reads with has-display=true - the deterministic gkernel+0x6d54 fault is gone. iPad strict lane: 2 runs, ottsel-fault.log 0 bytes, 346/346 ENTER/RETURNED, signed took oracle, scene-level=village1, drawn=44, title screen rendered. Evidence: evidence/A1/a11-ret-guard-two-band-2026-09-22.md.
2026-09-22 (L1, NEXT - one variable): the macOS lane needs its live frame counter (L0) so L2 can compare the game clock and the load-phase wall times against the iPad lane; then L2 (is the iPad game clock tied to 9 fps?) and L3 (drop the per-frame full-RGBA upload). Route/input acceptance stays behind those.
2026-09-22 (L0, LANDED - both lanes report their own cadence): the macOS lane logs `OTTSEL HOSTFRAME: frames=... wall_s=... fps=...` once every 300 rendered frames from `OpenGLRenderer::render` (the per-frame callee of `GLDisplay::render`), carried by `patches/a11-host-frame-heartbeat.patch` (a delta on top of h3, reverse-check clean, overlay-coverage guard PASS); the iPad lane keeps `OTTSEL SUBMITSTAT ... vsync=`. Measured on this machine, one lane at a time: macOS 59.91-59.93 fps steady across a 90 s run (0 crash dumps, 348 top-levels, `title-wait-ready`); iPad strict lane 270 frames / 40-41 s = 6.6-6.75 fps in the title/village window (fault log 0 bytes, scene-level=village1). Evidence: evidence/A1/macos-lane-frame-heartbeat-2026-09-22.md.
2026-09-22 (L2, NEXT - one variable): is the iPad lane's game clock tied to its 6.6-6.75 fps presentation? Measure the game's own time counters plus the boot->title, title-DGO-serve, level-link and level-active wall times on both lanes; if the clock is frame-coupled then the fix is cadence (L3, present path first), not game logic.
2026-09-22 (L2, FIRST MEASUREMENT - the lanes differ ~3x on loading but ~9x on presentation): from the logs already in hand (same machine, one lane at a time): macOS lane process start [37:18] -> `village1` linked and first pad read at [37:21], i.e. ~3 s to a live level, then a steady 59.9 fps; iPad strict lane start [57:09] -> first frame [57:09], pad read + `signed took oracle` [57:17] (8 s), `village1-vis` link [57:18] (9 s), first `scene-level=.village1.` SUBMITSTAT [57:19] (10 s), then 6.6-6.75 fps. So loading is ~3x slower on the iPad lane while presentation is ~9x slower - the lanes are not uniformly slow. What is still unmeasured is whether the iPad game clock is derived from its frame counter; the next run records the game time counters on both lanes.
2026-09-22 (L2, MEASURED - the game clock is wall-driven on both lanes, so the iPad lane is choppy, not slow): both heartbeats now carry the game's own display clock (macOS `OTTSEL HOSTFRAME ... game-base=`; iPad `OTTSEL SUBMITSTAT ... game-base=`), read from `*display*` at offsets identified by two-snapshot differencing on the macOS lane (u64 counters at 0x304..0x33c, `time-ratio` float at 0x384) and matching `(deftype display)` in display-h.gc. Mechanism: `read_ee_timer()` returns the host monotonic clock (`ns*3/10`) and `display-frame-start` advances base/game/part-frame-counter by `int(time-ratio)*time-factor`, so wall rate is 300 units/s. Measured: macOS 59.9 fps with game-base 300.0/s (time-ratio 1.000); iPad strict lane 4.74-10.0 fps (mean ~8) with game-base 299.6-337.5/s (mean ~316, time-ratio samples 4.000), 346/346 ENTER/RETURNED and 0-byte fault logs in both runs. Loading is ~3x, not ~9x (boot->active village1: macOS ~3 s, iPad ~8-10 s). Evidence: evidence/A1/game-clock-and-load-phases-2026-09-22.md.
2026-09-22 (L3, NEXT - one variable): the iPad lane presents at 4.74-10 fps while its clock is wall-correct, so the lever is the present path. Re-measure the per-frame cost breakdown under the current build (the earlier `sample` attributed ~41% to the present path - `presentRGBA:` -> `MTLSimTexture replaceRegion` -> a synchronous XPC round trip - and ~30% to the loop's 60 Hz sleep), then take the first single change: drive the frame budget from measured work instead of the fixed sleep, or stop re-uploading a full drawable-sized RGBA frame per present.
2026-09-22 (L3, BASELINE MEASURED under the current build): `sample <pid> 3` on the running iPad lane (1630 samples) puts the main thread at 864 samples in `SDL_SYS_DelayNS`/`nanosleep` (the loop waiting for the next chain, i.e. idle), 420 in `ottosel_metal_present` -> `presentRGBA:` -> `MTLSimTexture replaceRegion` - of which 268 are in `replaceRegion` and 190 inside the *synchronous* XPC round trip (`dispatchOperationWihReply` -> `sendXPCMessageWithReplySync` -> `xpc_connection_send_message_with_reply_sync` -> `mach_msg2_trap`) - and ~346 in game/renderer work.  All-thread symbol weights add `_platform_memmove` 26, `access` 37 (per-chain trigger-file probes on the DMA path) and stdio writes (`__sflush`/`__swrite`/`__write_nocancel` 11 each, the per-chain diagnostics), so the frame budget also pays for probes and logging.  Caveat: the game/EE thread did not separate in this sample (its frames resolve inside the EE image without symbols).  Candidates in order: drop/batch the per-chain `access()` probes, bound the per-chain verbose logging (keep the heartbeats), then the present path itself (no full-RGBA upload per present / persistent staging surface / measured frame budget).
2026-09-22 (L3, PROFILE + FIRST EXPERIMENT REFUTED): the game thread's 1630 samples are 1528 in `send_gfx_dma_chain`, 715 under `gfx_send_chain`, and 410 inside the synchronous `MTLSimTexture replaceRegion` sprite-texture upload (`render_mobile_sprite_group0` -> `ottosel_metal_append_sprite_mesh_n` -> `appendSpriteMeshNow:`, 319 of them in `xpc_connection_send_message_with_reply_sync`); the main thread is 864 idle in `SDL_SYS_DelayNS`, 420 in `ottosel_metal_present` -> `presentRGBA:` -> replaceRegion (190 in the same XPC), ~346 game work.  A content-addressed sprite texture cache (reuse an uploaded texture when the pixels are byte-identical) was **refuted by measurement**: 2.84 / 2.90 fps against the baseline's 5.40 / 5.74 fps in the same `vsync` 181..451 window, and reverting restored 5.51 / 5.74 - reusing a texture the in-flight frame still references pays a simulator hazard wait that a fresh texture per call never pays, plus the per-call hash and copy.  Evidence: evidence/A1/l3-sprite-texture-cache-refuted-2026-09-22.md.
2026-09-22 (L3, NEXT - one variable, reframed): `MTLSimTexture replaceRegion` is the *simulator's* upload path (the driver copies into the GPU process over XPC), so simulator fps understates device cadence.  Take the loop's own first candidate next - stop uploading a full RGBA frame on every present when the GPU path already drew the scene (16 MB per present, the largest single XPC) - measured with the L0 window (`vsync` 181..451, two runs) plus a `sample`, leaving the sprite path as the fresh-texture-per-call baseline.
2026-09-22 (L3, LANDED - the per-present CPU base upload is skipped when the live scene replaces it): the present path pushed the whole drawable-sized RGBA surface through the synchronous `MTLSimTexture replaceRegion` on every present even though the render pass already clears to the same neutral colour, the base *draw* was already skipped once both TFRAG/TIE meshes are ready (`ottsel_mobile_cpu_frame_should_draw`), and `ottsel_metal_gfx_game_frame` returns 0 unconditionally so that flat buffer was always what got uploaded.  `cpu_base_wanted` is now computed once per frame from the same policy and gates the texture creation, the upload and the base draw, so they cannot disagree.  Measured in the L0 window (`vsync` 181..451, two runs): cadence unchanged (5.29 / 5.87 fps against 5.51 / 5.74 - the main thread was 53% idle), but `sample` moves the main thread's `presentRGBA:` frame from 268 to 54 samples and the process total from 1630 to 1563; both runs reach chain 900 with 346 ENTER = 346 RETURNED, a 0-byte fault log, `DIRECT FRAME` drawn=44 and `SPRITE FRAME` drawn=23/26, and the screenshot still shows the title screen with its rendered village background.  Evidence: evidence/A1/l3-base-upload-skipped-2026-09-22.md.
2026-09-22 (L3, NEXT - one variable): the frame rate is set on the game thread (1528 of 1630 samples in `send_gfx_dma_chain`, `render_mobile_sprite_group0` 552, `appendSpriteMeshNow` 410).  Cross-frame texture reuse is refuted; the unexplored hazard-free variant is *intra-frame* dedup of identical sprite uploads (the uploads are drained before the frame is encoded, so no in-flight reuse), then the DMA walk itself.
2026-09-22 (L3, MEASURED + WITHDRAWN - the sprite upload volume): the sprite path performs ~13-15 uploads and ~13 MB per frame through the synchronous `MTLSimTexture replaceRegion`, and 92-95% of those bytes are byte-identical repeats of an upload earlier in the same frame (per-frame accounting inside `appendSpriteMeshNow:`, one bounded line per 90 presents); at the measured ~5.5 fps that is ~70 MB/s of XPC, matching the ~25% of the game thread the profile attributes to that call.  A frame-scoped dedup (hash plus reuse within one frame, the table cleared on every present so nothing is shared with a frame still in flight) was attempted and **withdrawn**: it broke the sprite pipeline (`SPRITE FRAME ... drawn=0`, the atlas path 7x less often, the lane degrading after ~270 chains), so this renderer does not tolerate two batches sharing one texture within a frame either.  Reverted and verified healthy: `drawn=14`, 97069 log lines, chain 810+, 0-byte fault log, L0 window fps 5.62 against the 5.51 baseline and 5.29 base-skip.  Evidence: evidence/A1/l3-sprite-upload-volume-2026-09-22.md.
2026-09-22 (L3, NEXT - one variable): attribute the ~13 byte-identical atlas uploads per frame to their callers (`render_mobile_sprite_bucket`, `render_mobile_sprite_group0` and the three atlas flush sites in metal_gfx.mm) and collapse the duplicate work at its source, rather than caching in the renderer - both texture-cache variants are now measured refusals.
2026-09-22 (L3, LANDED with measurement - the sprite atlas upload is sized to the rows it packs): the World2D product-group atlas (`metal_gfx.mm`, the 48-sprite group) was uploaded as a full 512x512 (1 MB) region on every call while packing only 1-6 tiles of 64x64; `uv[1]` is now emitted in atlas pixels and normalised after the loop by the number of rows actually used, and the texture and the upload cover only those rows (buffer size and packing math untouched).  Measured with the L0 harness in the same window (`vsync` 181..451): **8.18 / 6.92 fps** against the 5.51 baseline, 5.29 base-skip and 5.62 revert runs, i.e. +25-48% on the same GOAL objects.  Mechanism evidence: the bounded log now shows `512x64` (128 KB) for 124032 calls and `512x128` for 8 calls in run 1, where every call used to be `512x512`, and the lane reached chain 1350 / 1170 in 115 s against 900.  Correctness: `rejected=0`, `SPRITE FRAME drawn=16/25` and `DIRECT FRAME drawn=44` unchanged, 346 ENTER = 346 RETURNED, 0-byte fault logs, and the screenshot still shows the title screen with its village background.  Evidence: evidence/A1/l3-atlas-upload-sized-2026-09-22.md.
2026-09-22 (L3, NEXT - one variable): the sprite path still issues ~900-1080 uploads/s of ~128 KB (~110-135 MB/s) and the other three atlas/standalone upload sites in metal_gfx.mm still push their full textures - size those to their used content the same way, then re-profile for the DMA walk.
2026-09-22 (L3, LANDED - the sprite atlases are now sized on both axes; the upload is no longer the bottleneck): after the row sizing (World2D atlas upload 1 MB -> 128 KB, +25-48% fps) the two atlas sites are sized on the width axis too (the packing fills columns 0..n row-major, so the columns used bound the used area) with uv[0] deferred and normalised like uv[1]; the HUD site received both axes at once.  Measured in the L0 window (vsync 181..451): 7.71 / 6.75 fps against the row-sized runs of 8.18 / 6.92, i.e. unchanged within the run-to-run spread, while the upload size went from a flat 512x64 to 64x64 / 128x64 / 192x64 / 256x64 / 320x64 (1-5 tiles wide, one row) - another ~2-8x fewer bytes per call.  So the texture upload is no longer the frame bottleneck and what remains is the CPU side (send_gfx_dma_chain 1528/1630 samples).  Correctness: 346/346 ENTER/RETURNED, rejected=0, SPRITE FRAME drawn=32/16, DIRECT FRAME drawn=44, 0-byte fault logs, and the title screen still renders with its village background, so the two-axis re-normalisation places tiles correctly.  Evidence: evidence/A1/l3-atlas-upload-two-axes-2026-09-22.md.
2026-09-22 (L3, NEXT - one variable): the remaining frame time is the CPU chain walk, so attack send_gfx_dma_chain itself next (the DMA/bucket walk and its per-chain diagnostics), and keep the HUD atlas sizing on the list of things the first HUD-bearing scene must verify - it did not run in the title window.
2026-09-22 (L5 route attempt + L3 re-profile): the maintained route driver scripts/replay-ios-normal-route.py can no longer pass - it waits for the marker 'OTTSEL INPUT: pad0 sample buttons=0x0', which the current shell does not log (file triggers now log 'ottsel BOT22: latched <button> tap (file trigger)' on stderr, src/shell/main.cpp).  Driven by hand with --console-pty the shell latched 7 of 7 taps (START, CROSS, 4x DOWN, CROSS) but the frontend never left screen=27 - only the title's own OTTSEL PROGRESS request/entering/normal lines appear - and the pad's has-display=false is normal on this lane in every build held, so it is not a regression from the atlas work; a plain simctl launch was inconclusive by method (still linking gsound at 3m47s with the trigger files unconsumed).  Side result: the HUD native path now runs (24 lines) with atlas=384x64 and 512x128, exercising the previously unverified HUD atlas sizing; every run kept ottsel-fault.log at 0 bytes.  Re-profile (sample, root 1594): the main thread is 65% idle, the game thread is 1365 samples in send_gfx_dma_chain (490 gfx_send_chain, 457 sprite bucket, 287 group0), the largest single leaf is now -[MTLSimDevice newTextureWithDescriptor:] at 111 samples (~7%), and ~875 samples (55%) are the non-sprite walk.  Evidence: evidence/A1/l5-route-attempt-and-reprofile-2026-09-22.md.
2026-09-22 (NEXT - three queued): (1) make the game pad consume the injected taps, which is the L5 route blocker; (2) refresh the route driver's stale acceptance marker; (3) recycle sprite textures on command-buffer completion, mirroring the existing vertex-buffer pool, for the ~7% allocation cost - then the non-sprite DMA walk.
2026-09-22 (L5/I0, BLOCKED ON THE USER DATA PACK + a fresh-install defect found): the route driver could not pass because its acceptance marker (OTTSEL INPUT: pad0 sample buttons=0x0) only exists when the app is launched with OTTSEL_TRACE_INPUT=1 (out/jak-project/game/sce/libpad.cpp) and because its presses used one-frame tap triggers while src/shell/main.cpp documents holds as what the game reads at this lane's 5-8 fps; the driver now holds and the shell latches 7 of 7 taps, but the frontend still stays at the title.  Separately a fresh app container makes the app die during boot with an uncaught ghc::filesystem::filesystem_error naming .../OttselShell.app/iso_data/SBK: build-ios.sh stages only DGO and TEXT into the bundle (ROM-safe by design) while ios_boot.cpp needs the user pack families (CGO DGO fr3 MUS SBK STR TEXT VAG VIS), and a missing family is an uncaught exception rather than a named error.  This session's rebuild removed the staged families from the bundle and its simctl uninstall removed the container's promoted copy, and a scan of every simulator device finds no surviving copy, so the iPad lane cannot boot until the user's extracted Jak 1 data is restaged (prepare-user-data-pack.sh <extracted-jak1> <out>, stage the families into OttselShell.app/iso_data/, rebuild, install) or an existing pack is pointed out.  The macOS lane is unaffected.  Evidence: evidence/A1/ios-lane-user-data-dependency-2026-09-22.md.
2026-09-22 (NEXT): (1) restage the user data pack so the iPad lane boots again; (2) turn the missing-family abort into a named, graceful error; (3) resume the route (title -> New Game -> Village1) and then the sprite texture pool that the re-profile put at 111 of 1594 game-thread samples.
2026-09-22 (I0/L5, LANE RECOVERED and input proven): the iPad lane is back without new user data - the extracted game data was still in the repository's gitignored out/jak-project/iso_data/jak1 (CGO DGO MUS SBK STR TEXT VAG VIS) plus the derived fr3 in out/jak-project/out/jak1/fr3, so scripts/prepare-user-data-pack.sh built a 1.5 GB pack at /tmp/ottsel-user-pack in 12 s, and staging its missing families into the bundle after the build restored a clean boot: title=1, modules=346, fault log 0 bytes within 20 s.  The staging rule cost one boot: build-ios.sh repopulates iso_data with only the built DGO/TEXT, and staging the pack's DGO/TEXT over those boots to 332/346 modules and then crashes (fault pc=0x10534c000, GOAL offset=0 code-range=invalid, x0=0x0803c2d4, process held for lldb).  Input is proven end to end: with OTTSEL_TRACE_INPUT=1 a driven press logs OTTSEL INPUT: pad0 sample buttons=0x8 (START) then buttons=0x0 (release), so the shell maps the injected key, publishes it through ottosel::platform_input and GOAL's pad samples it.  What remains is the frontend transition: the route driver's August expectations no longer identify the current frontend's edges.  Evidence: evidence/A1/ios-lane-recovered-pack-staging-2026-09-22.md.  The macOS lane was never affected.
2026-09-22 (NEXT): (1) re-derive the route driver's expected edges from the current frontend and prove title -> New Game -> Village1; (2) close the packaging gap (stage a present pack into iso_data/ during the build; a missing family must be a named error, not an uncaught ghc::filesystem::filesystem_error); (3) then the sprite texture pool (111 of 1594 game-thread samples).
2026-09-22 (L5, ROUTE DRIVABLE - the press semantics were the blocker): with the lane booting clean again (346 modules, title, 0-byte fault log) the driver's presses were switched from ottsel-press-* (one frame of state, invisible at 5-8 fps) to ottsel-hold-* (what src/shell/main.cpp documents the game actually reads), and the frontend moves: title (PRESS START) -> 3 s START hold -> the main menu wheel over the village1 background (screenshots /tmp/ottsel-routeA-final.png and /tmp/ottsel-routeB-01-menu.png, with scene-level='village1' and merc-submits climbing in the same run).  Continuing the August sequence (cross, 4x down, cross) returned the frontend to the title, i.e. the press at the wheel selects an item that leaves the menu - so the stale part is the route's menu model, not its plumbing.  The pad trace confirms delivery (buttons=0x8 START always; later holds 0x40 / 0x4000 / 0x4040) and every run kept the fault log at 0 bytes.  Evidence: evidence/A1/l5-route-holds-2026-09-22.md.
2026-09-22 (NEXT): at the main-menu wheel, re-derive the item order empirically (press Down, screenshot, press Cross, screenshot) until the save menu and then the intro appear, then rewrite the driver's expected edges around the frames and OTTSEL PROGRESS lines the current build produces; after that the packaging gap and the sprite texture pool (111 of 1594 game-thread samples).
2026-09-22 (L5, ROUTE PROBE DECODES): holds are the working press and with them the title advances to the main-menu wheel (screenshots /tmp/ottsel-routeA-final.png and /tmp/ottsel-routeB-01-menu.png), while a Cross hold at the wheel returns the UI to the title, so Cross is not the New Game item on this build or the wheel needs a selection change first.  Pad bits decoded with OTTSEL_TRACE_INPUT=1: 0x8 = START (SDLK_RETURN), 0x4000 = Cross (SDLK_SPACE), 0x40 = DpadDown (SDLK_DOWN); a combined 0x4040 appeared once, i.e. the shell's hold state overlapped two of my holds, so probes must leave at least 1 s of neutral pad between presses.  Important interpretation fix: OTTSEL CAMERA ENTRY accepted-level-candidate level='title' -> level='village1' is the title screen's own live backdrop, not a route advance, so scene-level='village1' at the title must not be read as New Game.  The lane stayed healthy in every probe (< 20 s boot, 346 modules, 0-byte fault log).  Evidence: evidence/A1/l5-wheel-menu-probes-2026-09-22.md.
2026-09-22 (NEXT): one menu item per run - title, hold START, wait for neutral, press Down once, wait >= 2 s, screenshot, press Cross, wait, screenshot - until the frame shows the save menu, then Down xN + Cross for Continue Without Saving; only then rewrite the driver's expected edges, followed by the packaging gap and the sprite texture pool (111 of 1594 game-thread samples).
2026-09-22 (I0, THE SUPPORTED DATA PATH IS THE F1 IMPORT): src/shell/ios_boot.cpp already imports a validated pack from $HOME/Documents/OttselUserData and promotes a durable copy into Library/Application Support/local.ottsel/OttselShell/OttselUserData, overlaying the build's own generated TIT.DGO/VI1.DGO and *.TXT on top; the bundle's iso_data is only the diagnostic fallback, which is why staging there looked necessary and why a fresh install dies on a missing family.  Verified twice: copying /tmp/ottsel-user-pack (built from the repository's gitignored out/jak-project/iso_data/jak1 plus the derived fr3) into the container's Documents/OttselUserData and relaunching logs 'OTTSEL F1: imported validated user pack into ...' and reaches the title in 20 s with 346 modules, a 0-byte fault log and a 1560 MB durable copy - and because that copy lives in the container, a build-ios.sh rebuild no longer wipes the lane's data.  New script scripts/import-ios-user-data.sh <udid> [pack] does exactly that (validate, boot, import, print the relaunch instruction) and was verified end to end this turn.  Evidence: evidence/A1/ios-user-data-import-path-2026-09-22.md.
2026-09-22 (I0, FIXED - a fresh install names the missing game data instead of aborting): the fresh-install death was `fake_iso_FS_Init()`'s throwing `fs::directory_iterator(<iso_data>/SBK)` (game/overlord/common/fake_iso.cpp), reached from `jak1::mobile_sound_banks_ready()` (game/overlord/jak1/srpc.cpp) through the GOAL asm bridges, which carry no unwind information - so `ottosel_ios_run_boot`'s `catch (const std::exception&)` guard never saw it.  The root is now tested with `fs::is_directory(root, ec)`, reported once by name (`[FAKEISO] no readable root ...`) and returns -1 into the callers' existing "< 0" path; overlay `patches/i0-fake-iso-missing-root.patch` is narrow after H3, pin+H3+overlay reconstructs the file byte-for-byte, it reverse-applies and the Stage 0 coverage guard still passes.  Fresh install (simctl uninstall -> install, no pack in the bundle, Documents or durable copy; two runs): the existing F1 missing-family line plus exactly one named-root line, 0 `terminating`/`uncaught exception`, 346 ENTER = 346 RETURNED, 0-byte fault log, and the lane ran the whole 200 s window (vsync 10351, chain 10350, ending at the `ndi-intro` STR stage) where every earlier fresh install died at ~2 min.  With the pack imported the guard never fires (0 named-root lines) and the lane is unchanged: one F1 import line, `scene-level='village1'`, cam-accepted 9506 with 0 rejects, merc-submits 19272, eichar=4, vsync 1171, 0-byte fault log, title screenshot `/tmp/ottsel-i0e-title.png`.  Evidence: evidence/A1/i0-fresh-install-named-error-2026-09-22.md.  No route, playability, audio or lifecycle claim.
2026-09-22 (L5, ROUTE PROVEN - title -> New Game -> training level gameplay, and the maintained driver passes): driving the shell's hold triggers one press per step and reading the frontend's own markers gives `OTTSEL TITLE: start edge in title-wait abs=8 rel=8` -> `activate-progress returned ... master=progress` -> `OTTSEL PC PROGRESS: edge/accept screen=27 index=0` (NEW GAME is selected at index 0 and Cross accepts it) -> `edge screen=18 index=0..3` (Down x4) + `accept screen=18 index=4` (CONTINUE WITHOUT SAVING) -> `GAMEPLAY: enter training`, `scene-level='training'`, tie-ready/tfrag-ready true, cam-accepted 7329 with 0 rejects, merc-submits 19389, eichar 485, vsync 1081, game-base 314945, 0-byte fault log, and screenshots rendering the training level (animated actor, bridge, crates, terrain) rather than a title screen.  The maintained driver `scripts/replay-ios-normal-route.py` now passes end to end ("Continue Without Saving accepted", exit 0): its August edge sequence was correct, and it could not pass only because with hold semantics its `press()` waited for a neutral pad sample *before* releasing the trigger, which a hold can never produce - it now releases on the edge and requires the neutral sample afterwards, with the title's own edge marker as the first expectation (`screen=27` is only printed once the menu answers a later input).  Two earlier readings are corrected: the menu is the PC progress ring with NEW GAME selected (the "Cross returns to the title" probe had delivered Cross while the title was still up), and `/tmp/ottsel-routeA-final.png`/`/tmp/ottsel-routeB-01-menu.png` are the title screen, not a menu.  New probe tool `scripts/probe-ios-title-menu.py`.  Evidence: evidence/A1/l5-route-new-game-to-training-2026-09-22.md.  Not claimed: no sustained movement/target control, camera, audio, lifecycle or playability acceptance.
2026-09-22 (L5 controllability, DELIVERED BUT NOT ATTRIBUTED): holding `ottsel-hold-stick-left` after the route reaches the pad as the shell's A/D/W/S-derived left stick (`OTTSEL INPUT: pad0 sample buttons=0x0 left=(0, 127)`, then back to (127, 127) on release), but the training intro is still animating - a 12 s *no-input* control in the same window also produces a different frame and `eichar` keeps climbing (3005 -> 3095) - so the before/after frame difference cannot be attributed to the held stick.  A target world-position trace (or waiting for the intro to complete before the control) is required before any movement claim, and `scene-level='training'` with 0-byte fault logs held throughout.
2026-09-22 (L5/I1, CONTROL PROVEN - a held stick moves the game's target and a neutral pad leaves it exactly still): the previous turn's screenshot-diff control was inconclusive only because it judged frames instead of the position trace the target already arms at spawn (goal_src/jak1/engine/gfx/shadow/shadow.gc: `OTTSEL TARGET POS: t=(~f,~f,~f) pad=~f`, one line in sixteen, post-collision; armed for 2400 frames by target-death.gc).  New protocol `scripts/probe-ios-target-control.py <udid> --route --seconds 15`: fresh launch, drive the route, wait four seconds of zero movement so the level transition and intro cannot pollute the control window, then sample neutral / stick-left / neutral / stick-right in the same run and level.  Measured: neutral windows **exactly** constant (x and z range 0.0 over 9 and 15 samples, pad=0.0) and held windows moving the target at pad>=0.99 - stick-left displacement (-60442.0, +17984.5) |d|=63060.9 over 22 samples, stick-right (+4298.0, +1031.5) |d|=4420.0 over 23 samples - so the movement is input-driven, not drift, animation or renderer, and the x displacement reverses sign with the stick.  stick-right travelled ~7% as far as stick-left in this window (camera-relative axes with terrain on one side, seen in the training screenshot); not investigated, and not needed for the claim.  Evidence: evidence/A1/i1-target-control-proven-2026-09-22.md (which supersedes the inconclusive paragraph in evidence/A1/l5-route-new-game-to-training-2026-09-22.md, now updated).
2026-09-22 (L3/L0, GAMEPLAY CADENCE MEASURED - the lane runs at ~52 fps in the training level, so the round's 4.7-10 fps is the TITLE window): wall-clock vsync over 47 s in the route-reached training level with no input held gives 2430 frames = 51.70 fps, i.e. ~86% of the 60 Hz budget, with the game's own clock at 287/s against the 300/s nominal (game-time-ratio 1.000), scene-level='training', tie-ready/tfrag-ready true, cam-accepted 119064 with 0 rejects, merc-submits 57143, eichar 16205 and a 0-byte fault log.  Thread-precise profile of the same state (sample, 3 s): the main thread is 1216 of 1866 samples idle in SDL_SYS_DelayNS (the loop's 60 Hz cap, src/shell/main.cpp - it sleeps only the budget remainder), so it is not the pacer; the game thread is 1146 samples in send_gfx_dma_chain, of which 302 are the texture upload/decode path (gfx_send_chain -> handle_mobile_pc_port_texture_upload -> gfx_texture_upload_now -> download_texture_cached -> decode_texture_pixels_raw 180), 92 are the access() trigger probes, and the remainder is the DMA walk resolved into signed-module slots (pskernel/quaternion/matrix/vector-h/euler/geometry).  The decode memo is working and the residual decode cost is mostly inherent: OTTSELVRAM hits=83057 misses=27535 bytes=3407424 epoch=1 places=54949 changed=49178 evicted=27320 invalidations=49175 - a 25% miss rate against a 3.4 MB resident set (256 MB budget, so not budget evictions) with changed covering 89% of mirror writes, i.e. the game really does re-upload different bytes and the range invalidation is correct rather than redundant.  Evidence: evidence/A1/l3-gameplay-cadence-2026-09-22.md.
2026-09-22 (I1, CONTROL REPEATED WITH MATCHED, OPPOSITE DISPLACEMENTS): a second control run (20 s phases, same protocol) gives neutral windows exactly constant again (x/z range 0.0 over 18 and 35 samples, pad=0.0) and held windows of matched magnitude in opposite directions - stick-left displacement (-51477.0, +5791.0) |d|=51801.7 over 50 samples, stick-right (+12149.0, -48983.0) |d|=50467.1 over 25 samples, dot product -9.1e8 - which is the camera-relative left/right reversal and retires the first run's ~7% stick-right distance as camera orientation rather than a defect.  Visibly corroborated in the same run: /tmp/ottsel-play-stick-left-before.png (Geyser Rock start area, Jak standing by the log and the blue bridge) against /tmp/ottsel-play-stick-left-after.png (the canyon interior he walked into; his pose against the wall looks distorted and is recorded as an observation, not diagnosed).  Evidence: evidence/A1/i1-target-control-proven-2026-09-22.md (updated with both runs).
2026-09-22 (L3/L0, CORRECTION to the cadence line above - the display rate is STATE-DEPENDENT, the game clock is wall-correct): three windows in the same route-reached training level give 51.70 fps (47 s, time-ratio 1.000), 15.37 fps (41 s, ratio 4.000) and 13.50 fps (40 s, ratio 4.000), while game-base stays wall-correct in both the fast (287 units/s) and the slow (308 units/s) window against the 300/s nominal - so the lane is choppy, not slow, and the round's original 4.7-10 fps title reading and a 51.7 fps gameplay window are the same phenomenon at different scene states.  The separating signal, from 67 SUBMITSTAT samples of the current instance: every slow interval has raster-draws=0 at 11-15 fps and the fast intervals have raster-draws 260-1157 at 30-45 fps, with tie-ready/tfrag-ready true in BOTH, so the GOAL-side readiness flags do not distinguish them.  The upload gate cpu_base_wanted (src/shell/metal_shell.mm) uses a different, shell-side per-frame test (a SceneFrameReference in _activeSceneFrame with an uploaded mesh and non-zero index_count) through ottosel_mobile_cpu_frame_should_draw (src/shell/mobile_scene_policy.h), so a frame can be GOAL-ready and still take the 16 MB CPU base upload path; that is the hypothesis for the slow state, not proven.  Next single instrument: report cpu_base_wanted beside raster-draws.  Evidence: evidence/A1/l3-gameplay-cadence-2026-09-22.md (rewritten - its first version reported the 51.7 fps window as THE gameplay rate).
2026-09-22 (L3, HYPOTHESIS REFUTED + frame cost model measured - the CPU base upload is already skipped in gameplay): the opt-in instrument (OTTSEL_TRACE_BASE=1 in presentRGBA:, src/shell/metal_shell.mm, logs "OTTSEL BASEUPLOAD: n= wanted= tfrag-mesh= tie-mesh= live-scene= meshes= frame-refs=" on every change plus one line in ninety presents) built shell-only and run through the maintained route into the training level gives 82 SUBMITSTAT and 129 BASEUPLOAD lines: cpu_base_wanted is FALSE in 121 of the 123 attributable windows (mean 32.8 fps, raster-draws spanning 0..1780) and TRUE only in the two boot/level-load frames (meshes=0 frame-refs=0), so the 16 MB CPU base upload is not being made during gameplay and cannot be the slow-state cause - and the previous document's "raster-draws=0 correlates with slow" reading is refuted too, because raster-draws=0 occurs in both 22.5-30 fps and 45-90 fps windows of the same run.  Twelve paired 3 s sample windows (1687 samples per thread per window) give the model: at 45 fps the game thread is ~7.5 samples/frame (~13 ms) and the main thread ~3 (~5 ms), while at 22.5 fps they are ~16.7 (~30 ms) and ~7.7 (~14 ms), i.e. the frame is saturated at ~44 ms and the game thread's per-frame cost roughly doubles - consistent with game-time-ratio 1.0 in the fast windows against 3.0-4.0 in the slow ones, where the port's wall-clock compensation raises the game work per displayed frame and drives cadence down further; whether to cap that compensation is a product decision (wall-correct game speed against smoothness) and is NOT taken here.  The main thread's largest single non-idle item is presentRGBA: -> drainMercUploads -> newBufferWithBytes (up to six buffers per drain, each a synchronous XPC into MTLSimDriver) at only ~0.5-0.8 ms/frame, below the ~10% resolution of the fps windows, so it is not worth landing alone.  Evidence: evidence/A1/l3-base-upload-refuted-and-frame-model-2026-09-22.md.
2026-09-22 (I1, NEW GAP MEASURED - jump input reaches the game and the target never leaves the ground; the vertical axis looks inert in gameplay): driving the route into the training level and then holding Cross for 8 s (scripts/probe-ios-target-control.py with the new --phases list, /tmp/ottsel-jump-*) gives a delivered input - the shell's pad trace shows buttons=0x4000 with cross-pressure=255 and the game's own logic issues OTTSEL AUDIO: PLAYER RPC play id=65805 index=147 name=jump - while the target's position trace moves at most 0.4 world units vertically (x-range 4.0, z-range 7.5) against exactly 0.0 in both neighbouring neutral windows, and /tmp/ottsel-jump-cross-mid.png shows the character standing.  Across the whole run (113 samples) y takes 7 distinct values with a 207423-unit range but every change is at an intro/level transition; inside each gameplay window y is bit-identical to four decimals (28345.1562 in this run, -8191.9667 during the earlier analog-stick walks that moved x/z by tens of thousands of units), so walking is not terrain following - the leading explanation is that vertical motion (ground snap and jump) is not running on this lane's target, and the distorted pose seen when the target was pressed into the canyon wall points the same way.  Not localised and not fixed: the next instrument is the same bounded trace plus the target's vertical state (jump flag/velocity) or state name, which needs a GOAL recompile and full app build.  Evidence: evidence/A1/i1-jump-input-delivered-no-vertical-motion-2026-09-22.md.
2026-09-22 (L4 note, cloud blend is NOT open): the sky/cloud additive accumulation is running on the lane - OTTSEL SKY BLEND reports "produced copies=3 misses=0" every vsync with live RGB texels for both destinations (tbp=0x1f80 32x32 sky, tbp=0x1fa0 64x64 clouds, alpha-peak 128), i.e. the ALPHA 0x48 cloud item in the L4 list is handled by the CPU producer (out = min(255, out + in*intensity>>7)); the remaining L4 items are the dynamic MERC eyes and HUD/menu material.  Some L4 renderer work is unverifiable while the target's vertical axis is inert, because a stood-still character cannot show ground-contact differences.
2026-09-22 (I1, VERTICAL AXIS LOCALISED - the target carries a non-zero vertical velocity that the position never integrates): the bounded BOT62 trace now also reports (-> self control transv) as "OTTSEL TARGET VEL: v=(~f,~f,~f) t=(~f,~f,~f)" (overlay patches/a11-diagnostic-traces.patch extended and regenerated, reverse-applies, coverage guard PASS; GOAL recompiled with (mi) - 546 targets in 16.5 s - then a full app build, after which bash scripts/test-a11-asm-ret-guard.sh still reports 8/8 guarded .ret sites and python3 scripts/validate-arm64-emission.py --cgo out/jak1/iso/KERNEL.CGO still validates all 90112 code words, and the lane boots at 346 ENTER = 346 RETURNED with a 0-byte fault log and scene-level='training').  Forty-eight samples under the Cross-hold protocol: v.y spans -12288.000..1.998 with 36 of 48 samples non-zero, the steady state is v=(0.05, 2.00, -0.09) while t=(-5392879.0, 28345.57, 4363639.0) is bit-identical across the window (one sample at v.y=-12288.0 occurs at the level transition, falling in at t.y=38014.38).  So the jump behaviour runs and the control's velocity field is populated - what is missing is the step that turns velocity into a new trans, and walking shows the same asymmetry (x/z integrate by tens of thousands of world units, y pinned).  Next instrument, named and not run: read the collision side of the window (the control's ground/surface height, or the pre-collision integrated position) to decide whether the integration is skipped or its result is discarded by the ground resolution.  Evidence: evidence/A1/i1-jump-input-delivered-no-vertical-motion-2026-09-22.md.
2026-09-22 (I1, CORRECTION - JUMP WORKS; the "no vertical motion" reading two lines up was a sampling artefact in my own instrument): the target trace now prints the velocity **immediately whenever |transv.y| > 1000** (a jump impulse lasts about half a second, so the fixed one-in-sixteen cadence simply missed it), and with that instrument **seven of seven Cross presses produced a jump** (3/3 then 4/4), every arc identical: vy +14370 -> +50185 (apex) -> +1033 -> -15351 -> -64503 back to the ground, with t.y 29713 -> 40371 -> 30666, i.e. ~10.7k-11.4k world units of flight; the three presses before the level loads correctly produce no arc.  Gravity is set and therefore the jump formula has its input: OTTSEL TARGET GRAV reports g-len=245760.0000 g-n=(0.0000,1.0000,0.0000) on every sample, and init-var-jump computes sqrt(2 * gravity-length * height) along gravity-normal (target.gc:659).  The two artefacts that produced the earlier reading: (a) the position trace's one-in-sixteen cadence cannot sample a half-second arc, so a 2-8 s window can report a y-range of ~0.4 units although the jump happened - the phase table "saw" 1 of 3 and 2 of 4 jumps while the log shows 7 of 7; (b) the velocity trace printed on the same cadence and therefore showed only the standing residual v=(0.05, 2.00, -0.09), which I misread as "velocity populated, position never integrated".  The earlier "walking leaves y bit-constant" observation is no longer evidence of an inert axis (a flat stretch of the walked path is the simple explanation) and is not re-measured here.  Not explained and not dismissed: the single earlier 8 s window with no impulse at all (one press of the eight measured).  No gameplay code changed - the diff is the diagnostic trace and the probe tool.  Evidence: evidence/A1/i1-jump-works-measured-arc-2026-09-22.md.
2026-09-22 (I2, AUDIO PRODUCER PROVEN, DEVICE OPEN BLOCKS - the lane is silent for a host reason, not a sound-code reason): new opt-in overlay patches/i2-audio-pcm-capture.patch (player.cpp; reverse-applies, pre+overlay reconstructs byte-for-byte, coverage guard PASS, standalone -fsyntax-only clean) captures the PCM the Apple callback hands to the SDL stream.  In a default run the capture never fires because the stream never opens: the opener logs only "opening SDL output-only playback asynchronously" and neither the success line nor any of the three failure lines, and a 3 s sample puts the opener thread at 1591 of 1591 samples in std::__thread_proxy<snd::Player::InitOutput()::$_0> -> SDL_OpenAudioDeviceStream -> SDL_OpenAudioDevice -> OpenPhysicalAudioDevice -> COREAUDIO_OpenDevice -> SDL_WaitSemaphoreTimeoutNS -> _pthread_cond_wait, with CoreAudio parked in AudioObjectGetPropertyData -> HAL_HardwarePlugIn_ObjectHasProperty -> HALC_ProxyObject::HasProperty and an AudioQueueXPC_Server::Start; the host does have a default output device (system_profiler: "MacBook Air Speakers" 48 kHz) plus a virtual "Microsoft Teams Audio" device, so this is the Simulator HAL query hanging rather than a missing device, and the port's design contains it (the game thread never stalls, the lane just stays silent).  Repeating the same run with SDL_AUDIO_DRIVER=dummy opens the stream (device=21 paused=false) and proves the producer: OTTSEL AUDIO PCM second=1..9 peak=0 rms=0 (boot/title silence), second=10..19 peaks 6101/8215/9733/10003/10299 with rms 589..1386, dump complete frames=960512 bytes=3842048, and an independent wave read confirms 2ch/48000/16-bit/20.01 s with overall peak 10299 of 32767 and 11 of 20 seconds carrying signal - so banks, PLAYER RPC resolution, voices and mix all produce real audio.  Audibility itself is still NOT claimed: the remaining work is a Simulator-side driver/host workaround or the device lane (P1/D1), not the game's sound code.  Evidence: evidence/A1/i2-audio-pcm-measured-device-open-blocks-2026-09-22.md.
2026-09-22 (I2, SAVES WORK END TO END AND THE LIFECYCLE ROUND TRIP IS HANDLED): with the screen numbers named from the progress-screen enum (27 = title menu, 18 = save-game-title, 16 = load-game), driving the frontend by its own markers writes a real save - accept screen=27 index=0 (NEW GAME) then accept screen=18 index=0 (slot 1, previously EMPTY) produces .../OpenGOAL/jak1/saves/BASCUS-97124AYBABTU!/bank0.bin at 67584 bytes in the game's own memcard format - and a fresh process loads it back: accept screen=27 index=1 (LOAD GAME) then accept screen=16 index=0 (the file list) runs GAMEPLAY: enter title -> village1 -> training with scene-level='training' and leaves bank0.bin's mtime at 15:50, i.e. the load reads and does not rewrite; fault log 0 bytes throughout.  NOT proven: state fidelity, because the save was taken from the NEW GAME flow and therefore holds the level's start state, so a load of it is observationally identical to a new game - that needs an in-game save (pause menu or checkpoint) plus a position/progress comparison.  Lifecycle: launching Settings to background the game logs "OTTSEL LIFECYCLE: background input neutralized and audio paused" and relaunching the game logs "OTTSEL LIFECYCLE: foreground controller rechecked and audio resumed", after which the lane is still at scene-level='training' with a 0-byte fault log and a held stick still reaches the pad (left=(0, 127)).  The game does keep rendering while backgrounded on this host (vsync 901 -> 991 across the background window); suspension behaviour on a device is untested.  Evidence: evidence/A1/i2-saves-and-lifecycle-2026-09-22.md.
2026-09-22 (I3, THE IPAD TOUCH SURFACE IS NOW VISIBLE AND ITS ROUTING IS PROVEN END TO END): the nine default touch regions (left stick, camera, the four face buttons, start, L1, R1) always routed input, but upload_touch_overlay() only uploaded the vertices while the layout editor was open, so an iPad player driving by touch saw no controls at all - the surface now follows the input in use (drawn whenever g_native_input_mode is false, i.e. no keyboard/gamepad/mouse has taken over) and the editor only controls dragging.  Proof that it is drawn at the layout's own coordinates: two overlay frames 3 s apart versus one after a native-input event hid it, compared inside the nine region boxes against everywhere else for all four 90-degree mappings - only the layout's rotation shows a signal (mean channel difference 176.3 inside vs 50.1 outside, with a flat animation baseline of 8.0/20.8), and the same screenshot's nine solid blocks carry the layout's own hues.  Proof of routing: new bounded trigger ottsel-touch-<region> drives the real path (handle_touch_editor then g_input.touch, press followed by a small drag so stick regions deflect) and a touch-only run gives pad0 sample buttons=0x8 -> OTTSEL TITLE: start edge, buttons=0x4000 -> accept screen=27 index=0 (NEW GAME), another -> accept screen=18 index=0 (save slot, after which the game asks its own "A JAK AND DAXTER SAVE GAME ALREADY EXISTS ... DO YOU WISH TO OVERWRITE THIS?" because the earlier save is still in the container), and left-stick press+drag -> pad0 sample left=(167, 107) from (127, 127).  Operational: after simctl install the reported container UUID can change between calls, so read the writable directory after launch (the app's OTTSEL RUNTIME BOOT writable= line is authoritative).  Not claimed: the touch run ended at the overwrite prompt so it did not re-demonstrate level entry, multi-touch (stick plus button) is untested, and no physical device was used.  Evidence: evidence/A1/i3-touch-surface-drawn-and-routing-proven-2026-09-22.md.
2026-09-22 (I3, THE TOUCH LAYOUT GAINS ITS MISSING D-PAD; TOUCH-ONLY NAVIGATION, MULTI-TOUCH AND THE FULL TOUCH ROUTE INTO GAMEPLAY ARE PROVEN): ottsel_platform_input.h carries DpadUp/Right/Down/Left as their own digital bits and nothing synthesises them from the analog stick, while the game's frontend navigates with cpad-pressed? 0 down and friends - and the default touch layout had no D-pad at all, so a touch-only player could open a menu and then not move in it.  TouchRegion now gains DpadUp/DpadRight/DpadDown/DpadLeft between the face buttons and start, the default layout gets a compact four-square cross at x 0.215-0.385 y 0.395-0.555 (clear of every other region), the overlay colour table gains its violet entry, ShellPadInput::touch maps the four regions to the same canonical buttons the keyboard and gamepad paths use, and the layout file stays version 1 with per-region validation so an older nine-region file is rejected and the defaults are used.  Touch-only evidence: start -> TITLE: start edge; dpad-down -> pad 0x40 -> edge screen=27 index=0; dpad-down -> 0x40 -> index=1; dpad-up -> pad 0x10 -> index=2; cross -> 0x4000 -> accept screen=27 index=1 (LOAD GAME) - the progress log prints the pre-move index, so two downs and one up landing on index 1 is consistent end to end - and that load screen names the save as GEYSER ROCK with 9/22/2026 15:50, i.e. the game read the bank's level-name and timestamp fields back out.  The trigger now keeps one finger per present region, so multi-touch works: holding left-stick and cross together gives a single pad sample buttons=0x4000 left=(167, 107) cross-pressure=255, and the same touch-only run completes NEW GAME -> D-pad down to an empty slot -> Cross -> GAMEPLAY: enter training with scene-level='training'.  Evidence: evidence/A1/i3-touch-dpad-and-save-metadata-2026-09-22.md.
2026-09-22 (L3, FIVE-MINUTE GAMEPLAY SOAK + THE CADENCE MECHANISM CORRECTED): touch-only route into the training level (NEW GAME, D-pad down twice to an empty slot, Cross) followed by fifteen cycles of stick+Cross / stick+D-pad-up holds gives 107 SUBMITSTAT samples: throughout gameplay the per-frame content is CONSTANT (3 merc draws, ~1 eichar, 6 camera entries) while the displayed rate sits at 22.5-30.0 fps with time-ratio 3.0, against 45.0 fps and ratio 1.0 in the title window and 13.5 fps at ratio 4.0 in the heavy transient window measured earlier - so the slow windows are not a heavier scene, they are three points of one loop.  The loop is now named: time-ratio is not a knob but game code (drawable.gc:978-997 computes timer-count(0x10000800)/*ticks-per-frame*, rounds up, clamps to 1.0 under 1.3 ticks, then set-time-ratios *display*), so with R the render cost of one displayed frame and S the simulation cost of one game frame, T = R + k*S and wall-correct game time needs k = 60*T, giving T = R/(1-60*S): the frame time is set by R and S alone with S amplified (about 2.5x at S ~= 10 ms), which is why a small render-cost cut buys more than its sample share (the earlier atlas sizing gave +25-48% for ~7% of samples).  Stability over the soak: RSS 967 MB -> 910 MB (no growth), ottsel-fault.log 0 bytes throughout, 346 ENTER = 346 RETURNED, and every input came from the touch surface.  Evidence: evidence/A1/l3-gameplay-soak-and-cadence-mechanism-2026-09-22.md.
2026-09-22 (L3, LANDED - the MERC packet handler no longer allocates or stats per packet): a fresh sample of the training lane put the top game-thread leaves at _platform_memmove 412, capture_mobile_merc 369 (23% of the thread), access 161, __bzero 126, vector::__insert_with_size 114 and decode_texture_pixels_raw 101 - and capture_mobile_merc, which runs for every MERC setup transfer, was probing the merc-names trigger with access() on every packet and allocating three vectors the size of the whole level's MERC vertex set before skinning.  Now: the trigger is probed once per chain and latched (the histogram still accumulates, so an armed read still works - verified: distinct=50 submits=48639 eichar-submits=1569 with the trigger consumed), the three scratch vectors are file-scope and resized only when the level's vertex count changes with lighting_valid refilled each call (it is the gate the index validation already uses, so stale entries in invalid slots can never be read), and the two eichar diagnostic ledger loops skip entries that are not valid for the call, which is what makes the reuse honest.  Correctness: scene-level='training' with eichar=17 and level/actors/terrain/fruit/bridge all rendering in /tmp/ottsel-l3-correctness.png, fault log 0 bytes.  Effect: the targeted leaves fall hard (capture_mobile_merc 369 -> 130, _platform_memmove 412 -> 184) but the second sample was taken in the title state, so that is a share improvement rather than a like-for-like A/B.  Cadence post-change: 24.0 fps at game-time-ratio 3.000 over 30 s of continuous input, the same cadence as the pre-change soak (22.5-30.0 fps at ratio 3.0) held under a heavier host (load 4.3-4.7 against the soak's lighter window) - NOT offered as a proven speed-up: the same build measured 6 and 12 fps in title/menu windows minutes apart and the pre-change lane was already at ratio 4.000 in that window.  Evidence: evidence/A1/l3-merc-packet-hot-path-2026-09-22.md.
2026-09-22 (L3, LANDED - MERC packets skin and upload only the vertex slice they reference): the remaining per-packet cost was structural - capture_mobile_merc skinned every vertex of the level's shared MERC pool and handed the whole array to Metal although a packet only references the model it names.  It now scans the enabled effects' draw index ranges for the referenced span (skipping 0xffffffff strip sentinels), skins only that span, rebases the built indices by span_min after the existing absolute-index validation, and uploads vertices+span_min / lit_colors+span_min*4 with span_max-span_min+1 vertices (the Metal contract is a straight copy of count*32 and count*16 bytes, so the slice is exact, and a packet referencing an unskinned index still fails exactly as before).  The lane's own OTTSEL MERC NATIVE line now prints uploaded versus pool: eichar-lod0 3328 of 9942 (33%), sidekick-lod0 1311 of 9942 (13%), ndi-lod0 1123 of 22518 (5%), sagesail-lod0 209 of 50764 (0.4%) - i.e. 3x less skinning and copying for the player and up to 240x less for a small model, and those copies were the frame's largest leaves.  Correctness: /tmp/ottsel-span-gameplay.png shows the training level with Jak in the right colours after a touch-only route, zero MERC rejections, fault log 0 bytes, 346 ENTER = 346 RETURNED, overlay-coverage guard PASS, 8/8 guarded .ret sites PASS.  Cadence: two 30 s training windows measure 30.0 fps and 26.1 fps (load 3.58/3.39) against 24.0 fps on the previous build (load 4.3-4.7) and the pre-change soak's 22.5-30.0 fps at ratio 3.0 - at or above every earlier measurement, but NOT offered as resolved: the host load was never the same twice and the same build has read 6 and 12 fps in title/menu windows minutes apart, so the fps effect is consistent-with-mechanism rather than controlled.  Operational: the container's four accumulated test saves were deleted so the NEW GAME flow stops prompting to overwrite (the earlier save/load evidence stands as measured).  Evidence: evidence/A1/l3-merc-vertex-span-2026-09-22.md.
2026-09-22 (L3, CONTROLLED A/B DONE - the two MERC changes remove their targets: the leaf set falls from 86% to 54% of the chain walk): fps windows could not answer this - the host carries the Codex app itself (~35% of the load) and the same binary produced 5.81 fps and 3.00 fps in two consecutive 30 s windows of the same state (loads 4.00/3.71) - so the pre-change source was reconstructed by reversing the first change out of the saved intermediate file (the reversal asserts every region matches exactly once; the result differs by exactly those 57 lines), built, and both binaries were measured as 3 s samples in the SAME title state, the changed build under a heavier load.  Leaf shares of the chain walk: capture_mobile_merc 253 -> 10 samples (18.7% -> 0.8%), _platform_memmove 264 -> 74 (19.5% -> 5.6%), vector::__insert_with_size 67 -> 0, and the sum of the tracked set 1162 -> 718 (86.0% -> 54.0%) with chain-walk totals 1351 vs 1329 under loads 4.00 vs 4.91 - a like-for-like attribution of the removal, not an fps claim.  Follow-up attempt in the same turn: SkyIsolationProbe::activeRequest() polled two files on every present and now polls every sixteenth call with a memo (src/shell/metal_sky_isolation.h) - REFUTED as a lever (access 167 -> 156 in the same state, no real change), kept only because it removes stats without changing behaviour.  The remaining access cost is spread, not one caller: main-loop trigger polls 51 (the hold list plus the thirteen ottsel-touch-* polls this session added), presentRGBA: 49, the nested Mips2C particle launcher 42, render_mobile_sprite_bucket 5; and __bzero (13-18%) is a per-chain/packet zeroing untouched by the slice work.  Evidence: evidence/A1/l3-merc-optimisation-ab-2026-09-22.md.
2026-09-22 (L3, LANDED - the group0 sprite atlas no longer re-zeroes a megabyte per call; __bzero falls 215 -> 7 samples): grouping the __bzero leaves by enclosing frames put 208 of 215 inside render_mobile_sprite_group0, the World2D product-group sprite path, because it built its packing atlas as a fresh zero-filled 1 MB std::vector on every call (512 x 64 x 8 x 4) before packing one to eight 64x64 tiles into it.  The buffer is now a function-local static sized once, which is safe because every byte that leaves the CPU is written - the packing memcpys each tile's width x height rows into its cell plus alpha fixups, the upload covers only the used columns and rows, and the emitted UVs are scaled by those used dimensions so they sample only packed cells, leaving stale bytes only in cells neither uploaded nor sampled.  Measured in state-matched 3 s title samples: __bzero 215 -> 7 (7.5% -> 0.2% of chain+main), access 156 -> 196, capture_mobile_merc 12 -> 12, _platform_memmove 64 -> 78, with chain-walk totals 1358 vs 1300 and main-thread 1492 vs 1555, and the after sample ran under a HIGHER load (6.38 against ~4.4-5.1), so the drop is not a load artefact.  Correctness: SPRITE FRAME drawn=22 in the training level and 19-73 in title windows, the atlas still reports used-area sizes (native World2D atlas vertices=288 sprites=48 textures=7 atlas=448x64), /tmp/ottsel-atlas-level.png shows the level with its distant sprite actors, and ottsel-fault.log stayed 0 bytes throughout.  Evidence: evidence/A1/l3-sprite-atlas-buffer-reuse-2026-09-22.md.
2026-09-22 (L3, LANDED - the per-call diagnostics that dominated the log are bounded; log volume 6.2 MB -> 1.8 MB): counting the lane's own output first showed that 5014 of the last 6000 log lines were the SPRITE METAL native World2D atlas line, written on every atlas call several times a frame, with the three eichar ledgers (MATRIX/SHADE/MOD) ungated per packet behind it - and the SHADE ledger scanned the whole MERC vertex pool each time.  The atlas line now reports the first eight calls then one in ninety (the first attempt, "log when the values change", was refuted by the rebuild: the values change every call, so it still logged every call), and each eichar ledger is capped at eight lines per process with the shade pool-scan inside that cap; the findings those ledgers produced are already recorded in evidence/A1.  Measured in two comparable windows (driver route into the training level, 4 s sample each): log bytes 6.20 MB -> 1.81 MB, atlas lines per 6000 5140 -> 326, __write_nocancel leaf 70 -> 27 (1.7% -> 0.8% of chain+main), while decode_texture_pixels_raw 276 -> 330 (6.7% -> 9.3%) and access 191 -> 216 (4.7% -> 6.1%) rise in share simply because the totals fell (chain+main 4104 -> 3535).  Correctness: the lane still reaches scene-level='training' through the maintained driver, still draws sprites (SPRITE FRAME drawn=10 at close), ottsel-fault.log 0 bytes, 346 modules enter and return.  Evidence: evidence/A1/l3-bounded-per-frame-logging-2026-09-22.md.
2026-09-22 (L3, LANDED - the texture decode fetches each palette entry once instead of per pixel; decode falls 330 -> 89 samples): every CLUT format branch (PSMT8/0x13, PSMT4/0x14, PSMT4HL-HH/0x24-0x2c) walked the texture pixel by pixel and, per pixel, computed the palette address through the PSMCT32/PSMCT16 swizzle and fetched it through the get_clut32/get_clut16 lambdas - each doing a bounds check, a reading_clut flag flip, a CLUT read-window update and a four-byte memcpy - so a 64x64 texture re-fetched the same handful of entries thousands of times.  Each branch now keeps a lazily-filled table (256 entries for PSMT8, 16 for the 4-bit formats) with a clut_for(index) helper: the first use of an index computes and fetches exactly as before, later uses read the cached word, so the addresses actually read - and therefore the CLUT window the decode memo records for invalidation - are exactly the ones the per-pixel path read, and the texel window is untouched because get8 is unchanged.  Measured in the same protocol as the previous document (driver route into the training level, 4 s sample): decode_texture_pixels_raw 330 -> 89 (9.3% -> 2.4% of chain+main), gfx_texture_upload_now 94 -> 78, access 216 -> 166, capture_mobile_merc 91 -> 92, _platform_memmove 137 -> 151, totals 3535 -> 3679, i.e. the decode falls 3.7x in absolute samples on the same workload.  Correctness was checked visually because decoding is colour-critical: the training level still renders the same scene with the same palette (armoured character with the orange companion, wooden log, cyan mosaic bridge edge, palm foliage, rocky terrain, red fruit, purple enemies) in /tmp/ottsel-clut-level.png, OTTSEL GFX still reports sane decodes (512x256), fault log 0 bytes, 346 modules enter and return.  Evidence: evidence/A1/l3-clut-palette-cache-2026-09-22.md.
2026-09-22 (NEXT): (1) the remaining app leaves are all small now (access 4.5%, _platform_memmove 4.1%, gfx_texture_upload_now 2.1%, capture_mobile_merc 2.5%), so the next L3 step is systemic rather than per-leaf - either cut the per-frame mesh/texture upload volume with the content-keyed reuse the sprite path already has, or re-measure the whole frame with a fresh profile and decide whether the emulated-GOAL share is now the pacer; (2) I2 state fidelity - save from inside the level, then load and compare position/progress against a new game; (3) L4 dynamic MERC eyes and HUD/menu material as matched captures; (4) audibility (Simulator driver workaround or the device lane); (5) I3 settings/touch-layout persistence and controller handoff, then P1 iPhone and D1 devices.
2026-09-22 (P1, FIRST RUN ON A PHONE - it boots, routes and plays): the iPad lane was stopped first and one iPhone profile was booted (iPhone 16 Pro / iOS 18.5, `12A4163C-33A0-4936-8024-77A6D36698C5`) with the same strict signed-GAME control as the iPad lane (346 ENTER = 346 RETURNED, fault log 0 bytes). The phone reaches `title-play received wait` and renders the title (drawable 874x402; the 1206x2622 device surface is portrait because the app is landscape-only), and the touch-only route runs end to end - Start -> `edge screen=27 index=0`, Cross -> `accept screen=27 index=0` (NEW GAME), D-pad down -> `edge screen=18 index=0`, Cross -> `GAMEPLAY: enter training` with `scene-level='training'` - the same route the iPad lane takes. Cadence: 45 fps at `game-time-ratio=1.000` through the training level and 22-26 fps at ratio 3.000 later in the same level while the host load rose, i.e. the iPad lane's band at 2.87x fewer surface pixels (874x402 against 1210x834, both read from the driver's own `presentRGBA` log).
2026-09-22 (P1, LANDED - the touch-layout class now follows the real surface): `g_touch_layout_path` was computed ~20 lines before the CAMetalLayer reports its drawable, from `kSurfWDefault` 1024, so the `w < 1000` phone test could never fire and a phone read the tablet layout file (measured: with both files present in the phone container, the log named `touch-layout-tablet.cfg`). `refresh_touch_layout_path()` now re-resolves the path from the current surface width at boot, at the first Metal drawable and in the per-frame resize block (`src/shell/main.cpp`); after the change the phone logs `touch-layout-phone.cfg` and the iPad `touch-layout-tablet.cfg` with the other class' file present in both containers, and the editor's save writes the same variable (three `saved persistent layout ...phone.cfg` lines with the region table mutated by a drag). Evidence: `evidence/A1/p1-iphone-boot-layout-and-cadence-2026-09-22.md`.
2026-09-22 (P1, NEXT - three measured items, in order): (1) the compiled default table cannot be persisted - its triangle row is `0.965 0.665 0.055 0.055` so x+w = 1.020 and `load_touch_layout()`'s bounds check rejects the whole file, and the A/B on the iPad (0.965 -> no load line, 0.945 -> loaded) isolates that row, so an editor save is silently lost on the next boot; (2) the layout editor is one-way - while `g_touch_editor` is set `handle_touch_editor` consumes every finger event, so the Start double-tap that toggles it never reaches `g_input.touch` and only F6 exits, which traps a touch-only player in the editor; (3) phone reachability - the regions are axis fractions, so on 874x402 the face buttons are 48x22 pt and the D-pad arms 44x20 pt against 67x46 and 61x42 pt on the iPad, which needs a phone default set (and the editor fix) before P1's layout rework can be called done.
2026-09-22 (I3/P1, LANDED - the touch layout editor now round-trips on a device with no keyboard): both defects recorded in the previous line are fixed and measured on the phone and on the iPad. The compiled default triangle row is `0.945` (it was `0.965`, x+w = 1.020, so the whole default table failed the loader's own bounds check and the first editor save was silently discarded), `save_touch_layout()` now runs every region through `clamp_touch_region()` (w,h to [0.03, 1], x,y to [0, 1-w]) so everything the editor can write is loadable by construction, the loader keeps the same bounds with a 1e-4 rounding tolerance, and the Start double-tap now lives in a shared `start_double_tap()` consulted by both the game-input path and `handle_touch_editor()`, so the gesture that opens the editor also closes it instead of leaving F6 as the only exit.
2026-09-22 (I3/P1, MEASURED - the round trip works on both classes from a clean container): each lane started with zero layout files (0 `TOUCH: loaded` lines), a double-tap on Start gave `editor=on layout=...touch-layout-phone.cfg` on the phone and `...tablet.cfg` on the iPad, a press+drag saved `saved persistent layout ...`, a second double-tap gave `editor=off`, and a relaunch gave `loaded persistent layout ...` - the state the pre-fix build could never reach because the file it wrote was rejected. The saved file is the compiled default table with the triangle clamped to `0.945 0.665 0.055 0.055` and the dragged circle at `0.865 0.575`. Negative control: writing the pre-fix `0.965` row back into the same file gives 0 load lines, so the validator was not loosened. Regressions: a single Start tap still reaches the game (`TITLE: start edge`, `entering screen=27 state=27`), the iPad lane still reports 346 ENTER = 346 RETURNED with `scene-level='village1'` and a 0-byte fault log, and the overlay-coverage and `.ret` guards PASS. Evidence: `evidence/A1/i3-touch-layout-editor-roundtrip-2026-09-22.md`.
2026-09-22 (NEXT - one variable): the phone still uses the shared default region sizes, so on its 874x402 surface the face buttons are 48x22 pt and the D-pad arms 44x20 pt against 67x46 and 61x42 pt on the iPad's 1210x834 - the regions are fractions of each axis and flatten with the wider phone aspect, which is the reachability half of P1's layout rework (give the phone its own default table, sized so its targets clear the 44 pt guideline, then re-run the touch-only route and the editor round trip on it). Still open behind it: I2 state fidelity (save from inside the level and compare progress), L4 dynamic MERC eyes and HUD/menu material, audibility, and D1 devices.
2026-09-22 (I3/P1, LANDED - the touch defaults are per device class and both classes clear the 44 pt tap guideline): a geometry check over both tables (each against its own measured surface) showed the shared table was short on the phone AND that the accepted tablet table was short in the axis it is thin in (D-pad arms 60x42 pt, top bars 145-169x38 pt on 1210x834), so both were resized rather than only the phone's: phone 874x402 now gives stick 166x92, camera 175x80, face buttons 60x58, D-pad arms 48x48 and top bars 114x46 pt; tablet 1210x834 gives stick 157x138, camera 194x83, face 67x46, D-pad 60x46 and bars 145-169x46 pt, every region inside the screen with no two overlapping.
2026-09-22 (I3/P1, the class is now the platform idiom, not a surface width): the two tables and the per-class layout file are keyed on `ottosel_ios_shell_is_phone()` (UIUserInterfaceIdiom, implemented in `metal_shell.mm`, declared in `ios_boot.h`) because the width test was a pixels-versus-points trap - the simulator's CAMetalLayer reports 874x402 with contentsScale 1 while a device's layer reports points x contentsScale, so `g_surf_w < 1000` would have classified a real iPhone as a tablet; the idiom is also known before any drawable exists, so the class defaults are applied first and a persisted file still overrides them. Measured: phone `OTTSEL TOUCH: class=phone surface=874x402 min-region=48x46`, iPad `class=tablet surface=1210x834 min-region=60x46`; the touch-only route still reaches `GAMEPLAY: enter training` with `scene-level='training'` on both (iPad 346 ENTER = 346 RETURNED, fault log 0 bytes), and the editor round trip was re-run on both with the new rows (save -> relaunch -> `loaded persistent layout ...`). Evidence: `evidence/A1/i3-per-class-touch-defaults-2026-09-22.md`.
2026-09-22 (P1, NEXT - one variable): the phone's landscape safe-area insets have not been measured and the stick and the L1/Start/R1 bars sit where the Dynamic Island is on iPhone, so the next step is to read the insets from the platform seam, log them with the class, and move the defaults that fall inside them; an older phone profile (667x375 pt) would compute 46x54 pt face buttons, just under the guideline in width, and needs its own check. Behind it: I2 state fidelity (save from inside the level and compare progress), L4 dynamic MERC eyes and HUD/menu material, audibility, and D1 device readiness.
2026-09-22 (P1, LANDED - the phone's safe area is measured and the class defaults respect it): `ottsel_ios_shell_safe_area(l,t,r,b)` reads the key window's safe-area insets and reports them as fractions of that window's bounds (same coordinate space as the layout, and immune to the CAMetalLayer reporting points x contentsScale); `clamp_touch_region_to_safe_area()` shrinks a region only when the usable strip is narrower than the region and otherwise moves it, so target sizes survive, and the shell applies it to its own class defaults as soon as the drawable exists (retrying until the platform answers) while a persisted layout is left untouched. Measured: iPhone 16 Pro landscape reserves 62 pt on EACH side plus 21 pt at the bottom - symmetric, so one placement serves both landscape orientations - and iPad Pro 11-inch M4 reserves 0 sides / 24 top / 25 bottom. From the app's own layout dump, 11 of 13 phone rows moved exactly as the insets predict with no size change (stick x 0.045 -> 0.0709 = 62/874; cross and triangle x 0.880 -> 0.8601) and the iPad clamp is a no-op because every tablet region already clears its insets. Evidence: `evidence/A1/p1-phone-safe-area-defaults-2026-09-22.md`.
2026-09-22 (P1, MEASURED - the routes still hold with the clamp in place): with the clamped layout the phone goes touch-only from PRESS START through `entering screen=27` and `accept screen=27 index=0` to `GAMEPLAY: enter training` with `scene-level='training'`, and the iPad takes the same route with 346 SIGNED MODULE ENTER = 346 RETURNED and a 0-byte fault log; both logs carry `class=phone surface=874x402 min-region=48x46 safe-lrtb=62x0x62x21` and `class=tablet surface=1210x834 min-region=60x46 safe-lrtb=0x24x0x25`, and a relaunch with a persisted layout logs `loaded persistent layout ...` with no clamp line, which is the skip working.
2026-09-22 (NEXT - one variable, a new measured blocker): NEW GAME writes a save, and every later NEW GAME lands on the `~0LYES ~30LNO` confirmation that neither Cross nor the D-pad moved in this probe, while the save screen still lists 4 x `NONE` - the save is on disk (`OpenGOAL/jak1/saves/BASCUS-97124AYBABTU!`) but not in the game's own slot list, and the flow ping-pongs 18 <-> 11 at index 0; clearing the save restores the flow, which is how both routes above were completed, so this is either the port's save read path or that dialog's cursor and it needs its own turn before I2 state fidelity can be called done. Behind it: I2 state fidelity (save from inside the level and compare progress), L4 dynamic MERC eyes and HUD/menu material, audibility, and D1 device readiness.
2026-09-22 (I2, REFUTED - the overwrite dialog is answerable by touch; the previous line's blocker was a probe error): screen 11 is `progress-screen memcard-data-exists` with `*yes-no-options*`, and only the LEFT and RIGHT D-pad handlers touch `*progress-state* yes-no-choice` (`progress.gc:890-900` sets it #t on `cpad-pressed? 0 left`; the right block sets #f); up/down merely move the option index. Measured on a settled dialog (trace `a=128`, not the 8/23 fade): `dpad-down` then Cross logs `edge screen=11 index=0 abs=64` and takes the NO path back to the save screen, while `dpad-left` then Cross overwrites and reaches `GAMEPLAY: enter misty / village1 / training` with `scene-level='training'`. Earlier attempts only ever pressed right/down, which is why it read as unanswerable.
2026-09-22 (I2, MEASURED - save metadata survives a relaunch, plus two instrument/workflow facts): with a save the port wrote in an earlier session in place (`OpenGOAL/jak1/saves/BASCUS-97124AYBABTU!/bank0.bin`, 67584 bytes = BANK_SIZE + 2 x McHeader) the save screen draws slot 0 as `GEYSER ROCK` with `9/22/2026 18:13` and the other three rows EMPTY, and accepting it loads the training level - so write -> presence -> name/date -> load all round-trip. The `OTTSEL G1: str=` line prints the *option* name while save/load rows draw their text from the slot info, so that line's `NONE` was the trace's placeholder and never evidence of an empty slot: the desktop path (`progress-draw.gc`, in `a11-diagnostic-traces.patch`) now prints `<null-name>`, and the iOS lane's copy in `pc/progress-pc.gc` was left alone because it sits inside the canonical h3 patch (recorded in `patches/README.md`). Also: `scripts/build-ios.sh` does not re-emit GOAL (it copies only KERNEL/GAME.CGO, and its ENGINE.CGO is a stale leftover) while signed modules come from `out/jak1/obj/<module>.o`, so a GOAL edit needs the separate `goalc (mi)` 546-target re-emit before the app build or the app keeps the old code. Evidence: `evidence/A1/i2-save-overwrite-and-metadata-2026-09-22.md`.
2026-09-22 (NEXT - one variable): I2 state fidelity, now unblocked - save from a known state and prove the load restores it: move Jak to a measured position (the bounded `OTTSEL TARGET POS` trace in `shadow.gc` already reports `(-> self control trans)`), save through the pause menu, relaunch, load, and compare position/progress rather than merely reaching the level. Behind it: L4 dynamic MERC eyes and HUD/menu material, audibility, and D1 device readiness.
2026-09-22 (I2, CORRECTED - a Jak 1 save is a continue point plus run counters, not a transform, so the line above's method was invalid): the target's own position trace at the loaded spawn is `t=(-5393129.0,28317.4628,4362849.5)` and that float triple appears nowhere in `bank0/bank1/bank2`; every bank instead holds an ASCII continue-point name at body `+0x4c0` plus counters at `+0x470/+0x480/+0x490/+0x4a0`, and `bank2`'s `+0x470` = 339985 is exactly the `game-base=` value this session's own `SUBMITSTAT` printed, i.e. a run-clock field. The in-game pause wheel is the progress screen where up/down scroll levels and only CIRCLE opens settings (`respond-progress`, `progress.gc:1133` -> `progress-screen settings` = the `GAME OPTIONS / GRAPHIC / SOUND / LOAD GAME / SAVE GAME / DISABLE AUTO-SAVE / QUIT / BACK` list), and the file triggers drive it end to end (`edge screen=3 index=4` -> `accept screen=3 index=4` = SAVE GAME).
2026-09-22 (I2, LANDED - an in-level save restores its own continue point across a relaunch, measured A/B): the save screen showed slot 0 = `GEYSER ROCK 9/22/2026 18:21` with slots 1-3 `EMPTY`, and saving into slot 1 wrote a new `bank2.bin` (67584 B), so UI slot N maps to `bank<N+1>.bin` while `bank0.bin` is the auto-save card. After `simctl terminate` + relaunch, loading slot 0 (`bank1.bin`, body continue point `title-start`) routes `GAMEPLAY: enter title` -> `village1` -> `training` with `CAMERA START: cp "game-start"`, while loading slot 1 (`bank2.bin`, body `training-start`) goes straight to `GAMEPLAY: enter training` with `CAMERA START: cp "training-start"` - the loaded continue point is the string that slot's own save recorded, so the state comes from the save and not from a level default. `ottsel-fault.log` 0 bytes in both load runs, `scene-level='training'` in both; tool `scripts/verify-ios-save-continue-point.py` (positive `--slot 1 --expect-cp training-start` OK, negative control `--slot 0` reports MISMATCH). Evidence: `evidence/A1/i2-save-state-fidelity-2026-09-22.md`. Still open for I2: audibility, and a second save after real mid-level progress (the measured counters track the run clock, so they are not that proof).
2026-09-22 (G2 LOOP): the current execution loop is the new "September 22 (night) execution update - G2 acceptance goal loop" section of `RECOVERY_GOAL_LOOP.md` (entry state, then G2.1 save fidelity done, G2.2 L4 renderer parity, G2.3 audibility, G2.4 I3 frontend, G2.5 P1 iPhone re-run, G2.6 packaging/import, G2.7 devices). NEXT (one variable): G2.2's first item, per-batch ALPHA 0x48 additive clouds - the frozen real population is already retained, both carriers (`NativeSpriteBatch.diagnostic_alpha`, TIE DrawMode 3-bit) exist, so land two additive pipeline states plus mode-based selection and prove it with a production blend-equation regression and matched captures.
2026-09-22 (G2 MAINTENANCE): `scripts/replay-ios-normal-route.py` is stale - it waits for `OTTSEL INPUT: pad0 sample buttons=0x0`, which the current shell no longer logs (triggers log `ottsel BOT22: latched <button> tap (file trigger)`), so the maintained route driver must be refreshed to the markers the shell emits before it can be the one-command check again.
2026-09-22 (G2.2 PREMISE CHECK, the Sky-cloud item is stale - REFUTED, no renderer change landed): the retained 2026-09-12 premise was that Sky cloud batches request GS ALPHA 0x48 while the shell draws them through the source-over `directBlendPipeline`. On the accepted source that selection site is dead: `ottsel metal: SKYLOOP` (`metal_shell.mm:1902`) and `ottsel metal: SKYBOUNDFRAME` (`:2142`) are the block's own per-frame records, both gated on `!sky_batches.empty()`, and both count 0 for the whole of a full iPad run that reached the title, village1 and training, so no Sky batch was ever drawn through that pipeline. The decode does submit (`OTTSEL SKY PRODUCT` samples 6-8: `candidates=2 rejected=0 texture-misses=0 untextured=2 tex0-writes=0 primitives=2 submitted=2 ndc=(-1,-1)..(1,1) end=0x50c8e0 expected=0x50c8e0`, two untextured `PRIM.TME=0` full-screen strips that get the 1x1 white texel at `metal_gfx.mm:3436-3443`), so the loss is after the decode and the exact drop is still open. The composite that does run (`OTTSEL SKY BLEND`) is already replace-then-add (`metal_gfx.mm:4838-4849`), so it never consults the source-over Metal pipeline. Landing an additive Direct pipeline now would be unverifiable; evidence: `evidence/A1/g2-sky-batch-path-inert-2026-09-22.md`.
2026-09-22 (G2.2, RE-SCOPED): the Sky-cloud item is closed as stale, not fixed. The loop's renderer order is now (1) a bounded per-frame log of the Sky batch store's begin/publish/snapshot state to name where the two submitted strips are lost, (2) a bounded ledger of the blend modes live sites actually request - TIE's `draw.mode >> 24` still collapses additive enum 2 into the source-over pipeline (`metal_shell.mm:1796-1808`, `mobile_scene_policy.h:120-124`) and Direct/sprite batches carry `diagnostic_alpha` - then land the GS/DrawMode equation decoder plus additive pipeline states only at the sites that ledger proves, with a focused decode regression and a matched before/after capture, (3) then dynamic MERC eyes and HUD/menu material. Section: `RECOVERY_GOAL_LOOP.md` G2.2.
2026-09-22 (G2 STATE): no renderer change was made this round and none is claimed. Lane left clean after measurement - app terminated, all `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*` triggers removed, Simulator shut down, 0-byte `ottsel-fault.log`, strict build reports `GAMEPLAY: enter training`. Disk `/` Avail 45 GiB, zero `.git/objects/pack/tmp_pack_*`.

2026-09-22 (G2.2 ITEM 1, ANSWERED - the Sky store is not losing the strips; the earlier "reads empty" premise was a log-channel artifact): a ledger inside `OttselMobileDirectFrame` (`debug_take`/`debug_sizes`) plus one bounded 8-line `SKYSTORE` record at the draw pass' `_skyFrameStore.snapshot()` site shows every publish reaching the snapshot the pass consumes - `probe=1 begin=1 append=2 publish=1 rollback=0 empty-publish=0 empty-replace=0 pre(completed=2) snapshot=2`, then `append=40 snapshot=40`, `append=40 snapshot=40`, `append=34 snapshot=34` (two runs, identical). `empty-replace` counts a publish that retires a non-empty ready population with an empty one (the empty-bucket clear dropping submitted strips) and is 0 in every window, with `rollback`/`empty-publish` 0 too, so no clear overtook a submitted population. Evidence: `evidence/A1/g2-sky-store-not-losing-strips-2026-09-22.md`.
2026-09-22 (G2.2 METHOD CORRECTION - `NSLog` records live in the unified log, not `ottsel-runtime.log`): `SKYLOOP`/`SKYBOUNDFRAME`/`SKY ALPHA`/`SKY ENCODE`/`SKYFRAME` are `NSLog` (read with `xcrun simctl spawn <udid> log show`), while `ottsel-runtime.log` carries only the port's `lg::info` records (`OTTSEL SKY PRODUCT`, `OTTSEL SUBMITSTAT`, `OTTSEL DIRECT FRAME`). In one run the port log holds `SKYLOOP` 0 / `SKYBOUNDFRAME` 0 / `SKY PRODUCT` 8 against the unified log's `SKYLOOP` 24 (`frame=1 batches=2`, then `batches=40/40/34/34`) / `SKYBOUNDFRAME` 3 / `SKY ENCODE` 6. So the G2.2 premise-check line "the batch draw block never executes (`SKYLOOP` and `SKYBOUNDFRAME` count 0 for the whole run)" was a channel artifact and is retracted: the block runs, and any earlier conclusion drawn from an `NSLog`-only record needs the unified log.
2026-09-22 (G2.2 ITEM 2, FIRST HALF MEASURED - the live blend registers are source-over, so additive states stay unverifiable for a measured reason): `ottsel_metal_arm_blend_ledger` re-arms a bounded per-site sample on every `select_mobile_scene_level`, and the route (title -> NEW GAME -> CONTINUE WITHOUT SAVING -> `GAMEPLAY: enter title/village/misty`, `scene-level='training'`, eichar 112, 0-byte fault log) repeated the same numbers over 18 arms: `SKYREG i=0..3 blended=1 diagnostic-alpha=0x44 va=0.502 tex=32x32 n=3` (the port's own source-over packing; no batch carried the additive 0x48), `DIRECTREG i=0..3 blended=1 diagnostic-alpha=0x0 tex=256x512 n=3`, `TIEREG draws=200 enable=196/4 blend=196/4 preset=0,199,0,0,1,0,0,0` - preset 2 (the additive enum) zero times. `diagnostic_alpha` is the decoder's `GsRegisterAddress::ALPHA_1` value (`metal_gfx.mm:3872`/`:3483`), not the vertex alpha. Evidence: `evidence/A1/g2-live-blend-register-ledger-2026-09-22.md`.
2026-09-22 (G2.2 NEXT - one variable, now with a named prerequisite): landing additive (`Cs*As + Cd`) pipeline states needs a population that actually requests them. The live route requests source-over at all three sites, so the retained 2026-09-12 ALPHA 0x48 reading (cloud batches 4-34) has to be reproduced on the lane where it occurs - the desktop/host Training capture - and used as the decoder regression's input; on this lane the Sky/TIE/Direct sites already match the registers they are handed, so nothing is landed at them. Behind it: dynamic MERC eyes and HUD/menu material (G2.2 items 3), G2.3 audibility, G2.6 packaging.
2026-09-22 (G2 MAINTENANCE, MEASURED - the route driver passes on the current build): `scripts/replay-ios-normal-route.py 08636791-2675-4675-8335-EF72EF954DCF` drove `OTTSEL TITLE: start edge` -> `accept screen=27 index=0` -> `edge screen=18 index=0..3` -> `accept screen=18 index=4` and printed "Continue Without Saving accepted" in ~23 s, so its held-press + post-release neutral-sample contract is satisfied by the documented launch env (`SIMCTL_CHILD_OTTSEL_TRACE_INPUT=1`, which is what produces the `OTTSEL INPUT: pad0 sample buttons=0x0` marker it waits for). The G2 LOOP/MAINTENANCE lines that call it stale are superseded.
2026-09-22 (G2 STATE): no rendering behaviour changed this round and none is claimed - the two probes are observability only (a store ledger and a bounded per-site register sample). Lane left clean after measurement: app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 0-byte `ottsel-fault.log`, strict build reports `scene-level='training'`. Disk `/` Avail 45 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-22 (G2.2 ITEM 2, CORRECTED then LANDED - the additive population is live and the decode is in): the previous line's four-batch sample was too small and is corrected by an exhaustive per-population histogram (`SKYREG-MIX`, one line per distinct register mix over *every* batch): the textured cloud tiles carry GS ALPHA 0x48 (S/Z/S/D = `(Cs-0)*As + Cd`) and only the untextured full-screen strips carry 0x44 (source-over); the Direct text/logo batches report register 0 because the register was never carried to the shell on that path (now plumbed).  Landed: `src/shell/mobile_blend_policy.h` decodes a/b/c/d(+fix) into the six combinations the desktop DirectRenderer supports plus `Unsupported` (zero = `Unspecified`, since both capture paths reset the decoder state per bucket), `directAdditivePipeline` (rgb SrcAlpha/One/Add, alpha One/Zero), and the Sky site now picks opaque / additive / source-over from the batch's own register.  Host regression `bash scripts/test-mobile-blend-policy.sh` (`test/mobile_blend_policy_test.cpp`) PASS 12/12.  Evidence: `evidence/A1/g2-sky-additive-blend-2026-09-22.md`.
2026-09-22 (G2.2, MATCHED CAPTURE + the selection proof): with the gate `ottsel-trace-sky-blend-register` flipped inside one run at one camera, `SKYBLEND register-drive=0 additive-drawn=0` against `register-drive=1 additive-drawn=31` (the 6 source-over-key batches are never switched).  Static Training camera, region x 0.85-1.0 / y 0.15-0.40 of the 1668x2420 capture: 85.882/88.208 mean under source-over against 110.523/111.669 under the additive state; the two-capture diff changes 47.163% of that region's pixels by >24 with mean|delta| 50.46/channel, confined to the region box, and the sky strip is black against light blue.  Tool: `scripts/measure-png-region-mean.py` (region mean, or two captures to diff).
2026-09-22 (G2.2, WHY THE FIX SHIPS GATED - a newly visible pre-existing defect, named): the village1/title backdrop's sky tiles decode to garbage colour data on this lane, so enabling the register-driven additive state there turns a muted artefact into a vivid one.  `SKYREG-MIX` shows the whole sky population's vertex colours are grey 0.5 (some vertices black) while the first textured batch's vertices are `(0.50,0.50,0.50)`, so the colour comes from the *texture*, not the vertices; an alternating capture sweep 1 s apart at one camera shows the same large cloud quads vivid under additive (`/tmp/ottsel-g22/sweep/a15.png`) and muted under source-over (`b15.png`).  The Training level's sky decodes correctly and is strictly improved (black -> light blue), so the gate is a data-defect gate, not a decode gate.  Default product behaviour is unchanged; the gate is `ottsel-trace-sky-blend-register`.
2026-09-22 (G2.2, TOOLING + the overlay record): new `scripts/measure-png-region-mean.py` (region mean / two-capture diff through `sips`, no Python deps) and `scripts/test-mobile-blend-policy.sh` + `test/mobile_blend_policy_test.cpp` (host decode regression).  The round's source changes are recorded as `patches/g2.2-sky-blend-and-ledger.patch` (new `mobile_blend_policy.h` plus `mobile_direct_frame.h`, `metal_shell.h/.mm`, `metal_gfx.mm`), verified in both directions against a reconstructed pre-round tree; the probe-only overlay recorded earlier the same day was removed because its pre-side carried a dangling ledger block and it no longer reverse-applied.
2026-09-22 (G2.2 NEXT - one variable, with the blocker named): fix the village1/title sky texture/CLUT decode (the texture is the colour source, the vertices are grey), then flip `ottsel-trace-sky-blend-register` on by default so the level sky renders its requested additive equation everywhere.  Behind it: the Direct site's blend decision (its register is now carried but never selected on) and the TIE preset-2 question (199 of 200 live draws request preset 1; preset 2 is still never observed live), then dynamic MERC eyes and HUD/menu material.
2026-09-22 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 45 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-22 (G2.2 ITEM 2, ROOT CAUSE CORRECTED - the Sky bucket is upstream's SkyBlend consumer, and drawing it raw was the rainbow): the desktop oracle settles it by reading, not guessing: `SkyRenderer` is bound to `BucketId::SKY_DRAW` = bucket 3 (`OpenGLRenderer.cpp:676`) and its `render` (`SkyRenderer.cpp:158-247`) is a `DirectRenderer` that reads a 64-byte setup packet and only draws when the *following* tag is `qwc == 5`, sampling the **64x96 sky texture the SkyBlend handlers composite** (buckets 32/39, `OpenGLRenderer.cpp:762/780`).  The live 1 Hz `OTTSEL SKY SHAPE` ledger matches: `payload-qwc=4 payload-size=64 after-setup-qwc=5 desktop-path=sky-draw`.  Two readings from earlier in this round are retracted: `qwc != 8 -> tfrag-trans` is `SkyBlendHandler`'s branch (buckets 32/39), not bucket 3's, and the sky tiles do not decode to garbage colour data - `OTTSEL SKY TEXEL` shows real sky-source texels (`0x154005f80 psm=0 32x32 rgba=(131,162,189,128)/(136,199,253,128) registry=1`).  Evidence: `evidence/A1/g2-sky-draw-source-2026-09-22.md`.
2026-09-22 (G2.2, THE FIX AND THE MATCHED PAIRS): this lane does not implement the SkyBlend composite, so drawing bucket 3 samples the uncomposited relocated source while the port's own composite (`OTTSEL SKY BLEND`) already draws the sky - and the quads' live registers are additive (`SKYREG-MIX`: 32x32 cloud tiles 0x48, untextured 1x1 strips 0x44), so the double-draw became a vivid rainbow.  The sky draw is now skipped by default (`drawn=skipped`); matched tight pairs at one camera: `/tmp/ottsel-g22/disc/new-9.png` (default) clean sky against `/tmp/ottsel-g22/disc/old-9.png` (legacy) rainbow, and `/tmp/ottsel-g22/fin-fixed-2.png` against `fin-legacy-2.png` at another phase.  A fresh default process logs no sky draw/store records at all across title + training, and the title and Training render normally (`clean-title.png`, `clean-train.png`); lane health unchanged (346 ENTER = 346 RETURNED, 0-byte fault log, `scene-level='training'`).
2026-09-22 (G2.2, THE REGISTER SELECTION IS NOW UNCONDITIONAL + the A/B controls): with the rainbow's cause removed, the `ottsel-trace-sky-blend-register` gate is gone and the Sky site always selects opaque / additive / source-over from the batch's own GS ALPHA register, exactly as upstream's DirectRenderer does (it is inert on this lane until the composite exists, because no sky population is drawn).  Two live controls remain: `ottsel-trace-sky-skip-draw` (issue no Sky draw) and `ottsel-trace-sky-draw-legacy` (draw the bucket quads = the pre-fix behaviour).  New `SKYUV` record shows the ST/Q decode is sane (stored ST ~1e-4 with q ~3e-5..3e-4, post-divide uv 0..0.65 across a 32x32 tile), so the uv path was never the defect.
2026-09-22 (G2.2, STORE SEMANTICS FOUND THE HARD WAY): the sky store *retains* its last published population, so after the legacy control publishes one (44 batches at 23:18:36) that population keeps being drawn every frame until replaced (`SKYFRAME batches=42` in the same process afterwards, even with the trigger removed).  Future default-state measurements must use a fresh process; this is why an intermediate check in this round read 21 sky records in the level after an A/B.
2026-09-22 (G2.2 NEXT - the faithful fix, one variable): port the SkyBlend composite (`SkyBlendGPU`/`SkyBlendCPU`: sky copies + cloud copies into the 64x96 sky texture) and draw bucket 3 from its result; the decoder, the additive pipeline state and the register-driven selection are already in place.  Behind it: dynamic MERC eyes and HUD/menu material, then G2.3 audibility and G2.6 packaging.
2026-09-22 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 44 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source is recorded as `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions.
2026-09-22 (G2.2 ITEM 3, STAGE 1 - the eye bucket decoder and composition are landed; nothing is bound yet): bucket 54 is `BucketId::MERC_EYES_AFTER_PRIS` (`buckets.h:61`), and upstream's `EyeRenderer` consumes a 128-byte GS offset packet, a 32-byte alpha setup, a NEXT/NOP, then per eye slot an ADGIF (iris TEX0) + background draw + iris L/[optional right-ADGIF +] iris R + test + ADGIF (pupil) + pupil L/R + test + ADGIF (lid) + lid L/R + end, each draw being a 32-byte scissor plus a 96-byte sprite whose `uv0` carries the reading merc-ctrl's FNV hash.  Composition happens in the GS 512..1024 window at four units per texel (`shaders/eye.vert`: `gl_Position = (xyst - 768)/256`), so `target_px = (xyz - eye_offset)/4 - 128` (or `/8 - 128` for the 64-unit layout); the target starts as the iris page's (0,0) texel, iris and lid are copies, only the pupil blends, and the result is loaded at `8160 + slot`, which is how `Merc2.cpp:1175`'s `eye_id == 0xff ? tree_tex_id : (0xefffff00 | eye_id)` resolves.  Implemented natively in `submit_mobile_native_eye_bucket` (metal_gfx.mm): the decode, a CPU composition into 128x128 RGBA per slot, one submission per vsync, plus `ottsel-trace-eye-dump` PPM dumps of the composed slots and their source pages.  Evidence: `evidence/A1/g2-merc-eyes-bucket54-decode-2026-09-22.md`.
2026-09-22 (G2.2 ITEM 3, MEASURED AGAINST THE REAL PACKETS): the decode walks the real chain - `OTTSEL EYE ADGIF: addr0=0x6 addr1=0x1cf06a14 addr2=0x34 addr3=0x8 addr4=0x42` is exactly TEX0_1/TEX1_1/MIPTBP1_1/CLAMP_1/MIPTBP2_1, `OTTSEL EYE: pair=0 using64=0 iris=0x2004f3e51130a76f pupil=0x200446e51130a231 lid=0x200446651130a232 lrect=(480,564..936,1020) prect=(596,680..820,904)` remaps into the 128x128 target as the oracle's mapping predicts (iris (-8,13..106,127), pupil (21,42..77,98)), and the three layers resolve from the registered images (`iris tbp0=0x276f psm=19 cpsm=0 cbp=0x279f registry=1 16x16`).  Visually the pupil page decodes as a clean soft black disc, so the page decode is right; the iris page carries speckled green/magenta blocks and the composed slot is blocky because this composition samples nearest while the oracle uses LINEAR.  Lane health unchanged (346 ENTER = 346 RETURNED, 0-byte fault log, `scene-level='training'`).
2026-09-22 (G2.2 ITEM 3 NEXT - three named steps, one variable each): (a) bilinear sampling in the eye composition so the layers match the oracle's LINEAR filtering; (b) decide whether the iris page's speckles are the game's data or a palette/CLUT issue, by comparing it with the level texture the MERC eye draw samples today (slots 323/324, the audit's "background base"); (c) bind - the MERC eye draws (`eye_id != 0xff`) must sample the composed slot (`0xefffff00 | eye_id` -> slot `eye_id % 40`) instead of the level slot.  Only (c) changes what the player sees, and the in-game eyes are still uncomposed until it lands.
2026-09-22 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 44 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source (sky rounds plus this eye decoder) is recorded as `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions.
2026-09-23 (G2.2 ITEM 3, STAGE 2 - THE COMPOSED EYES ARE BOUND AND VISIBLE): the bind mirrors upstream's `Merc2.cpp` rule by making the composed slot a reserved texture slot: `MercDraw::eye_id` is `(pair << 1) | is_r` (`Tfrag3Data.h:553`) so it indexes the composed slots directly, `mobile_eye_texture_base()` takes 40 slots from `g_mobile_next_texture_base` (no collision with a level's range), the bucket-54 consumer composes every pair it walks into `g_mobile_eye_images[pair*2 + lr]`, and the MERC draw builder overrides `draw_texture_index` for `eye_id != 0xff`, uploading the composed 128x128 only when it differs from the last uploaded copy.  Measured (346 ENTER = 346 RETURNED, 0-byte fault log, `scene-level='training'`): `OTTSEL EYE BIND: model=eichar-lod0 eye-id=0x0 slot=0 texture-index=1689` and `eye-id=0x1 slot=1 texture-index=1690`, plus `model=sidekick-lod0 eye-id=0x3/0x2 slot=3/2` - both actors' eyes now sample composed slots.  What the eye sampled before the bind: the level texture at index 323 is a **4x4 flat blue-grey page** (`OTTSEL EYE LEVEL PAGE: index=323 4x4`).  Visual (turning Jak with `ottsel-hold-stick-left` + D-pad, `/tmp/ottsel-g22/heads-big.png`): the eye now shows a light-blue iris, a dark pupil and a skin-coloured lid band, where before it was that flat page.  Evidence: `evidence/A1/g2-merc-eyes-bind-2026-09-23.md`.
2026-09-23 (G2.2 ITEM 3, OPEN ITEMS NAMED): (a) the iris page's rim texels decode to saturated green/magenta on this lane and the eye draws' `ignore-alpha=true` lets them show as coloured patches around the eye at close range - either the game's data is like that (check the desktop lane) or the page's palette/CLUT resolution differs from the level's own texture data (then resolve the eye sources through the level texture path); (b) the composition runs four slots per chain on the CPU, fine at four but a full 40-slot chain needs the same change detection the upload already uses; (c) there is no desktop-capture A/B for the whole eye yet.  Also carried forward from the sky round: port the SkyBlend composite so bucket 3 can draw from its result instead of being skipped.
2026-09-23 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 46 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source (sky rounds, eye decoder, eye bind) is recorded as `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions.
2026-09-23 (G2.2 ITEM 3, THE RIM SPECKLES WERE A SOURCE-RESOLUTION DEFECT - FIXED): the eye composition first preferred the *relocated-registry* copy of a page, and for these palettized (PSMT8) pages that copy carries garbage palette colours, so the iris drew with saturated green/magenta rim texels that `ignore-alpha=true` let show around the eye.  Upstream resolves an eye layer through the *level's texture pool* by TBP0 (`texture_pool->lookup_gpu_texture(adgif.tex0().tbp0())`), so `mobile_eye_source` now tries the same route first: the page's metadata `combo_id` -> `g_mobile_pool_textures` -> the level's own texture.  Measured: `OTTSEL EYE SRC: name=iris path=pool tbp0=0x276f psm=19 cpsm=0 cbp=0x279f registry=1 16x16` and the resolved page is a clean blue iris disc (the registry copy was speckled).  On the actor the eye now reads as white sclera + blue iris + dark pupil on Jak and white sclera + dark pupil on Daxter (`/tmp/ottsel-g22/fixc-heads-big.png`), with one small speck left above Jak's eye.  Lane health unchanged (346 ENTER = 346 RETURNED, 0-byte fault log, `scene-level='training'`).  Evidence: `evidence/A1/g2-merc-eyes-bind-2026-09-23.md`.
2026-09-23 (G2.2 ITEM 3, OPEN + ONE OBSERVATION): open - the composition covers four slots per chain on the CPU (fine at four; a full 40-slot chain needs the change detection the upload already uses), and there is still no desktop-capture A/B for the whole eye.  Observation: one frame of the pool-source run showed a large transient white cloud-like overlay that its neighbouring frames do not; it is camera-dependent and unattributed, and the reserved eye slots cannot alias another consumer's indices (`g_mobile_next_texture_base` is used only for level bases, and the sprite path uses a fixed `0x3c00` base).  Carried forward from the sky round: port the SkyBlend composite so bucket 3 can draw from its result instead of being skipped.
2026-09-23 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 46 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source (sky rounds, eye decoder, eye bind, pool source resolution) is recorded as `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions.
2026-09-23 (G2.2 ITEM 3, EVERY EYE PAIR IS NOW COMPOSED - AND ONLY ON CHANGE): the bucket-54 walk covers all 20 pairs (it was capped at two) and recomposes a pair only when its packet signature (the three layer textures plus their rects) changes, so the steady-state cost is one comparison per pair per chain.  Measured: `OTTSEL EYE CHAIN: pairs=2 slots=4 composed=2` on the first pass, then `composed=0` while nothing moves, then `composed=1` when a pair does (a blink moving a lid rect); the chains in this level carry one or two pairs and the MERC draws request only slots 0-3 (the eichar's pair 0 and the sidekick's pair 1).  Close-range capture on this build still shows white sclera with a blue iris and dark pupil on Jak, and white sclera with a dark pupil on Daxter (`/tmp/ottsel-g22/fe2-big.png`).  Lane health unchanged (346 ENTER = 346 RETURNED, 0-byte fault log, `scene-level='training'`).  Evidence: `evidence/A1/g2-merc-eyes-bind-2026-09-23.md`.
2026-09-23 (G2.2 ITEM 3 REMAINING + NEXT): the eye item is functionally complete and visually verified; what is left is a desktop-capture A/B for the whole eye and the unattributed transient white overlay seen in one earlier frame.  The loop's next renderer sub-item is HUD/menu material, and the SkyBlend composite port is still carried forward so bucket 3 can draw from its result instead of being skipped.
2026-09-23 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 46 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source (sky rounds, eye decoder, eye bind, pool source resolution, change-detected composition) is recorded as `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions.
2026-09-23 (G2.2 HUD/MENU MATERIAL, CHARACTERIZED - DECODED AND SUBMITTED, NOT VISIBLE): the game's HUD sprite groups reach the port and are consumed (48 sprites/288 vertices and 32/192 across the run), the atlas is populated (`atlas-rgb=23785/40960`, `atlas-alpha=18611/40960`), nothing is skipped, the Sprite3 pass is permissive (GEQUAL with depth writes off, alpha test GEQUAL at 2/128, scene depth clear 0.0) and the HUD's own ndc-z is 0.995 - so the quads are submitted and pass both the alpha test and the depth test, yet no HUD is visible in the in-level captures.  Per-sprite data: the first sprite is a full-screen quad at 4.7% alpha (the screen fade) and the next are large panels (`clip=(-1.559,1.754)(0.020,1.754)(0.020,-2.040)(-1.559,-2.040)`, `color=(0.502,0.502,0.502,0.502)`), while the group's clip x reaches 13.95 (some quads sit several screens right).  Evidence: `evidence/A1/g2-hud-material-decode-2026-09-23.md`.
2026-09-23 (G2.2 HUD, ONE HYPOTHESIS MEASURED AND REFUTED): `sprite_3d.vert`'s 2D/HUD paths assign `scales_vf01.w = scales_vf01.z` (z holds the sy-derived value), so upstream scales both bases by `max(sy*Q, min_scale)` while the port uses sx for the x basis; a gated build (`ottsel-trace-hud-desktop-scale`) replicates the quirk and logs the raw scales, and the measured sprites have sy > sx (`sx-raw=48496 sy-raw=87408`), so the quirk *widens* x and cannot explain the off-screen extents.  It stays a gated probe, not a landed fix.  NEXT (one variable): capture the in-level HUD window itself (all 24 logged groups share one timestamp, i.e. the sampled groups are the intro/loading panels), then instrument the sprite draw path for the HUD batches if the quads still do not land.
2026-09-23 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 45 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source (sky rounds, eye decoder/bind, the HUD diagnostics and the gated scale probe) is recorded as `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions.
2026-09-23 (G2.2 HUD, NARROWED - THE HUD IS EMITTED IN-LEVEL AND IS ENCODED): with a per-second record (the earlier 24-line budget filled in one second) the HUD groups appear throughout the level, one every ~18 vsyncs (`sprites=48 atlas=384x64 vsync=934`, `vsync=952`, ... `vsync=1133`, all `scene-level='training'`), the shell's own draw record confirms what reaches the encoder (`Sprite3 native draw vertices=288 blend=enabled batches=2 depth=gequal/no-write alpha-test=gequal/5/2 texture=hit`), and dumping the *largest* atlas shows the real HUD content - the four face-button icons (X/Square/Triangle/Circle), eco shapes and Daxter's head - so the decode, packing and uv normalisation are right.  Two suspects are eliminated: forcing the HUD's vertex alpha to 1 (`ottsel-trace-hud-opaque`) changes nothing on screen (so icon alpha is not what hides it), and the store-clearing legacy path (`set_sprite_mesh` -> `clearSpriteBatches`) is gated off whenever the native sprite product is requested, which is the in-level case.  Evidence: `evidence/A1/g2-hud-material-decode-2026-09-23.md`.
2026-09-23 (G2.2 HUD NEXT - one variable): draw a HUD *fixture* (the same batch with its clip corners replaced by a known corner quad) to separate "the quads are off-screen" from "the fragments are rejected" (a texel alpha of 0 at the sampled uv); whichever it is names the fix - the clip mapping or the uv/atlas sampling.  Carried forward: the SkyBlend composite port for the sky, and the eye item's desktop-capture A/B.
2026-09-23 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 46 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source (sky rounds, eye decoder/bind, HUD diagnostics and the two gated HUD probes) is recorded as `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions.
2026-09-23 (G2.2 HUD, THE FIRST CONTROL THAT CHANGES WHAT THE SPRITE PASS PAINTS): `ottsel-trace-sprite-overlay-depth` draws sprite batches with the overlay (ALWAYS/no-write) state instead of the Sprite3 GEQUAL/no-write state, and armed it makes long thin strips appear over the bridge/rock area where the plain build shows nothing (the same frames without the control are clean) - so at least part of the live sprite population (the World2D set, which shares the pass with the HUD) is *rejected by the depth test*: its z is farther than the world's depth where it is asked to draw.  A gated HUD fixture (`ottsel-trace-hud-fixture`: every HUD quad replaced by a known corner quadrant at z=0.995, opaque, atlas-centre uv, logged active) paints nothing alone and still paints no quadrant with the overlay-depth control, while other sprite batches do paint strips - so either the fixture's vertices never reach the drawn batch or the geometry is degenerate in a second way.  Evidence: `evidence/A1/g2-hud-material-decode-2026-09-23.md`.
2026-09-23 (G2.2 HUD NEXT - one variable, and cheap): the sprite vertex buffer is `MTLResourceStorageModeShared`, so the shell's draw loop can log the first vertex it is about to submit; if it is the fixture's own corner (-1,1) the fixture reaches the GPU and the rest is raster/pipeline state, and if it is not then the HUD path's vertices are dropped or overwritten before the draw.  Carried forward: the SkyBlend composite port for the sky, the eye item's desktop-capture A/B, and the newly exposed World2D sprite depth rejection (thin strips) as its own defect.
2026-09-23 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 45 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source (sky rounds, eye decoder/bind, HUD diagnostics and the three gated HUD/sprite probes) is recorded as `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions.
2026-09-23 (G2.2 HUD, THE DRAWN ATLAS BATCHES ARE WORLD SPRITES - THE HUD'S BATCH NEVER REACHES THE DRAW): `ottsel-trace-sprite-first-vertex` reads the first vertex of every atlas-sized drawn batch back from the shared vertex buffer (1 Hz), and all 40 records in a routed run are world space - e.g. `tex=384x64 n=288 v0=(-5.375,44.424) uv=(0.000,0.000) q=25.500 z=0.0006` and `v0=(1956.933,-9743.802) q=445.682 z=-0.0978` - while the HUD path in the same run reports submitting 23 groups.  None of the drawn batches carries the HUD's own signature (per-sprite depth 0.995 and an atlas uv), so the HUD's appended batch never reaches the draw.
2026-09-23 (G2.2 HUD, THE TWO BLOCKERS ARE SEPARATED): the World2D sprite batches *are* drawn and are rejected by the GEQUAL depth test (which is exactly why `ottsel-trace-sprite-overlay-depth` makes them paint as thin strips), while the HUD's quads are not drawn at all - and had they been drawn their depth (0.995, behind most world pixels) would have passed that same test.  So the HUD needs the store question answered, not a depth-policy change.  NEXT (one variable): log the sprite store's size immediately after the HUD path's append (game thread) and again at the pass' snapshot (main thread), which places the HUD's entries as never-appended, appended-then-erased, or appended into a store the pass does not read.
2026-09-23 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 46 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source (sky rounds, eye decoder/bind, HUD diagnostics and the four gated HUD/sprite probes) is recorded as `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions.
2026-09-23 (G2.2 HUD, CORRECTED - THE HUD *IS* DRAWN AND ITS DEPTH IS AT THE NEAR PLANE): my previous line's "the HUD's appended batch never reaches the draw" was a sampling artifact - the probe read one batch per second, and reading *every* batch of one pass per second shows the HUD's atlas batch present (`store=72 idx=7 tex=384x64 n=288 v0=(-5.399,43.544) uv=(0.000,0.000) q=25.500 z=0.0006`, alongside small-texture world batches at idx 1-6 and 8) while the producer side records `OTTSEL HUD APPEND: tex=320x64 n=288 store=1` with the store size varying from 1 to 72 as the pass snapshots and erases.  The drawn HUD vertex implies an effective depth of `z/q = 2.4e-5` - the near plane - so those quads are discarded by the pass' GEQUAL test against the world, exactly like the World2D strips; other HUD groups carry 0.995 and would pass, so the population's depth is inconsistent.
2026-09-23 (G2.2 HUD, ROOT CAUSE NARROWED TO THE SPRITE DEPTH DERIVATION): `depth[vertex] = final_position.z / 16777216` with `final_position = base + x_basis*xy.x + y_basis*xy.y`, and `base` includes the selected offset (`hud.hvdf` or `hud.user_hvdf[matrix-1]`), so the offsets' and bases' z components decide the depth - two HUD groups sharing a q of 25.5 differ by four orders of magnitude (2.4e-5 against 0.995), which points at the per-sprite offset/matrix selection or the HUD matrix's z row rather than at the pass state.  NEXT (one variable): log the first sprites' matrix index, the selected offset's four components and the pre-multiply depth, and compare them with the desktop's own inputs (`sprite_3d.vert` reads the same `hud_hvdf_offset` / `hud_hvdf_user[matrix-1]`).  Carried forward: the SkyBlend composite port, the eye item's desktop-capture A/B, and the World2D depth rejection as its own defect.
2026-09-23 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 46 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source (sky rounds, eye decoder/bind, HUD diagnostics, the sprite store-size API and the four gated HUD/sprite probes) is recorded as `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions.
2026-09-23 (G2.2 HUD, THE DEPTH INPUTS ARE MEASURED - THE REMAINING VARIABLE IS THE WORLD'S DEPTH CONVENTION): `OTTSEL HUD DEPTH` (deduped per offset signature) shows the per-sprite `hud.user_hvdf[matrix-1]` offsets carrying z ~ 8.36-8.37M, `base.z` ~ 16.7M and a pre-multiply depth of ~0.995 (`idx=0 matrix=1 src=user offset=(2048.0,2048.0,8363981.5,270.87) base=(2048.0,2048.0,16697315.0,269.00) pre-depth[0]=0.995238 clip-w[0]=269.001 q=0.033`), and the pass-side read-back (filtered to the HUD's q band) confirms the stored vertices (`store=68 idx=8 tex=320x64 n=288 v0=(74.5,259.6) q=255.026 z=0.9931`, idx 9-17 at q 233-253) - i.e. `z = pre-depth x clip-w` exactly as the code writes.  So the rasterizer sees `z/q ~ 0.001-0.004`, the near end of the port's [0,1] range, for the quads that land on screen while other groups sit at the far end (0.995).  The Sprite3 pass tests GEQUAL with depth writes off against a scene cleared to 0.0, which is the same state that hides the World2D population (hence the overlay-depth control being the first control that made sprite geometry paint).
2026-09-23 (G2.2 HUD NEXT - one variable; two of my own readings retracted): read a world (TIE/MERC) vertex's z and q back the same way (the shell's mesh buffers are shared storage) and compare it with the HUD's `z/q`, which fixes the sprite depth - or the sprite depth-test choice - against the world's actual convention instead of inferring it.  Retracted as sampling artifacts: "the published store reads empty" and "the HUD's batch never reaches the draw" (both from logging one batch per second).  Carried forward: the SkyBlend composite port, the eye item's desktop-capture A/B, and the World2D depth rejection as its own defect.
2026-09-23 (G2 STATE): lane left clean - app terminated, no `ottsel-hold-*`/`ottsel-press-*`/`ottsel-touch-*`/`ottsel-trace-*` triggers present, Simulator shut down, 346 SIGNED MODULE ENTER = 346 RETURNED, `scene-level='training'`, 0-byte `ottsel-fault.log`.  Disk `/` Avail 46 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source (sky rounds, eye decoder/bind, HUD diagnostics, the sprite store-size API and the five gated HUD/sprite probes) is recorded as `patches/g2.2-sky-blend-and-ledger.patch`, verified in both directions.
2026-09-23 (G2.2 HUD/MENU MATERIAL, THE READING IS CORRECTED - THE SPRITE PASS DRAWS THE MENU): the authority's last `Next` (read a world vertex's z and q back and compare it with the HUD's) was done, and it refutes the depth explanation.  A per-pass census of every batch the sprite pass encodes (20 records per logged pass, 240 lines) shows the HUD's atlas batches *are* drawn - `tex=384x64 n=252 blend=1 q=263.223 z=262.0018 z/q=0.99536`, with `tex=512x128 n=288` - so `the appended batch never reaches the draw` was a sampling artifact of a 60-line global budget that filled inside three passes (and of a q-band filter that also skipped the draw it was only meant to observe; both are fixed in the probe, and it no longer drops draws).
2026-09-23 (G2.2 HUD, DEPTH IS NOT THE MECHANISM - MEASURED ON BOTH SIDES): the sprite pass tests GEQUAL with depth writes off against a 0.0 clear, exactly as upstream does (`Sprite3.cpp` `m_default_mode` GEQUAL/no-write; `OpenGLRenderer.cpp: glClearDepth(0.0)`), and the world's own Metal depth read back from the TFRAG clip ledger is `ndc-z=(-0.8645,0.9120)` for village1 (window depth 0.068..0.956) while the HUD's `z/q` is 0.9952..0.9959 - the near end.  A near-end fragment passes GEQUAL over that world everywhere, so both the sprite depth derivation and the sprite depth-test choice are faithful and neither hides the HUD.
2026-09-23 (G2.2 HUD, WHAT THE OFF-SCREEN QUADS ARE): `OTTSEL HUD DEPTH` now logs the raw record beside the derived values - `idx=0 matrix=1 xyz=(0,0,0,61440) projected=(0,0,251006816,-1.0966) base=(2048,2048,16697315,263.22)` against `idx=6 matrix=7 xyz=(245760,0,0,1228.8) ... projected=(123374.867,0,251006816,-1.0966) base=(5568,2033,16699363,263.22)`.  42 of the group's 48 sprites carry the identical `xyz.x=245760`, the HUD matrix's first row scales it by 0.502, and `base.x=5568` puts those quads at NDC x ~ 13.8 - about seven screens right.  That is the progress screen parked off screen (its only on-screen element is the 4.7%-alpha dimmer), and the port's chain (`sprite_matrix_transform(hud.matrix, ...)`, `Q=pfog0/w`, `+= user_hvdf[matrix-1]`, `(x-2048)/256`) is `sprite_3d.vert`'s HUD branch line for line, with the frame read at VU qword 980 and the 80-qword HUD matrix at qword 900 as upstream declares and the `static_assert`s prove.
2026-09-23 (G2.2 HUD, THE CONTROL THAT SEPARATES OFF-SCREEN FROM FRAGMENT-DISCARDED): new gated probe `ottsel-trace-sprite-atlas-fill` redraws the atlas-size batches through the sprite pipeline with a 1x1 opaque white texture and the overlay depth state.  Armed with the menu closed it paints nothing; armed and then with the pause menu open (Start) it paints eight white cells exactly in the menu's panel/icon slots over the level - so the pass does rasterize this material, `the HUD is invisible in-level` is really `the closed pause screen is off screen`, and the earlier fixture's null result is explained (its atlas-centre uv could sample a transparent cell).  The menu itself renders with material (`hud-pause.png`: GEYSER ROCK / 0% / OPTIONS plus the face-button icons over the level).
2026-09-23 (G2.2 HUD, NEXT AND CARRIED FORWARD): next, the title screen's solid-colour rectangles (`hud-title.png`) as their own defect - name the untextured colour fallback before touching the menu - then the menu panel cells that read as near-invisible while its text and icons show (the fill now separates their sampling/alpha from their geometry).  Carried forward: the SkyBlend composite so bucket 3 can draw from its result instead of being skipped, and the eye item's desktop-capture A/B.  Evidence: `evidence/A1/g2-hud-material-decode-2026-09-23.md` (supersedes its own first version, whose depth explanation is retracted).
2026-09-23 (G2 STATE): lane left clean - app terminated, Simulator shut down, no `ottsel-hold-*`/`ottsel-press-*` input triggers present, 0-byte `ottsel-fault.log`, `scene-level='training'` reached by the route.  Disk `/` Avail 46 GiB, zero `.git/objects/pack/tmp_pack_*`.  The round's source (sky/eye rounds, the sprite census and the two gated HUD/sprite probes) is still recorded in `patches/g2.2-sky-blend-and-ledger.patch`; the patch does not yet carry this round's `metal_shell.mm`/`metal_gfx.mm` probe edits.
2026-09-23 (G2.2 HUD/MENU MATERIAL, THE MENU RENDERS - WITH A MATCHED UNFILLED CAPTURE): a fresh routed run with only an observation probe armed, then Start pressed to open the pause menu, captures GEYSER ROCK, 0%, OPTIONS, the four face-button icons on their own panels, Daxter's head and the ring icons over the level (`/tmp/ottsel-g22/menu-nofill.png`) - so the HUD/menu atlas, the standalone progress textures, their uvs, their alpha and the blend all reach pixels.  The previous round's `the menu's panel cells read near-invisible` is **retracted**: the gated white-texture fill (`ottsel-trace-sprite-atlas-fill`) paints its eight cells exactly where those panels and icons are, i.e. it was covering working material, and with the menu closed it paints nothing because the closed progress screen is off screen (`xyz.x=245760` -> NDC x ~ 13.8, measured last round).
2026-09-23 (G2.2 HUD, THE ZERO-ALPHA CELLS ARE BY DESIGN - MEASURED BEFORE CHANGING CODE): new gated probe `ottsel-trace-hud-texel` samples the atlas at each submitted quad's own uv (`uv=(64.0,0.0) texel=(0,199,202,0) color=(0.502,0.502,0.502,0.502)`, `uv=(192.0,0.0) texel=(255,255,255,1)`), and decoding every HUD/menu tex0 in the run shows **TCC = 1 for all of them** (`tbp0` 0x252d, 0x2517, 0x2506, 0x340, 0x100, 0x380, ... psm 19/20).  Upstream's `sprite_3d.frag` forces `T0.w = 1.0` only when TCC = 0, so the port's hardcoded `tcc=1` sprite state is faithful for this population and a zero-alpha texel is meant to be discarded: the candidate `carry the sprite's TCC / ta0` fix is refuted before it was written.
2026-09-23 (G2.2 TITLE/OVERLAY, BOTH READINGS CORRECTED): the settled title renders (logo, PRESS START, the PRECURSOR LEGACY text over the village, `/tmp/ottsel-g22/t-title-b.png`).  The dense glyph lattice that fills the screen in the first seconds after `title-wait-ready` is a *transient opening state*: it is gone by +20 s and it survives with the sprite pass skipped (`ottsel-trace-metal-scene-no-sprite` consumed), so it is neither a sprite-pass nor a settled-title defect.  The solid-colour blocks are the port's own touch overlay - `setTouchOverlay` builds a 1x1 white texture and tints it per overlay vertex colour - and `hide_touch_overlay_for_native_input()` removes it under real touch, so as drawn here it is a file-trigger artifact of this harness, not game material.
2026-09-23 (G2.2 HUD/MENU MATERIAL SUB-ITEM: STANDS, NO PRODUCT FIX OWED): the material path draws what the game submits; with no menu open the only in-level sprite population the game sends is the closed progress screen (off screen) plus its 4.7%-alpha dimmer, so `no in-level HUD in the captures` is the game's own state rather than a rejected draw, and the census accounts for every drawn sprite batch.  Probes added this round and last: `ottsel-trace-sprite-first-vertex` (per-pass drawn-batch census), `ottsel-trace-sprite-atlas-fill` (white-texture redraw), `ottsel-trace-hud-texel` (atlas sample at the quad's uv); all observation-only and off unless their trigger exists.
2026-09-23 (G2.2 NEXT - THE RENDERER ITEM LEFT IS THE SKYBLEND COMPOSITE): implement the SkyBlend handlers (buckets 32/39) so the 64x96 sky texture they composite exists in this lane, then draw bucket 3 from its result instead of skipping it (`evidence/A1/g2-sky-draw-source-2026-09-22.md` names the source; the skip is `drawn=skipped`).  Carried forward behind it: the eye item's desktop-capture A/B.  Evidence for this round: `evidence/A1/g2-hud-material-decode-2026-09-23.md` (46 lines, superseding its own two earlier versions).
2026-09-23 (G2 STATE): lane left clean - app terminated, Simulator shut down, no `ottsel-hold-*`/`ottsel-press-*` input triggers and no `ottsel-trace-*` triggers present, 0-byte `ottsel-fault.log`, `scene-level='training'` reached by the route.  Disk `/` Avail 45 GiB, zero `.git/objects/pack/tmp_pack_*`.  Source/build in sync (`metal_shell.mm` 02:12, `metal_gfx.mm` 02:12, installed `OttselShell` 02:13).  The round's source is not yet folded into `patches/g2.2-sky-blend-and-ledger.patch` (it carries the sky/eye rounds plus the sprite census and the gated HUD/sprite probes); the three probe additions of this round are still unwrapped.
2026-09-23 (G2.2 SKY, LANDED - BUCKET 3 NOW DRAWS FROM THE SKYBLEND COMPOSITE BY DEFAULT): the carried-forward item is closed in source.  The native producer (`produce_mobile_sky_blend_bucket`) already walks the qwc == 6 copy pairs in buckets 32/39, blends with upstream's equation (`out = min(255, out + (in * intensity) >> 7)`, first draw overwriting via `PRIM.ABE`) and registers the 32x32 (tbp 0x1f80) and 64x64 (tbp 0x1fa0) results where the SKY_DRAW fan lookup already looks; what remained was the old default, written before the composite existed, that returned 0 unless `ottsel-trace-sky-draw-legacy` existed.  The bucket now computes `skip-flag`/`legacy-flag` and draws by default, with `ottsel-trace-sky-skip-draw` (live per frame) as the control and the legacy trigger still forcing the draw for a same-run A/B; `ottsel_metal_sky_skip_draw` is the new bridge accessor.
2026-09-23 (G2.2 SKY, MEASURED AND MATCHED): the producer reports composed content, not noise - `dest tbp=0x1f80 32x32 ... peak=253 mean=149 alpha-zero=0/1024` and `dest tbp=0x1fa0 64x64 ... peak=231 mean=121 alpha-zero=0/4096`, `produced copies=3 misses=0`, sources from the registry (tbp 0x14/0x10 psm 19 32x32, tbp 0x20 psm 19 64x64).  In one run at one camera and time of day the flag was flipped live between two captures: `drawn=as-sky` shows the sky band **blue**, `skip-flag=true drawn=skipped` shows the same band **black**; the captures differ on 22455 pixels (1.589% of the frame) with mean |delta| 121.2 per channel, confined to one box (1090,98)-(1667,846) - the sky region - so no other path moved.  Lane health on the same run: 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte `ottsel-fault.log`, `scene-level='training'`.
2026-09-23 (G2.2 SKY, NAMED AND NOT LANDED): the composite is registered under `(0x1f80|0x1fa0, psm 0)`, which matches this level's sky tex0; a level whose sky tex0 carries a non-zero psm would miss the composite and fall back to the uncomposited source.  Behind it remain the two questions item 2 already named - the Direct site's blend decision and the TIE preset-2 additive preset - plus the eye item's desktop-capture A/B.  New regression note: the sky A/B is a matched-capture gate, so `scripts/measure-png-region-mean.py` remains the checker; no host unit test covers the blend equation yet.
2026-09-23 (G2 STATE): lane left clean - app terminated, Simulator shut down, no `ottsel-hold-*`/`ottsel-press-*` input triggers and no `ottsel-trace-*` triggers present, 0-byte `ottsel-fault.log`.  Disk `/` Avail 45 GiB, zero `.git/objects/pack/tmp_pack_*`.  Source/build in sync (installed `OttselShell` 02:48, built from `metal_gfx.mm`/`metal_shell.mm`/`metal_shell.h` of the same minute).  `patches/g2.2-sky-blend-and-ledger.patch` still predates this round's probe and sky-default edits.
2026-09-23 (G2.2 SKY, THE CHANGE IS SCOPED TO THE FAN): the same early return that skipped the sky-draw fans also gated this bucket's generic tfrag-trans path, so the first version of this change (draw the whole bucket) also drew a translucent sky sheet across the level - caught by the settled-title and open-menu captures and by un-gating the path alone.  The landed form draws only the sky-draw shape (`after-setup-qwc == 5`) in a gameplay level (`mobile_level_sky_phase()`) and keeps the previous skip everywhere else, logged as `skip-flag` / `legacy-flag` / `level-phase` / `drawn`.  The generic tfrag-trans sheet is now named as its own carried-forward defect rather than un-gated here.
2026-09-23 (G2.2 SKY, PRODUCTION REGRESSION LANDED): the copy equation is extracted to `src/shell/mobile_sky_blend.h` (`ottsel_sky_blend_scale` / `ottsel_sky_blend_accumulate`, the initial-overwrite and accumulate-clamped forms) and used by the producer; `scripts/test-mobile-sky-blend.sh` compiles `test/mobile_sky_blend_test.cpp` on the host and checks unity/half/zero/clamped cases plus the whole byte range at four intensities against upstream's own slow path - PASS.  This is the regression the G2.2 exit requires for the sky blend.
2026-09-23 (G2.2 SKY, THE SUSPECTED TINT WAS TIME OF DAY - THREE MATCHED PAIRS AGREE): the same-run A/B on the shipped binary changes 20441 px (1.447%, mean |delta| 137.8/channel) confined to the sky box (1098,98)-(1667,846); the earlier in-level pair 22455 px (1.589%, 121.2/channel, sky box) and the menu-open pair 14177 px (1.003%, 81.1/channel, sky patch) agree.  The dusk orange/purple tint visible in some captures is present with the draw on *and* off, so it is the level's own time-of-day lighting, not this change; lane health on the shipped run is 346 SIGNED MODULE ENTER = 346 RETURNED with a 0-byte `ottsel-fault.log`.
2026-09-23 (G2.2 SKY, THE BUCKET'S GENERIC PATH IS MEASURED - THE SKIP IS CORRECT AND THE FIX IS NAMED): `ottsel-trace-sky-draw-legacy` is exactly the control for the sky bucket's non-sky-draw windows (it forces `ignore` for both shapes), and a same-run A/B shows what processing them does: at the settled title the frame becomes a **full-frame triangular mosaic** (71.720% of pixels changed, mean |delta| 72.8/channel, box (0,0)-(1667,846)) where the default shows the composite's pink/blue sky, while in-level the same control moves only 0.673% of pixels inside the sky box (`(1091,98)-(1667,846)`, mean |delta| 24.5).  Upstream renders TFRAG TRANS/LOWRES_TRANS geometry in that window and the port decodes it as Direct/GIF packets, so the mosaic is a decode-path defect, not a state one; the landed default keeps the path skipped and rendering those trees is the next renderer item.  This also corrects my own earlier attribution (I had blamed this path for the translucent sheet, which is present with the path skipped too).
2026-09-23 (G2.2 BLEND, BOTH REMAINING QUESTIONS CLOSED BY LIVE MEASUREMENT - NO CHANGE OWED): the G2.2 ledger arms on every level selection (it is NSLog, so it is read from the unified log).  TIE: `TIEREG draws=200 enable=195/5 blend=195/5 preset=0,200,0,0,0,0,0,0` - all 200 sampled draws select preset index 1 (source-over) and the additive enum (preset 2) is never requested, so the preset-2 question needs no renderer change.  Direct: `DIRECTREG-MIX arm=2 n=460 r0=0x0:460 r1=0x0:0 r2=0x0:0 r3=0x0:0 other=0` across frames with n = 44, 176, 356, 460, 464 - every batch carries register 0x0, which decodes to `Unspecified`, so a register-driven selection would select nothing and the primitive's own blend flag (upstream's fallback when ALPHA_1 is absent) stands.  The Direct site's blend decision therefore needs no code change in this lane's live population.
2026-09-23 (G2 STATE): lane left clean - app terminated, Simulator shut down, no `ottsel-hold-*`/`ottsel-press-*` input triggers and no `ottsel-trace-*` triggers present, 0-byte `ottsel-fault.log`, `scene-level='training'` reached by the route, 346 SIGNED MODULE ENTER.  Disk `/` Avail 45 GiB, zero `.git/objects/pack/tmp_pack_*`.  Evidence for the round: `evidence/A1/g2-sky-blend-default-draw-2026-09-23.md` (60 lines, extended with the generic-path measurement and the two blend populations) and `evidence/A1/g2-hud-material-decode-2026-09-23.md`.  `patches/g2.2-sky-blend-and-ledger.patch` still predates this round's source.
2026-09-23 (P1/G2.5, THE 667x375 PHONE PROFILE - PASSES WITH ITS DATA, AND THE FIRST RUN NAMED A G2.6 GAP): created the profile the loop was missing (`Ottsel iPhone SE3`, 7357D8E4-245A-4500-8123-77ECA72A4425) and ran it.  Surface log: `OTTSEL TOUCH: class=phone surface=667x375 min-region=37x43 safe-lrtb=0x0x0x0` - exactly the documented 667x375-point profile.  Installed with an empty container the lane boots, serves its modules and keeps a 0-byte fault log but **never reaches `title-wait-ready`**: it loops with **2638** `OTTSEL STR: chunked animation not found name=ndi-intro` warnings and loads no FR3 level.  The iPad container holds 1.5 GB of `OttselUserData`; the phone's held none - so this was a data-import gap, not a profile defect, and the failure mode is a silent loop that names no missing family (that is G2.6's question, answered in the negative with this evidence).
2026-09-23 (P1/G2.5, WITH THE DATA RESTORED THE ACCEPTED ROUTE HOLDS ON THE PHONE): copying `OttselUserData` contents plus `OpenGOAL` saves/settings into the phone container makes the same binary reach `title-wait-ready` and pass title -> NEW GAME -> CONTINUE WITHOUT SAVING -> Training with `scene-level='village1'` then `'training'`, 346 SIGNED MODULE ENTER = 346 RETURNED and a 0-byte `ottsel-fault.log`.  The save menu draws the copied save's own metadata (`GEYSER ROCK 9/22/2026 18:21`, `0%`, `EMPTY`, CONTINUE WITHOUT SAVING, BACK) at 667x375 with no clipping, and the in-level frame is clean with the sky rendering - the same composition as the iPad lane.  Note for re-runs: `simctl install` rotated the app's data container, so the imported data has to be re-copied into the fresh container after each install (contents-only copy; `cp -R src dest` nests one level).
2026-09-23 (A1 SKY, THE FAN'S FIRST-FRAME GARBAGE IS CHARACTERIZED AND TWO GATES WERE REFUTED): on the phone profile the title's first seconds draw the sky fan from whatever the registry holds for its key - a live `ottsel-trace-sky-skip-draw` A/B at that moment moves 329322 pixels (94.227% of the frame, mean |delta| 120.1).  The new SKY SHAPE fields show the fan names `tbp0 0x0` (the level's own sky page, real sky data), not the composite destinations 0x1f80/0x1fa0, so the fan legitimately renders the level's sky (`drawn=as-sky`, blue in-level, same key) and only its early frames are unresident.  I tried requiring the producer's composite and then requiring the fan's key to name a composite destination; the second would have removed the legitimate in-level sky (measured `fan-tbp=0x0` with the fan both drawn and skipped), so both gates were reverted in-session and the fields land as observability only.  The residency defect is carried forward as its own item; `kSkyDims`/`kSkyTbp` are now file-scope so the bucket and producer share one definition.
2026-09-23 (G2 STATE): lane left clean - app terminated, the SE3 Simulator shut down, no `ottsel-hold-*`/`ottsel-press-*` input triggers and no `ottsel-trace-*` triggers present, 0-byte `ottsel-fault.log`, 346 SIGNED MODULE ENTER.  Disk `/` Avail 43 GiB (the phone lane now carries a 1.5 GB imported-data copy), zero `.git/objects/pack/tmp_pack_*`.  New evidence: `evidence/A1/p1-phone-se3-profile-route-2026-09-23.md` (42 lines) and the extended `evidence/A1/g2-sky-blend-default-draw-2026-09-23.md`.
2026-09-23 (G2.6, WHAT AN ASSET-FREE INSTALL SHOWS - MEASURED, WITH ONE OF MY OWN CLAIMS CORRECTED): with the phone container's `OttselUserData` absent the log *does* name every missing family (`OTTSEL F1: no user pack at ...; using diagnostic bundle data` then `OTTSEL F1: bundle data at <bundle>.app/iso_data is incomplete (missing: CGO, fr3, MUS, SBK, STR, VAG, VIS); import a user pack with scripts/import-ios-user-data.sh`), so last turn's phrasing `a silent loop that names nothing` is corrected: the log names them and the failure is not an uncaught `ghc::filesystem` error, but the **screen** shows neither that list nor the shell's `DATA: import OttselUserData in Files` line - the capture is a full-frame grid of unresident game tiles - and the boot then spins (921 `chunked animation not found name=ndi-intro` warnings, no `title-wait-ready`).
2026-09-23 (G2.6, WHY THE INSTRUCTION IS INVISIBLE - TWO GATES LANDED, BUILT, INSTALLED AND SHOWN TO HAVE NO EFFECT): `render_surface()`, the only code that draws the shell's status screen (the DATA line plus the log tail carrying the F1 list), runs only when `!g_metal || !ottsel_metal_gfx_has_live_scene()`, and a data-less boot still reports a live scene.  I landed (a) drawing the status screen when `!ottsel_ios_has_user_data()` and (b) preferring its frame over the game's in the presentation branch; both were built and captured at the same moment and the frame was byte-for-byte the same grid, so the shell's CPU surface is drawn but never reaches the layer while the game renderer owns it.  The `data_missing` gate is kept in source as the prerequisite and is inert alone; the fix is to composite the status screen inside the product pass (the touch overlay's slot) or to suppress the game's presentation while no user pack is in use.  Evidence: `evidence/A1/g2-asset-free-install-what-the-user-sees-2026-09-23.md` (35 lines).
2026-09-23 (G2 STATE): lane left clean - app terminated, the SE3 Simulator shut down, no input or trace triggers present, and the phone lane's imported pack restored (contents-only copy; `simctl install` rotates the data container and the data then has to be re-copied).  Disk `/` Avail 43 GiB, zero `.git/objects/pack/tmp_pack_*`.  Source/build in sync after the last build of `src/shell/main.cpp`.
2026-09-23 (G2.6, SECOND ATTEMPT LANDED AND STILL NOT VISIBLE - AND MY FIRST EXPLANATION IS REFUTED): the in-pass status overlay is now in source and builds clean - `ottsel_metal_set_status_overlay` (a full-screen quad over an uploaded RGBA texture, half-intensity vertex colour so `direct_fs`'s doubling reproduces the surface 1:1) drawn in the product pass right after the touch overlay, pushed throttled from `main.cpp` while `!ottsel_ios_has_user_data()`, with the earlier `data_missing` gate kept.  Installed and captured at the same empty-container reproduction, the frame is byte-for-byte the same grid as before, so the screen half of this gate is still open.  The attempt also refutes what the previous note said: `ottsel_metal_gfx_game_frame()` is a stub that always returns 0, so the shell's `ottsel_metal_present(g_rgba)` branch is the only presentation it ever requests - the shell's CPU surface is not 'never presented', and the grid is not a game frame outranking it.
2026-09-23 (G2.6, THE NEXT MEASUREMENT IS NAMED - ONE VARIABLE, CHEAP): two mechanisms still fit the identical captures and are not separated: either the shell's present is not the path that reaches the layer, or the status screen's own drawing is what the layer shows and it is unreadable at this size (the captured tiles are ~40x56 px where `g_font_scale` 3 on a 750 px drawable would give ~15x21 px).  The discriminator: fill `g_rgba` with a flat unique colour just before `ottsel_metal_present` in the data-less state - if the screen turns that colour the present path is visible and the status screen's drawing is the defect, and if the grid survives then some other encoder owns the layer and the overlay has to be attached there.
2026-09-23 (G2 STATE): lane left clean - app terminated, the SE3 Simulator shut down, the phone lane's imported pack restored (contents-only copy), no input or trace triggers present.  Checks green: blend policy 12/12, sky blend PASS, overlay coverage PASS.  Disk `/` Avail 43 GiB, zero `.git/objects/pack/tmp_pack_*`, source and binary in sync after the last build.
2026-09-23 (G2.6, THE FLAT-COLOUR DISCRIMINATOR RAN - g_rgba DOES REACH THE LAYER, BUT THE PROBE IS AMBIGUOUS AS BUILT): trigger-gated flat green fill of `g_rgba` just before the present, data-less phone lane: the screen is uniformly green, and the same run logs `OTTSEL STATUS: surface=667x375 font-scale=3 flat-probe=1` - so the shell's status surface *does* reach the layer, and the CPU surface is 667x375 at font scale 3 (new measured facts).  The probe cannot name the presenter, though: both candidates upload `g_rgba` (the shell's `ottsel_metal_present` and the in-pass status overlay landed last turn), so green proves "the status surface reaches the screen" and nothing about which path carried it.  Corrected discriminator: colour the two paths differently in one run (blue in-pass vs green CPU present) so the colour on screen names the winner, then fix the named one - legible status text at 667x375/scale 3, or delete the now-redundant overlay.
2026-09-23 (G2 STATE): lane left clean - app terminated, the SE3 Simulator shut down, the phone lane's imported pack restored (11 families, contents-only copy), the flat trigger removed, no input or trace triggers present.  Disk `/` Avail 43 GiB, zero `.git/objects/pack/tmp_pack_*`.  Evidence: `evidence/A1/g2-asset-free-install-what-the-user-sees-2026-09-23.md` (60 lines).
2026-09-23 (G2.6, THE MECHANISM IS NOW READ FROM THE PRESENTER, AND TWO MORE ATTEMPTS STAYED INVISIBLE): `presentRGBA:` is the single presenter and it deliberately *skips* the CPU base surface once the level's TFRAG and TIE meshes are both ready (`ottssel_mobile_cpu_frame_should_draw`), a condition a data-less boot satisfies because the bundle's TIT/VI1 geometry loads anyway - which is exactly why the shell's status screen (the DATA line plus the log tail with the F1 list) is never painted.  Landed this round: the CPU base is kept when `!ottsel_ios_has_user_data()` (the `cpu_base_wanted` extension), and the in-pass status overlay now logs `OTTSEL STATUS OVERLAY: set 667x375 vertices=6`, so its upload and its quad are live.  Both were built, installed and captured at the same reproduction; the frame stayed byte-for-byte the same grid, so the chain `g_rgba` -> visible pixels is still not understood.
2026-09-23 (G2.6, SUSPECTS NAMED, ONE RUN DECIDES): the flat-green probe turns the screen uniformly green and logs `OTTSEL STATUS: surface=667x375 font-scale=3 flat-probe=1`, so the status surface does reach the layer - but both presentation candidates upload `g_rgba`, so no presenter is named.  The remaining suspects are the CPU surface geometry (667x375 logged) against the drawable the layer reports for this device (750x1334, landscape content shown rotated), or the overlay quad not being rasterised where it is drawn (it has a `set` record but no `drawn` record).  Next: one run that colours the two paths differently plus a draw-time log in the overlay slot.
2026-09-23 (G2 STATE): lane left clean - app terminated, the SE3 Simulator shut down, the phone lane's imported pack restored (11 families, contents-only copy), no input or trace triggers present.  Checks green: blend policy 12/12, sky blend PASS, overlay coverage PASS.  Disk `/` Avail 43 GiB, zero `.git/objects/pack/tmp_pack_*`.  Evidence: `evidence/A1/g2-asset-free-install-what-the-user-sees-2026-09-23.md` (49 lines).
2026-09-23 (G2.6, FOUND AND FIXED A REAL SCISSOR BUG, AND PROVED THE OVERLAY DRAWS): the Direct batch loop set a per-batch GS scissor (`setScissorRect` at the Direct draw site) and never restored it, so every full-screen overlay draw after it - the touch overlay and the new status overlay - was clipped to the last batch's rect.  The shell now restores the full drawable rect before either overlay draws (landed, builds clean).  That did not change this state's frame, and the next probe settled why: a trigger that paints the status overlay slot with the known-good opaque magenta fill (`skyDebugFillPipeline`) turns the screen uniformly magenta, so the overlay draw *is* reached and does rasterise - the mechanism is sound and what the user sees is the overlay's uploaded surface.
2026-09-23 (G2.6, SHARPENED: THE SURFACE CONTENT IS THE DEFECT, AND ITS GEOMETRY IS SUSPECT): at original resolution the captured tiles are letter-shaped glyphs of roughly 40x56 px repeating in a lattice - scale-3 glyphs magnified about 2.25x - not the status lines (`OTTSEL F1: ... missing: CGO, fr3, ...`), so the shell's status surface (`render_surface`) is what the layer shows and its content is wrong.  Two measured geometry facts point at the same place: the shell logs `surface=667x375` while this phone's drawable is 750x1334, so the surface does not share the drawable's aspect.  Named next steps: dump the surface itself (`dump_surface_ppm` already exists) and read whether it holds the status text or this lattice, then reconcile the surface geometry with the drawable the layer reports.
2026-09-23 (G2 STATE): lane left clean - app terminated, the SE3 Simulator shut down, the phone lane's imported pack restored (contents-only copy), no input or trace triggers present.  Disk `/` Avail 43 GiB, zero `.git/objects/pack/tmp_pack_*`.  Evidence: `evidence/A1/g2-asset-free-install-what-the-user-sees-2026-09-23.md` (52 lines).
2026-09-23 (G2.6, THE SURFACE DUMP SETTLES IT - CONTENT RIGHT, MAPPING WRONG, MY PREVIOUS READING REFUTED): `dump_surface_ppm()` writes `Library/Application Support/ottsel/shell/surface.ppm` (667x375, matching the logged surface), and read at original resolution it is the status screen itself - a header line, a green line, the yellow `DATA: import OttselUserData in Files` line and rows of log lines - not a lattice.  So `render_surface()` and the F1/DATA reporting are correct, the previous turn's `the surface content is wrong` reading is refuted, and the remaining defect is the mapping of that image onto the layer: the simulator capture is 750x1334 while the shell's CPU surface *and* its reported drawable are both 667x375.  Next: reconcile the CPU surface geometry with the layer and confirm the text lands readable - which also decides whether this gate's screen half needs only the geometry or the simulator's compositing as well.
2026-09-23 (G2 STATE): lane left clean - app terminated, the SE3 Simulator shut down, the phone lane's imported pack restored (contents-only copy), trace triggers cleaned.  Checks green: blend policy 12/12, sky blend PASS, overlay coverage PASS.  Disk `/` Avail 43 GiB, zero `.git/objects/pack/tmp_pack_*`.  Evidence: `evidence/A1/g2-asset-free-install-what-the-user-sees-2026-09-23.md` (55 lines).
2026-09-23 (G2.6 FIRST QUESTION ANSWERED YES - AND THE DEFECT WAS THE SHELL'S OWN FONT): the asset-free install now names the missing user-data family **on screen** as well as in the log.  The unreadable screen was `draw_char` reading `font5x7.h` row-major while the table is column-major (five column bytes of seven rows each), which transposed every glyph and read two bytes past each one - the "lattice of letter tiles" the captures showed all along.  Fixed with `kFontW` 5 / `kFontH` 7 and the loops swapped, verified two ways on the same reproduction: `dump_surface_ppm()` (`Library/Application Support/ottsel/shell/surface.ppm`, 667x375) now reads `ottsel S2.0 - Metal` / `GPU path: Metal` / `DATA: import OttselUserData in Files` in yellow plus the log tail, and the device capture shows the same legible lines.  The whole shell text surface is legible for the first time (that also covers the diagnostic screens).
2026-09-23 (G2.6, WHAT REMAINS OF THE GATE): this answers the first half - the log names every missing family (`OTTSEL F1: ... incomplete (missing: CGO, fr3, MUS, SBK, STR, VAG, VIS); import a user pack with scripts/import-ios-user-data.sh`) and the screen now shows the DATA instruction - while the reconstruction-from-pin/patches and allowlist-inspection halves are untouched, and the bundle-fallback diagnostic path (TIT/VI1 + TEXT) is unchanged.  Cosmetic remainder: the log tail is dominated by repeated `OTTSEL DIRECT/SPRITE FRAME` lines.  Two real fixes landed on the way and are verified: the Direct batch loop now restores the full GS scissor before the overlay draws (it had been clipping both overlays), and the status overlay path is proven to rasterise.
2026-09-23 (G2 STATE): lane left clean - app terminated, the SE3 Simulator shut down, the phone lane's imported pack restored (contents-only copy), trace triggers cleaned.  Checks green: blend policy 12/12, sky blend PASS, overlay coverage PASS.  Disk `/` Avail 43 GiB, zero `.git/objects/pack/tmp_pack_*`.  Evidence: `evidence/A1/g2-asset-free-install-what-the-user-sees-2026-09-23.md` (56 lines).
2026-09-23 (REGRESSION CHECK ON THE PRIMARY IPAD LANE AFTER THE SCISSOR AND FONT FIXES - CLEAN): reinstalled the current build on the iPad profile and ran the accepted route: title -> NEW GAME -> CONTINUE WITHOUT SAVING -> Training, `scene-level='village1'` then `'training'`, **346 SIGNED MODULE ENTER = 346 RETURNED**, 0-byte `ottsel-fault.log`.  The in-level frame is intact - grass, cliffs, palms, the wooden structure, the blue-lit ring, and Jak and Daxter with the composed eyes landed earlier - and the touch overlay stays hidden under file-trigger input (which is what `hide_touch_overlay_for_native_input()` is for), so the scissor restore did not reveal anything unexpected on the product path.  So the two main-pass fixes (the full GS scissor before the overlay draws, and the column-major font read) leave the primary lane unchanged.
2026-09-23 (G2 STATE): both simulators shut down (SE3 and iPad), no input or trace triggers present on either, checks green (blend policy 12/12, sky blend PASS, overlay coverage PASS).  Disk `/` Avail 42 GiB - still above the 40 GiB gate, but the two phone/iPad imported-data copies are the bulk of the recent consumption; zero `.git/objects/pack/tmp_pack_*`.  Evidence: `evidence/A1/g2-asset-free-install-what-the-user-sees-2026-09-23.md` (56 lines, G2.6 first question answered YES).
2026-09-23 (G2.6 PACKAGING HALF: BUNDLE AUDIT DONE, AND A STALE 18 MB CONTAINER REMOVED): the app bundle was audited against the asset-freedom question.  It holds exactly what `scripts/build-ios.sh` copies - `OttselShell` 22.8 MB, `GAME.CGO` 22.8 MB, `KERNEL.CGO` 0.42 MB, `Info.plist`, `_CodeSignature/`, `iso_data/` 17 MB (`DGO/TIT.DGO`, `DGO/VI1.DGO`, `TEXT/*`) - and **none** of the seven user-data families (`CGO`, `fr3`, `MUS`, `SBK`, `STR`, `VAG`, `VIS`) appears in it; the only game-derived content is the build's own diagnostic `iso_data`, whose boundary the packaging step states itself ("Local Simulator research bundle only ... not a data-free distribution package. The release path must separate generated code from assets supplied via F1 import").  The audit found one real defect: the bundle carried a stale `ENGINE.CGO` (18.5 MB, Sep 11) that the script never copies and the runtime never loads (`src/shell` has no reference to it), and it had ridden along in every bundle since.  `scripts/build-ios.sh` now clears `*.CGO` before copying its own containers; verified by rebuilding (79 MB -> 61 MB) and by re-running the accepted route on the iPad with the leaner bundle (village1 -> training, 346 ENTER = 346 RETURNED, 0-byte fault log).  Evidence: `evidence/A1/g2-packaging-bundle-audit-2026-09-23.md`.
2026-09-23 (G2 STATE): lane left clean - app terminated, iPad Simulator shut down, no input or trace triggers present, checks green (blend policy 12/12, overlay coverage PASS).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.  Reconstruction note: `patches/README.md` + `verify-overlay-coverage.py` PASS document the pin/overlay path and name the outer-repo files no patch captures; a from-scratch rebuild from the pin alone has NOT been run and remains the open half of this gate.
2026-09-23 (G2.5 PHONE SAVE WRITE - ATTEMPTED, NOT ACHIEVED, BASELINE RECORDED): I tried to close the phone's save-write gap by driving the game's own save flow on the SE3 with hand-rolled trigger presses (start -> cross at screen 27 -> cross at screen 18 index 0 -> the overwrite dialog's D-pad-left + Cross), checking `bank0/1/2.bin` hashes before and after.  **The presses did not register** (`start False`, `newgame False`; the only path markers logged were `GAMEPLAY: enter title`), so no write occurred and the three hashes are byte-identical before and after (bank0 536a64d5fdec8da8, bank1 39757c172fef9c5b, bank2 a8ad9b0968e5e902) - the same files the game itself wrote on the iPad.  My hand-rolled sequence is the failure, not the game: the accepted route driver presses the same buttons and completes twice on this lane, so the next step is to extend *that* driver with a save-accept step (its own press() waits for the marker while held, which mine replicated but with a longer settling gap than the phone's menu needed) rather than to re-run an ad-hoc script.  The lane was left clean (triggers none, Simulator shut down).
2026-09-23 (G2.3 AUDIBILITY - THE CODE HALF IS ALREADY PROVEN; THE REMAINING HALF IS EXTERNALLY GATED): re-read `evidence/A1/i2-audio-pcm-measured-device-open-blocks-2026-09-22.md` rather than re-deriving it.  The substrate produces real PCM - 2ch/48 kHz/S16, 960512 frames, 11 of 20 seconds carrying signal after second 10 (boot/title silent, level audio starts), peak 10299 of 32767 (~31% FS), overall RMS 446 - measured through the callback capture with `SDL_AUDIO_DRIVER=dummy`, which opens immediately.  What is missing is *audibility*: the Simulator's CoreAudio device open never returns, so nothing plays there, and `dummy` discards by definition.  That makes G2.3 an environment/device item, exactly as the loop says - the device lane (G2.7) decides it, and no code change is owed or claimed here.  Event association is only coarsely shown (signal starts when the level does), so the finer ambient/effects/music/dialogue association still needs a surface that actually plays.
2026-09-23 (G2 STATE): both simulators shut down (SE3, iPad), no input or trace triggers present, bundle audited at 61 MB with no user-data families and no stale container.  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-23 (G2.5 PHONE SAVE WRITE - THE DRIVER NOW DRIVES A SLOT, AND THE MEASUREMENT CORRECTED MY OWN LABEL): `scripts/replay-ios-normal-route.py` gained a slot-accept path built on its own reliable `press()` loop (hold until the marker appears, then release and wait for the neutral pad sample).  I first called it `--write-save` and it reported a clean accept on the phone (`accept screen=18 index=0`, no overwrite dialog, slot read as free) - but the three memcard hashes were **identical before and after** (bank0 536a64d5fdec8da8, bank1 39757c172fef9c5b, bank2 a8ad9b0968e5e902, mtimes unchanged), so no write happened.  The reason is that in this route screen 18 is the **continue/load** menu - its own last option is "Continue Without Saving" - not the save screen, so accepting a slot there neither writes a memcard nor raises the overwrite dialog.  The flag is renamed `--accept-slot` with that measurement in its help text, so the harness no longer claims to write.  The phone's save WRITE therefore still needs the in-level pause menu's save screen (which is where the iPad's evidence wrote bank2.bin), and that path is not driven yet.
2026-09-23 (G2 STATE): lane left clean - app terminated, SE3 Simulator shut down, no input or trace triggers present, driver syntax checked after the edit.  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.  The phone lane's memcard is unchanged by this round (no write occurred), which is now on record rather than assumed.
2026-09-23 (G2.5 PHONE SAVE WRITE - NARROWED: THE GAME NEVER ENTERS A SAVING STATE, AND ITS MEMCARD READ DOES NOT SEE THE COPIED FILES): read the authoritative screen enum from the game source (`goal_src/jak1/engine/ui/progress/progress-h.gc`): `16 load-game`, `17 save-game`, `18 save-game-title`, `11 memcard-data-exists`, `13 memcard-saving`, `15 memcard-creating`, `20/21/24/25` the memcard error screens.  On the phone the driver's accept of `18 index=0` logs `edge screen=18 index=0` then `accept screen=18 index=0` and **nothing after** - no `memcard-saving`/`memcard-creating` marker, no memcard error screen, no overwrite dialog, and no `bank*.bin` written anywhere in the container (both `OpenGOAL/jak1/saves` and the nested `OpenGOAL/OpenGOAL/jak1/saves` were checked, nothing newer than two hours), while the identical accept wrote bank0.bin on the iPad in the earlier evidence.  That also means the game's memcard READ did not see the copied files (a filled slot would have raised screen 11).  Next measurement (exact): read the app's `OTTSEL F1: save root=` line *in full* on the phone and compare it with the directory that actually holds the memcard - the lane's save root is evidently not the `OpenGOAL/jak1` path the copied files sit in, which is also consistent with the phone's save menu showing the slots as empty.
2026-09-23 (G2 HOUSEKEEPING + STATE): removed two container duplicates my earlier staging left behind - `OttselUserData.staged-away` (3.0 GB on disk) and the nested `OpenGOAL/OpenGOAL` (208 KB, a mis-nested saves copy) - so the phone lane now holds exactly `OpenGOAL`, `OttselUserData` and the runtime logs/dumps.  Disk `/` Avail 42 GiB (the lanes' user-data copies are APFS clones, so removing one clone frees little; still above the 40 GiB gate), zero `.git/objects/pack/tmp_pack_*`.  Both simulators shut down, no input or trace triggers present.
2026-09-23 (G2.5 SAVE WRITE - MY PHONE-SPECIFIC FRAMING IS REFUTED BY THE KNOWN-GOOD LANE; THE DRIVER PATH IS THE NON-WRITER): repeated the exact same slot accept (`accept screen=18 index=0`) on the **iPad** - the lane where the earlier evidence wrote bank0.bin - and it behaved identically to the phone: no overwrite dialog (the slot reads as free on both), **no `memcard-saving` marker**, and all three memcard hashes byte-identical before and after (bank0 536a64d5fdec8da8, bank1 39757c172fef9c5b, bank2 a8ad9b0968e5e902, mtimes Sep 22).  So the title-flow slot accept is not the save writer on either lane, and last turn's "the phone's write fails / its save root is not the path the copied files sit in" is refuted.  The save root is in fact exactly right: the app logs `save root=.../OttselShell/OpenGOAL/jak1/saves`, which is where the copied memcard sits, and the phone's own save menu drew that memcard's name/date (`GEYSER ROCK 9/22/2026 18:21`), so the READ path works.  Both runs also only reached `scene-level='village1'` (the intro), i.e. they ended before level entry, so the auto-save/in-level write was never exercised.
2026-09-23 (G2.5 SAVE WRITE - NEXT STEP, EXACT): let the run reach **Training** before checking, then compare the memcard hashes again.  Two candidate writers remain and both need the level: the level-entry auto-save (bank0 is the auto-save card) and the in-level pause menu's save screen - the path the earlier iPad evidence used to write bank2.bin.  The check is the same `shasum`/mtime comparison, just with the window extended past `GAMEPLAY: enter training`.
2026-09-23 (G2 STATE): iPad Simulator terminated and shut down; phone lane still shut down; no input or trace triggers present on either.  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.  Both lanes' memcards are unchanged by this round (no write occurred anywhere), which is on record rather than inferred.
2026-09-23 (G2.5 SAVE WRITE - THE LEVEL-ENTRY AUTO-SAVE IS REFUTED; THE IN-LEVEL MENU IS THE ONLY WRITER LEFT): ran the accepted route on the **iPad** and let it finish: title -> NEW GAME -> CONTINUE WITHOUT SAVING -> intro -> **Training** (`TRAINING` reached, 346 SIGNED MODULE ENTER, 0-byte fault log), then waited 12 s and compared the memcard again.  All three hashes are byte-identical to before (bank0 536a64d5fdec8da8, bank1 39757c172fef9c5b, bank2 a8ad9b0968e5e902, mtimes still Sep 22) and the run logs **no** `memcard-saving`/`memcard-creating` marker at all.  So entering a level does not auto-save on this lane: the first of the two candidate writers is refuted, and the remaining one is the in-level pause menu's save screen - the path the earlier iPad evidence used to write bank2.bin.  The phone's save-write verification therefore needs the pause menu driven, which is a discovery task (the pause screen's entries are the four face buttons plus OPTIONS), not another hash check.
2026-09-23 (G2 STATE): iPad Simulator terminated and shut down, phone lane still shut down, no input or trace triggers present on either, and both lanes' memcards are unchanged by this round (the write never happened, now measured rather than inferred).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.  Reminder of the open boundary: the Simulator cannot prove audibility (its CoreAudio device open never returns) and the physical-device gate is external.
2026-09-23 (G2.5 SAVE PATH - THE BUTTON MAPPING IS NOW SOURCE-VERIFIED, AND THE MEMCARD STATE GATES THE WRITE): read the pause/settings handler in `goal_src/jak1/engine/ui/progress/progress.gc`.  `((or (cpad-pressed? 0 x) (cpad-pressed? 0 circle))` activates a `game-option-type menu` entry - `push!` plus `next-display-state = param3` - and when that state is `load-game`, `save-game` or `save-game-title` it routes through **`set-memcard-screen`** (line ~1047); `up`/`down` (and `left`/`right`) move `option-index`, and `square`/`triangle` cancel/back.  So the driver's `cross` is the right accept button and the pause menu needs `up`/`down` to reach its SAVE entry.  The same file also explains why the accept writes nothing: before the save screen is used the code checks the memcard device's own state and redirects to `memcard-no-data` (23), `memcard-no-space` (7) or `memcard-format` (10) when `inited`/`formatted`/capacity are not satisfied (lines ~700-719).  Those are *transitions*, not accepts, so my accept-only log greps would not have shown them - and a slot that reads as free on a card the game considers uninited is exactly that shape.
2026-09-23 (G2.5 SAVE PATH - NEXT MEASUREMENT, EXACT): drive the pause menu (start -> up/down to SAVE -> `x`) with the driver's press loop and log the **screen transitions**, not just the accepts - the port's `OTTSEL PC PROGRESS` line carries a `transition=` field, which is how the existing driver distinguishes a settled screen from an in-flight one.  If the run reaches `memcard-no-data`/`no-space`/`format`, the port's memcard-state initialisation is the defect and the write path is fine; if it reaches `save-game` with a slot accept and still writes nothing, the write itself is the defect.  Either way the discriminator is a transition trace, not another hash-only check.
2026-09-23 (G2 STATE): both simulators shut down, no input or trace triggers present, both lanes' memcards still unchanged (Sep 22 mtimes, hashes bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-23 (G2.5 PAUSE MENU - REACHED, BUT THE SAVE ENTRY IS NOT REACHED BY BLIND PROBING; NO WRITE, AND THE NAMED NEXT STEP IS THE OPTION TABLE / TRACE): with the lane in Training I probed the pause screen with the driver's press loop.  `start` opens it and it logs `screen=0` (the enum's `fuel-cell`) and `screen=1` (`money`), so its `up`/`down`/`left`/`right` presses switch the *collectible pages*, not a menu highlight - the logged `index` stayed 0 through every press - and neither the face buttons (`cross`/`square`/`triangle`/`circle`) nor any direction produced a save-screen transition (no 17 `save-game`, 18 `save-game-title`, 11 `memcard-data-exists`, 23 `memcard-no-data`, 7 `memcard-no-space`, 10 `memcard-format`), no memcard marker beyond the `memcard-h` source-name artifact, and **no memcard write** (all three hashes and mtimes still byte-identical).  So the earlier `save-game-title` screen the route reaches is the *frontend's* own save prompt, and the pause menu's SAVE entry needs the level's option table to be read rather than guessed.
2026-09-23 (G2.5 PAUSE MENU - NEXT STEP, EXACT): the port's highlighted-option name trace (`OTTSEL G1: str=`) is what would name the entries, and it is silent in this build because it lives in `patches/a11-diagnostic-traces.patch` (recorded in `patches/README.md` as a desktop-path trace with the iOS copy left inside the canonical h3 patch).  Two concrete options, both cheap: read the pause screen's `game-option-type menu` table from the game source / level task data to get the entry order and the `param3` screen each one opens, or apply the diagnostic-traces overlay to this lane so the entries print their names while the highlight moves.  Until one of those lands, the phone's in-level save write stays unverified by design rather than by omission.
2026-09-23 (G2 STATE): iPad Simulator terminated and shut down; phone lane shut down; no input or trace triggers present; both lanes' memcards still unchanged (bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-23 (G2.5 PAUSE/SAVE PATH - THE OPTION TABLE IS FOUND, SO THE SAVE ENTRY IS NO LONGER A GUESS): `goal_src/jak1/pc/progress-pc.gc` (this lane's own progress source) defines `*main-options-pc*` at lines 111-160, the table bound to `progress-screen settings` (3), and its entries in order are: **0 game-options -> game-settings, 1 graphic-settings, 2 sound-settings, 3 load-game, 4 save-game (`:name (text-id save-game)`), 5 memcard-disable-auto-save, 6 quit**.  Each is `(game-option-type menu)` with `:param3 (game-option-menu <screen>)`, and the accept path in `progress.gc` routes `load-game`/`save-game`/`save-game-title` through `set-memcard-screen`.  So from the settings screen the save entry is exactly **four `down` presses then `x`** - no probing needed.  The port's own markers for this are `OTTSEL PC PROGRESS: edge screen=~D index=~D transition=~A abs=~D rel=~D` and `... accept screen=~D index=~D selected=~A` (progress-pc.gc lines 2208/2448), and the highlighted-option *name* trace (`OTTSEL G1: str=`) is absent from this lane because it lives in the desktop-path diagnostics overlay.
2026-09-23 (G2.5 PAUSE/SAVE PATH - NEXT STEP, FULLY SPECIFIED): two tiny reads and one run.  Reads: the pause screen's own table (there is an `:name (text-id options)` entry around line 766 of the same file) to get the index that opens `progress-screen settings`, and confirm the settings entry index above (0-based 4).  Run, with the lane in Training: `start` -> `down` x (pause->OPTIONS index) -> `x` -> `down` x4 -> `x` -> the save screen appears (screen 18 / `set-memcard-screen`) -> `x` on a slot -> compare the memcard hashes.  Because the table is now known, this is a deterministic sequence rather than the blind probing that failed, and any memcard state screen among {7 no-space, 10 format, 23 no-data} would name the port's memcard initialisation as the defect instead.
2026-09-23 (G2 STATE): both simulators shut down, no input or trace triggers present, both lanes' memcards unchanged (bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-23 (G2.5 SAVE PATH - BOTH MENU TABLES ARE NOW VERIFIED, INCLUDING ONE THAT EXPLAINS SCREEN 18): read the two tables in `goal_src/jak1/pc/progress-pc.gc`.  **`*title-pc*` (line 747)** is the title menu: **0 new-game -> save-game-title**, 1 load-game, 2 options -> settings-title, 3 secrets, 4 quit-game, 5 back - so the `save-game-title` screen (18) that the accepted route reaches is entered as *part of NEW GAME*, which is why accepting index 0 there is a save-slot choice for a new game rather than a pause-menu save, and why the overwrite dialog (11) only appears when that slot already holds data.  **`*main-options-pc*` (line 113)** is the settings menu used by `progress-screen settings` (3): 0 game-options, 1 graphic-options, 2 sound-options, 3 load-game, **4 save-game (`:name (text-id save-game)`)**, 5 disable-auto-save, 6 quit-game, 7 back.  So the in-level save is: reach the settings screen, `down` x4, `x` - deterministic, no probing.  The port's own markers for this path are `OTTSEL PC PROGRESS: edge screen=~D index=~D transition=~A abs=~D rel=~D` (line 2208) and `accept screen=~D index=~D selected=~A` (line 2448); the highlighted-option *name* trace is desktop-only.
2026-09-23 (G2.5 SAVE PATH - THE ONE REMAINING UNKNOWN, NAMED): which input opens `progress-screen settings` from the in-level pause screen.  My probe showed the pause logging `screen=0` (`fuel-cell`) / `screen=1` (`money`) with `index` pinned at 0 whatever I pressed, so the logged index there is a page, not a menu row; the pause handler's own navigation is what to read next (`progress.gc` around lines 850-1140 has the up/down/left/right and square/triangle branches, and the `(or (cpad-pressed? 0 x) (cpad-pressed? 0 circle))` branch is the one that pushes a `game-option-type menu` entry).  Once that index is known the run is `start -> down x N -> x -> down x4 -> x -> slot -> hashes`, and a memcard state screen among {7, 10, 23} would instead blame the port's memcard initialisation.
2026-09-23 (G2 STATE): both simulators shut down, no input or trace triggers present, both lanes' memcards unchanged (bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-23 (G2.5 SAVE PATH - THE BUNDLED LAYOUTS FOUND, AND THE SAVE ENTRY CONFIRMED AT INDEX 4 IN BOTH VARIANTS): `goal_src/jak1/engine/ui/progress/progress-static.gc` holds the menu layouts that ship inside `ENGINE.CGO`/`GAME.CGO` - `*main-options*` (line 11) with 0 game-options, 1 graphic-options, 2 sound-options, 3 load-game, **4 save-game**, 5 quit-game, 6 back, and `*title*` (line 54) with 0 new-game -> save-game-title, 1 load-game, 2 options -> settings-title, 3 back.  The port's PC variants in `pc/progress-pc.gc` mirror them with small additions (an auto-save row and more title entries), and the port's own remap binds `settings-title` to its options table, so **save-game is index 4 wherever it appears** - the two independent tables agree, which is what makes the four-`down` sequence safe to try.  A grep of the whole `goal_src/jak1` tree found no entry that navigates to `progress-screen settings`; the entries that target `save-game` live in these layouts and the settings screen is reached from the title's OPTIONS entry or the in-game pause, whose own entry table is level/task data rather than this file.
2026-09-23 (G2.5 SAVE PATH - WHERE THIS LEAVES THE VERIFICATION): the sequence is now specified for the frontend-reached settings screen (`start`/title -> OPTIONS -> `down` x4 -> `x` -> the save screen -> slot -> hashes), but the **in-level** pause menu's route into that screen is still unnamed, and that is the one that matters for a *game* save (a settings screen reached from the title has no loaded level to record).  Two candidate resolutions, both cheap and both source-side: read the level/task-data tables the in-game pause uses, or apply the desktop diagnostics overlay so the highlighted entry prints its name (`OTTSEL G1: str=`), which is the trace this lane lacks.  Until then the phone's in-level save write stays unverified by design, with the memcards unchanged (bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902) and both simulators shut down.
2026-09-23 (G2 STATE): no booted simulators, no input or trace triggers present, disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-23 (G2.5 MENU DRIVING - THE LONG-HOLD PRESS WORKS, AND OPTIONS LEADS TO A SCREEN BEYOND THE ENUM I HAD READ): my earlier hand-rolled presses failed because I released after a fixed 1.3 s while the accepted driver holds the button *until the game acts*; holding 4 s makes them work.  Measured on the title: `down`, `down` moved the highlight (`edge screen=27 index=0` -> `index=1`) and `cross` accepted it (`accept screen=27 index=2`) - i.e. the title menu's **OPTIONS** entry, exactly as `*title-pc*`/`*title*` say.  Accepting it lands on **screen 28** (`edge screen=28 index=0..3`), a screen number *beyond* the `progress-screen` enum I read (which ended at `title 27`), so the port's enum continues past it and screen 28 is the settings/options screen.  No memcard state screen appeared and no memcard write happened (hashes unchanged), because my `down` x4 *wrapped* on a screen whose table only offered indices 0-3 - the arithmetic needs that screen's own table, not `*main-options*`.
2026-09-23 (G2.5 MENU DRIVING - NEXT READS, BOTH CHEAP AND SOURCE-SIDE): (1) the tail of the `progress-screen` enum in `progress-h.gc` past `title 27` to name screen 28 (and any sibling), and (2) the table bound to it - `*options-remap*` in `pc/progress-pc.gc` maps `settings-title` to `*options*`, so the entry order of `*options*` (the bundled layout in `progress-static.gc`, which I only read down to its fourth entry) gives the exact number of `down` presses to reach `save-game`.  With those two numbers the sequence is deterministic from the title: `start` -> `down` x2 -> `cross` -> `down` x(<save index>) -> `cross` -> the save screen -> a slot -> the hashes.  The long-hold press is the harness lesson: hold until the game acts (or ~4 s), never a fixed short hold.
2026-09-23 (G2 STATE): iPad Simulator left running by the probe and then shut down; no input or trace triggers present; both lanes' memcards unchanged (bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-23 (G2.5 SAVE PATH - SCREEN 28 NAMED, AND IT HAS NO SAVE ENTRY - WHICH EXPLAINS THE WRAP): read the enum's tail and the table bound to the screen my probe landed on.  The `progress-screen` enum continues past `title 27` with **`settings-title 28`, `auto-save 29`, `pal-change-to-60hz 30`, `pal-now-60hz 31`, `no-disc 32`, `bad-disc 33`, `quit 34`, `max 35`**, so the empirical landing was `settings-title` (28) exactly.  And the bundled `*options*` layout in `progress-static.gc` - the table the port's remap binds to `settings-title` - is only **game-options (0), graphic-options (1), sound-options (2), back (3)**: four entries, no load/save/quit.  That is precisely the 0-3 index range my probe wrapped through, so the title's OPTIONS screen is a *settings-only* menu and cannot be talked into a save.  The SAVE entry (index 4) exists only in `*main-options*` / `*main-options-pc*`, which belong to **`progress-screen settings` (3) - the in-game variant** - which is why every attempt from the title dead-ends here.
2026-09-23 (G2.5 SAVE PATH - THE REMAINING READ IS ONE LINE, AND THE PATH IS NOW CLEAR): the port's remap sets a table for `(progress-screen settings)` at `pc/progress-pc.gc:2053` (the read I truncated earlier).  That line names the in-game settings table, and with it the sequence is: in-level `start` (pause) -> the input that opens `progress-screen settings` -> `down` x4 -> `cross` -> the save screen -> a slot -> compare hashes.  The pause's own entries are the still-unnamed link, but the *save* half is now fully specified and screen 28 is proven to be a dead end for it, so the earlier title-to-settings route is retired rather than left ambiguous.
2026-09-23 (G2 STATE): both simulators shut down, no input or trace triggers present, both lanes' memcards unchanged (bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-23 (G2.5 SAVE PATH - THE IN-GAME PAUSE IS NAMED, AND THE LAST UNKNOWN SHRANK TO ONE BINDING): three source facts from this pass.  `engine/game/main.gc:127` **the in-game pause activates `progress-screen fuel-cell` (0)** - which is exactly the `screen=0` my probe logged - and `engine/draw/drawable.gc:1157` shows the pause is the `*master-mode* 'pause` loop that `start`/`R2` exits, so the pause and its info pages are one screen.  `engine/game/game-save.gc:1176` shows the auto-save has its own screen (`auto-save` 29) activated from the save system, and the route-to-Training run logged no such screen, independently confirming the refuted level-entry auto-save.  And the pause's *entry* table is not in the port file: `progress-static.gc:258` defines `*options-remap*` as an empty runtime-filled array, the port fills its `settings` slot (line 2053 -> `*main-options-pc*`), and the bundled `progress.gc` fills the rest (`load-game -> *load-options*`, `save-game -> *save-options*`, `save-game-title -> *save-options-title*`, all present at `progress-static.gc:222/233/244`).
2026-09-23 (G2.5 SAVE PATH - NEXT STEP IS ONE GREP, THEN THE DETERMINISTIC RUN): grep the bundled `progress.gc` for `(-> *options-remap* (progress-screen fuel-cell))` to get the pause's own table and its entry order; with that index the full sequence is `start` (pause, screen 0) -> `down` x(index of the settings/options entry) -> `cross` -> `progress-screen settings` (3) -> `down` x4 -> `cross` -> `save-game` -> the save screen -> a slot -> compare hashes.  The harness rule is already on record: hold each button until the game acts (or about 4 s), because the accepted driver's presses work and fixed short holds do not.
2026-09-23 (G2 STATE): both simulators shut down, no input or trace triggers present, both lanes' memcards unchanged (bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-23 (G2.5 SAVE PATH - THE PAUSE SCREEN HAS NO OPTIONS TABLE BOUND, WHICH IS WHY IT IGNORED EVERY INPUT): read the bundled `*options-remap*` block in `engine/ui/progress/progress.gc`.  It binds `settings -> *main-options*` (the 7-entry table whose index 4 is `save-game`), `game-settings`/`graphic-settings`/`sound-settings`, every `memcard-*` screen, `load-game -> *load-options*`, **`save-game -> *save-options*`**, **`save-game-title -> *save-options-title*`**, `title -> *title*`, `settings-title -> *options*`, `auto-save -> *ok-options*` and the PAL screens.  It binds **nothing** for `fuel-cell`, `money` or `buzzer` - and those are the screens the in-game pause actually activates (`main.gc:127` uses `fuel-cell`).  So the pause's entries do not come from this table at all; they come through the level/task-data path (`*level-task-data*` at `progress-static.gc:327` with `*level-task-data-remap*` at 283), which is why blind button probing produced no index movement and no menu transition, and why the frontend's own `save-game-title` (screen 18, reached by NEW GAME) was the only save screen my probes ever touched.
2026-09-23 (G2.5 SAVE PATH - THE COMPLETE PICTURE AND THE NEXT READ): the *frontend* path is fully specified (`settings -> *main-options*`, index 4 = save-game, and `save-game -> *save-options*` holds the slot rows), and the *in-game* path is the task-data one.  So the next read is the task-data path: how `progress`'s update selects entries for a screen with no `*options-remap*` binding - `*level-task-data*` plus `*level-task-data-remap*` in `progress-static.gc`, and the branch of the update method that reads them.  That names the pause's rows and their order (and with it the input that reaches `settings` or `save-game` directly).  The prior evidence that an in-level save *did* write `bank2.bin` (STATUS 2026-09-22) proves the port's pause wiring exists, so this is a matter of naming it rather than doubting it.
2026-09-23 (G2 STATE): both simulators shut down, no input or trace triggers present, both lanes' memcards unchanged (bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-23 (G2.5 SAVE PATH - CONSOLIDATED INTO ONE EVIDENCE DOCUMENT): the save-path findings had grown to a dozen STATUS lines, so they are now one artifact: `docs/evidence/A1/g2-save-path-map-2026-09-23.md` (57 lines, inside the 60-line cap).  It records the two source-verified menu tables (`*main-options*`/`*main-options-pc*` with save-game at index 4, `*title*` with new-game -> save-game-title, `*options*` as the 4-entry settings-title table), the `*options-remap*` bindings including `save-game -> *save-options*` and `save-game-title -> *save-options-title*`, the enum tail that names screen 28 `settings-title` and 29 `auto-save`, what is verified on the lane (screen 28 cannot save; the route's only save screen is the frontend's `save-game-title`; entering a level does not auto-save; the save read works and the root is right), the in-game pause's `fuel-cell` activation and its unbound remap slot, the task-data path that actually supplies the pause's rows, and the harness rule that fixed short holds do not register while holding until the game acts does.
2026-09-23 (G2 STATE): both simulators shut down, no input or trace triggers present, both lanes' memcards unchanged (bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.  Next in this gate: the task-data row selection (how the update method builds rows for a screen with no `*options-remap*` binding), then the deterministic run.
2026-09-23 (G2.5 SAVE PATH - THE IN-GAME PAUSE CANNOT SAVE: IT IS A TASK/INFO SCREEN, NOT AN OPTION MENU): the update and draw code confirms what the probes showed.  `pc/progress-pc.gc:3609-3611` draws the pause from `(-> *level-task-data* (-> self display-level-index) task-info (-> self task-index) task-id)` - i.e. the level's own **task list** - while every navigation and accept branch works on a local `options` array whose rows come from `(-> *options-remap* (-> obj display-state))`, and `*options-remap*` (bundled `progress.gc`) binds **no** entry for `fuel-cell`/`money`/`buzzer`.  So an unbound screen has no `game-option` rows at all: the pause shows tasks and stats, and there is nothing to `down` through and nothing to accept.  That is why `index` stayed at 0 through every probe and why no menu transition followed.
2026-09-23 (G2.5 SAVE PATH - WHICH RETIRES THE IN-LEVEL HUNT AND RE-SCOPES THE REMAINING GAP): the save screen the earlier evidence used ("saving into slot 1 wrote a new bank2.bin") is the **frontend's** `save-game-title` (screen 18), which `*title*` index 0 reaches as part of NEW GAME - the same screen the accepted route touches - and `save-game -> *save-options*` / `save-game-title -> *save-options-title*` are both bound, so the frontend path is the lane's only save path.  The remaining question is therefore no longer "how does the pause reach save" but why an accept on that frontend save screen writes nothing on both lanes while the same accept wrote on 2026-09-22: the two candidates are the memcard state the game checks before using the screen (`inited`/`formatted` -> `memcard-no-data`/`no-space`/`format`) and the slot's own read.  Both are cheap to discriminate now that the screen is named: log the screen transitions after an accept (13 `memcard-saving`, 15 `memcard-creating`, or a 7/10/23 state screen).  The save-path map document already records this scope.
2026-09-23 (G2 STATE): both simulators shut down, no input or trace triggers present, both lanes' memcards unchanged (bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.
2026-09-23 (G2.5 SAVE SCREENS - THE ROW TABLES ARE READ, SO THE ACCEPTS ARE NOW NAMED): `progress-static.gc` gives the save screens' rows.  `*load-options*` (222) and `*save-options*` (233) are each **four anonymous `(game-option-type button)` slot rows plus index 4 = `back`**; `*save-options-title*` (244) is four slot rows plus **index 4 = `continue-without-saving`** and index 5 = `back`.  So the accepted driver's default (`accept screen=18 index=4`) is exactly "Continue Without Saving" as its own comment says, and my `--accept-slot 0` was **slot 1** - a real slot row.  That also means the earlier evidence's written `bank2.bin` came from accepting a slot, not from the continue row.
2026-09-23 (G2.5 SAVE SCREENS - WHY ONE ACCEPT WRITES NOTHING: THE SLOT ACCEPT MOVES BETWEEN SCREENS): the port's own save-screen branch (`pc/progress-pc.gc:2865-2866`) sets `next-display-state` to `save-game-title` or `save-game` when a slot row is accepted - i.e. **selecting a slot moves between the title-save and save screens, and the write belongs to the `save-game` screen (17)**, whose rows are the same four slots.  My single `--accept-slot 0` therefore only selected the slot, and the expected follow-up is a transition to **screen 17**; the log showed no such transition, so even that first step did not land.  The deterministic sequence is now: at `save-game-title` (18) accept slot 0 -> expect `edge screen=17` -> accept again -> expect `memcard-saving` (13) or a state screen (7/10/23) -> compare hashes.  Two accepts, not one, and every step has a named marker to wait for.
2026-09-23 (G2 STATE): both simulators shut down, no input or trace triggers present, both lanes' memcards unchanged (bank0 536a64d5fdec8da8 / bank1 39757c172fef9c5b / bank2 a8ad9b0968e5e902).  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.

2026-09-23 (G2.5/G2.1 SAVE WRITE - VERIFIED ON BOTH LANES; THE ELEVEN-ROUND "NO WRITER" WAS A HARNESS DEFECT): `scripts/replay-ios-normal-route.py --accept-slot 0` on a fresh launch drives the port's own trace all the way to a real write - `accept screen=27 index=0` (NEW GAME) -> `accept screen=18 index=0` (slot row) -> `edge screen=11` (the overwrite dialog the accept lands on) -> a D-pad LEFT hold answers the yes/no row YES -> the next accept enters `memcard-saving` (13), after which the port prints no further edges because 13 has no `*options-remap*` row.  iPad bank0.bin `6b8040a7...` -> `a3599ea8...`, a repeat run bank1.bin `b4e89c5f...` -> `7513e633...`; phone (SE3) bank0.bin `6b8040a7...` -> `526cfe06...`; 346 SIGNED MODULE ENTER = 346 RETURNED and 0-byte fault logs on both, and the written block parses as a save (save_count 3, continue-point `title-start`, counters tracking the run clock).  The dialog was never answered before because the driver answered it with `ottsel-hold-dpad-left`, a name the shell does not read (holds are `ottsel-hold-{start,cross,left,right,up,down}`, `src/shell/main.cpp:1288-1298`; `dpad-left` is only a touch region), so every prior accept left the dialog at NO.  The same driver also reads the written files back (`--load-slot N`): slot 1 loads `cp "training-start"` and slot 0 - this round's file - returns to the title and starts its level with `cp "game-start"`, the documented `title-start` shape.  Evidence: docs/evidence/A1/g2-save-write-2026-09-23.md.
2026-09-23 (G2.5 SAVE MODEL CORRECTED): each save *file* has two banks - a save writes `file*2 + 4 + p4` with `p4 = last_saved_bank ^ 1` and `save_count + 1` (`game/kernel/common/kmemcard.cpp:240-282`) - so UI slot N uses banks 2N/2N+1 and consecutive saves of one slot land on different files; that is why run 1 wrote bank0 and run 2 wrote bank1.  `scripts/verify-ios-save-continue-point.py`'s "UI slot N maps to bank<N+1>.bin" header was a misreading of this and is corrected.
2026-09-23 (G2 STATE): both simulators shut down, no input triggers left on either container; disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.  Still open in this gate: a save after real mid-level progress, audibility (Simulator CoreAudio), and physical devices.

2026-09-23 (G2.1 IN-GAME SAVE - THE PAUSE SAVES; THE "THE PAUSE CANNOT SAVE" READING IS REFUTED): the pause has no option rows of its own (it activates `progress-screen fuel-cell` and draws the level's task list), but it never needed any: `respond-progress` pushes `progress-screen settings` (3) outright on CIRCLE (`progress.gc:1128-1135`), and screen 3 is bound to the main options table whose index 4 is `save-game`, so the in-game save is pause -> CIRCLE -> DOWN x4 -> Cross -> the save screen.  The harness could not press CIRCLE because the shell's hold table has no Circle row (the key map at `src/shell/main.cpp:353-355` has E/F/R, the hold list at 1288-1298 is start/cross/left/right/up/down), so `ottsel-touch-circle` drives the finger path an iPad player uses.  Measured in one run: a held left stick moved the target 71343.1 units with pad-max 1.0, then `entering screen=0` -> `edge screen=3 index=0..3` -> `accept screen=3 index=4` -> `accept screen=17 index=0` -> `edge screen=11` -> LEFT + Cross, and `bank0.bin` changed `a3599ea8...` -> `01a8adfd...`: save_count 5, continue-point `training-start`, counters `311565 323780 311355 302313` equal to the lane's own `game-base=311565`, 346 = 346 ENTER/RETURNED and a 0-byte fault log.  New maintained probe `scripts/probe-ios-ingame-save.py`; evidence `docs/evidence/A1/g2-ingame-save-2026-09-23.md`; the save-path map's pause section is corrected.  This closes G2.1's second-save-after-mid-level-progress increment.
2026-09-23 (G2 STATE): iPad Simulator terminated and shut down, no input triggers left; disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.  Still open in the goal: audibility (Simulator CoreAudio), the renderer items (sky-fan first frames, blend-mode ledger, MERC eyes, HUD material), frontend settings, and physical devices.

2026-09-23 (G2.2 ITEMS 1-2 CLOSED BY MEASUREMENT - NOTHING LEFT TO LAND, AND TWO OLD READINGS ARE SUPERSEDED): one accepted route on this source (346 = 346 modules, 0-byte fault log) and the ledgers read from the unified log.  Item 1: `SKYSTORE probe=1 begin=1 append=40 publish=1 rollback=0 empty-publish=0 empty-replace=0 published-batches=40 snapshot=40` (and 34 on the next level), and on a frame where the producer does not run the previous snapshot is still there - so the sky batch store loses nothing and the "submitted=2 but the published store reads empty" reading does not reproduce; the same run logs `SKYLOOP` 72x, `SKYBOUNDFRAME` 9x, `SKYFRAME` 334x, which supersedes the 2026-09-22 sky-batch-path-inert document on this source.  Item 2: only the sky ever requests additive - `SKYREG-MIX` shows 0x44 and 0x48 with `other=0`, `SKYBLEND additive-drawn=32 ... additive=32` (every additive-keyed batch already drawn additively), `TIEREG draws=200 ... preset=0,199,0,0,1,0,0,0` i.e. preset 2 (additive) is 0 of 600 draws across three windows, and `DIRECTREG-MIX` shows `r0=0x0` for every batch (no ALPHA register written), so no pipeline state is owed at any site; the decode itself is `bash scripts/test-mobile-blend-policy.sh` PASS 12/12.  Evidence: `docs/evidence/A1/g2-blend-ledger-and-sky-store-2026-09-23.md`.  Remaining in G2.2: item 3 (dynamic MERC eyes) and the sky-fan first-frame residency.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no input triggers left; disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`.  Still open in the goal: G2.2 item 3 and the sky-fan residency, audibility (Simulator CoreAudio), frontend settings, packaging reconstruction/allowlist, and physical devices.
2026-09-23 (G2.2 CARRIED SKY ITEM, CORRECTED BY THE SAME RUN): the fan is not what fills the title's sky.  Its own `OTTSEL SKY SHAPE` line (an lg::info line in `ottsel-runtime.log`, which is why unified-log greps miss it) reports `after-setup-qwc=6 ... drawn=skipped` for all 57 title-window samples and `qwc=5 ... drawn=as-sky` for the 67 in-level ones, yet the title's sky region shows diagonal purple bands in one capture and bright multi-colour facets 6 s later.  Two A/Bs bound it: at the title a no-op A/B 6 s apart already moves 62.8% of the sky band (mean|delta| 44.1) because the scene animates, so a capture diff there attributes nothing and the earlier "94% of the frame moved" reading cannot either; in-level the scene is stable (no-op 0.66% of the frame, mean|delta| 0.78) and `ottsel-trace-sky-skip-draw` moves only 0.25-1.02% (mean|delta| 1.4-2.0), so the fan is a thin band and the sky fill comes from another path.  Captures under `/tmp/ottsel-route-2026-09-23/` (`title-frames/`, `sky-ab/`); evidence updated in `docs/evidence/A1/g2-blend-ledger-and-sky-store-2026-09-23.md`.  Next: name the filler (the sky-bucket store, whose SKYSTORE line publishes 40 batches, or the Direct path).

2026-09-23 (G2.6 RECONSTRUCTION AT HUNK LEVEL - THE PATH-LEVEL GUARD'S OPEN HALF, AND A LIVE PATCH THAT WAS NOT A DIFF): new `scripts/verify-overlay-hunks.py` reverse-applies every live overlay per target root (mixed patches checked in each tree with `--include`, plus a `--file PATH` mode that names which patch reproduces a file).  Measured here: 75 patches, 28 documented do-not-apply, **21 reverse-apply cleanly, 34 do not, 0 malformed** - and the 34 are the layered-stack case, not staleness (a patch whose files a later layer edits cannot reverse-apply alone; the canonical `h3-jak1-host-boot.patch` is in that group for exactly that reason), which the checker prints per patch as "N later patch(es) touch these files".  It found one real defect: `a11-loader-fail-closed.patch` was listed live but `git apply` rejects its body with `corrupt patch at line 39`, and the README's malformed list named eleven other files, not this one.  Both files it targets are reproduced by other patches (kscheme.cpp by `a11-host-cbridge-counters`/`a11-signed-export-banks`; ottsel_signed_gstate.cpp by `a11-data-only-main-segment`/`a11-kind2-method-counts`/`a11-module-record-extensions`), so it is a stale snapshot; it is now recorded in the README's malformed group with that evidence and the live stack's malformed count is 1 -> 0.  The one nested file whose only overlays are an older r1 record plus the base (`target-handler.gc`) is reproduced by the canonical patch, i.e. supersession rather than a gap.  Still open in G2.6: a from-scratch *build* from the pin.  Evidence: `docs/evidence/A1/g2-overlay-hunk-check-2026-09-23.md`.
2026-09-23 (G2.3 AUDIBILITY - THE MISSING SOUNDS ARE ONE DANGLING DATA REFERENCE, NOT A PORT DEFECT): the lane's RPC path warns 2977 times in a session, but the population is one name: `fire-pop` (id 67288) is requested 2970 times and never resolves, while the other four names (`fly7`, `training-amb`, `water-lap-cls`, `starts-options`) are 2 occurrences each and `fly7`/`water-lap-cls` do play later - i.e. transient requests before their bank loads.  Measured cause: banks load with real name lists (`common 461`, `village1 43`, `misty 41`, `training 6`) and 304 RPC plays succeed, but the name is in **none** of the 24 SBK files (no `fire-p*` entry anywhere) although the game's own data references it (`DGO/VI1.DGO`, `DGO/VI3.DGO`, `CGO/L1.CGO`) - and the repository's own extracted ISO data has the same three references and no bank entry, so it is a dangling reference in the shipped game data, not a pack or port defect.  G2.3's exit cannot require that sound; the remaining G2.3 gap is unchanged (a supported surface that actually opens its audio device).
2026-09-23 (G2.2 SKY, ONE HYPOTHESIS REFUTED): the composite producer does run in the title window - `OTTSEL SKY BLEND: produced copies=3 misses=0 vsync=63..66` right after `GAMEPLAY: enter title` - so "the title has no composite because the producer is gated to levels" is not the explanation for the title's banded/rainbow sky, and naming what fills it needs a frame-matched A/B at a static moment plus a sampled-texture dump (the title scene animates, so capture diffs there attribute nothing).
2026-09-23 (G2 STATE): no simulator was booted this round (both lanes stay shut down), no input triggers present, disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`, both guards PASS (path-level coverage and the new hunk-level check).

2026-09-23 (I3 PRESSED/NEUTRAL FEEDBACK - LANDED AND VERIFIED IN DATA AND PIXELS): the shell's own touch surface drew thirteen flat translucent tints from a layout walk and never reflected input, so a touch-only iPad player saw the same screen whether or not the game was receiving a button.  `src/shell/main.cpp` now has `ShellPadInput::pressed_region_mask()` (derived from the stick/camera/action fingers, so feedback cannot disagree with what the game is handed), `build_touch_overlay(int pressed_mask)` (a held region lifts 80% toward white and goes to alpha 0.97-1.00 from the neutral 0.18-0.24), and `update_touch_overlay_feedback()` (once per frame after input and the touch triggers; rebuilds and re-uploads only when the mask changes, so idle cost is one integer compare), plus a bounded 20-line log with the pressed region's actual RGBA.  Data: `mask=0x100 region=8 color=(0.970,0.910,0.990,1.000)`, `0x40 region=6` same, `0x1000 region=12 color=(0.930,0.930,0.950,0.970)`, back to `0x0`, always `vertices=78 uploaded=1`.  Pixels (matched captures in the training level, changed-pixel fraction above 24 per channel inside each region's own box): dpad-up held -> its box 89.2% while every other region stays 0.0%; r1 held -> its box 97.2%, others 0.0%; the no-input control pair 0.0% everywhere.  Measurement note for future rounds: the shell's surface is landscape (`class=tablet surface=1210x834`, landscape-only plist) while `simctl io screenshot` captures the portrait device frame, so an app-space box (x,y,w,h) appears at x'=1-(y+h)..1-y, y'=x..x+w - my first two readings of this round were wrong because of that frame, not the product.  Evidence: `docs/evidence/A1/i3-touch-pressed-feedback-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no input triggers left, loaded pack 1.5 GB and the three memcard banks intact; the installed app matches the current source build.  Disk `/` Avail 42 GiB, zero `.git/objects/pack/tmp_pack_*`, path-level coverage guard and hunk-level overlay check both PASS.  Still open: region labels/art, the settings entries (Gameplay / Controls / Video / Audio / Data & Saves / Diagnostics), audibility on a surface whose audio device opens, the title-sky filler, G2.6's from-scratch build, and physical devices.

2026-09-23 (I3 THE PERSISTENT THREE-DOT SETTINGS ENTRY - LANDED, DRIVEN BY TOUCH, AND PERSISTED ACROSS A RELAUNCH): the completion plan's settings entry now exists and only carries entries with real behaviour.  `src/shell/main.cpp` gains a `Menu` touch region **appended after `R1`** (so no existing region index or saved layout changes meaning), drawn as three dots inside the region the hit-test already owns and reachable with an `ottsel-touch-menu` trigger like every other region; a `ShellSettings` store persisted per device class beside the layout (`settings-tablet.cfg` = version + visibility); a screen composed on the CPU into `g_rgba` (the surface the shell status screen already uses) and handed to the product pass through the status overlay, so no glyph geometry is needed in the vertex path; and `handle_settings_touch` ahead of the layout editor and the game pad, which consumes every finger while the screen is up so the game cannot be driven behind it (D-pad up/down select, Cross or left/right change, Circle or Menu close).  Three entries with behaviour that already existed to drive: SURFACE OPACITY (0.25 steps, writes the overlay tint and the layout file), SURFACE VISIBLE (AUTO/ALWAYS/HIDDEN, driving the overlay upload policy added here; AUTO keeps the old rule that a keyboard/pad/mouse event hides the surface) and RESET LAYOUT.  Verified by touch only: `touch menu -> screen open visible=AUTO opacity=1.00`, `dpad-down`, `cross -> saved visible=ALWAYS path=.../settings-tablet.cfg` and `row=1 value=ALWAYS`, `menu -> screen closed`; the file holds `1` then `1`; after terminating and relaunching, reopening the screen reports `visible=ALWAYS` and the capture shows it, so the value survives a fresh process.  Captures `/tmp/ottsel-route-2026-09-23/settings-surface/`; lane health 346 = 346 modules and a 0-byte fault log throughout.  Evidence: `docs/evidence/A1/i3-settings-surface-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no input triggers left, 1.5 GB pack and the three memcard banks intact, installed app matches the current source build.  Disk `/` Avail 41 GiB, zero `.git/objects/pack/tmp_pack_*`, path-level coverage guard and hunk-level overlay check both PASS.  Still open: the Video/Audio/Data & Saves/Diagnostics sections, region labels/art, controller handoff and accessibility labels, audibility on a surface whose audio device opens, the title-sky filler, G2.6's from-scratch build, and physical devices.

2026-09-23 (I3 SETTINGS SECTIONS, AND A MUSIC-VOLUME SETTING WHOSE EFFECT IS MEASURED): the settings surface now has the plan's structure - a section list (CONTROLS, AUDIO, DATA & SAVES, DIAGNOSTICS, CLOSE), one screen per section with its rows plus BACK, D-pad select, Cross open/change, left/right change, Circle back one level, the three dots close from anywhere, every finger consumed while it is up so the game cannot be driven behind it - and it fills only the sections whose entries have real behaviour (no decorative controls): CONTROLS (opacity, visible, reset layout), AUDIO (MUSIC VOLUME, 10% steps), DATA & SAVES (USER PACK PRESENT/MISSING and the data root, read-only), DIAGNOSTICS (LOG OVERLAY keeps the shell log surface up after the screen closes).  Gameplay and Video are absent on purpose: no shell-side setting with real behaviour exists for them yet.  The audio row drives `snd_SetMasterVolume(16, 0x400 * v / 100)`, the port's own music master (group 16 feeds the synth master in 989snd/player.cpp), applied on change, on screen open and once at startup, and its effect is **measured in the lane's own PCM dump** rather than inferred: with MUSIC VOLUME 0 all 39 seconds of a 40 s capture read `peak=0 rms=0`, and with 100 the same window carries real signal (`second=8 peak=27218 rms=4554`, `second=21 peak=16747 rms=3638`, ... `second=39 rms=1087`).  `settings-<class>.cfg` now holds version + visibility + music + log; driven by touch only, music went 100 -> 80 (`dpad-left` twice), the file read `1 | 0 | 80 | 1`, and after terminating and relaunching the screen reported `screen open level=0 visible=AUTO music=80 log=1`, so all three values survived a fresh process.  Captures `/tmp/ottsel-route-2026-09-23/settings-sections/`; lane health 346 = 346 modules and a 0-byte fault log.  Wart on record: the loader is version-gated and the old two-field file is discarded once (defaults) before the new four-field file is written.  Evidence: `docs/evidence/A1/i3-settings-sections-and-audio-volume-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no input triggers left, 1.5 GB pack and the three memcard banks intact, installed app matches the current build; the lane's settings file is left neutral (`1 0 100 0`).  Disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the Gameplay/Video sections, region labels/art, controller handoff and accessibility labels, audibility heard on a device, the title-sky filler, G2.6's from-scratch build, and physical devices.

2026-09-23 (I3 THE TOUCH SURFACE NOW NAMES ITS CONTROLS): the surface was thirteen flat tints plus the settings entry's three dots, so a touch-only player could see where the controls were but not what they did.  `src/shell/main.cpp` gains `add_touch_glyph`/`add_touch_label`, which emit a glyph as **one quad per lit pixel** of the same column-major 5x7 font the shell status screen already uses, and `touch_region_label` naming the controls (`STK`, `CAM`, `X`, `O`, `[]`, `TR`, `^`, `>`, `v`, `<`, `ST`, `L1`, `R1`).  It costs only vertices - the overlay's vertices sample a 1x1 white texture, so a three-character label is ~40 quads - and needs no pipeline, texture or bridge change.  Each label is centred inside **its own hit region**, so what is drawn and what is touched cannot drift apart, and it brightens with the held state.  Verified: `/tmp/ottsel-route-2026-09-23/touch-labels/title-labelled.png` shows every label inside its region (`STK` in the stick block, `CAM` in the camera area, `ST` on the start bar, `X`/`[]`/`TR` on the face buttons, the four arrows on the D-pad cross, `L1`/`R1` on the top bars), and the feedback contract is unchanged with the labels in place - in the training level, holding `dpad-up` changes 73.7% of that region's own box and 0.0% of every other region while the no-input control pair reads 0.0% everywhere.  Lane health 346 = 346 modules and a 0-byte fault log.  Evidence: `docs/evidence/A1/i3-touch-labels-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no input triggers left, 1.5 GB pack and the three memcard banks intact, installed app matches the current build, settings file left neutral.  Disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: real button art and VoiceOver labels for the regions, controller handoff, the Gameplay/Video settings sections, audibility heard on a device, the title-sky filler, G2.6's from-scratch build, and physical devices.

2026-09-23 (I3 CONTROLLER HANDOFF - A GAMEPAD WAS RELEASED EVERY PASS, AND THE PATH IS NOW VERIFIED END TO END): the plan's controller handoff had never been exercised because no pad is attached to this machine, so a bounded virtual-pad diagnostics made the SDL gamepad path testable - and it found a defect that made controller play impossible: `release_mobile_gamepad("shutdown")` sat **inside the frame loop**, so every acquisition was immediately followed by `OTTSEL GAMEPAD: pad0 released reason=shutdown state=neutral` and no gamepad input could ever reach the game; it now sits with the other exit calls after the loop.  Handoff is also self-healing now: the frame body re-enumerates at most once a second while the shell owns no pad, so a dropped pad (spurious quit, remap, suspend) comes back.  The diagnostics (`<writable>ottsel-virtual-pad` plus per-button/`stick-*` files, off by default) attaches an SDL virtual gamepad; two details are on record: it keeps its **own** joystick handle (a borrowed `SDL_GetJoystickFromID` handle is closed with the shell's gamepad and then silently drops every button), and it claims pad 0 while present because this environment already exposes a device named "Gamepad".  Verified through the pad: the whole accepted route (`TITLE: start edge` -> `accept screen=27 index=0` -> `edge screen=18 index=0..3` -> `accept screen=18 index=4` -> `GAMEPLAY: enter training`), the analog stick (`pad0 sample buttons=0x0 left=(0, 127)`, target moved (-66766.5, -233.0) at pad-max=1.0), and a detach/reattach cycle after which a Cross press still reaches the game (`pad0 sample buttons=0x4000 ... cross-pressure=255`).  346 = 346 modules, 0-byte fault log.  Not proven: physical hardware - G2.7/D1 still owns that.  Evidence: `docs/evidence/A1/i3-controller-handoff-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no input triggers left, 1.5 GB pack and the three memcard banks intact, installed app matches the current build.  Disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the Gameplay/Video settings sections, real button art and VoiceOver labels for the regions, physical controllers (D1), audibility heard on a device, the title-sky filler, and G2.6's from-scratch build.

2026-09-23 (I3/G2.5 THE LABELLED SURFACE NOW FITS BOTH DEVICE CLASSES, AND THE PHONE PROFILE IS CHECKED): the labels landed last round were sized for the tablet, and the phone's regions are narrower, so `src/shell/main.cpp` now fits each label to its **own** region (`pixel_y = min(region.h / (kFontH + 2), 0.82 * region.w / (label_units * aspect), 0.0115)`; a fixed pixel overflowed the phone's 0.055-wide D-pad arms), makes glyphs square on screen by folding the axis aspect in (`pixel_x = pixel_y * h / w`, without it a glyph is stretched 1.45x on the tablet and 1.78x on the phone), and rebuilds the overlay when the drawable size changes (both the safe-area clamp and the label aspect derive from it).  Verified on the phone profile (`OTTSEL TOUCH: class=phone surface=667x375 min-region=37x43`): `/tmp/ottsel-route-2026-09-23/phone-labels/phone-title-labelled.png` shows every label inside its own region on the small class and `phone-settings-sections.png` shows the settings section list at 667x375, with the run logging `screen open`/`screen closed` through the touch path.  iPad regression on the same build (`class=tablet surface=1210x834`): the same labelled surface and section list, and `ipad-held-dpad-up.png` with the held D-pad cell visibly brighter than its neutral neighbours, so last round's pressed/neutral feedback is intact with the new geometry.  346 = 346 modules and 0-byte fault logs in both runs.  Judged limit on record: the fit is a construction from the region's own box confirmed by captures, not a matched A/B of the label pixels this time.  Evidence: `docs/evidence/A1/i3-labels-both-classes-2026-09-23.md`.
2026-09-23 (G2 STATE): both simulators shut down, no input triggers or pad files left, 1.5 GB pack and the three memcard banks intact on each lane, installed app matches the current build.  Disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the Gameplay/Video settings sections, region art and VoiceOver labels, physical controllers (D1), audibility heard on a device, the title-sky filler, and G2.6's from-scratch build.

2026-09-23 (G2.2 TITLE SKY - THE FAN IS THE SKY, AND A GATE RELAXATION WAS TRIED AND REVERTED UNPROVEN): a same-run A/B at the title with the existing `ottsel-trace-sky-skip-draw` control settles what fills the title's sky: with the fan skipped the sky-only strip reads meanRGB (27.6,27.6,32.7) with 0% blue pixels (near-black) and with it drawn the same strip reads (63.1,144.4,233.6) with 91.5% blue, and the capture pair is unambiguous (black vs blue sky with terrain in front) - so the title's sky **is** the fan.  The title window also carries the `after-setup-qwc == 6` form of the same bucket (same start pointer and 64-byte setup, one extra qword), so I relaxed `sky_shape_is_draw` to accept it and measured the result - and **reverted it**: on the un-relaxed build the settled title's sky strip is already blue (blueish 91.1%, high-chroma 86.3%), so the earlier banded/rainbow title reading is not reproduced on this source and the change had no evidence behind it.  Two method findings are on record: `OTTSEL SKY SHAPE` is **racy** (the same bucket start reads qwc=6 and qwc=5 in different samples of one run, so its qwc field cannot classify a bucket - which is how "the title is the qwc==6 form" and "the producer runs at the title" could both be read from it), and both sky windows I tried were confounded by the logo and terrain (the wide band 21.8% vs 21.7% high-chroma; the edge strip 86.3% old vs 87.0% new), so a numeric sky metric needs a logo-excluding mask.  Next measurement (named): set the skip trigger *before* the title's first frames, capture the first seconds with and without the fan, and compare only pixels the logo cannot cover - that decides whether the qwc==6 frames draw the uncomposited sheet or already the sky.  Evidence: `docs/evidence/A1/g2-title-sky-fan-is-the-sky-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no input triggers left, 1.5 GB pack and the three memcard banks intact, installed app matches the current source (the reverted build).  Disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the early-frame title-sky A/B above, the Gameplay/Video settings sections, region art and VoiceOver labels, physical controllers (D1), audibility heard on a device, and G2.6's from-scratch build.

2026-09-23 (G2.2 TITLE SKY CLOSED - THE FAN IS THE SKY FROM THE FIRST FRAME ON BOTH PROFILES): the named next measurement is done and it retires the carried item.  Two launches per profile with `ottsel-trace-sky-skip-draw` set before the app launched for the control, captures from 0.3 s after `title-wait-ready` through 15 s, read through a frame-edge strip that the control proves is sky-only: with the fan the strip is blue and drifting to a sunset from the first capture (iPad s00 (109.3,178.9,236.5) blue=91.4% ... s14 blue=91.4%; phone s00 (105.0,178.6,236.5) blue=91.4% ... s14 blue=91.3%), and with the fan skipped the strip is the same constant flat fill at every moment on both profiles ((27.6,27.6,32.7), blue=0.0%, dark=88.3%).  So there is no early window in which another draw fills the sky, the carried "fan first-frame garbage" reading is not reproducible on this source, the gate relaxation stays reverted, and nothing is owed here.  Artifacts: `/tmp/ottsel-route-2026-09-23/title-sky-earlyipad-{fan,skip}/` (iPad, 1668x2420) and `title-sky-early-{fan,skip}/` (phone, 750x1334).  Evidence: `docs/evidence/A1/g2-title-sky-fan-is-the-sky-2026-09-23.md` (53 lines).
2026-09-23 (G2 STATE): both simulators shut down, no input triggers or pad files left, 1.5 GB pack and the three memcard banks intact on each lane, installed app matches the current source.  Disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the Gameplay/Video settings sections, region art and VoiceOver labels, physical controllers (D1), audibility heard on a device, and G2.6's from-scratch build.

2026-09-23 (PHONE LANE: ONE UNREPRODUCED FAULT DURING THE TITLE-SKY RUNS - RECORDED, NOT EXPLAINED): the phone's `ottsel-fault.log` was non-zero after the two early-frame title runs (338 lines: `fault pc=0x1049539c4 lr=0x104953988`, the host register/stack dump, GOAL process/region reads and the symbol-slot scan, with **no** attribution line in the dump).  A repeat of the same fan-skip run produced **0 bytes**, 346 SIGNED MODULE ENTER = 346 RETURNED and all captures intact, so it did not reproduce from the same route; the artifact is preserved beside the lane as `ottsel-fault.log.prev`.  Because the slide of that past run is unknown, the dump alone cannot name the site; if it recurs, the next step is to decode the pc against the built binary while it is live.  No cause is claimed.

2026-09-23 (STABILITY - THE FAULT HANDLER NAMES ITS OWN SITE NOW, AND THE PHONE FAULT DID NOT REPRODUCE IN SEVEN ATTEMPTS): the carried phone fault (338-line dump, `fault pc=0x1049539c4 lr=0x104953988`, adjacent host-text addresses, no attribution) cannot be decoded after the fact because that run's slide is unrecoverable (its stack and symbol-slot lines carry EE/GOAL addresses, not host anchors), so `src/shell/ios_boot.cpp` now records the image slide (`_dyld_get_image_vmaddr_slide(0)`) and names the pc and lr through `dladdr` (symbol, offset, pc image) right after the register line - diagnostic only, nothing moves.  Reproduction attempt: six phone cycles alternating the fan-skip control that was set during the runs in which the fault appeared, each reaching `title-wait-ready` (6.6-7.6 s) and dwelling 20 s at the title, gave **0 fault bytes every cycle** with 346 modules (with the earlier repeat that is seven clean attempts of the route and window), and no `ottsel-trace-*` trigger was left behind.  So the fault is **not explained**: it does not reproduce on this route, the lane stayed live through the original occurrence, and the next occurrence will name itself; its artifact is preserved beside the phone lane as `ottsel-fault.log.prev`.  Evidence: `docs/evidence/A1/ios-fault-attribution-2026-09-23.md`.
2026-09-23 (G2 STATE): both simulators shut down, no triggers or pad files on either lane, the current source build installed on both (sha256 9ba69a47), 1.5 GB packs and the three memcard banks intact, disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the unexplained phone fault, the Gameplay/Video settings sections, region art and VoiceOver labels, physical controllers (D1), audibility heard on a device, and G2.6's from-scratch build.

2026-09-23 (G2.5 PHONE PARITY RE-RUN ON THE CURRENT BUILD, THEN THE IPAD RE-CHECK - BOTH PASS): the phone's earlier route evidence predates the labelled surface, the settings entry and the per-class label fit, so the lane was re-driven end to end through the **touch path** (`ottsel-touch-*`, the handler a finger takes) on the current build: `touch start` -> `TITLE: start edge`, `touch cross` -> `accept screen=27 index=0` (NEW GAME), `touch cross` -> `accept screen=18 index=0` (slot), `touch dpad-left` + `touch cross` -> `edge screen=11` (the overwrite dialog) and `accept screen=11 index=0` (the YES answer), and **bank1.bin changed** `b4e89c5f9e69` -> `2e7f1460ddc3` with bank0/bank2 byte-identical; the post-save flow then reached `GAMEPLAY: enter training` and the **touch** stick moved the target (30 samples, `pad-max=0.3424`, displacement (36951.0, 31792.5)) at 346 = 346 modules and a 0-byte fault log.  Sequential iPad re-check on the same build: the same touch-driven save wrote **bank0.bin** `01a8adfdb8ff` -> `36d71248a01a` (bank1/bank2 identical), Training reached, touch stick displacement (37236.5, 32574.0), 346 = 346, 0-byte fault log.  The two writes landing on different banks of the same slot is the port's own double-buffer rule.  Harness note on record: my first phone attempt reported nothing because the script omitted the START press, so the wheel never opened - a harness defect, not a lane one.  Artifacts: `/tmp/ottsel-route-2026-09-23/phone-g25-rerun/` and `ipad-g25-recheck/`.  Evidence: `docs/evidence/A1/g25-phone-parity-rerun-2026-09-23.md`.
2026-09-23 (G2 STATE): both simulators shut down, no triggers or pad files on either lane, both fault logs 0 bytes, 1.5 GB packs and the memcard banks intact on each lane, disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the unexplained phone fault (self-naming now), the Gameplay/Video settings sections, region art and VoiceOver labels, physical controllers (D1), audibility heard on a device, and G2.6's from-scratch build.

2026-09-23 (G2 STABILITY SOAK ON THE IPAD - EIGHT MINUTES OF GAMEPLAY WITH INPUT, A LIFECYCLE ROUND TRIP, NO FAULT): the acceptance bar wants fresh gameplay with input, stability and lifecycle rather than counters or a title frame, so the current build was soaked: launch -> the accepted route to Training (driver exit 0) -> sixteen 30-second ticks of input through the shell's own hold triggers (stick holds of ~24 s in each direction, D-pad taps, Cross taps) with a lifecycle round trip at tick 6 (Settings backgrounds the app, relaunch foregrounds it), sampling per tick the `pad0 sample` lines, `scene-level`, the fault-log size and the tick's module census, plus a screenshot every second tick.  Result: `scene-level='training'` in **all sixteen** ticks (village1 during the route), `ottsel-fault.log` **0 bytes at every tick** and at the end, 346 SIGNED MODULE ENTER = 346 RETURNED, input reaching the game in fourteen of the sixteen ticks (the two D-pad ticks log no pad-sample change because that line only prints when the pad state moves), and the target trace over the session: **311 samples spanning (-4790650, 3646196) units at pad-max 1.00** - sustained movement from the held sticks.  Lifecycle on the same run: `background input neutralized and audio paused` -> `foreground controller rechecked and audio resumed`, and a stick hold immediately afterwards still produced a pad sample, so input survives the round trip.  Captures `soak-000` through `soak-016` (the last a live in-level frame with the character mid-animation).  Not claimed: audibility (device gate), physical devices, or any device-side cadence.  Evidence: `docs/evidence/A1/g2-ipad-soak-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers or pad files left, fault log 0 bytes, pack and memcard banks intact; disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the unexplained phone fault (self-naming now), the Gameplay/Video settings sections, region art and VoiceOver labels, physical controllers (D1), audibility heard on a device, and G2.6's from-scratch build.

2026-09-23 (G2.5/G2.4 PHONE SOAK WITH THE SETTINGS SURFACE EXERCISED UNDER A LIVE GAME - CLEAN, AND THE DIAGNOSTICS OVERLAY WORKS IN PLAY): the phone lane had no sustained-play evidence and is the only lane where a fault has been seen, and the settings surface had only ever been driven at the title, so the lane was soaked: the accepted route to Training (driver exit 0) then sixteen 30-second ticks of hold-trigger input with the settings surface exercised at tick 4 (touch `menu` -> CONTROLS -> a Cross step on SURFACE OPACITY -> close), a lifecycle round trip at tick 9, and the diagnostics toggle at tick 12 (DIAGNOSTICS -> LOG OVERLAY on -> close -> capture -> back off).  Result: **all sixteen ticks in `scene=training` with fault=0** (history: sixteen zeros), 346 SIGNED MODULE ENTER = 346 RETURNED, input in fourteen ticks (the two D-pad ticks log no pad sample because that line only prints on a state change), and the target trace over the session **312 samples spanning (-4482456, 3461459) at pad-max 1.00**; lifecycle logged `background input neutralized and audio paused` then `foreground controller rechecked and audio resumed` with input continuing after.  Settings under load: `screen open level=0` -> `changed section=CONTROLS row=SURFACE OPACITY value=100%` -> `screen closed` (the value was already at its cap, so the step clamped - the flow, redraw and save ran, no visible change claimed).  Diagnostics under load: `changed section=DIAGNOSTICS row=LOG OVERLAY value=ON` -> `screen closed ... log=1`, and `phone-soak/soak-logoverlay-12.png` shows the shell's own log surface (the `ottsel S2.0 - Metal` header, `GPU path: Metal` and the live log tail) filling the screen over the running game, which is what that row is for; the toggle was then turned back off so the soak continued over the game.  Not claimed: audibility, physical devices, or device-side cadence.  Evidence: `docs/evidence/A1/g25-phone-soak-and-settings-under-load-2026-09-23.md`.
2026-09-23 (G2 STATE): phone lane terminated and shut down, no triggers or pad files left, fault log 0 bytes, pack and memcard banks intact; disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the unexplained phone fault (self-naming now, not seen in eight minutes of sustained phone play), the Gameplay/Video settings sections, region art and VoiceOver labels, physical controllers (D1), audibility heard on a device, and G2.6's from-scratch build.

2026-09-23 (I3 THE SURFACE NOW CARRIES THE PS2 BUTTON REFERENCE, NOT STAND-IN LETTERS): the plan's control layout asks for the PS2 button reference to be recognisable and the surface had only ASCII marks (`X`, `O`, `[]`, `TR`, `^`, `>`, `v`, `<`), so `src/shell/main.cpp` gained a small shape vocabulary on the overlay's triangle list: `add_touch_unit_triangle` (a filled triangle in unit space with a rotation, mapped as x = cx + u * radius * aspect, y = cy + v * radius so the symbol is round on screen and sized by the region's narrow dimension), `add_touch_unit_bar` and `add_touch_unit_disc`, then `add_touch_face_symbol` (○ as a disc, × as two 45-degree bars, □ as a filled square, △ as a triangle) and `add_touch_dpad_arrow` (the four arrowheads, rotated per arm).  Each symbol is centred in **its own hit region** at 34% of the narrow dimension and brightens with the held state exactly as the text did, so drawing and hit-testing cannot drift; the stick, camera, shoulders and start keep their short text and the settings entry keeps its three dots.  Verified on both profiles: iPad `touch-shapes/shapes-neutral.png` shows the four arrowheads and ×/□/△/○ on the face buttons inside their regions, `shapes-cross-held.png` shows the Cross region brighter with its × lifted (the shapes participate in the pressed feedback); phone `touch-shapes-phone/phone-shapes.png` shows the same symbols and arrowheads at 667x375 with the text marks and dots intact.  346 = 346 modules and 0-byte fault logs in both runs.  The shapes are filled rather than the PS2's outline art, and VoiceOver labels remain open.  Evidence: `docs/evidence/A1/i3-ps2-button-shapes-2026-09-23.md`.
2026-09-23 (G2 STATE): both simulators shut down, no triggers or pad files on either lane, both fault logs 0 bytes, packs and memcard banks intact, the current build installed on both lanes, disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the unexplained phone fault (self-naming now), the Gameplay/Video settings sections, VoiceOver accessibility labels, physical controllers (D1), audibility heard on a device, and G2.6's from-scratch build.

2026-09-23 (I3 ACCESSIBILITY LABELS - THE ON-SCREEN CONTROLS NOW NAME THEMSELVES): the shell draws its own controls into the Metal layer, so UIKit had nothing to name and VoiceOver saw an unlabelled game surface.  `src/shell/metal_shell.h` declares `OttselAccessibilityRegion` plus the set/log bridges; `src/shell/metal_shell.mm` adds `OttselAccessibilityView`, a transparent container over the Metal view that takes no touch (`hitTest:` returns nil) and answers the container protocol UIKit uses (`accessibilityElementCount` / `accessibilityElementAtIndex:` / `indexOfAccessibilityElement:`) with one `UIAccessibilityElement` per region - a spoken label, the button trait, and a frame in the container's own space; `src/shell/main.cpp` maps each `TouchRegion` to a full word and republishes from `upload_touch_overlay` so the elements follow the drawn surface and are cleared when it hides, behind a bounded `ottsel-trace-a11y` trigger.  Correction on record: my first cut flipped the frame Y, but `add_touch_rect` maps a region's y=0 to clip y=+1 and UIKit is also top-left origin, so the element box *is* the drawn box - with the flip `Start` (y 0.075) read near the bottom and the stick (0.605) near the top.  Verified on both classes: iPad `container-elements=14 view-frame=(0,0,1210,834)` with `Start` y=62.55 and `Movement stick` y=504.57, phone `container-elements=14 view-frame=(0,0,667,375)` with `Start` y=6.75; and independently of the log, the `D-pad up` frame mapped through the capture rotation lands on the held region - iPad mean (251.4,250.5,249.9) with 95.4% of pixels > 235 inside against (89,45,24)/(68,41,15) just outside, phone 94% bright.  346 = 346 modules, 0-byte fault logs.  Not proven: VoiceOver activation routing.  Evidence: `docs/evidence/A1/i3-accessibility-labels-2026-09-23.md`.
2026-09-23 (G2 STATE): both simulators shut down, no triggers or pad files on either lane, both fault logs 0 bytes, packs and memcard banks intact, the current build installed on both lanes, disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: VoiceOver activation routing, the Gameplay/Video settings sections, the unexplained phone fault (self-naming now), physical controllers (D1), audibility heard on a device, and G2.6's from-scratch build.

2026-09-23 (I3 GAMEPLAY AND VIDEO SECTIONS - THE LAST TWO FRONTEND ITEMS, WITH BEHAVIOUR THAT IS MEASURED): the plan's settings entry names Gameplay, Controls, Video, Audio, Data & Saves and Diagnostics, and only Gameplay and Video were absent, so `src/shell/main.cpp` gains GAMEPLAY (CAMERA SENSITIVITY 50..200% in 25% steps, which scales the touch camera region's drag gain, and INVERT CAMERA Y, which flips its vertical drag - both the shell's own producer, with defaults that reproduce the old behaviour exactly) and VIDEO (RENDER SCALE 100/75/50%, which the shell applies to the CAMetalLayer drawable that the game and every native draw render into; the layer scales it back up).  `load_settings` is now tolerant - a field the file does not carry keeps its default - so an older short file loads instead of being discarded.  Correction on record: VIDEO was first brightness+contrast on the shell's scaled frame; it persisted and logged but measured as a **no-op on screen** (band-mean 56.48/56.60/56.21 at 100/50/150%) because the tone lands on the shell's CPU buffer while the visible frame is drawn natively by the game, so it was removed.  Verified by measurement on both classes: the camera hold's own pad sample reads `right=(147,117)` at 50% and `(208,87)` at 200%, and `(208,167)` inverted at 200% (phone `(147,117)` / `(147,137)`); render scale moves the shell's surface 1210x834 -> 907x625 -> 605x417 on the iPad and 667x375 -> 500x281 -> 333x187 on the phone; and the static settings screen's bright-pixel fraction is 0.0234 at 100% against 0.0544 at 50%.  Persistence: the iPad reboots at surface 605x417 with `screen open ... sens=200 invert=1 scale=50` (cfg `1 0 100 0 200 1 50`), the phone cfg `1 0 100 0 50 1 50`.  346 = 346 modules and 0-byte fault logs on both.  Evidence: `docs/evidence/A1/i3-gameplay-video-sections-2026-09-23.md`.
2026-09-23 (G2 STATE): both simulators shut down, no triggers or pad files left, both fault logs 0 bytes, the shell's own settings files reset to neutral (`1 0 100 0 100 0 100`), packs and memcard banks intact, disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  I3's settings sections are now complete (Gameplay, Controls, Video, Audio, Data & Saves, Diagnostics); still open: VoiceOver activation routing, audibility heard on a device, the remaining renderer items (the TRANS/LOWRES_TRANS tfrag trees), the unexplained phone fault, physical controllers (D1), and G2.6's from-scratch build.

2026-09-23 (G2.6 RECONSTRUCTION, MEASURED AT FILE LEVEL - AND THE GAP NAMED AND CAPTURED): the coverage guard is path-level and the hunk guard only reverse-applies, so the forward reconstruction claim was untested; this round ran the README's own recipe - a fresh worktree at pin `641fb572e` plus an ordered forward replay - and measured it.  `h3-jak1-host-boot.patch` alone reproduces **153 of 178** files byte-for-byte; applying every other overlay that `git apply --check` accepts (31, in repeated sorted passes; the rest are superseded by h3, outer-tree-only, or the documented corrupt `a11-loader-fail-closed.patch`) brings it to **182 of 193**; the remaining 11 files (395 lines) were working-tree diagnostic and experiment edits that no overlay captured - BOT62's target trace in `cam-update.gc`/`target-death.gc`, the `title-obs`/`progress-pc` diagnostic prints, `sif_ee.cpp`'s `OTTSEL_SIGNED_GAMEDATA_TEST` guard, `kscheme.cpp`'s A1.1 diagnostics, and the loader/audio/AOT traces - so `patches/g2-working-tree-source-gap.patch` now captures exactly that delta and the recipe reproduces **193 of 193** nested files, re-verified end to end from a second fresh worktree.  File-level only: the reconstructed tree is byte-identical to the tree that already builds, but the build/run half of G2.6 stays open.  Evidence: `docs/evidence/A1/g26-reconstruction-file-level-2026-09-23.md`.
2026-09-23 (G2 STATE): no simulator booted, no triggers left, both fault logs 0 bytes, packs and memcard banks intact, the scratch reconstruction worktrees removed so the nested worktree list is back to one entry, disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the reconstructed *build* for G2.6, VoiceOver activation routing, audibility heard on a device, the remaining renderer items, the unexplained phone fault, and physical controllers (D1) - no code-signing identity or provisioning profile exists on this machine, so a device build is not possible here.

2026-09-23 (G2.3 AUDIBILITY - THE SIMULATOR BLOCKER IS GONE, AND THE SOUND IS TIED TO GAME EVENTS): the 2026-09-22 finding that the Simulator's CoreAudio open hangs forever **no longer reproduces** - in two consecutive runs the same build logs `SDL output-only playback stream opened device=21 paused=false` and `route='System audio playback device'` with no `SDL_AUDIO_DRIVER` set, so it is the real device, not the `dummy` driver the earlier evidence had to fall back on (what changed in the host is not established, only that the blocker is gone).  With `OTTSEL_AUDIO_DUMP=45` the captured PCM is 45.01 s of S16 stereo 48 kHz, overall peak 32768, rms 4913, and its per-second profile accounts for all ten silent seconds - boot 0-6, the level-load gap at 10, and the two seconds the app was backgrounded.  The sound is tied to game events, not tones: 19 distinct PLAYER RPC events played - frontend (`cursor-up-down`, `select-menu`, `select-option`, `menu-close`; the driven route's own edges), movement (`walk-grass1/2`, `land-grass`), swimming (`swim-kick-surf`, `swim-idle1/2`, `swim-stroke`, `breath-in/out-loud`), water (`water-drop`, `water-lap-cls`), ambience (`training-amb`, `bird-2`, `fly7`) and `warpgate-tele` - with `Load music village1` for the level's music (sustained in-level rms 8.8k-14.5k).  Interruption is visible in the PCM and not only in the log: `background input neutralized and audio paused` at the two silent seconds, then `foreground controller rechecked and audio resumed` with signal returning at second 23.  346 = 346 modules, 0-byte fault log, `scene-level='training'`.  Not proven: dialogue (no NPC conversation on this route) and a human listening check.  Evidence: `docs/evidence/A1/g23-audibility-simulator-open-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: G2.3's dialogue leg and a human 'heard' check, the reconstructed build for G2.6, VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - blocked, there is no code-signing identity or provisioning profile on this machine).

2026-09-23 (I3 THE TOUCH SURFACE COMES BACK WHEN TOUCH IS THE INPUT AGAIN - A DEFECT FOUND WHILE CAPTURING ACCEPTANCE): an in-level acceptance capture came back with no controls drawn and the log named the cause - `ShellPadInput::keyboard()`, `mouse_motion()` and `mouse_button()` all call `hide_touch_overlay_for_native_input()`, which sets `g_native_input_mode` and clears the surface, and **nothing ever cleared it**, so one keyboard/mouse/gamepad event removed the touch controls for the rest of the run (the lane shows a stray host event at 15:06 after which every capture was control-less, and the harness's own `ottsel-hold-*` triggers reproduce it because they inject through the same keyboard path).  `src/shell/main.cpp` now clears that flag on `FINGER_DOWN`, which is what `SURFACE VISIBLE = AUTO` ("follows the input actually in use") means; the frame loop's existing upload gate restores the surface with no other change.  Verified on a same-build, in-level A/B by counting the overlay's own left-stick tint: after the keyboard hold 0 pixels, after one touch 74,595.  Evidence: `docs/evidence/A1/i3-touch-surface-restored-on-touch-2026-09-23.md`.
2026-09-23 (G2 ACCEPTANCE - VISIBLE GAMEPLAY, INPUT, STABILITY, LIFECYCLE AND AUDIO IN ONE RUN): with the audio substrate reachable this session, one run now carries the whole simulator-side acceptance bar.  Fresh install, route to Training (rc 0), in-level play driven through the **touch** path so the drawn controls stay up, plus a bounded 25 s recording.  Measured: 346 SIGNED MODULE ENTER = 346 RETURNED and a 0-byte `ottsel-fault.log` with `scene-level='training'` 75 times; pad samples carrying the driven state (`left=(167,107)` touch stick, `buttons=0x4000` Cross, `0x20` DpadRight) with the target trace spanning 5,642,301 x 3,666,344 units over 159 samples; the audio stream open on device=21 with an 80.00 s PCM dump (peak 32768, rms 3743, 71 of 80 seconds carrying signal) and `Load music village1`; **27 distinct PLAYER RPC sound events** tied to the driven input (walk-grass/sand/water, land-grass/sand, jump, eco-bg-blue, swim-jump/stroke/idle/kick-surf, breath, training-amb, bird-2, fly7, and the frontend's cursor/select/menu sounds); and stills plus a video showing live in-level gameplay with the touch controls drawn.  Not established: device playability (no signing identity or provisioning profile here), dialogue audio (the training level defines no `level-hint-spawn`), or a human listening check.  Evidence: `docs/evidence/A1/g2-acceptance-run-with-audio-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings file left neutral, disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: G2.3's dialogue leg and a human 'heard' check, the reconstructed build for G2.6 (disk-gated - a from-scratch build would drop free space under the 40 GB floor), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - blocked, no signing identity or provisioning profile on this machine).

2026-09-23 (G2.5 THE PHONE LANE RE-CHECKED ON THE CURRENT BUILD - PARITY HOLDS, INCLUDING THE NEW ITEMS): the phone was last driven before three shell changes landed (the Gameplay/Video settings sections, VIDEO render scale, and the fix that lets a touch restore the touch surface), so it was re-driven rather than assumed.  Fresh install, route to Training (rc 0): `class=phone surface=667x375`, `GAMEPLAY: enter training`, `scene-level='training'`, 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte fault log, `pad0 sample buttons=0x4000 cross-pressure=255` with the target spanning 5,558,057 units.  The new items behave identically: RENDER SCALE moves the surface 667x375 -> 500x281 (75%) -> 333x187 (50%) -> 667x375; CAMERA SENSITIVITY 50% with INVERT CAMERA Y ON gives the camera hold's own sample `right=(147,137)`; and the touch-surface fix reads 0 overlay pixels after a keyboard hold against 39,559 after one touch.  Audio reaches the real device on the phone too - stream opened device=21, `Load music village1`, an 80.00 s PCM dump (peak 32768, rms 3467) with **21 named PLAYER RPC events** - and `settings-phone.cfg` is `1 0 100 0 50 1 100`, so the new fields persist on the phone as on the iPad.  Not proven: anything device-side (no signing identity or provisioning profile here).  Evidence: `docs/evidence/A1/g25-phone-parity-current-build-2026-09-23.md`.
2026-09-23 (G2 STATE): both lanes exercised and shut down, no triggers left, both fault logs 0 bytes, packs and memcard banks intact, settings files reset to neutral, disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: G2.3's dialogue leg (needs gameplay into village1 - the training level defines no `level-hint-spawn` and the shell has no level-load trigger) and a human 'heard' check, the reconstructed build for G2.6 (disk-gated - a from-scratch build would drop free space under the 40 GB floor), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - blocked, no signing identity or provisioning profile on this machine).

2026-09-23 (G2.3 DIALOGUE: REACHABLE, AND SILENT FOR A NAMED PORT REASON - THE iOS PATH HAS NO VAG PLAYER): my earlier note that the training level defines no dialogue hint was wrong - the grep was truncated by `head`.  `training-obs.gc:109-129` defines seven hint volumes (`asstvb41/42/48`, `sagevb21/22/24/27`) fired when Jak enters a tutorial trigger, and driving Jak forward produced hint activity within one leg.  The line is silent because a voicebox plays it as a sound named `spool-<name>` (`ambient.gc:287/329/335`) and `game/overlord/jak1/srpc.cpp` has **two** `RPC_Player` implementations: the desktop one (`:313`) strips the prefix, uppercases the name, `FindVAGFile`s and `PlayVAGStream`s, while the `#ifdef OTTSEL_IOS` one (`:104`) has no such branch, so the name falls through to the bank lookup and is dropped (`PLAYER RPC sound missing name=spool-sagevb38`, `spool-asstvb40`).  The cutscene path is silent for the same class of reason: `str-play-async`'s consumer is the PLAY-STR RPC registered through the PS2 SIF, and the lane logs `OTTSEL SPOOL: start name=sage-intro-sequence-a ... initial-pos=-1`, so `current-str-pos` never leaves -1.  Not a bank/pack defect: `sagevb38`, `asstvb40`, `asstvb41` and `sagevb22` are absent from all 24 SBK files - dialogue is `VAG/VAGDIR.AYB` + `VAGWAD.ENG`, and the building blocks exist (the shell's opt-in `OTTSEL_AUDIO_VAG_PROBE` reads VAGDIR/VAGWAD and starts a voice with `snd_StartVAGProbeShared`; the engine has `VagVoice`).  Next is a real feature - a `spool-` branch on the iOS RPC plus a shell-side VAG service (the fake-ISO root is owned by the banks, so the reader cannot simply be shared) - left for its own round rather than half-wired.  Lane health during the drive: 346 = 346 modules, 0-byte fault log, `scene-level='training'`.  Evidence: `docs/evidence/A1/g23-dialogue-ios-vag-gap-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail 41 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the iOS VAG dialogue player (the concrete next step for G2.3's dialogue leg), a human 'heard' check, the reconstructed build for G2.6 (disk-gated), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - blocked, no signing identity or provisioning profile on this machine).

2026-09-23 (G2.3 DIALOGUE LANDED - THE iOS PATH PLAYS THE VAG VOICE LINES NOW): the previous round root-caused dialogue to a missing iOS VAG player; this round builds it.  `game/overlord/jak1/srpc.cpp`'s `#ifdef OTTSEL_IOS` `RPC_Player` gains a `spool-` branch that hands the line to the shell (bridge declared at file scope like `ottsel_ios_writable_dir`), and `src/shell/ios_boot.cpp` gains `ottsel_ios_play_vag_dialogue(name8)`: it parses `VAG/VAGDIR.AYB` once (807 entries, 8-character name + u32 offset **in 2048-byte sectors** - measured, `offset * 2048` lands on the `VAGp` header for every entry), uppercases and space-pads the name, reads the VAG from `VAG/VAGWAD.ENG`, takes the data size and 48 kHz rate from the header, sets the end-of-sample flag on the last ADPCM block as the existing probe does, and starts it with the engine's own VAG voice, keeping the last four sample buffers alive because the voice holds a raw pointer.  Measured by driving Jak into the training level's hint volumes: `VAG dialogue name='SAGEVB38' sector=62646 bytes=153632 rate=48000 started=1` and `ASSTVB40 ... started=1` (`started=1` is the engine's own return from submitting the voice), the two lines that were dropped last round now give **zero** `sound missing name=spool-` warnings, and a second hint fires afterwards so nothing stalls on a stream.  346 = 346 modules, 0-byte fault log, `scene-level='training'`, `Load music village1` intact, PCM dump 120.00 s peak 32768 non-silent.  Not covered: the cutscene `str-play-async`/PLAY-STR path (a different channel) and a human listening check.  Operational: the two full builds this round left `/` at 40 GiB, exactly the repository floor, so no further full build without freeing space.  Evidence: `docs/evidence/A1/g23-dialogue-ios-vag-player-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail 40 GiB (**at** the 40 GB floor - a further full build needs space freed first), zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: the cutscene VAG path and a human 'heard' check, the reconstructed build for G2.6 (now disk-gated harder), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - blocked, no signing identity or provisioning profile on this machine).

2026-09-23 (G2.3/G2.5 THE DIALOGUE FIX VERIFIED ON THE PHONE, AND THE REPOSITORY IS BELOW ITS DISK FLOOR): the phone lane still had the pre-fix build, so the current one was installed there and driven the same way - `OTTSEL AUDIO: VAG dialogue name='SAGEVB38' sector=62646 bytes=153632 rate=48000 started=1`, **zero** `sound missing name=spool-` warnings, 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte fault log, `scene-level='training'` - so the voice-line path behaves identically on both classes.  Disk finding, measured not guessed: `scripts/build-ios.sh:321` does `SIGNED_GENERATION="$(mktemp -d "$SIGNED_DIR/modules.XXXXXX")"` and never removes it, so every build leaks a generation directory; `out/jak-project/out/ios/app/signed-gstate` now holds 79 `modules.XXXXXX` plus 3 `aggregate.XXXXXX` directories totalling **13 GB** (largest 236 MB; newest `modules.EQoUSg`, `modules.FoJD99`).  The phone install's fresh 1.5 GB container copy put the volume at **38 GiB - below the 40 GB the repository requires - while the lane was booted**, and it returned to **45 GiB once the lane shut down**, so what breached the floor was the lane's own container copy on top of the accumulated leak, not the product.  The leak is still worth reclaiming (13 GB, and ~160 MB per build) and was put to the user rather than done unilaterally, because deletion is gated in this workspace.  Evidence: `docs/evidence/A1/g23-dialogue-ios-vag-player-2026-09-23.md`.
2026-09-23 (G2 STATE): phone lane terminated and shut down, no triggers left, settings reset to neutral, 0-byte fault logs on both lanes, packs and memcard banks intact, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS (78 patches, 24 reverse-apply clean, 0 malformed).  Disk: **45 GiB available** after both lanes shut down (the phone install dipped it to 38 GiB while booted, below the floor); the build-script leak above holds 13 GB and is worth reclaiming, which is awaiting the user's decision.  Still open: the cutscene VAG channel and a human 'heard' check, the reconstructed build for G2.6, VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.3 DIALOGUE CUTSCENE HALF LANDED, AND TWO BUGS FIXED ON THE WAY): the cutscene channel was only clock-emulated on iOS (`g_ottsel_stream_clock.play(...)` plus an `OTTSEL STREAM CLOCK: play ... name=` line in `game/sce/sif_ee.cpp`), so a cutscene's timeline advanced without audio; the branch now resolves the same 8-character name the desktop `RPC_PLAY` does (a `$`-prefixed name is already a VAG name, anything else goes through `ISONameFromAnimationName`) and hands it to the shell's VAG player, so both dialogue channels share one implementation.  Two bugs surfaced and were fixed: (1) `RPC_Play_Cmd_Jak1::name` is `char[48]` and the first cut copied `sizeof(command.name)` into a 17-byte local - the canary caught it as `__stack_chk_fail` -> SIGABRT inside `sceSifCallRpc` (crash report `OttselShell-2026-09-23-100557.ips` on the GOAL thread); the copy buffer is now sized from the field.  (2) The shell player kept only the last four samples alive, and a cutscene line (`SAISA`, 2.36 MB, ~11 s) outlived four later plays, so its buffer was freed under the decoder - a 38,728-byte fault naming `snd::Voice::DecodeSamples`; every handed-over buffer now stays alive, keyed by name so a repeat reuses it.  Verified on the exact five-play sequence that faulted (`NDINTRO`, `LOINTRO`, `SAISA`, `SAGEVB38`, `ASSTVB40`): all `started=1`, `scene-level='training'`, 346 = 346, **0-byte fault log**, app alive.  Both edits are captured as overlays (`g23-ios-vag-cutscene.patch`, and `g23-ios-vag-dialogue-shell.patch` regenerated); guards PASS (79 patches, 25 reverse-apply clean, 0 malformed).  Not proven: a human listening check, and simultaneous lines share one engine voice.  Evidence: `docs/evidence/A1/g23-dialogue-cutscene-vag-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail ~45 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Still open: a human 'heard' check for dialogue, the reconstructed build for G2.6 (disk-gated by the un-reclaimed 13 GB build-script leak), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.3 DIALOGUE STOP HANDLING - A SKIPPED CUTSCENE NO LONGER KEEPS TALKING): the stream RPC's stop command (`result 1`) ends a spooled line, and the lane's log shows five stops against three plays, so the cutscene hook ignoring it would leave narration playing over whatever came next - which is what skipping a cutscene does.  `snd_StopVAGProbeShared` (a hard `Voice::Stop` in `game/sound/sndshim.cpp`, declared in the header) is now called from the iOS stop branch through a new shell bridge `ottsel_ios_stop_vag_dialogue`.  Verified on the full route plus drive: **5 VAG plays / 5 stops**, `scene-level='training'`, 346 = 346 modules, **0-byte fault log**, app alive.  Captured as overlays (`g23-ios-vag-cutscene.patch` regenerated with the stop hook, new `g23-ios-vag-stop-shim.patch` and `-header`, `g23-ios-vag-dialogue-shell.patch` regenerated); guards PASS (81 patches, 27 reverse-apply clean, 0 malformed).  Evidence: `docs/evidence/A1/g23-dialogue-cutscene-vag-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail ~45 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  Both dialogue channels (voicebox hints and cutscene narration) now play and stop correctly.  Still open: a human 'heard' check, the reconstructed build for G2.6 (disk-gated by the un-reclaimed 13 GB build-script leak), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.3 AUDIBILITY - A CORRECTION AND AN OPEN QUESTION, NOT A CLAIM): the I3 round's AUDIO row labelled `MUSIC VOLUME` was measured in the PCM and read as the music group, but it drives `snd_SetMasterVolume(16, ...)` and group 16 is the synth **master**; measured directly, two runs with it set to 0 - one reaching Training with its own level ambience - produced **120.00 s and 115.00 s of pure silence** (peak 0, rms 0, 0 non-silent seconds each), so the control mutes the whole mix and a player setting "music" to 0 loses all sound.  The row is now labelled **MASTER VOLUME** (verified by driving the screen: `changed section=AUDIO row=MASTER VOLUME value=90%`, cfg `1 0 90 0 100 0 100`); a true music-only volume needs the music handler's own group, not yet established.  The dialogue A/B this round intended - suppress the VAG player with the new `ottsel-trace-vag-off` diagnostic and compare - is confounded by exactly that finding (both runs silent), so **dialogue audibility is still unproven**: what holds is only what was claimed, that the lines resolve and the engine accepts and submits the voice (`started=1`), not that the narration contributes signal to the mix.  Two dead ends recorded so they are not repeated: the `OTTSEL_AUDIO_VAG_PROBE` path produced no probe lines this run, and one analysis read a stale dump (delete the wav before each capture).  Lane health: 346 = 346 modules, 0-byte fault log.  Evidence: `docs/evidence/A1/g23-audio-master-volume-and-dialogue-audibility-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail ~44 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS (82 patches, 28 reverse-apply clean, 0 malformed).  Still open: proving the dialogue reaches the mix (the concrete next step above), a human 'heard' check, a true music-only volume, the reconstructed build for G2.6 (disk-gated by the un-reclaimed 13 GB build-script leak), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.3 DIALOGUE - THE VOICE PROVABLY PRODUCES AUDIO, AND THE STREAM STOP IS NOW PER-STREAM): three results.  (1) The VAG probe armed at boot, when nothing else plays, is the clean isolation and it produced `VAG refill producer started entry=SA3INTRO bytes=429809` with PCM **peak 30836, non-silent 7/9 seconds** (`[0,0,684,30736,30836,21282,30684,25518,30788]`) through `snd_StartVAGProbeShared` - the same voice the dialogue uses - so the voice path demonstrably turns VAG data into output.  (2) The stream stop was **global** and would cut whichever line was playing; the PLAY-STR branch now resolves one shared 8-character token for play and stop and the shell stops only the line the engine is playing, verified by `stopped name='NDINTRO '` versus `stop ignored name='NDINTRO ' playing=''`; this mirrors the desktop, whose `StopVAG` does `snd_keyOffVoiceRaw`.  (3) New observation, not root-caused: the game plays **and stops each cutscene line in the same second** (`NDINTRO` 3366, `LOINTRO` 3367, `SAISA` 3382) while the training hints (`SAGEVB38`, `ASSTVB40`) get no stop at all and play in full - so the cutscene narration is cut short by the game itself and the tutorial hints are the dialogue that completes; no spool abort or recover appears in the log (one `STALL-ART` line).  Still open: the narration's share of the mix (at full volume the mix clips at 32768 in both runs, and a reinstall rotated one comparison dump away) - a same-run off-switch window or a voice-level meter would close it.  Lane health: 346 = 346 modules, 0-byte fault log, `scene-level='training'`.  Evidence: `docs/evidence/A1/g23-dialogue-voice-works-and-stream-stop-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail ~43 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS (82 patches, 28 reverse-apply clean, 0 malformed).  Still open: the narration's share of the mix and why the game stops the cutscene lines immediately, a human 'heard' check, a true music-only volume, the reconstructed build for G2.6 (disk-gated by the un-reclaimed 13 GB build-script leak), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.6 ALLOWLIST PACKAGE INSPECTION - THE BUNDLE SHIPS NO ROM DATA, MEASURED): the second half of G2.6 is what the product actually ships.  Enumerating the built bundle recursively gives exactly 61 MB of: `OttselShell` (22 MB), `Info.plist`, `_CodeSignature/CodeResources`, `GAME.CGO` and `KERNEL.CGO` (goalc output from the GOAL source), `iso_data/DGO/TIT.DGO` (1.4 MB) and `VI1.DGO` (11.5 MB), and 48 `iso_data/TEXT/*.TXT` files - and a search for ROM families finds none (`*.iso`, `SCUS*`, `*.SBK`, `*.VAG`, `VAGWAD*`, `*.MUS`, `Z6TAIL*`, `*.STR`).  The bundled DGO/TEXT are the **build's**, not the disc's: same names, different bytes - `TIT.DGO` bundle `7421fc02...` against the extracted ROM's `7226f8e0...`, `VI1.DGO` `ccbce309...` vs `9300242a...`, `0COMMON.TXT` `d28eb00a...` vs `2defc222...` - which is the distinction the loop doc records the hard way (staging the pack's originals boots to 332 modules and crashes; the build's own boot to 346).  The player's data is not in the bundle at all: the app's Files import promotes their pack into the app container (1.5 GB), so the bundle stays asset-free by design.  Evidence: `docs/evidence/A1/g26-allowlist-package-inspection-2026-09-23.md`.
2026-09-23 (G2 STATE): no simulator booted this round (the inspection reads the built bundle and the extraction on disk), no triggers left, settings files neutral, disk Avail ~44 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS (82 patches, 28 reverse-apply clean, 0 malformed).  G2.6 is now file-level complete plus this content inspection; its build half stays disk-gated by the un-reclaimed 13 GB build-script leak.  Still open: the narration's share of the mix and why the game stops the cutscene lines immediately, a human 'heard' check, a true music-only volume, the reconstructed build for G2.6, VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.3 AUDIBILITY - A REAL MUSIC VOLUME, AND THE DIALOGUE MEASURED IN THE MIX): two results.  (1) The port's own `SetMusicVol()` (`game/overlord/jak1/ssound.cpp:189`) drives **groups 1 and 2** for music while group 16 is the synth master (`Player::SetMasterVolume` calls `mSynth.SetMasterVol` only for 16), so the shell's AUDIO row was a master mute; `apply_music_volume` now scales groups 1 and 2.  Measured with the row at 0 on the route to Training: **90.00 s captured, peak 16383, rms 951, non-silent 79/90** against **0/120** and **0/115** when it drove the master - music gone, world ambience intact, `scene-level='training'`, 0-byte fault log.  The row is `MUSIC VOLUME` again (it was briefly `MASTER VOLUME` while it drove the master).  (2) Muting the music made the dialogue measurable: driving Jak into the training hint volumes, the captured mix's per-second rms goes from a ~200-800 ambience baseline to **6179, 4731, 2629, 2495** at the exact second `SAGEVB38` starts (second 28; its VAG is 153632 bytes ~ 5.6 s), stays elevated through `ASSTVB40` at second 33, and returns to baseline - so the narration contributes signal to the output for the length of each line, which is what the earlier rounds could only state as "the engine accepted the voice".  Still open: a human listening check, and why the game stops the cutscene lines in the same second they start.  Evidence: `docs/evidence/A1/g23-music-volume-and-dialogue-in-mix-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail ~43 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS (82 patches, 28 reverse-apply clean, 0 malformed).  Still open: a human 'heard' check, why the game stops the cutscene lines immediately, the reconstructed build for G2.6 (disk-gated by the un-reclaimed 13 GB build-script leak), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.6 A REAL DISPLAY BUG - THE SHELL'S STATUS SCREEN WAS COVERING THE RUNNING GAME): found while checking whether the intro cutscene renders - a screenshot showed the shell's own surface (`ottsel S2.0 - Metal`, `GPU path: Metal`, `DATA: import OttselUserData in Files`, the scrolling log tail) filling the screen while the game ran behind it, so a player would have seen the log, not the game.  A bounded `OTTSEL DATA: status state=...` line (logged on change) showed `has-user-data` **oscillating**: `state=2 data-missing=0 has-user-data=1` -> `state=3 data-missing=1 has-user-data=0` -> back.  `select_ios_iso_data_dir()` reset `g_has_user_data = false` at its start, and it runs again mid-run while a pack is re-imported (the log shows the import twice, the second ~7 s after boot); during that call's `remove_all(durable)`/`rename(staging, durable)` window a frame rendered with `data_missing=1`.  It then stayed up because the status overlay is uploaded inside `if (!g_metal || !has_live_scene() || data_missing)` and the clear is the `else if` of that same branch - skipped once the scene is live and the data is present, so it was never cleared.  Fix (one file, `src/shell/ios_boot.cpp`): only `bundle_data_fallback` clears the flag, the pack branches set it true.  Verified: the state sequence is now `1 -> 0 -> 2` with **no state=3**, and the screen reads **mean 59.7, dark 0.04** (game) against the status screen's 34.4/0.84; 346 = 346 modules, 0-byte fault log.  Residual: the clear is still inside that branch, so a future late upload would still stick - moving it out is the defensive follow-up.  This also means the current build had been hiding the game since the double import began, so earlier rounds' "visible gameplay" captures predate it and the logs alone could not show it.  Evidence: `docs/evidence/A1/g26-status-screen-covered-the-game-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail ~43 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS (83 patches, 29 reverse-apply clean, 0 malformed).  Still open: the overlay-clear residual above, a human 'heard' check, why the game stops the cutscene lines immediately, the reconstructed build for G2.6 (disk-gated by the un-reclaimed 13 GB build-script leak), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.6 THE STATUS-SCREEN RESIDUAL CLOSED - THE CLEAR IS REACHABLE FROM OUTSIDE THE BRANCH): the follow-up named last round is done: `status_overlay_active` is hoisted out of the `if (!g_metal || !has_live_scene() || data_missing)` branch and the overlay is cleared after it whenever it is still up, the data is present and the scene is live, so an upload that happens after the scene goes live can no longer stick.  A normal run is unchanged - the state sequence is `1 -> 0 -> 2`, the screen reads mean 60.7 / dark 0.03 (game, not the status surface), `scene-level='training'`, 346 = 346 modules, 0-byte fault log - and the new branch's own trigger is the bug fixed last round, so it is a guard rather than a fix and is not exercised by that run.  Both changes are in `g26-status-screen-flag.patch`.  Evidence: `docs/evidence/A1/g26-status-screen-covered-the-game-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail ~44 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS (83 patches, 29 reverse-apply clean, 0 malformed).  Still open: a human 'heard' check, why the game stops the cutscene lines immediately, the reconstructed build for G2.6 (disk-gated by the un-reclaimed 13 GB build-script leak), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.6 AFTERMATH - THE VISIBLE EVIDENCE RE-ESTABLISHED ON THE FIXED BUILD): because the status-screen bug hid the game, the visible claim was re-checked rather than carried over.  A fresh route with captures every 1.2 s now shows the screen **changing with the game** (`route00` mean 34.7 through `route16` 124.2) instead of the frozen status surface, and the in-level frame is the game itself - Jak on the training cliff with palms, the portal and the sky - at **mean 60.8 / dark 0.03** against the status screen's 34.4 / 0.84.  The frame carries no touch controls only because the route drives with keyboard triggers, which hide the surface by design; one `ottsel-touch-cross` puts them back (**90,133 overlay-tint pixels**, `feedback mask=0x8 uploaded=1`).  `scene-level='training'`, 346 = 346 modules, 0-byte fault log.  Artifacts: `/tmp/ottsel-fixed/inlevel.png`, `touch.png`.  Still open from the same thread: whether the intro cutscene plays its intended sequence - the frames vary now, so it is visible at all, but its audio lines are still played and stopped in the same second.  Evidence: `docs/evidence/A1/g26-status-screen-covered-the-game-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail ~44 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS (83 patches, 29 reverse-apply clean, 0 malformed).  Visible gameplay is re-established on the current build (game frame mean 60.8, touch controls restorable).  Still open: a human 'heard' check, whether the intro cutscene plays its intended sequence, the reconstructed build for G2.6 (disk-gated by the un-reclaimed 13 GB build-script leak), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.3/G2.6 THE INTRO CUTSCENE DOES NOT PLAY - ITS ART SPOOL STALLS ON A BUFFER LOCKED BY ANOTHER OWNER): the open question from the dialogue thread is answered, and the reason is named.  The cutscene's *level* loads and draws (`GAMEPLAY: enter title -> village1 -> misty -> village1 -> training`, and a capture every 0.45 s shows the title, the main-menu wheel over the village backdrop, then a close-up of rock geometry with no camera framing, no actors and no HUD right after New Game) - but its *sequence* does not.  The port's own bounded `STALL-ART` trace shows why: `ja-play-spooled-anim` waits for each part's file status to become `active`, and the buffer holding the cutscene's part is `locked` with owner **`sequenceA-village1`** (the title screen's own village1 sequence) - `STALL-ART sage-intro-sequence-a 0 fs=#f,locked b1=sage-intro-sequence-a/0/locked/lk=#f/own=sequenceA-village1 ... r1=sidekick-human-intro-sequence-b/0/-1.0000`, then the same for part 1 - so the part never activates, the wait spins and the sequence aborts.  That also explains the audio: `ja-play-spooled-anim` calls `str-play-stop` on the way out, which is why the cutscene's lines are played and stopped in the same second while the training hints (no spool) play in full.  The port's existing spool recovery (`OTTSEL SPOOL RECOVER`, added for a permanently locked buffer) did **not** fire - its condition evicts a partner whose status is `active`, and this one is `locked`.  Next: either the title's `sequenceA-village1` should release the buffer when the intro takes over, or the recovery must cover a buffer locked by an owner other than the requester; the first is the more likely correct fix, but the game's spool-ownership contract needs reading first.  Not proven: which fix is right, and whether every cutscene or only this one is affected.  Evidence: `docs/evidence/A1/g23-intro-cutscene-spool-stall-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail ~44 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS (83 patches, 29 reverse-apply clean, 0 malformed).  Still open: the cutscene spool contention above, a human 'heard' check, the reconstructed build for G2.6 (disk-gated by the un-reclaimed 13 GB build-script leak), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.3 THE CUTSCENE STALL ROOT-CAUSED TO A STALE HANDLE - THE SPOOL OWNER RESOLVES TO AN INVALID OBJECT): the spool-ownership contract was read (a buffer sits at 'locked until external-art-control::update promotes it to 'active, and that promotion requires `(not locked?)` **and** `(handle->process load-file-owner)`), and the obvious fix was tried - a dead-owner branch in the port's own `OTTSEL SPOOL RECOVER` block plus an `owner-alive` field on the `STALL-ART` trace.  It did not fire, and the trace is decisive: `b1=sage-intro-sequence-a/0/locked/lk=#f/own=sequenceA-village1 owner-alive=0,#<invalid object #x1>` - `handle->process` on that owner resolves to an **invalid object**, not `#f`, so the game's promotion never runs (it needs a live owner) *and* a `not handle->process` guard never matches (the value is truthy).  The root is therefore the stale handle lookup, not the spool: a spool owner whose process has gone should resolve to `#f`.  Shipped in the build: the `owner-alive` trace (what found it) and the inert dead-owner branch; the cutscene still does not play.  Lane health unchanged: 346 = 346 modules, 0-byte fault log, `scene-level='training'`.  The GOAL change was rebuilt through `goalc --isa arm64 -c '(load-project "goal_src/jak1/game.gp") (mi)'` (546 targets, 8.0 s) then `scripts/build-ios.sh`.  Evidence: `docs/evidence/A1/g23-intro-cutscene-spool-stall-2026-09-23.md`.
2026-09-23 (G2 STATE): iPad lane terminated and shut down, no triggers left, 0-byte fault log, pack and memcard banks intact, settings reset to neutral, disk Avail ~43 GiB, zero tmp packs, path-level coverage guard and hunk-level overlay check PASS.  The build now carries a GOAL change (`loader.gc`: the `owner-alive` trace plus an inert dead-owner recovery branch).  Still open: the stale spool-owner handle lookup above, a human 'heard' check, the reconstructed build for G2.6 (disk-gated by the un-reclaimed 13 GB build-script leak), VoiceOver activation routing, the remaining renderer items, the unexplained phone fault, and physical controllers (D1 - no signing identity or provisioning profile on this machine).

2026-09-23 (G2.3 THE CUTSCENE STALL, SHARPENED - A FREED PROCESS WHOSE PID STILL MATCHES): `handle->process` (`gkernel-h.gc:369`) dereferences the handle's process pointer and returns the process only if the handle's PID equals the process's PID - the design relies on that check to catch a stale handle.  The `owner-alive` field shows why it does not here: the owner's memory was freed but its PID field still matched the handle's, so the check passed and a **dangling object** came back instead of `#f` - which is also why the `(not (handle->process ...))` guard added earlier this round is inert.  The second half is the buffer's own bookkeeping: it is `'locked` holding *our* part while its owner field still names the other sequence, so it never promotes to `'active` for us and nothing releases it.  Both halves need the kernel's handle/process teardown and the spool's owner bookkeeping read together; the cutscene still does not play.  Lane health unchanged: 346 = 346 modules, 0-byte fault log.  Evidence: `docs/evidence/A1/g23-intro-cutscene-spool-stall-2026-09-23.md`.

2026-09-23 (G2.3 THE CUTSCENE ROOT, CORRECTED - MY "FREED PROCESS" READING WAS WRONG): reading `deactivate` refutes the previous entry: it already ends with `(set! (-> this pid) 0)` (`gkernel.gc:2012`), so a deactivated process can never match a live handle's PID - yet the trace still shows a dangling object from `handle->process`, so the owner is **not** a deactivated process.  That leaves two candidates, separated by one bounded measurement: the owner is alive but its object is unreadable (a corrupt type pointer), or the *handle's own* PID is 0, which would make `0 == 0` pass against a zeroed process; printing `(-> b load-file-owner pid)`, the dereferenced object's `pid` and its `status` for the stuck buffer names it in one run.  The buffer's other half is unchanged (it sits `'locked` holding *our* part while its owner field still names the other sequence).  The cutscene still does not play; lane health unchanged (346 = 346, 0-byte fault log).  Evidence: `docs/evidence/A1/g23-intro-cutscene-spool-stall-2026-09-23.md`.
