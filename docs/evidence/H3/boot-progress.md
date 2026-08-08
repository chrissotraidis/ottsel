# H3 — Jak 1 host AOT boot: status after second iteration

Date: 2026-08-07/08. Pin: `641fb572e876750d8618434d9f7c1a531b43b366`
Patch: `patches/h3-jak1-host-boot.patch`
Evidence: `docs/evidence/H3/boot-to-goal-entry.log`

## What now works (verified)

1. **Full Jak 1 kernel compiles for ARM64** (10 targets, `KERNEL.CGO` produced)
   including the x86-named GOAL asm functions via an ARM64 register-name map.
2. **`gk` boots on Apple Silicon with the no-emit runtime**:
   - EE memory mapped RW-only (no RWX; W^X respected)
   - missing `fr3` tolerated (empty common level) so boot proceeds
   - IOP/OVERLORD starts, `KERNEL.CGO` loads via the real linker
   - `gcommon` links with data-only relocations
   - code pages flipped to RX after link (16KB page granularity fixed)
   - `call_goal_on_stack` enters the ARM64 GOAL top-level with correct
     `st`/`offset`/goal stack (16-byte aligned)

Log tail:

    [link and exec] gcommon   0  26364 heap-use 533002  0: 0x1c1f2a
    OTTSEL no-emit: code pages flipped RX (481093697536..481093713920)
    link finish: gcommon
    OTTSEL call_goal_on_stack: fptr=0x70036b72e4 st=0x18fe04 off=0x7000000000 rsp=0x7007fffff0
    OTTSEL target first words: 00 00 00 10 00 00 16 cb | 90 1c 00 70 10 02 00 91

## Precise remaining blocker (SIGILL rc=-4)

The top-level's first IR is `mov-fa` (`IR_FunctionAddr`) for `function-identity`.
It emits `adr x0, slot; sub x0, x0, x22` with an unpatched ADR placeholder.
The `identity` function is in a different segment than the top-level, and
`patch_arm64_static_ref` only resolves **same-segment** references. The
unpatched `adr x0,#0` makes execution fall into the inline literal → SIGILL.

## Fix needed (next slice)

Cross-segment ARM64 function/static references must resolve at AOT finalize
using the global segment layout (offsets known once all segments are placed in
the link image), not only same-segment offsets. `patch_arm64_static_ref` needs
the final absolute delta between the ADR and its target across segments.
This is the last linker-side gap before the top-level can run to completion
and set `kernel-dispatcher`.

## Also fixed this iteration (for the record)

- `make_function_from_c` ARM64 C-export stub bytes (correct ldr-literal layout;
  previously emitted x86 bytes on aarch64).
- `_arg_call_arm64` reads the pushed target at `[sp,#16]` (was reading saved x29).
- `_call_goal_on_stack_asm_arm64` restore uses the x29 frame (was restoring from
  the wrong stack after the switch).
- EE goal-stack addresses 16-byte aligned; `*stack-base*` aligned on aarch64.
- EE mapping RW-only under `OTTSEL_NO_EMIT`; code pages flipped RX post-link
  with `sysconf(_SC_PAGESIZE)` (16KB on Apple Silicon).

## Honest boundary

The host boot reaches the first real GOAL top-level entry with the no-emit
runtime, but does not yet return from it (cross-segment ADR resolution). H3 is
NOT PASS. The remaining work is bounded: one linker finalize path.
