# H3 evidence — GOAL kernel dispatcher loop reached (2026-08-08)

## Result

The ARM64 no-emit runtime now boots the real Jak 1 kernel far enough that the
**GOAL kernel dispatcher executes and loops** — the first real GOAL entry
required by Gate H3. The prior blocker (SIGILL on an invalid emitter word)
is resolved.

## Root-cause fix (one line)

`goalc/emitter/IGenARM64.cpp`, `load32u_gpr64_gpr64_plus_gpr64`:

- Before: `Base(0b1011100001100000000010, 22)` → emitted `0xb8760801`
  (invalid: missing option/extend bits 13:10).
- After: `Base(0b1011100001100000111010, 22)` → emits `0xb876ea01`
  (`ldr w1,[x16,x22,sxtx]`), verified against `as -arch arm64` output via
  capstone.

The crash PC `0x70001a4998` (word `0xb8760801`) was inside
`execute-process-tree` in gkernel main-segment code.

## Verified boot sequence (lldb, `process launch -- -fakeiso -boot -v -- -nosound`)

- All 8 KERNEL.CGO objects link; each top-level runs and returns under RX.
- `Got correct kernel version 2.0, loaded in 13–48 ms`.
- `kernel: machine started`.
- Stub arenas A+B flipped RX (W^X preserved; no RWX, no runtime emission).
- `KernelCheckAndDispatch` calls GOAL `kernel-dispatcher`
  (fptr=`0x70001a5384`, inside gkernel main-segment RX code
  `0x1a0000..0x1a8000`).
- Dispatcher executes and returns cleanly, repeatedly — observed for minutes
  with zero faults (PTY-visible `call_goal_on_stack: returned 1375532` =
  `0x14fd2c`, the idle-tree walk result).
- Run ends with graceful window-close EXIT (SDL quit → `MasterExit = EXIT`,
  code 2), not a crash.

## Logs

- `boot-dispatcher-loop-2026-08-08.log` — captured stdout to the window-close
  shutdown (the per-dispatch lines go to stderr, so they appear in the PTY
  transcript, not this file; both runs confirmed them).
- `boot-to-goal-entry-adrp-add.log` — prior run showing the SIGILL state
  before the load32u fix.

## Caveats / honest boundaries

- The dispatcher returns a constant `0x14fd2c` per iteration: the process
  pool is idle (no listener/GAME.CGO in the no-emit boot), so no game
  processes are created yet. That is expected for H3 (kernel dispatcher
  running = GOAL entry proven); driving processes is S1+ work.
- The two evidence runs opened the game window in **Borderless (mode 2)**,
  which the operator flagged as fullscreen. Fixed: user settings
  `display-settings.json` now `display_mode: 0` (Windowed), and the source
  default in `game/settings/settings.h` is now `Windowed` (rebuild gk for it
  to take effect; the settings-file fix is immediate).
- One `gk` instance at a time, always.
