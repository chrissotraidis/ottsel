# R1 same-transition route marker — 2026-08-21

## Gate

Compare the first mobile and macOS Sprite3 producer state at the actual shared
Village1 display boundary, rather than matching only a level name.

## Build and identity

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream: `641fb572e876750d8618434d9f7c1a531b43b366`.
- ARM64 GOAL `(mi)`: 546 targets rebuilt successfully in 10.308 seconds.
- iOS build/sign: `scripts/build-ios.sh` passed; app SHA-256
  `ccb4609d3aa361857692215fdae58270435520cfafe46c22c1a6e25b967e193e`;
  strict codesign passed.
- macOS log: `out/jak-project/log/jak1.2026-08-20T20-35-37.log`.
- iPad Pro 11-inch (M4) Simulator, iOS 18.5; app data container UUID
  `39511ED2-4859-4EEA-AA31-913E3A1659B2`.

## Live route markers

Both fresh runtimes emitted the actual level-display marker twice:

```text
OTTSEL LEVEL MARKER: level=village1 display=display-self
OTTSEL LEVEL MARKER: target-trans=(-635598.8750,222551.6562,710496.2500,1.0000)
```

The iPad fault log was 0 bytes. The macOS runtime was stopped after the
marker/trace capture; no crash/fault marker was found in the retained log.

## Same-boundary producer comparison

After the macOS marker, the fresh Sprite3 trace captured:

```text
tbp=9458 (0x24f2) tex0=0x2004d1e59930a4f2 psm=19 wh=64x64
vec=(-575829.562,144133.312,857026.125,12287.999)
SPRITE3 DRAW tbp=9458 sprites=55 blend=2 ztest=2 zwrite=false alpha-test=2 aref=0.000
```

The stable iPad replay at the same `display-self` target position still begins
with `0x2c8d`, `tex0=0x2005a0455530ac8d`, 32×32, and its previously captured
raw vectors. The target position now matches across the two paths while the
first resource/record domain does not.

## Verdict

OPEN. Route-state position mismatch is ruled out as the immediate explanation
for the first resource divergence. The remaining discriminator is producer
data-family/phase ownership or a handoff before the native consumer; no TBP
remap, camera correction, or native Metal widening is justified. The Simulator
remained blank/non-audible, so this is diagnostic evidence only.
