# BOT31 Handoff — M1: village1 RENDERS (user-verified); color + input are the wall

Date: 2026-08-17.  From: BOT30 (32 boot cycles, six ARM64 root causes).
Read this + docs/evidence/M1/m1-collide-list-overflow.md (the full evidence
chain) + docs/STATUS.md.  Prior handoff docs/BOT9_HANDOFF.md is now
historical.

## Hard-won honesty rule (read first)

BOT30 claimed "playable" off CPU telemetry and was wrong — the screen was
black.  The user's screenshots are the ONLY accepted proof of visual
state.  Never claim visual progress from logs alone.  Screen capture from
the agent shell currently fails (`screencapture` -> "could not create
image from display"); the user has been asked to grant Screen Recording to
the agent's host app.  Until that works, ask the user for screenshots.

## Where the game ACTUALLY is (user-screenshot-verified, 2026-08-17)

`cd out/jak-project && ./build/h1/game/gk -v --game jak1 -- -boot -fakeiso`
- Boots to title; attract STR demos stream through the real overlord
  (LOLOOP/ASIBESWI/LOI2.STR chunk loads); VIS loads via RAMDISK
  ("Swapping in vi1 VIS", 617696 bytes).  VIS/STR "wiring" needed nothing —
  it was blocked by codegen bugs.
- `touch /tmp/ottsel-bg-village1` after "GAMEPLAY: enter title" -> Jak
  spawns in village1; 5-minute soak PASS (zero crashes, zero collide
  overflows).
- **USER-VERIFIED RENDER**: village1 geometry draws with correct
  perspective and real textures (huts, palms, sea, horizon).  Two visible
  defects remain:
  1. **Everything is tinted deep blue** (time-of-day / color-palette path).
  2. **"Stuck": no response to input** — the scene sits at the spawn camera.

## The six ARM64 root causes fixed by BOT30 (all pinned by A1.0 tests 24-28)

| # | Bug | Fix location |
|---|-----|--------------|
| 1 | `add_vf` emitted integer ADD .4S, not FADD .4S | goalc/emitter/IGenARM64.cpp |
| 2 | `f32_to_int32`/`int32_to_f32` read `Rn(dst)` not `Rn(src)` | IGenARM64.cpp |
| 3 | ADRP static-ref patchers wrote raw lo12 into SCALED LDR imm12 (rip float/vector constants read zeros; sin/cos returned 0 -> NaN camera -> collide-list overflow -> the old EE 0x3075274 crash) | ObjectGenerator.cpp `patch_arm64_static_ref` + klink.cpp runtime twin |
| 4 | `load8u/load16u +s32` double-applied field offsets | IGenARM64.cpp |
| 5 | kernel-asm reg map `rbp`->X29 left X26 unsaved across `(suspend)` | goalc/compiler/compilation/Asm.cpp `parse_register` |
| 6 | `pextlw/uw/lh/uh/lb/ub` ported as UZP (deinterleave) instead of ZIP (interleave) — broke `matrix-transpose!` -> garbage camera matrix -> the black screen | IGenARM64.cpp |

Lesson that found all six: when a GOAL subsystem misbehaves, disassemble
the COMPILED function (capstone; code phase from the 0xaeaeaeae fn-tag
offsets in the .o) and compare against the x86 emitter as the reference.

## NEXT STEPS, in order (precise)

### 1. The blue tint (time-of-day / color path)
- Ground truth first: in TFragment.cpp render(), the per-level itimes are
  already captured (`tree.itimes_debug[i] = settings.camera.itimes[i]`).
  Add a 1/s log of `settings.camera.itimes[0..3]` (each a Vector4 of
  int16-packed time-of-day weights).  Sane values: 8 weights summing to
  ~0x40 (64) per component group; garbage/one-hot-night explains the tint.
- Two candidate causes:
  a. LEGITIMATE night palette: the bg-trigger flow may leave the
     time-of-day clock uninitialized (mood defaults to night).  Check by
     also logging `(-> *time-of-day-context* ...)`-adjacent state, or
     simply compare the UNTRIGGERED title screen's tint (the attract
     demos should be daylight; the user's title screenshot was also
     blue-ish -> likely NOT just the clock).
  b. GOAL mood/itimes math still broken: mood.gc / time-of-day.gc use
     int16 packed ops; audit remaining parallel-op emitters the same way
     as bug #6 (candidates: `pinteh/ppacb/psllh/psrlh`-family, `pmulth`,
     any op with an x86 punpck/pack reference).  Diff EVERY ARM64
     parallel-op emitter against IGenX86.cpp semantics — bug #6 showed
     whole families can be wrong.
- The fix workflow is mechanical: fix emitter -> A1.0 test -> ninja goalc
  gk -> `rm out/jak1/obj/*.o` -> `(mi)` (MUST be `(mi)`; kernel+GAME alone
  leaves TIT/VI1 DGO code stale) -> boot -> user screenshot.

### 2. Input ("stuck")
- The pad PATH works: `touch /tmp/ottsel-press-start` (START) and
  `echo <hex> > /tmp/ottsel-press-button` (e.g. 4000 = X) inject buttons
  and the game consumes them (verified in logs).
- Physical keyboard: needs the gk window FOCUSED; check upstream OpenGOAL
  jak1 default keybinds (game/system/hid) actually map on this build —
  the display/input manager was untouched by ottsel patches, so if focused
  keys do nothing, probe `game/system/hid` event flow with a keypress log.
- Also verify the target actually accepts control in the bg-trigger flow
  (it may be in a wait state): send `echo 40 > /tmp/ottsel-press-button`
  (down) etc. and watch `*target*` trans in a CAMWATCH-style probe.

### 3. Retail flow blocker: auto-save NULL spawn
- After START + X (new game) the auto-save process spawn jumps to NULL
  (sig=11 pc=0 lr=0; proc type 'auto-save'; mc-* exports ARE registered
  at kscheme.cpp:2135).  Repro is title-menu-timing sensitive; the direct
  path is `(auto-save-command 'auto-save 0 0 *default-pool*)` from
  game-save.gc.  Next probe: dump the `auto-save` type's method table and
  `auto-save-init-by-other`'s symbol value at spawn time (crash dump
  already prints a symbol table for NULL-pc cases — see runtime.cpp).
- Beware: `process-spawn ... :stack *kernel-dram-stack*` — a special
  stack; if other :stack spawns work, compare.

### 4. After both visual defects fall
- 5-min soak + user screenshot + keyboard control = the real M1 gate.
- Then remove ALL debug probes (inventory below), regenerate
  patches/h3-jak1-host-boot.patch, update STATUS.md gate board.

## Probe/instrumentation inventory (in the fork tree; remove before M1 close)

- game/runtime.cpp: SIGILL hook + genuine-fault crash dump (registers,
  code around lr, engine lists, cspace walk, symbol-area register names,
  NULL-pc symbol dump, GOAL-stack backtrace).
- game/sce/libpad.cpp: bg-village1 driver (BOT26), ARTC dump (BOT25),
  ENG/TYPEWATCH/CAMWATCH periodic dumps, cull-test one-shot + in-vivo
  cull/trig/false-func audits, synthetic START/button injection (BOT30).
- game/mips2c/jak1_functions/collide_cache.cpp: collide-list overflow log
  + query/items dumps.
- game/graphics/opengl_renderer/background/TFragment.cpp: TFR3 level/tris
  logs (BOT27) + CAMMTX camera-packet dump (BOT30).
- game/kernel/jak1/klink.cpp: CODEMAP per-object code-region map log.

## Build/debug discipline (violations cost cycles this session)

- goalc changed? -> `ninja -C build/h1 goalc gk ottsel-a1-sem`, run
  `./build/h1/goalc/ottsel-a1-sem` (28 tests must PASS), then
  `rm out/jak1/obj/*.o` and `goalc --isa arm64 -c '(load-project
  "goal_src/jak1/game.gp") (mi)'` — 546 targets, ~10 s.  Verify the fix
  landed by scanning the .o/CGO bytes for the expected encoding.
- cwd traps: gk runs from out/jak-project; ottsel repo is two levels up;
  shell cwd persists across commands — `cd` explicitly every time.
- `pkill -f game/gk` before rebuilds.  One fix per boot cycle.  lldb
  attach to a LIVE gk works fine (healer needs
  `settings set platform.plugin.darwin.ignored-exceptions EXC_BAD_ACCESS`
  only when running UNDER lldb from launch).
- Patch regen: from out/jak-project: `git add -A && git diff --cached
  641fb572 > ../../patches/h3-jak1-host-boot.patch && git reset` — NEVER
  commit in the fork; commit/push only in ottsel (origin main).
- Offline disasm: capstone; find the code phase via `data.find(b'\xae'*4) % 4`;
  v3 header: 16B preamble + link_infos[3] + code_infos[3] + code_size[3] +
  link_block_length; segment data starts at file offset link_block_length.

## Commits this session (ottsel repo)

4dbb4a9 (fixes 1-3), 190a825 (fixes 4-5 + soak), e430896 (retail
VIS/STR verified + auto-save blocker), 892df18 (probe tidy), 908de8f
(fix 6, camera matrix sane).

## Addendum (BOT30 late, same session)

- **Input CONFIRMED at game level**: the JAKPOS probe shows Jak's root
  trans moving ~500 units after a synthetic X injection — the game is
  controllable via the pad path.  "Stuck" is keyboard mapping/focus only.
- **Blue tint: likely the midnight palette, not broken math** — itimes
  are well-formed packed halfword weights summing to 64 (e.g.
  0x3A003A + 0x060006).  New driver: `echo 9.0 > /tmp/ottsel-set-tod`
  calls (set-time-of-day 9.0); after the call the weights shift palette
  slots.  Awaiting the user's visual verdict; if daylight looks right,
  bake set-time-of-day into the bg driver and close the tint item.
- New probes: OTTSEL JAKPOS (target root trans, libpad), OTTSEL ITIMES
  (tod weights, TFragment), /tmp/ottsel-set-tod driver.
- **cwd hazard (cost a cleanup this session)**: shell cwd persists across
  commands; a doc append + commit intended for ottsel ran in the fork and
  a soft-reset intended for the fork ran in ottsel.  ALWAYS `cd` with an
  absolute path in the same command as any git operation, and never rely
  on inherited cwd.  (Both repos were restored; the fork push failed
  safely because its remote is upstream with no matching branch.)

## Addendum 2 — NULL-spawn refinement (autonomous tick, 2026-08-17 ~06:20)

The village1 daylight session ran 1h+ (Jak moved ~19k units from spawn —
possibly user-driven) then died on the SAME NULL call (sig=11 pc=0 lr=0).
New facts from the NULL-pc symbol dump:
- `auto-save-init-by-other` = 0x4335fa4 (valid), `set-to-run` = 0x3ed7a34
  (valid), `mc-run` valid.
- `*kernel-dram-stack*` and `run-now-in-process` symbol values are 0 —
  RED HERRINGS: both are macros/defconstants (gkernel.gc:113,
  gstate.gc:72), not runtime symbols.
- The crash is reachable from ambient gameplay (no menu needed) — some
  process-spawn during play (othercam? ambient?) hits it after long
  uptime.
NEXT PROBE for this item: instrument `run-function-in-process` /
`set-to-run` (gkernel.gc kernel asm — same rlet family as the fixed
rbp/X26 bug) — disassemble the compiled fns from gkernel.o and audit the
stack-switch + call sequence for another ARM64 mapping/protocol fault;
also log the spawn args (proc, fn, stack) C-side right before the jump.
