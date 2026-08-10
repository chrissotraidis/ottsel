# S2.1 — process-heap C-stub forwarding fix (2026-08-10)

## Reproduced cause

With the trace-free product CGOs, live LLDB stopped at `font-h` code
`ee+0x006c41f4`. Its third `object-new` call selected the process heap
(`x0 = s7 + FIX_SYM_PROCESS_TYPE`) with current GOAL process `x20 =
0x02338ba4`. The generated no-emit C stub executed `br x17` before its
conditional `mov x3, x20`, so the move was unreachable and
`alloc_heap_object` received the stale stub value as argument 4.

## Fix and validation

`game/kernel/jak1/kscheme.cpp` now emits the optional `mov x3, x20` (or NOP)
before `br x17`, without changing literal offsets. A1.0 regression 16 in
`tools/ottsel_a1/semantic_regressions.cpp` checks the ordering; the complete
`build/h1/goalc/ottsel-a1-sem` suite passes.

The rebuilt Simulator boot advances beyond that `font-h` failure. Its next,
distinct S2.1 fault is a type-method dispatch at `ee+0x0019b8a30`: it loads a
zero method field at `type+0x34` and branches to `ee+0`. The continuation is
`ee+0x0019b8a34`. The signal handler now logs only registers and control-flow
state so this later evidence is clean.
