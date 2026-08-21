# D0-NORMAL Direct attribution — 2026-08-19

## Ledger

| Field | Result |
|---|---|
| Gate | D0 — attribute the Jak 1 glyph on desktop |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; local `gk` rebuilt by `ninja -C out/jak-project/build/h1 gk` |
| Environment | Native arm64 macOS, one Windowed `out/jak-project/build/h1/game/gk`, Jak 1 `-boot -fakeiso -nosound`; no Simulator concurrent |
| Before failure | iPad Direct packets were decoded by the diagnostic path, but their desktop target/visibility route was unproven; prior offscreen inference relied on coordinates and scissor alone |
| Change | Opt-in probe in `DirectRenderer.{h,cpp}`. It fingerprints `nloop=1`, `PRE`, `PRIM=0x5c`, `NREG=13`, records bucket/state/FBO/viewport/texture/bounds, and logs post-flush draw counters. It does not alter rendering. |
| Focused proof | `ninja -C out/jak-project/build/h1 gk`; `git -C out/jak-project diff --check` — PASS |
| Live proof | `/tmp/ottsel-d0-run-6.log`; eight matching packets in bucket `[67] debug`, exact `A+D,ST,RGBAQ,XYZF2` repeated four times; each `direct_qwc=14`, `gif_qwc=14`, `fbp=0`, `fbo=65`, viewport `1280x960`, `offscreen=false`, texture hit/non-placeholder. Post-flush: `draws=1`, `tris=44`. Same-phase visible macOS title/logo frame: [`d0-macos-same-phase-2026-08-19.jpg`](./d0-macos-same-phase-2026-08-19.jpg). |
| Fault scan | No `Exception thrown`, `Everything will crash`, `OTTSEL CRASH`, `SIGILL`, `SIGBUS`, or fatal marker in the run log. |
| Verdict | **D0-NORMAL PASS.** |
| Next gate | D1 — build a ROM-safe generated red Direct fixture from this ordered state contract; first experiment is a before-failing desktop fixture counter/image harness. |

## Interpretation

The matching packet is Jak 1 bucket 67’s plain `DirectRenderer("debug")`. Its
observed `FRAME.fbp=0` and `offscreen=false` state select the normal final-target
branch. The same bucket flushes one native desktop draw; no target store/alias or
later consuming draw is required by this trace. This falsifies the earlier
coordinate-only claim that the packet requires the Jak 2 `ProgressRenderer`
128x128 target model.

The trace is renderer attribution, not mobile playability, a complete title/menu
interaction pass, or the D1 fixture pass. The temporary trace is opt-in through
`/tmp/ottsel-trace-glyph` and must not be treated as product behavior.
