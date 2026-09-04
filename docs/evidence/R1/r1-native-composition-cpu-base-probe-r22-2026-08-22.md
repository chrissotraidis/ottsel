# R1 native-composition CPU-base probe — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 native composition after source/resource parity |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618344d9f7c1a531b43b366`; signed Simulator executable `8358376dabdabb56b624c3bc075918fb0c2c958bfd17160a07df150524a027f5` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime PID `78275` |
| Before failure | Normal presentation still draws the CPU `presentRGBA` texture as a full-screen base before native TFRAG/TIE/Sprite3. The clean native scene is incomplete and not playable. |
| Change | Added a one-shot diagnostic trigger `ottsel-trace-metal-scene-no-cpu-frame` that skips only that full-screen CPU base draw. Native scene submissions and depth/material policy were otherwise unchanged. |
| Focused proof | `scripts/build-ios.sh` completed and strict deep codesign passed. |
| Live proof | Fresh validated-pack route via Start → Cross → Down×4 → Cross reached the Village scene. Normal frame: `artifacts-2026-08-22-ipad-live-visual/ipad-native-route-with-cpu-base-110243.jpeg`. Triggered frame: `.../ipad-native-route-no-cpu-base-110304.jpeg`. |
| Fault/audio | `ottsel-fault.log` was 0 bytes. Audio mixed frames but `pcm-peak=0`. |
| Verdict | OPEN — the probe proves the CPU base contributes visible debug/flat content, but native TFRAG/TIE composition remains materially incomplete. This is not playability proof. |
| Next gate | R1 Direct/Sprite/material composition; compare the no-CPU frame against the macOS same-phase frame and isolate the first missing native bucket. |

## Visual result

With the CPU base enabled, the frame contains a washed-out/incomplete scene
with large missing lower regions. With the base disabled, the same live route
shows a more coherent textured Village structure, but still has large black and
missing regions. This separates the CPU fallback artifact from the remaining
native composition defect; it does not justify deleting the base permanently
until title/menu and all required native buckets are composed.

The existing native WASD path remains active and was previously observed to
change the rendered camera on this same Simulator. The host video recorder was
still unavailable (`Host recording is already in progress`); the two fresh
still frames are the authoritative visual artifacts for this probe.

## Native bucket isolation follow-up

The same one-Simulator route also exercised the existing trigger-gated bucket
isolators:

- `ipad-native-no-tie-110457.jpeg`: TIE disabled, with CPU base disabled;
  substantial Village geometry remains, so TFRAG is the dominant scene
  contributor in this view.
- `ipad-native-tie-only-110854.jpeg`: TFRAG disabled, with CPU base disabled;
  the remaining TIE output is visibly stretched/radial rather than a coherent
  scene.
- `ipad-native-no-tie-no-tfrag-110516.jpeg`: both native families disabled;
  the drawable is blank, as expected.

This narrows the next experiment to native TFRAG composition/material/strip
state while retaining TIE as a separate contributor. These are diagnostic
isolations, not accepted gameplay frames.

## Shared camera-equation falsification

The existing reference-projection trigger was wired through Metal and accepted
in a fresh signed build after routing its `camera_sign` into the uniform. The
reference equation produced only the diagnostic blocks/clear surface, while
the restored native derived-pc-camera path again produced malformed geometry.
This falsifies promoting the reference equation as a camera fix. Evidence:
`/tmp/ottsel-video/scene-reference-projection-20260822-1654.png` and
`/tmp/ottsel-video/scene-normal-after-reference-20260822-1655.png`.
The bounded draw-limit=1 frame is coherent partial TFRAG geometry; no-TIE leaves
those fragments, so full-scene accumulation/material coverage remains open.
