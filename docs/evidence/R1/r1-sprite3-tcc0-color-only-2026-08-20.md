# R1 Sprite3 TCC=0 color-only contract — 2026-08-20

## Gate

Preserve the captured untextured Sprite3 state while making the existing
bounded native probe able to represent it without a protected or placeholder
texture.

## Before failure

The fresh prelaunch Village1 capture showed valid ADGIF register/data pairs
with `TEX0=0` (`TCC=0`). The native probe always derived a texture size and
called the texture decoder, so it had no explicit color-only contract.

## Test-first change

Added `ottsel::sprite3_uses_texture(u64)` and the
`Sprite3Native.RecognizesCapturedTccZeroColorOnlyAdGif` regression. The test
failed before the helper existed, then passed after the helper recognized the
captured `TEX0=0` state and retained the textured
`0x2005a0455530ac8d` state.

The native probe now uses a generated opaque 1×1 white texel only for TCC=0;
vertex color remains the source of color and alpha. TCC=1 continues through
the existing decoded texture path. No CPU frame publication, bucket widening,
texture remap, or game-content change was made.

## Proof

- Focused `Sprite3Native.*`: 13/13 passed.
- `scripts/build-ios.sh`: passed.
- Strict deep codesign: passed.
- Signed app executable SHA-256:
  `beab3ac459713d803175dfe9f7d1fe78deacabc8bf316c8f6b27cfab0b1d94dc`.
- Fresh supported background route, PID `19645`, uploaded the existing first
  bounded textured candidate with `tcc=1`, 64×64 texture, and bounds
  `(0.438,0.484)..(0.617,0.788)`; fault log was 0 bytes.

The color-only branch is source/test verified but did not become the selected
first native upload in this run. The Simulator remained blank/non-audible.

A follow-on color-only-only probe trigger was then accepted on a fresh
background route (PID `21697`, signed executable SHA-256
`50abb057c4ab62b0a2aa6552a83df11c72b3492f5def61d2d70c492011ef54bd`). It
skipped the earlier TCC=1 candidates and reached the repeated TCC=0 ADGIF
groups, but no native upload line followed before shutdown; those groups did
not reach the existing usable native candidate path. Fault log remained 0
bytes. This validates trigger selection and preserves the open visibility/
transform dependency; it does not claim a color-only visible draw.

## Transform rejection proof

The next signed probe (`f224fcacc6615e588f9e178e5e776ccef4cd058df222f1d1943a245b9f640a99`)
logged the TCC=0 records at the existing transform guard. For 16 consecutive
records, the vector was `(0,0,0,0)`, the transformed camera value was
`(0,0,16760950,0)`, and `camera.w=0` made the denominator rejection explicit.
The fault log remained 0 bytes. This confirms the color-only records are
non-renderable empty records in this phase; relaxing the denominator guard or
changing camera/shader signs would be incorrect.

The next R1 slice therefore returns to textured phase/resource ownership and
the missing macOS world sequence. The color-only handling remains covered but
is not a product-playability pass.

## Verdict and next gate

OPEN. The TCC=0 data shape is now regression-covered and represented in the
bounded native probe. Full Sprite3 phase/resource parity, visible frame
composition, audio, touch, save/reload, iPhone parity, and device readiness
remain open.
