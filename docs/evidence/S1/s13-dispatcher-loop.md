# S1.3 evidence — GOAL kernel dispatcher loop on the iPad Simulator

Date: 2026-08-08 (Bot 4, continued session). Gate: **S1.3 PASS** —
**Gate S1 PASS** (primary bar met: the no-emit ARM64 runtime boots to the GOAL
kernel dispatcher loop on the iPad Pro 11-inch (M4) Simulator, iOS 18.5).

## Result

The app `OttselShell` (bundle `com.ottsel.shell`) launches on the iPad
Pro 11-inch (M4) Simulator and the no-emit runtime:

1. maps EE main memory RW at `0x7000000000` (no W^X, no writable+executable),
2. links **all 8 KERNEL.CGO objects** with the same RW->RX code-page flips as
   the host (stub arenas A/B RX, main segments RX, top-level transient RX),
3. prints `Got correct kernel version 2.0, loaded in 8.1 ms`,
4. hard-disables the listener/REPL,
5. enters the GOAL `kernel-dispatcher` loop and **runs continuously with zero
   faults**:

       [info] OTTSEL_IOS: GOAL kernel dispatcher iteration 200 (running)
       ... 48,200+ iterations logged, process still alive at capture ...

## Root cause found and fixed (this session)

The earlier session's dispatcher faults (jump to EE offset 0) were caused by
**two compounding issues in the OTTSEL_IOS build**, not by invalid ARM64
encodings (S1.1 proves every word valid):

1. **`pc-prof` (and the other PC-port C exports) were never registered.**
   The kernel dispatcher's first statement is
   `(profiler-instant-event "ROOT")`, which calls the C export `pc-prof`.
   An OTTSEL_IOS early-return in `init_common_pc_port_functions` skipped the
   registrations, so the symbol the GOAL side reads had value 0 -> call to
   EE offset 0. Fix: register the PC-port exports on iOS too (the headless
   stubs in `game/ios_stubs.cpp` cover the input/display/GFX symbols they
   reference).
2. **The GOAL-side and C-side interning diverged.** `find_symbol_from_c`'s
   open-addressing probe is order-dependent; with thousands of kernel-link
   interns, a name can become unreachable from its hash position, so a later
   intern creates a second entry and the GOAL side reads a slot the C side
   never wrote. Fix: an OTTSEL_IOS full-table fallback scan in
   `find_symbol_from_c` guarantees every intern of a name finds the one
   canonical entry. Also re-ordered `InitHeapAndSymbol` (OTTSEL_IOS) so the
   C exports are interned before the kernel link.
3. Reverted a wrong attempt that set `*listener-function*` to 0: the GOAL
   dispatcher's `(when *listener-function*)` test compares the value against
   `s7` and skips when equal, so the H3 sentinel (`s7.offset`) is correct and
   the listener branch is a no-op.

## Evidence files

- `s13-dispatcher-loop.log` — full boot log: EE map, 8 objects linked,
  `Got correct kernel version 2.0`, `kernel: machine started`, and
  continuous `GOAL kernel dispatcher iteration N (running)` lines (48,200+).
- `s13-dispatcher-loop.png` — the app's visible log surface on the
  Simulator showing the iteration lines.
- `s13-gated-{stop,visible2}.log|png` — the earlier explicit-gated-error
  fallback (before the fix), demonstrating the no-crash-loop behavior.

## Honest boundaries

- Simulator evidence is never device proof (physical-device validation and
  signing remain open; no IPA is advertised).
- The dispatcher process pool is idle (no listener/GAME.CGO in the no-emit
  boot), so no game processes are created yet — expected for S1; S2+ drives
  those.
- The gated signal handler remains installed as the "no crash loop" safety
  net.
