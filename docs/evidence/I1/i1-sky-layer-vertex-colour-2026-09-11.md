# I1 sky: per-layer vertex colour collapses the sky to black — 2026-09-11

Scope: iPad Pro 11 M4 Simulator, Village1. Measurement plus observability-only
`cmax`/`SKYRGB` diagnostics in `metal_shell.mm`. No product change. N1 unproven.

## Method correction — do this before trusting any earlier sky A/B

`clean1_full_rot.png` and `clean2_full_rot.png` are the same run six seconds
apart: 98.9% of sampled pixels differ and the sky band moves from 0.0% to 52.7%
pass-clear. Single-screenshot A/Bs here are frame-cadence noise. Capture with
`/tmp/ottsel-diag/runprobe.sh <probe> <tag> 8 3` and classify with `stats.py`.

## Confirmed by the 8-frame A/B

- `sky-debug-fill` (opaque magenta, ignores texture and vertex colour) paints the
  sky in 2 of 8 frames, up to 20.6% of the frame: pipeline, vertex layout, depth
  state and pass slot all work; the captures differ by camera state, not health.
- `sky-debug-tex` (real texel, alpha forced 1, ignores vertex colour) painted a
  grey speckle layer over the sky in 1 of 8 frames, never magenta.
- The fan is submitted nearly every presented frame: `SKYFRAME` holds at 38-46
  batches with alpha0=0, alphaHalf=all, amax=0.502.

## Root cause candidate — `SKYRGB`, stable at 1 Hz all run

    1x1=(0.000,0.000,0.000)  32=(0.502,0.502,0.502)  64=(0.078,0.078,0.118)

`direct_fs` does `color.rgb = in.color.rgb * texel.rgb` then `*= 2.0`, so the
sky equals the texel times the batch's vertex colour:

- 1x1 untextured **full-screen** fans: vertex RGB exactly 0 -> `0 * texel = 0`.
  They cover the drawable, so they blacken the sky.
- 64x64 dome fans: (0.078,0.078,0.118) = bytes (20,20,30), capping the dome near
  12% luminance however bright its texture is.
- 32x32 fans: 0.502 = 0x80, white — the only bright sky content lands there.

An earlier `cmax` probe reported (0.502,0.502,0.502) and wrongly exonerated the
vertex colour: it took the max across all batches, hiding the black 1x1 layer.
Per-size-class reporting is required.

## Refuted this round (stop re-testing)

- Zero vertex alpha, dead texture, dead pipeline, bad pass position: both debug
  pipelines paint through the product's own depth state and amax=0.502.
- `sky-debug-fill` = 0.00% magenta (BOT57-Q3): stale one-screenshot reading.

## Next falsifiable step

1. Decide whether (0,0,0) and (20,20,30) are the decoded game values or a decode
   error: dump the raw GIF vertex-colour words for the 1x1 and 64x64 sky draws
   and compare against 0x80808080.
2. Decode error -> fix the colour source offset. Decode correct -> those layer
   colours are not what upstream assigns, so find what upstream writes there.
3. Only then judge the 64x64 texture content (currently grey speckle, not sky).

Evidence: this file; `/tmp/ottsel-diag/{runprobe.sh,stats.py,bands.py,prof.py}`;
`/tmp/ottsel-video/{cleanB,magB,texB}-*_r.png`.
