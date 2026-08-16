# M1 Phase Plan — Jak running on macOS (2026-08-16)

Goal: a verified, playable boot of Jak 1 on this Mac (native arm64 gk,
real renderer/audio/streaming), today if the single gating bug yields.

## Phase state (from docs/14-roadmap-to-playable.md)

READY: fr3 assets (out/jak1/fr3, 25 files) · full iso (out/jak1/iso,
321 files) · native arm64 gk with the full upstream stack (GL renderer,
SDL3, IOP/overlord, 989snd) · no-emit AOT link of our ARM64 GOAL code.

BLOCKED BY: the nondeterministic no-emit link-phase fault (sim: ~1-in-3;
host today: 6/6). Death mid-KERNEL.CGO link at varying objects
(pc-debug-methods/pad, vif-h).

## Phase run

1. **P1 — Catch the fault with a real debugger.**  The host is debuggable
   with lldb (unlike the Simulator's raw fault dumps): run gk under lldb
   batch mode, capture the faulting pc, disassembly, and registers.
   Exit: a concrete faulting instruction + memory state.
2. **P2 — Root-cause.**  Prime suspect (classic for this bug class): the
   RW->RX page-flip path executes freshly written ARM64 code; on Apple
   Silicon, written code must be icache-invalidated
   (sys_icache_invalidate / __builtin___clear_cache) before execution or
   stale icache lines produce nondeterministic SIGILL — exactly the
   observed signature.  Verify whether the no-emit link path invalidates
   after every code write/flip.
3. **P3 — Fix + prove.**  Apply the smallest fix; rebuild gk; boot in a
   loop (target: 5/5 clean links).  The same fix ships to the iOS runtime
   archive (same code path) and should erase the Simulator's 1-in-3 too.
4. **P4 — Boot to the game.**  gk to the rendered title (real fr3
   renderer), intro spool (real STR via overlord), then village1.
   Evidence: log excerpts + screenshot.  Input check: keyboard bindings
   (pc-settings); controller optional.
5. **P5 — Record the gate.**  Evidence in docs/evidence/M1/; update
   STATUS.md (M1 row), 13-current-state.md, 00-loop-log.md; regenerate
   patches/h3-jak1-host-boot.patch; commit.

## Rules

One fix per boot cycle; verify against the running gk and lldb ground
truth; never patch game source to mask runtime bugs; never commit
ROMs/ISOs/assets (fr3/iso outputs stay untracked); stop and report at
three consecutive blocked cycles.
