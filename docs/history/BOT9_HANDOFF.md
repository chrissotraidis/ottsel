# BOT9 Handoff — M1: one crash from Jak alive in the village on macOS

Date: 2026-08-16.  From: the M1 session (BOT22–BOT29).  Read
docs/14-roadmap-to-playable.md (strategy), docs/15-m1-phase-plan.md, and
docs/evidence/M1/* (esp. m1-engine-connection-crash.md — the live target).

## Where the game is (all verified, deterministic addresses across boots)

Host build: out/jak-project/build/h1/game/gk (native arm64, full upstream
stack: GL renderer + fr3 assets + IOP/overlord + no-emit AOT GOAL).
Boot: `cd out/jak-project && ./build/h1/game/gk -v --game jak1 -- -boot
-fakeiso`.  The Sony boot logo RENDERS (display path proven end-to-end).
The title loads; the retail title flow stalls waiting for VIS (not wired
yet).  Trigger `touch /tmp/ottsel-bg-village1` AFTER "GAMEPLAY: enter
title" appears: the driver (game/sce/libpad.cpp) runs (bg 'village1),
sets play? #f + *artist-all-visible* #t, then (start 'play cp) — Jak
spawns, "GAMEPLAY: enter village1" fires, TFragment renders village1
meshes... and seconds later the EE thread dies, freezing a black frame.

## THE crash (fix this first — it is the wall)

EXC at EE pc=0x3075274, lr=0x41e32bc (compiled `bsp` object), identical
registers every run (x0=0x2e7e8c4 obj type 0x153e2d4, x2=0x153c270
scratch).  lldb crash-hook dumps prove: the called address is a DATA
object (type 0x153db74), and the dispatch source (~0x153e2d0) is an
ENGINE CONNECTION LIST — 16-byte rows {level-heap param, level-heap
param (0x3075xxx stride 0x40), code ptr, code ptr} — the dispatcher
calls a PARAM slot as the function.  Hypothesis (one probe out):
`deactivate` of the discarded title ran `(remove-by-param1
*background-draw-engine* title-bsp)`; the ARM64-compiled connection
surgery or `execute-connections` iterator (engine.gc/engine-h.gc)
corrupts/misreads the list.  Next probe: dump
*background-draw-engine*'s alive list ({next, function, param0..2} per
connection, offsets from engine-h.gc minus basic offset) right after
"Discarding level title" and at the crash; then read the compiled
remove/iterate code (lldb: process is deterministic; `-k` runs commands
on crash).  Fix the smallest fault (suspect codegen for the linked-list
field access or the engine loop), reboot, expect: Jak + village visible,
keyboard control (Enter=START; SDL input live on host).

## This session's fixes already in the tree (don't re-litigate)

sys_icache_invalidate at every RW->RX flip (was THE 1-in-3 link SIGILL);
per-slot stub sealing incl. mips2c reg (boot-order-proof); low 512kB
PROT_READ in no-emit builds (PS2-faithful; sidekick reads null bones by
design); _stack_call_arm64 no longer clobbers x0 (every stack-arg C
builtin returned arg0 before — text reload loop 127k->2 loads); v3
main-seg RX flips for non-executed objects; a SIGBUS/SIGSEGV exec-fault
healer (runtime.cpp) that flips+invalidates EE pages and retries.  All
synced into the iOS runtime archive.  goal_src diverges from upstream
ONLY in kernel/gkernel.gc (the tie/tfrag ln restorations were reverted).

## After the crash falls (M1 completion order)

1. 5-minute stable soak in village1, keyboard/controller verified, audio
   listened to.  Record evidence in docs/evidence/M1/.
2. Wire VIS (RAMDISK) + STR spool streaming through the overlord (files
   exist: out/jak1/iso has all 321; iso_data/jak1 has the full 1.4GB) —
   this makes the RETAIL flow work: intro movie autoplays, title waits
   for START, no /tmp trigger needed.  The stall points are documented:
   target-continue's vis wait (target-death.gc) and the art-control
   spool chain (m1-black-screen-diagnosis.md).
3. Remove the debug triggers/probes; regenerate
   patches/h3-jak1-host-boot.patch (from out/jak-project: git add -A,
   git diff --cached 641fb572 > ../../patches/h3-jak1-host-boot.patch,
   git reset) — NEVER commit in the fork; commit/push only in ottsel.
4. Then the iOS track per docs/14-roadmap-to-playable.md (renderer port
   ANGLE-first, IOP un-stub, data bundle, S3 touch).

## Rules & gotchas

One fix per boot cycle; lldb ground truth before theories (a probe
misread cost BOT27 a wrong root cause — offsets: basic ref = mem+4,
inline kheap 16-aligned, time-frame 8-aligned).  Boot takes ~60-90s to
title; "begin load" -> playable needs the trigger.  cwd traps: gk runs
from out/jak-project; the ottsel repo is two levels up.  Kill stray gk
(`pkill -f game/gk`) before rebuilds.  Crash reports:
~/Library/Logs/DiagnosticReports/gk-*.ips (json after line 1).  Never
patch game source to mask runtime bugs; never commit ROMs/ISOs/assets;
push to origin main (chrissotraidis/ottsel) only.
