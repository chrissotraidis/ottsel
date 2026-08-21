# D0-NORMAL macOS glyph attribution — 2026-08-20

| Field | Result |
|---|---|
| Gate | D0 — attribute the Jak 1 glyph on desktop |
| Source/build identity | Outer Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; upstream dirty diff hash `1ecdeacb924fff3437efa52c71e7ad1bc3b82de601bc842fbb03662c2ef61da1` |
| Environment | macOS arm64 `gk`, Jak 1, one Windowed runtime, `-boot -fakeiso -nosound`; no Simulator active |
| Before failure | The mobile trace had identified the 14-qword packet but the desktop target/visibility branch was not recorded. The prior offscreen interpretation was therefore not sufficient to choose a product target. |
| Change | No product source change. Armed the existing bounded `/tmp/ottsel-trace-glyph` DirectRenderer trace and ran the maintained desktop reference. |
| Focused proof | The matching packet is `[67] debug`, `direct_qwc=14`, `gif_qwc=14`, `fbp=0`, `fbo=65`, viewport `(0,0 1280x960)`, `offscreen=false`, texture hit `true`, placeholder `false`, `prim=92`, `verts=6`. After the bucket flush: `draws=1 tris=44 flushes=1`. |
| Live proof | Same-phase desktop capture `/tmp/ottsel-macos-glyph-wrapper-20260820.png` (SHA-256 `a6e40e3ff2f992202ea34de17209b05281dc4bbe319254ef300997ede42c2d56`) shows the running Jak 1 title scene with logo and `PRESS START` while the trace was active at `40:08`. |
| Fault scan | No `ASSERT`, `OTTSEL CRASH`, or DirectRenderer size failure in the bounded log. `-nosound` was used for renderer isolation; this is not audio proof. |
| Verdict | OPEN / D0-NORMAL attribution established: this Jak 1 glyph is consumed by plain DirectRenderer in the final non-offscreen desktop pass, not Jak 2's ProgressRenderer target model. The exact later composition event for the individual glyph is not independently isolated from the bucket flush. |
| Next gate | D1/D2: compare the ordered desktop glyph IR/state tuple with the ROM-safe mobile fixture, then add the smallest same-phase mobile native Direct/Sprite comparison. |

The desktop screenshot and runtime log remain local evidence artifacts; no game data or generated build product is added to the repository.
