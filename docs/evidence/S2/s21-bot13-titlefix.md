# S2.1 BOT13: title-state symbol fix -- stable title boot, zero faults

Date: 2026-08-15.  Status: VERIFIED MILESTONE.  The previous deterministic
blocker (`enter-state` calls `(go target-title)` with the state value 0, then
`blr` to EE+0) is FIXED and the boot now reaches the title screen state
machine with the full game process tree, zero faults, and a live dispatcher.

## Root cause (evidence chain)

The BOT12 analysis blamed a "state-symbol mislink" (`intern_from_c
("target-continue") -> 0x19810c, value 0x42b4000` via lldb).  In-process
probes (bundle logs, one Simulator, Windowed) disproved that and pinned the
real cause:

1. All target state symbols are CORRECT: `target-continue` -> 0x19818c ->
   value 0x4624074, single entries, no duplicates, verified right up to the
   fault (the BOT12 lldb read was stale/misleading).
2. The fault is `enter-state` (gstate main 0x3eec000, function at +0x2d4,
   symbol value confirmed 0x3eec2d4) executing the state-change path for the
   TARGET process (pid 12, `pp=0x1f6424`): `(set! pp->state pp->next-state)`
   with next-state = 0.  The go-hook `(set! pp->next-state state)` had stored
   0 because the second `go` in target-continue's `:code`
   (`(go target-title)`, target-death.gc:148) read the `target-title` symbol
   whose value was 0.
3. `target-title` is defined in `levels/title/title-obs.gc` -- an object of
   the title level DGO (TIT.DGO), NOT GAME.CGO.  The port served the raw ISO
   TIT.DGO, whose GOAL objects use the PS2 v3 format (first word 0x0, e.g.
   `title-obs` tag=0x0), and the DGO loader's skip test
   (`tag == 0xffffffff`) classified them as "non-GOAL" and skipped them.
   GAME.CGO does not contain title-obs (upstream packs it in tit.gd), so
   `target-title` was never defined and its symbol value stayed 0.
4. `enter-state` then read the state's handler fields from EE+0 (the zeroed
   low-EE guard): `[0+0x18]` (enter) = 0 != #f, so it called the "enter"
   function value 0 + off -> `blr` to 0x7000000000 (SIGBUS).

## Fix (smallest falsifiable, runtime-side; no game source patched)

1. `scripts/build-ios.sh`: ship the RECOMPILED TIT.DGO
   (`out/jak1/iso/TIT.DGO`, built by goalc from `dgos/tit.gd`) instead of the
   raw ISO one.  The recompiled static-screen.o/title-obs.o use the no-emit
   v3 "GOAL"-magic format the runtime already links.
2. `game/sce/sif_ee.cpp`: the DGO serve skip test now accepts BOTH linkable
   block kinds -- v2/v4 type tag -1 (tpage/logo/title-vis records) AND the
   no-emit v3 "GOAL" magic (0x4c414f47, recompiled objects); raw data records
   (e.g. `texture-upload`) are still skipped.
3. `game/kernel/jak1/klink.cpp` `link_begin`: complete the link
   synchronously (loop `jak1_work` until done, then `jak1_finish`), matching
   the game's first ("linking finished (that was fast)") branch.  The
   goal-side multi-frame resume path (level `linking` flag + `link-resume`)
   never fires for the v3 DGO objects on this port (zero `link-resume` calls
   observed for any object), so the v3 objects were left half-linked
   (top-level never ran -> target-title 0).  The v2/v4 path already finished
   in the single work call.
4. Recompile title objects: `goalc --isa arm64 -c '(load-project
   "goal_src/jak1/game.gp") (make "out/jak1/iso/TIT.DGO")'` (produces
   static-screen.o + title-obs.o in the no-emit v3 format).

## Verified (one boot, one Simulator, Windowed)

- `ottsel-fault.log` = 0 bytes (no fault).
- `link finish: static-screen` / `link finish: title-obs` -- the v3 DGO
  objects complete their link and their top-levels run.
- Title-obs main seg placed at 0x4924000 (code 0xc000); the target process's
  pc at dispatch 100000 = 0x492a9fc (inside title-obs code) -- the target is
  executing the title state machine.
- `GAMEPLAY: enter title` prints twice; the boot then requests the village1
  level (`Adding level village1`, `begin load village1-vis [vi1.DGO]`), which
  is NOT in the bundle -- the ROM-safe boundary the game tolerates.
- Full process tree at dispatch 100000 (24 nodes): target (pid 12), sidekick,
  HUD processes, camera-master/slave/list-keeper/combiner, display (pid 8),
  subtitle (pid 5, parked at its text-load boundary), time-of-day, etc.
- GOAL kernel dispatcher stable past 121,000 iterations; the only repeated
  activity is the STR subtitle/text RPC emulation returning the ROM-safe
  no-data response (the game handles it and continues).

## Honest boundaries / open items

- The repeated STR RPC calls (155k over the run) are the missing-text
  no-data boundary; the game continues, but this is not a full level load.
- The game's goal-side multi-frame linker path (`linking` flag + resume) is
  unused; links complete synchronously.  Root-causing why the goal-side flag
  never fires is deferred (it is not needed while all links complete in
  `link_begin`).
- The renderer (Metal) still presents the shell log surface; the first real
  Jak frame (S2.2) is the next gate.

Evidence: `s21-bot13-titlefix-clean-runtime.log` (head/tail sample; the full
46 MB log is in the app container), `s21-bot13-titlefix-clean-fault.log` (0
bytes), `s21-bot13-titlefix-metal.png` (Metal surface presenting).
