# R1 mobile post-setup Sprite3 records — 2026-08-21

## Gate

Trace the first post-setup mobile producer records at a valid Village1 phase.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed app SHA-256: `6cf0c7ca32e042a20a8d283fccb663f446a388e08141e102fc76f7d6536088eb`.
- One iPad Pro 11-inch (M4) Simulator;
  `08636791-2675-4675-8335-EF72EF954DCF`.
- Validated pack imported and selected before Metal; fault log 0 bytes.

## Live proof

After the route logged `GAMEPLAY: enter village1` twice, the bounded 64-record
ledger captured chain `14258`, group 0:

```text
frame-pfog0=-0.2847222 frame-inv-area=0.09339085
matrix.camera-t=(-293725.72,242559.8,2.5598743e+10,869.1126)
pc-level='village1'
pc-trans=(158510.39,27992.596,3370947.8)
pc-r0=(0.9647592,0.0808916,0.2503923)
pc-r2=(-0.26313445,0.296582,0.91804105)
pc-fog=-0.2847222
```

The first records in that group were:

```text
index=0 tbp=0x2d8c psm=19 tw=6 th=6
xyz=(-4436985,-833232.25,3739648,493339.1)
rgba=(63.295525,72.62395,143.82071,4.597858)
index=4 tbp=0x2c8d psm=19 tw=5 th=5
xyz=(7362714,5788441.5,-16714376,190327.8)
index=5 tbp=0x2d7c psm=19 tw=6 th=6
xyz=(-4914672,360240,4386096,39321.5)
```

## Comparison

The macOS accepted world sample begins at TBP `0x24f2` (`9458`) and includes
records such as `xyz=(-575829.562,145196.625,857026.125,9284.269)` with a
64×64 texture. The mobile post-setup group uses different TBPs, substantially
different raw positions/scales, and a different resource state. This is a
producer/phase-data divergence before the native Metal clip test.

## Interpretation and verdict

OPEN. The validated root and frame/matrix boundary are established, while the
post-setup mobile record contents do not match the macOS phase oracle. No TBP
remap, camera sign change, shader adjustment, or native-consumer widening is
justified. The next slice is to trace the mobile source producer/phase state
that emits this group and compare it with macOS `Sprite3::handle_sprite_frame_setup`
and first world `flush_sprites` inputs. The Simulator remained blank and
non-audible; this is diagnostic evidence only.

## Focused regression

Command: `cmake --build build/h1 --target goalc-test -j3 &&
./build/h1/goalc-test --gtest_filter='Sprite3Native.*'` from
`out/jak-project`. Result: all 12 maintained Sprite3Native tests passed,
including bucket-boundary ownership, Jak 1 MSCAL classification, validated
root selection, area-fade/color handling, and the native depth/alpha/blend
contracts. This rules out a currently failing maintained boundary regression;
it does not prove producer/resource parity or visual playability.
