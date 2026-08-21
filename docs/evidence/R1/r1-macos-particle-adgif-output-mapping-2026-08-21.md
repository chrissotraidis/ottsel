# R1 macOS particle AdGif output mapping — 2026-08-21

## Gate

Compare the macOS producer-ID → AdGif/TEX0 mapping with the fresh iPad
capture before changing the native Metal consumer.

## Identity and environment

- Outer source: `549508edfa0ee605f487f73a90c9206a8b15737b` (`main`).
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`, with the
  maintained diagnostic changes applied locally.
- Host executable SHA-256:
  `26bdcbc8e2e2864adc5a2e178e55529d6d107b3a5633cf13e6825cc5e2be0b68`.
- Runtime: one native arm64 macOS `gk`, `-boot -fakeiso -nosound`, isolated
  config; no Simulator was booted.

## Before failure

The iPad trace proved that the native consumer preserves the mobile producer's
selected TEX0, but only the iPad side had been captured with the new output
trace. The macOS side still needed the corresponding live mapping at the
Village1 transition.

## Change

No product renderer or resource-selection code changed. The existing bounded
`/tmp/ottsel-trace-particle-adgif` trigger was armed after the fresh host
`title-wait-ready` route marker and observed the existing MIPS2C cache-copy
output. This keeps the experiment diagnostic-only and preserves the
signed-native/no-runtime-emit boundary.

## Focused proof

`ninja -C out/jak-project/build/h1 goalc-test` completed, then
`goalc-test --gtest_filter='Sprite3Native.*'` passed all 16 tests. The host
binary is the rebuilt native arm64 executable above.

## Live proof

The host route reached the shared Village1 target marker with the same target
translation used by the mobile comparison:

```text
target-trans=(-635598.8750,222551.6562,710496.2500,1.0000)
```

The trace completed 32 samples. Representative output pairs were:

```text
raw=0x00200400 page=0x2 index=0x4
  tex0=0x2004cfe55530a518 tex1=0x120 clamp=0x1010001c0 alpha=0x44
raw=0x00201e00 page=0x2 index=0x1e
  tex0=0x2004d1e59930a4f2 tex1=0x120 clamp=0x1010001c0 alpha=0x44
raw=0x00202200 page=0x2 index=0x22
  tex0=0x2004c3255530a5ee tex1=0x120 clamp=0x1010001c0 alpha=0x44
raw=0x00200000 page=0x2 index=0x0
  tex0=0x2004c1259930a6e1 tex1=0x12c clamp=0x1010001c0 alpha=0x44
```

The trace completed, the host process was stopped, and `/tmp/ottsel-fault.log`
was 0 bytes. The full raw log is `/tmp/ottsel-macos-r1-adgif.log` and is not
committed as a build/runtime artifact.

A separate trigger-gated Sprite3 trace at the same fresh title-wait route
captured the host setup before the first world flush:

```text
pfog0=-0.036405455 inv-area=0.036767285
hvdf=(2048,2048,8380365.5,264.3198)
first world tex0=0x2004d1e59930a4f2 tbp=9458 size=64x64 mscal=211
first vector xyz=(-421721.6,45137.92,301110.94,8654.301)
```

The first setup scalars match the stable mobile setup values already captured
in the R1 producer ledger, while the first world resource and vector domain do
not. This shifts the next comparison away from the shared scalar frame setup
and toward the post-`MSCAL=3` phase/data-family handoff.

## Interpretation and verdict

**OPEN.** The macOS producer maps its selected IDs directly to its own
resource family (`0x...a518`, `0x...a4f2`, `0x...a5ee`, `0x...a6e1`), while the
fresh iPad mapping selects a different family beginning with
`0x2005aa459930ab8d`. Both sides preserve producer output; neither justifies
a native TBP remap, camera rewrite, or shader change. The first unresolved
dependency remains the upstream phase/data-family selection that produces the
different first 3D/world tuple.

## Next gate

Add one same-route source/data-family discriminator around the first
`Sprite3::handle_sprite_frame_setup` / `flush_sprites` resource selection,
then compare its result on macOS and iPad. Keep the native consumer
diagnostic-only until that producer divergence is localized.
