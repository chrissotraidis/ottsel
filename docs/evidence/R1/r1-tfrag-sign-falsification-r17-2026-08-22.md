# R1 TFRAG sign falsification R17 — 2026-08-22

## Hypothesis

The current Jak 1 TFRAG upload might share the validated TIE source-side
camera sign, with only material/depth state differing.

## Build/runtime proof

- `scripts/build-ios.sh`: passed for the sign experiment.
- `codesign --verify --deep --strict`: passed.
- One booted iPad Pro 11-inch (M4) Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`.
- One `com.ottsel.shell` runtime; no second Simulator or macOS runtime.

## Fresh visual/runtime evidence

- [direct Simulator regression frame](artifacts-2026-08-22-ipad-r1-tfrag-sign-falsification-r17/fresh-direct-simulator-regression.jpeg)
- [simctl regression screenshot](artifacts-2026-08-22-ipad-r1-tfrag-sign-falsification-r17/fresh-simctl-regression.png)
- [runtime log](artifacts-2026-08-22-ipad-r1-tfrag-sign-falsification-r17/ottsel-runtime.log)

After a native W key event hid the touch overlay, the live Simulator frame
showed an almost entirely black game surface with one stretched geometry strip.
The runtime continued producing TFRAG visibility and Sprite frames and mixed
audio frames, so counters/log activity did not constitute visual or
playability proof. This falsifies applying the TIE camera sign to TFRAG as a
shared projection fix.

## Decision

Only the latest TFRAG `camera_sign=-1` source change was reverted. The TIE-only
correction remains the bounded baseline. R1 remains open; continue with the
TFRAG material/depth/composition contract without remapping TBP or lookup.

The restored signed baseline was rebuilt, reinstalled, and actively inspected
on the same Simulator. After W, the frame again showed recognizable Village1
geometry, but with severe dislocation/black regions and therefore still failed
playability. A fresh video attempt was made and remained blocked by the host
`Resource busy` / `Host recording is already in progress` condition; fresh
Simulator screenshots were captured instead.
