# S2.1 BOT11: `(play)` never ran — boot gated on a missing C++ boot step (VERIFIED)

Date: 2026-08-11
Status: VERIFIED MILESTONE (boot advances past text boundary into level-load path)

## Question (from BOT10 handoff)

"determine whether the game process tree is supposed to spawn more processes and
why none have appeared — use a runtime probe (walk the process pool / active-pool
from kernel-dispatcher, or log a new probe at a later dispatch) to name what the
boot is waiting on."

## Probe added (out/jak-project/game/kernel/jak1/kboot.cpp)

At dispatch 100000 and 200000:
- OTTSEL_TREE: walk `*active-pool*` (left-child/right-sibling tree; links are
  PPOINTERs, node = [link]; #f links == s7.offset 0x18fe04) and dump every
  node's name/mask/pid/status/main-thread pc/sp/stack-top/size.  Reads are
  mincore-guarded (the first version faulted at g_ee_main_mem+0x2c by reading
  the PROT_NONE low-EE guard through a #f link).
- OTTSEL_STATE: dump key game-state symbols.

Layout ground truth: runtime field offset = type-system offset - 4 (verified
against the compiled kernel disassembly for process-tree/process/thread).

## Result 1: the process tree is COMPLETE and HEALTHY (premise was wrong)

The BOT10 handoff said "only listener + writer processes exist" (based on a
2-address probe).  The full tree walk shows 13 nodes, 8 processes, identical at
dispatch 100000 and 200000 (fully static):

- active-pool (0x4f44d4)
  - default-pool: time-of-day-proc (pid 2, pc 0x43c4f84)
  - entity-pool: (empty)
  - target-pool: (empty)
  - camera-pool: camera-master (pid 4, pc 0x44bc1f8)
    - camera-slave (pid 9, pc 0x44ec89c), list-keeper (pid 8, pc 0x44bc360)
    - camera-combiner (pid 3, pc 0x44f7904)
  - display-pool: hud-battle-enemy (pid 6, pc 0x475a4f0), subtitle (pid 5,
    pc 0x4860c14 — the "writer")

All status = 0x19d304, sp constant, stack-top/size sane, dispatcher healthy.
The game's link-time process spawns all worked.

## Result 2: the boot was gated on a MISSING C++ BOOT STEP, not a game bug

OTTSEL_STATE at dispatch 100000/200000:
- `*kernel-boot-message* = 0x0`  (native sets it to 'play only if DiskBoot)
- `*dproc* = #f`, `*run* = #f`   (display-loop process never spawned)
- `*master-mode* = 'game` (correct), *game-info*/*level* objects exist

Root cause: on iOS, `DiskBoot = 0` (the shell never calls InitParms), so
kmachine.cpp `InitMachineScheme`'s `if (DiskBoot && MasterUseKernel)` block —
which calls `call_goal_function_by_name("play")` — never ran.  The shell linked
GAME.CGO itself but never invoked `(play)`, so `(on)` never spawned the display
process.  The boot parked with a complete but idle tree.

## Fix (src/shell/ios_boot.cpp)

After `ottsel_ios_link_cgo_from_bundle("GAME.CGO")`, mirror the native boot
step:

```cpp
jak1::intern_from_c("*kernel-boot-message*")->value =
    jak1::intern_from_c("play").offset;
lg::info("OTTSEL_IOS: calling play (BOT11)");
jak1::call_goal_function_by_name("play");
```

## Verified result (one boot, one Simulator, Windowed)

- `(play :use-vis :init-game ) has been called!` and
  `*kernel-boot-message*: play` appear in the log — the game's play entry ran.
- The boot then advances to the level-load path: `(play)` →
  `(alloc-levels!)` → `(load-package "art" global)` → `BeginLoadingDGO` →
  `load_and_link_dgo_from_c("art")` blocks in `while (!lastObjectLoaded)`
  waiting for the IOP (channel-1 DGO loader RPC) — no ISO data.
- No fault, no spin print, but 100% CPU in the C++ wait loop.

## Honest boundary

The `(play)` fix is VERIFIED PROGRESS, not S2.1 PASS:
- PROVEN: the boot advances past the text boundary into the game's level-load
  path; boot-message is consumed correctly; the process tree is complete.
- OPEN: `(play)` blocks on `load-package "art"` (no ISO data).  The display
  process `(on)` spawns only after the level load.  Next decision: how the
  ROM-safe no-data boot should handle `load-package "art"` (fail cleanly /
  skip level load / provide a data-less ART) so the renderer path can start.

Evidence: docs/evidence/S2/s21-bot11-play-levelload-runtime.log (235 KB),
s21-bot11-play-levelload-fault.log (empty), this file.
