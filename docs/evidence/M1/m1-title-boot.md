# M1 — Jak 1 boots to the title on macOS, native arm64 (2026-08-16)

## Result

`./build/h1/game/gk -v --game jak1 -- -boot -fakeiso` on the M1 Mac:
the game boots to the **displayed title screen in ~15 s** and keeps
running (no faults, no crash reports): `begin load title-vis` →
`Displaying level title [display]` → `GAMEPLAY: enter title` →
`begin load village1-vis` (preload behind the title), with the real
OpenGL 4.1 renderer, SDL3 window, and the real IOP/overlord serving
files (0COMMON.TXT text loads cycling in the live game loop).  Our
recompiled ARM64 GOAL code runs through the no-emit AOT link path.
Evidence: m1-title-boot.log (screen capture blocked by macOS
Screen-Recording permission; the game window is live on the desktop).

## The three root causes fixed (each lldb/crash-report verified)

1. **Missing icache invalidation** at every RW→RX code-page flip
   (klink.cpp top-level + main flips, kscheme.cpp stub arena).
   mprotect does not flush the instruction cache on Apple Silicon; the
   reused top-level staging pages could execute the previous object's
   stale code — the long-standing nondeterministic link-phase SIGILL
   (~1-in-3 on the Simulator).  Fix: `sys_icache_invalidate` after every
   flip.
2. **Stub-arena boot-order dependency** (EXC_BAD_ACCESS executing RW
   arena pages at EE 0x4f10904/0x4f10a24, caught twice under lldb).  The
   phase A/B bulk flips assumed the iOS shell's hand-ordered boot; the
   host goal_main path registers phase-B stubs that GOAL executes DURING
   the kernel CGO link, and `LinkedFunctionTable::reg` (mips2c) wrote
   stubs with no seal at all.  Fix: per-slot sealing —
   `ottsel_stub_alloc` reopens the slot's page RW,
   `ottsel_stub_seal_last()` (all 5 writers) flips it RX + invalidates
   the icache immediately after the bytes are written.
3. **Low-memory guard too strict** (EXC_BAD_ACCESS reading EE 0x30 from
   `vector<-cspace!`, called from sidekick — deterministic).  The PS2's
   low memory is readable, and the game reads through null-ish bone
   pointers by design (the og:preserve-this swamp-blimp workaround loads
   the bone transform, then checks `w == 0.0`).  Upstream's PROT_NONE on
   the first 512 kB kills that path.  Fix (OTTSEL_NO_EMIT builds):
   PROT_READ — reads return zeros exactly like the Simulator shell's
   fully-RW mapping (which is why the identical GAME.CGO never crashed
   there); writes still fault.

## Also fixed en route

- mips2c table guard widened to `OTTSEL_IOS || OTTSEL_NO_EMIT` so the
  host h1 gk links (`register_all_jak1` was iOS-only).
- All three fixes compiled into the iOS runtime archive
  (libottsel-runtime.a: kscheme/klink/mips2c members) + shell rebuilt;
  the Simulator's 1-in-3 link fault should be erased by the same
  icache/sealing fixes (verification is the next session's first step).

## How to reproduce the boot

```
cd out/jak-project
./build/h1/decompiler/decompiler decompiler/config/jak1/jak1_config.jsonc \
  iso_data decompiler_out --version ntsc_v1 \
  --config-override '{"decompile_code": false}'   # fr3 assets (~6 s)
./build/h1/goalc/goalc --isa arm64 -c \
  '(load-project "goal_src/jak1/game.gp") (mi)'   # full iso (~20 s warm)
./build/h1/game/gk -v --game jak1 -- -boot -fakeiso
```

## Remaining for "playable" (M1 completion)

Input (keyboard/controller bindings — gk warned no controllers found),
audio verification (989snd is live; listen), title → new game → village1
progression, and a performance sanity pass.  The title currently idles
before the logo spool; whether the intro STR spool plays end-to-end on
the host overlord is the next check.
