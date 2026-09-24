# A1.1 strict signed-GAME oracle-serve crash - 2026-09-21/22 (host + app)

Stage 0 reconciliation, two landed fixes with regressions and gated probes, a working non-strict baseline, and the
narrowed reading of the crash that stopped the 2026-09-15 continuation. No playability claim.

## Stage 0: three overlays, each proved byte-for-byte
`patches/a11-streamed-link-begin.patch` (klink sha256 3eb8cd27), `patches/a11-call-goal-synthetic-return.patch`
(asm sha256 ba996119) and `patches/a11-asm-ret-fail-safe.patch` (a pin-to-current snapshot of `IR.cpp`, because
the h1/h2/h3 overlays do not compose for that file), each with a verifier under `scripts/verify-*.py`.

## Fixes landed
Bridge contract: the C->GOAL bridges push the GOAL synthetic return slot that asm-funcs read
(`scripts/test-a11-call-goal-asm-ret.sh` SIGSEGVs before, PASSes after). `.ret` fail-safe: `IR_AsmRet`'s ARM64
lowering selects `[sp]` against the incoming x30 by the port address split (`keep = ((slot >> 32) - 1) >>a 63;
x30 -= (slot - x16) & keep`), x2/x16/x17 only, x0/v0 preserved, verified by
`scripts/test-a11-asm-ret-guard.sh` (select cases plus emitted-module check).

## Probe gates and the constraint they exposed
The module emitter rewrites prebuilt `out/jak1/obj/*.o`, so emitter changes reach the app only after the objects
are regenerated with the documented command
`cd out/jak-project && ./build/h1/goalc/goalc --isa arm64 -c '(load-project "goal_src/jak1/game.gp") (mi)'`
(546 targets, ~8 s). Two emitter probes are gated by environment so normal builds stay clean:
`OTTSEL_TRACE_GOAL_CALLS` enables the bounded GOAL call trace (`g_ottsel_call_trace`, dumped by the fault
handler) and `OTTSEL_ASM_RET_GUARD_OFF` restores the historical plain `.ret` sequence for A/B work.

## Working baseline
`config/signed-kernel-full.json` + banks 1: no fault, `LINKBEGIN: name=oracle` twice, 68 `DGO RPC: continue`
objects, two `GAMEPLAY` markers, live level activity (`OTTSEL STR: loaded LOLOOP.STR`).

## Crash reading
With the old objects and no trace the strict profile branches into GOAL data: `pc = x30 = 0x181674`, the
`village-cam` Symbol address, at CPU-stack offset 0 - the slot an `IR_AsmRet`-style `ldr x30, [sp]` reads, with
`[sp+0x38]` holding that type's base and `sp+0x98` naming `villagep-obs+0x9d24`. `villagep-obs.o` is
byte-identical before and after regeneration, so the guard's effect came from `gkernel`/`gstate` `.ret` sites.
With the guard in the regenerated objects the branch is gone and the run instead faults in `gkernel` at GOAL
0x8027874 (`code-range=invalid`); with the trace on and the guard off it reaches `GAMEPLAY` and then dies on a
null call (`pc = lr = 0`). Three symptoms for one configuration family means state corruption, not one
deterministic miscompile.

### Refuted, with evidence
Emitter kind (faithful kind-1 records; the loader line reads `sym=0x181674 value=0x0 w196..w228=0xffff1870
s7=0x18fe04`), consumer dereference (both seg2 sites dereference), export banks (`banks=0` faults identically),
`method_set` with a Symbol type (a bounded log over the symbol-table window produced no hits). The host lane is
not an oracle - it links the prebuilt `build/h1/game/libruntime.a` and never defines the export banks - and the
dladdr frame list mixes live frames with stale words.

### The ring
The trace recorded 50178 calls in the guarded run and 57478 in the trace-plus-guard-off run. Entries are 32-bit
halves, so `host = 0x100000000 | value`; subtracting the run's `ee-base` and mapping onto the runtime's
`SIGNED MODULE ENTER` list names every entry, e.g. `site target-handler+0xe64 -> target title-obs+0xf2d04
pp=0x1f6464`. The guard-off run's tail runs `gcommon -> dgo-h -> target-handler -> game-info -> main`, ending
`main+0x14e50 -> gkernel+0x43f4` just before the null call.

## Next experiment - one variable
Use the decoded ring as an auditor rather than chasing symptoms: dump more of the ring and flag any entry whose
`target` is not a module entry or whose `caller-lr` is an EE value, then examine the `main -> gkernel+0x43f4` call
and its neighbours against the emitted DGO-completion code. The product state (guard on, no trace) is restored.
