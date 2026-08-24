# Mobile Simulator bootstrap — 2026-08-24

## Scope

This is a bootstrap/render gate for the current no-emit iOS target. It is not
an honest playability or release claim.

## Reproducible build

```text
scripts/build-ios.sh
```

The script builds SDL3, zstd, the no-emit runtime, the signed A1.1 slice, and
`out/jak-project/out/ios/app/OttselShell.app`. It now builds the
`ottsel-a11-slice` prerequisite before invoking it, avoiding a stale checkout
failure when the configured executable has not yet been produced.

## Fresh runtime evidence

- iPad Pro 11-inch (M4), iOS 26.5 Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`: installed, launched, rendered live
  Metal frames, and remained running after a 10-second observation.
- iPhone 17 Pro, iOS 26.5 Simulator,
  `7B639924-AD8F-4D5C-AD29-71F47C768A0D`: installed, launched, rendered live
  Metal frames, and remained running after a 10-second observation.
- Fresh screenshots: `/tmp/ottsel-mobile-evidence-20260824/ipad-boot.png` and
  `/tmp/ottsel-mobile-evidence-20260824/iphone-boot.png`.
- App validation: `codesign --verify --deep --strict` passed.

## Open gate

The iPad screenshot is visibly rotated/laid out incorrectly and the current
route has not yet demonstrated coherent gameplay controls, lifecycle recovery,
or audio acceptance on mobile. Keep mobile status at bootstrap/render only;
next work is orientation/viewport correction followed by input, lifecycle,
and audio tests on one device at a time.
