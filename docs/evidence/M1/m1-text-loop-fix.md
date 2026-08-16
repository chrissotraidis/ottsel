# M1 — BOT24: the text reload loop, and an ARM64 trampoline ABI bug (2026-08-16)

## Symptom

With the title booted (m1-title-boot.md), the overlord served
**0COMMON.TXT 84,666× and 0SUBTIT.TXT 42,334× in ~14 minutes**
(~150 loads/s): `load-game-text-info` rejected the loaded text every
frame and reloaded it forever.  No crash — a hot loop wasting the EE
thread and re-linking two files per frame.

## Root cause (ground truth via a C-side probe in link_and_exec)

The GOAL-visible `link` builtin is a **stack-arg C stub**
(make_stack_arg_function_from_c → `_stack_call_arm64`).  The probe
showed every link returning the correct entry (e.g. 0x1c8b9d4) while the
GOAL-side store received **entry+0x2c** (0x1c8ba00) — exactly the
pre-link aligned load address, i.e. **argument 0**.

`_stack_call_arm64` (game/kernel/asm_funcs_arm64.s) built the argument
array on the stack, called the C target, then "restored arguments" with
`ldp x0, x1, [sp], #16` — **clobbering the return register x0 with saved
arg 0**.  GOAL received the first argument as the return value.  The
x86-64 trampoline just pops the array (`add rsp`) without restoring;
`_arg_call_arm64` (the common 6-arg path) never restores either, which is
why everything else worked.  With the bogus "linked object" pointer, the
game-text-info's language-id/group-name fields read as garbage, the
acceptance check failed, and the loader retried every frame.

Fix: `add sp, sp, #64` — discard the array, preserve x0.

## Verified

- 0COMMON.TXT loads per boot: **127,001 → 2** (one per text heap —
  correct).  0SUBTIT.TXT likewise.
- Title boots in ~10 s, `Displaying level title`, `GAMEPLAY: enter
  title`, "Load music village1" (the sound-bank path now engages),
  village1-vis loaded (7,479,408 bytes served by the overlord), process
  alive, zero new crash reports.
- The fix is assembled into the iOS runtime archive
  (game_kernel_asm_funcs_arm64.s member) + shell rebuilt.

## Note for the next session

Every GOAL→C call through `make_stack_arg_function_from_c` returned
arg0 instead of its result until now (on ARM64 no-emit builds).  Any
past mystery where a stack-arg builtin's return value seemed wrong
(str-load-status?, dgo state checks) deserves a re-test on both host and
Simulator now that the trampoline is honest.  Also: silence the
per-dispatch "OTTSEL_IOS dbg" listener log spam (pure noise at runtime),
and the TXTLINK probe (capped at 6 prints) can stay temporarily.
