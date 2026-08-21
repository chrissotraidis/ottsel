# R1 macOS Village1 Sprite3 producer capture — 2026-08-21

## Gate

Capture the macOS Sprite3 source records after Village1 is active and compare
the ordered producer/resource boundary with the stable mobile replay.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Runtime: `out/jak-project/build/h1/game/gk`, native arm64, `-boot -fakeiso -nosound`.
- Log: `out/jak-project/log/jak1.2026-08-20T20-18-53.log`.
- One Windowed macOS runtime; stopped after capture; no Simulator concurrent.

## Live proof

The trace was armed after the log reached `Displaying level village1
[display-self]`. The first captured Sprite3 frame reported 32 group-0 blocks
and 1,536 sprites. Its first accepted world draw was:

```text
tbp=9458 (0x24f2)
sprites=55
tex0=0x2004d1e59930a4f2
psm=19 wh=64x64
mode=0xfabe26fc blend=2 ztest=2 zwrite=false alpha-test=2 aref=0.000
```

The first sampled world record used the same resource and raw vector domain as
the existing macOS oracle, for example:

```text
vec=(-575829.562,146882.047,857026.125,2184.533)
rgba=(16.000,7.247,127.000,118.467)
```

The trace completed three frames with 24 samples per frame and no crash/fault
marker in the retained runtime log.

## Comparison and verdict

OPEN. The stable mobile replay at the corresponding Village1 producer boundary
begins with `0x2c8d` (`tex0=0x2005a0455530ac8d`, 32×32) and a different raw
vector/camera state. This confirms that the mobile and macOS ordered source
records are not interchangeable; it does not yet prove whether the difference
is caused by route state, data-family selection, or a producer-side handoff.
The next slice is to add/compare an explicit route-state marker at the exact
New Game→Village1 transition on both platforms, then match the first producer
group before any native Metal change.
