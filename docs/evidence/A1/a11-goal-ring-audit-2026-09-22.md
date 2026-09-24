# A1.4 - the bounded GOAL call-trace ring, audited (2026-09-22, app)

The ring is now decodable, and the two implausibility criteria the A1.3 board named are both
refuted for the traced strict run: no target is a non-entry, and no caller-LR is an EE value.
No playability claim; product state (guard on, no trace) untouched.

## Run identity (read-only; a sibling task owned the build)
Installed shell sha256 206662cf, slide 0x4588000, arena 0x104f80000, GAME list 348 modules,
export banks on, .ret guard present but in its inert form (lsr x17,x17,#32 appears 34 times in the
binary - the mask comes from the pushed continuation, the defect A1.4 later fixed), trace probe on
(trace-count=58927). Emission modules.vLhp7r matches the run's per-module source= hashes.

## Decoding anchors (all three were missing before)
1. EE offset: site/caller-lr are host addresses truncated to 32 bits, so ee = v - (arena &
   0xffffffff); target is already a GOAL function value.
2. The ASLR slide is in no artifact, but the fault log's own host-frame lines over nm give it per run.
3. Text ranges: a module runs from _ottsel_module_<name>_s0_code to s2_code + seg2_text, and nm with
   the slide and the arena turn that into EE; the .json supplies spans and entries, the binary's own
   s0/s2 difference cross-checks them, and modules the run never entered still get ranges.

## Entry validity = the runtime's own predicate
A target is an entry iff the word before it is the function type (0x1bfec4) - exactly what
validate_module checks against each immutable_function_tag slot. The signed export banks are code
too: 279 64-byte stubs, each .long 0x001bfec4 plus a bridge through _ottsel_export_bank_targets, so
bank_begin + 64k + 4 is an entry (the bank carries no names; stub index follows the generator's
kind order arg177/process3/stack4/mips2c93/nothing1/zero1).

## Result: 40/40 entries are plausible
All 40 site values land in signed module text. All 40 target values are real entries: 28 module
functions (gkernel, main, math, text, gstring, progress, hint-control, depth-cue, font) and 12
calls into export-bank stubs 61/163/277. All 22 non-zero caller-lr values land in signed module
text - no EE-valued caller-LR exists in this ring.
The 17 remaining entries are caller-lr=0, all from call sites inside main+0xeb44..main+0x12774 plus
one in drawable. Export stubs reach GOAL with br and push the return slot on the stack, so X30 is
not a return address in those frames: the recorder's LR field is uninformative there rather than
evidence of state corruption.

The earlier board note read a ring from a different build (guard-off objects): its
main+0x14e50 -> gkernel+0x43f4 is, against that build's own tables, a tag at 0x43f0 - also a real
entry. The "target that is not a module entry" lead came from pairing offsets with the wrong
emission.

## What the same run did show
337 of 348 modules ENTERed (all but village_obs, fishermans_boat, village1_part, village1_part2,
sequence_a_village1), so this configuration now runs past the DGO-completion class the A1.3 board
stopped at, and faults later, in font seg0 +0x6864 - the last store of draw-string, a 4-byte store
through a null pointer so the address is EE 4. Corrected by A1.5
(evidence/A1/a11-font-null-dma-buffer-2026-09-22.md): a null font DMA buffer, not the A1.2/A1.3
Symbol-address class.

## Handoff
scripts/a11-goal-ring-audit.py (--binary, --modules, --runtime-log, --fault-log, --tail) resolves every
site/target/caller-lr to module+offset and flags SITE-OFF-CODE, TARGET-OFF-CODE, TARGET-MID-FUNCTION,
TARGET-IN-BANK-NOT-A-STUB and LR-*; run it first on every traced run.
## Addendum (A1.6): the whole-ring auditor runs in the app
`src/shell/ios_boot.cpp` classifies all 128 ring entries in the fault handler (`ring-audit v2`, gated
on `idx > 0`, so an untraced product build never prints it): `target[mod-fn=90,bank-fn=38,BAD=0]
caller[host=111,zero=17,BAD=0] pp-nonzero=0`, so 40/40 generalizes to 128/128. The fourth field is
`x20`, the port's GOAL process register (`RegisterInfo::get_process_reg()`), not a pp copy, and it is
0 in every entry. Two runs at different ASLR bases each recorded 58927 calls with an identical tail.
Product restore verified (sibling build + fresh strict run, 2026-09-22): all 518
`out/jak1/obj/*.o` SHA-match the pre-experiment backup, the emitted modules carry 0
`ottsel-goal-call-trace` references, and the rebuilt app reports `trace-count=0` and faults at
`font` seg0 `+0x6864` (signal 10, `fault addr = ee_base + 4`), so the auditor is inert in the
product state.
