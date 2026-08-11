# S2.2 BOT12: title screen state-entry fault -- state symbol mislink diagnosis

Date: 2026-08-11.  Status: DIAGNOSED (not fixed).  The boot reaches
"GAMEPLAY: enter title"; the target's first state (`(go target-continue ...)`
at the end of init-target) faults in `enter-state` (gstate.o, pc 0x3eec874
`blr` to EE+0) because the state symbol value is garbage.

## Verified facts (all from the live app, one Simulator, Windowed)

1. `intern_from_c("target-continue")` -> a symbol whose value is
   **0x42b4000** = object 178 (shrub-work) main seg + 0x4000 -- a zeroed
   region, not a state.  The three target-death states live in target-death's
   static data and two of them have correct symbol values:
   - 0x4624074 (no trans, post/event = target handlers) and
   - 0x46252d4 (name sym 0x19cf74) -- both values correct.
2. The no-emit linker's cross-segment ADRP+ADD static patch is CORRECT: a new
   `OTTSEL LINKSTAT` diagnostic in `cross_seg_dist_link_v3` showed
   target-death's top-level state/static references resolve exactly
   (e.g. tgt_off 0x14074 -> 0x4624074, page_delta 2932 = 0xB74, correct
   lo12).
3. A new `OTTSEL TOPDUMP` diagnostic captured target-death's PATCHED
   top-level code (base 0x3ab0000, first 0x600 bytes).  It shows the state
   field writes and the symbol-set sequence: each `(set! state-sym state)`
   loads the state's static address, then loads `(sym - s7)` from a slot in
   the TOP-LEVEL segment's static data (`adrp x16, 0x4000; add x16,#off;
   ldrsw; add s7; add EE; str`) and stores the state address at EE+sym.
4. **The `(sym - s7)` slots live in the TRANSIENT top-level segment
   (0x3ab0000..0x3ab4068), which every subsequent object's top-level
   overwrites.**  The slot for `target-continue` is at 0x3ab4014.  The slots
   are written by `symlink_v3` at link time and read during the object's own
   top-level (immediately after), so they should be correct at that moment --
   yet the resulting symbol value is garbage.

## Interpretation

The state objects are correctly linked and the ADRP+ADD patches are correct;
the failure is in the symbol-value write/read path.  Two concrete next
probes, in order:

1. Identify the exact symbols at the intern-table entries near 0x19810C /
   0x19818C (the state at 0x4624074 carries name sym 0x19818c; the value at
   0x19818c IS 0x4624074, so one of the state symbols is at the "wrong"
   table offset -- or the intern table shifted between the C-side intern
   calls and the goal-side symbol references).  Decode the slot contents:
   at 0x3ab4000..0x3ab4068 (top static) the (sym - s7) values should be
   verifiable against the intern table.  A mismatch here is a
   symbol-hash/intern issue (the init_crc fix covered `_empty_` but the hash
   may still collide for some names).
2. If the intern table is consistent, trace the symbol-set store: the slot
   read at 0x3ab4014 must equal (target-continue_sym - s7) at the moment
   target-death's top-level runs.  Capture the slot bytes with a klink
   diagnostic right before `call_goal_on_stack` for target-death.

## Diagnostics left in the worktree (temporary, remove after the fix)

- `game/kernel/jak1/klink.cpp`: `OTTSEL LINKSTAT` (cross-seg ADRP+ADD patch
  values for target=MAIN, tgt_off >= 0x10000) and `OTTSEL TOPDUMP` /
  `OTTSEL TOPW` (patched top-level words for target-death, first 0x600
  bytes).
- Evidence logs: `s21-bot12-topdump-runtime.log` (3.2 MB -- includes all
  LINKSTAT + the TOPDUMP), `s21-bot12-target-death-topw.txt` (the patched
  top-level words).

## Boot status recap

Fixed this loop: low-EE PROT_NONE -> PROT_READ (PS2 memory semantics),
`msub_gpr32` MADD->MSUB (mod), `min_vf`/`max_vf` FAMINMAX->FMIN/FMAX (M4
SIGILL).  The boot now reaches the title screen state; the remaining fault
is the state-symbol mislink above.
