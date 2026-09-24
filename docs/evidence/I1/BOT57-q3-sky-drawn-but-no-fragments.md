# BOT57 Q3 — the sky submits screen-covering geometry and still produces no fragments

Date 2026-09-11. UDID 08636791, pid 68474, `ottsel-fault.log` 0 bytes, disk gate
`18Gi` free / zero `tmp_pack_*`. No source change; each arm used a fresh launch.

## Correction to B56-F as written

The black backdrop is **not** the CPU `g_rgba` fill. That fill exists
(`main.cpp:1041`), but `ottsel_metal_gfx_game_frame` is `return 0;`
(`metal_gfx.mm:8754`), so `main.cpp:1081` always takes the `else` and presents
`g_rgba` — which is never what the user sees when a live scene exists. The
presented image is the Metal pass, whose color attachment clears to
`MTLClearColorMake(0.03, 0.04, 0.07, 1.0)` (`metal_shell.mm:1178`). In BGRA8Unorm
that is exactly `(8,10,18)`, measured pixel-for-pixel across the sky region. So
"the lower two thirds are the neutral base fill" should read: they are the
**render pass clear colour**.

## What the sky submits (live `SKYBOUND` / `SKY ENCODE`)

40 batches/frame, each a single triangle, `blend=1`, alpha `0.502`. Textures are
real 32x32/64x64 images with full range and distinct samples
(`ottsel-sky-source-1..3.ppm`). Geometry is non-degenerate and covers the drawable:

    i=0 tex=32x32 v0=(0.000,-0.009) v1=(4.000,-0.009) v2=(4.000,3.991)   -> upper-right quadrant
    i=x tex=32x32 v0=(-4.000,0.096) v1=(-2.992,0.096) v2=(-3.142,3.991)  -> off-screen left

## The decisive A/B (captures 4 s apart; camera fly-through does not mask this)

| capture | armed | dark `(8,10,18)` | magenta |
|---|---|---|---|
| H0 | none | 10.9% | 0.00% |
| H1 | `-sky-debug-fill` | 21.5% | **0.00%** |

`-sky-debug-fill` swaps in `direct_fs_debug_fill`, returning
`float4(1.0, 0.0, 1.0, 1.0)` (`metal_shell.mm:97`) — opaque magenta at alpha 1.0 —
so under `SourceAlpha/OneMinusSourceAlpha` it must paint unconditionally. The 1x1
batches are skipped; the 36 textured batches whose geometry covers the screen are
drawn. **Zero magenta pixels appear.** The pipeline is not the failure: at 13:49
the same probe plus `-sky-debug-all` (adding one full-screen
`DirectFixtureVertex` triangle from a locally-owned buffer through that same
pipeline) painted the whole screen magenta. No pipeline-creation error was logged
in either run.

## Exonerated

Depth is `overlayDepthState` = compare **ALWAYS**, no write (`1833`). Blending is
opaque magenta (above). Winding matches the reference triangle that does paint
(both CCW in NDC). `directLayout` uses attributes 0/1/2 at offsets 0/8/16 with
`stride = sizeof(DirectFixtureVertex)` (`646-654`), and `DirectFixtureVertex`
(215-219) is byte-identical to `OttselMetalSpriteVertex`. Pool buffers are
recycled only in the completion handler (`2121`). One encoder, one pass, clear
precedes every draw.

## Open question, precisely stated

Geometry that must rasterize, through a pipeline proven to paint, with a buffer
the CPU reads correctly at encode time, contributes no fragments; an identically
formatted local buffer through the same pipeline does. That points at the draw as
the GPU executes it, not at pipeline or state. Next falsifiable step: a one-batch
fixture re-using the sky's own `id<MTLBuffer>` and draw verbatim, or a GPU capture.
