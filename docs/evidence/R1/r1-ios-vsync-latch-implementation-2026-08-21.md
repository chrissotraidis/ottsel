# R1 iOS VSYNC presentation latch — 2026-08-21

## Scope

The earlier sync correction delegated iOS `sceGsSyncV` to the Metal renderer,
but `gfx_vsync()` still returned immediately. macOS waits for the graphics
loop's next frame. This slice adds a presentation epoch/condition-variable
latch: the game thread waits for the shell's next frame signal, and shutdown
wakes all waiters before joining the boot thread.

Changed files:

- `src/shell/metal_gfx.mm`
- `src/shell/metal_shell.h`
- `src/shell/main.cpp`

## Proof so far

- `scripts/build-ios.sh`: passed.
- Strict deep codesign: passed.
- Signed executable SHA-256:
  `a3af1793efce65018e3829358bb49740e0805388079485167aa07bf39823da69`.
- `git diff --check` passed for the changed shell/source files.

## Live proof

A longer fresh iPad Pro 11-inch (M4) Simulator launch reached the delegated
VSYNC path. Calls 1 and 8 were logged at `51:12`; call 60 was logged at
`51:13`, all with `renderer-delegated=true`. The game thread therefore
progressed through repeated waits/wake-ups on the presentation cadence rather
than remaining in the old immediate-return path. The runtime was terminated
and the Simulator shut down cleanly; `ottsel-fault.log` was 0 bytes.

This proves the latch's bounded wake-up and shutdown behavior. It does not
prove Sprite3 phase parity, visual output, audio, or playability.

## Next experiment

Run one fresh valid route after the latch and capture the same-transition
Sprite3 aggregate. If backgrounding or interruption exposes a waiter issue,
fix only that lifecycle seam before interpreting phase data.
