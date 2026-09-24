# macOS/iOS parity review and the host-lane link repair - 2026-09-22

Gate: opening review for the parity loop (L0-L6 in `docs/RECOVERY_GOAL_LOOP.md`).  The strict signed-GAME
crash class is closed; this gate establishes the macOS oracle and measures what the iPad lane still gets
wrong: it does not load the way macOS does and it does not run at speed.

Question 1: is the macOS reference lane (`out/jak-project/build/h1/game/gk`, M0) healthy and rebuildable
from the current source?

Answer: no, on both counts - and the reason was concrete.
- The checked-in binary was stale (Aug 23, pre-A1.7b) and `ninja -C out/jak-project/build/h1 gk` failed to
  link: the ARM64 trampolines in `game/kernel/asm_funcs_arm64.s` write eight `ottsel_cbridge_*`
  diagnostics that only the iOS product shell (`src/shell/ios_boot.cpp`) and the assembly-only test
  harness defined -> `Undefined symbols: _arg_call_arm64 ...`.  The reference lane could not be built
  from source at all.
- Fixed (A1.15): the inner runtime now defines the eight counters for every non-iOS build
  (`game/kernel/jak1/kscheme.cpp`, `#ifndef OTTSEL_IOS`, so the iOS app keeps the shell copy and no
  symbol is duplicated).  Overlay `patches/a11-host-cbridge-counters.patch`, guard
  `scripts/verify-host-cbridge-counters.py` (definitions, every assembly reference, iOS shell copy,
  overlay reverse-apply).  `ninja -C build/h1 gk` links again (binary 2026-09-22 10:04).

Question 2: does the rebuilt macOS lane boot the game?

Answer: no.  Run `OTTSEL_ENABLE_KEYBOARD=1 ./build/h1/game/gk -v --game jak1 -- -boot -fakeiso` (cwd
`out/jak-project`, the documented macOS reference invocation) boots the kernel, links 216 top-levels
(`OTTSEL link: executing top-level of ...`, last `time-of-day`), then:
- `OTTSEL CRASH: sig=11 pc=0x7003ed6d54 lr=0x70043cd51c sp=0x7007fffe50 base=0x7000000000
  si_addr=0x710252d5a0`, with `x9=0x7008000000`, `x10=0x7008c30000` (the `IR_AsmRet` guard's module
  window), `x17=0x7003ed79b4` (the guard slot, an EE value outside the window) and `x16=0x710252d5a4`
  (the fallback): the guard rejected the slot and jumped through a host address outside the window.
- The same crash block is present in the Aug 23 binary, so it predates A1.13/A1.14 and is not a
  regression from this round.  After it, only the audio thread keeps logging: the lane stalls before the
  title screen.  So the oracle is currently broken, not merely slow - L1 is now the next item.

Question 3: how fast is the iPad lane, and where does its frame time go?

Answer: 9 fps, dominated by the present path and the fixed frame budget.
- Cadence: the game's own `vsync` counter advanced 48601 -> 48781 = 180 frames in 20 s of wall time
  (measured live on the running app).  The app is otherwise healthy: 0-byte `ottsel-fault.log`,
  `scene-level='village1'`, ~92% of one core busy (`ps -p <pid> -o %cpu`), title screen rendering.
- `sample <pid> 3` on the main thread: 1562 samples, 639 in `SDL_main` -> `ottosel_metal_present`
  (`presentRGBA:` -> `MTLSimTexture replaceRegion` -> `MTLSimDriver` -> `xpc_connection_send_message_with_
  reply_sync` / `mach_msg2_trap`, 294 of them, plus `_platform_memmove`) and 468 in
  `SDL_SYS_DelayNS` (the loop's 60 Hz budget cap in `src/shell/main.cpp`).  The rest is game/renderer
  work.  A full drawable-sized RGBA frame is uploaded on every present and the Simulator serializes that
  range over XPC, which is the single biggest lever.

Comparison to carry into the loop: the macOS lane draws the world with the upstream GPU renderer (OpenGL)
and presents through the window system, while the iPad lane draws through the shell's own Metal path and
then uploads a whole CPU RGBA frame per present.  Parity therefore has to be measured (same route, same
frame, same counters) before it can be claimed, and the L0 harness has to give both lanes a frames/s
number from their own logs - the iPad side already has `OTTSEL SUBMITSTAT ... vsync=`; the host side has
no bounded frame heartbeat yet and needs one.

Not claimed: no playability, audio or lifecycle claim; the iPad cadence is measured, not fixed; the
macOS lane is not restored.  Next: L1 (why the host `IR_AsmRet` fallback during boot differs from the
iPad lane on the same emitted objects), then L2 (clock/loading contract) and L3 (present path).
