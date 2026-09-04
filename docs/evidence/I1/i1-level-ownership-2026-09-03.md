# I1 level ownership — 2026-09-03

Status: OPEN. The packet-level ownership change is visible in runtime logs,
but the route still does not produce playable Village1.

Regression-first:

- Existing `MobileSceneSnapshotStaysStableAcrossCameraMotion` passed and covers
  the required distinction between camera motion and level changes.
- The production change removes eager `build_mobile_tie_mesh` from level load,
  clears the active snapshot on a packet-level change, and rebuilds from the
  packet's level.

Verification:

- Signed app: `out/jak-project/out/ios/app/OttselShell.app`.
- Fresh iPad Pro 11-inch (M4) Simulator frame: `/tmp/ottsel-level-ownership.png`.
- Runtime logged `packet-level owner='title'`, then later
  `packet-level owner='village1'`; this falsifies the prior last-loaded-level
  latch.
- The frame remained in a malformed debug-font/title state; Jak was not
  visible or controllable. Playability remains OPEN.
- `VU1STAT`: chain 810 at 15:11 to 900 at 15:21, approximately 0.15 chain/s,
  below the required 30/s gate. `pcm-peak=0`; fault log 0 bytes.
- The no-MERC/no-TIE controls were armed for the fresh run. Container size was
  1,627,952 KiB at launch baseline; no growth was observed during the first
  25-second capture window.

Follow-up with the ownership-only build: the focused packet-owner regression
passed, but the live scripted route did not reach Village1. The app entered a
gated SIGSEGV at `enter-state pp=x20=0`, fault address `0x140`, and was held for
LLDB. The retained `ottsel-fault.log` measured 40 KiB, so this run fails the
fault-free bar and cannot validate the renderer change. The exact app process
was terminated after capture; no claim is made that the ownership edit caused
this pre-Village1 linker/GOAL fault.

Next: root-cause and regress this existing title `enter-state` fault before
repeating the ownership runtime experiment; then obtain matched Village1
no-MERC/no-TIE frames.
