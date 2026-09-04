# I1 Merc topology correction — 2026-09-03

Question: does the native Merc consumer preserve the upstream per-draw
triangle-list versus triangle-strip primitive contract?

Before: `capture_mobile_merc` copied every draw's source indices and Metal
submitted every draw as `MTLPrimitiveTypeTriangle`. Upstream `Merc2::flush_draw_buckets`
selects `GL_TRIANGLES` when `draw.no_strip` is true and `GL_TRIANGLE_STRIP`
otherwise, with `UINT32_MAX` primitive restarts.

Change: in `src/shell/metal_gfx.mm`, retain triangle-list indices for
`no_strip` draws and expand strip runs with restart-aware alternating winding
into triangle-list indices before creating `OttselMetalTieDraw`.

Build: `scripts/build-ios.sh` completed and signed
`out/jak-project/out/ios/app/OttselShell.app`; build log:
`/tmp/ottsel-build-merc-strip-2026-09-03.log`.

Runtime: installed on iPad Pro M4 Simulator
`08636791-2675-4675-8335-EF72EF954DCF`, launch PID `14805`.
The fresh log reports `model='eichar-lod0' ... triangles=3593 draws=13`;
the previous retained snapshot reported 2253 triangles for the same model.

Frame: `/tmp/ottsel-video/bot36-merc-strip-2026-09-03.png`, SHA-256
`78514723d059089a83a95072adc9aaa01227d8f3e0127e2babe8845618090514`.
The capture was still on the diagnostic/title composition, not a fresh
Village1 gameplay frame, so no visual actor-pass claim is made.

Follow-up frame: `/tmp/ottsel-video/bot36-merc-strip-route-2026-09-03.png`,
SHA-256 `622d283453cdd1e0232d148febafce492852e6f15aaf4f006b0da33777c9acc7`.
Village1 was reached, but the composition remained malformed and the clip
ledger still reported `visible=0` for Eichar; topology is not the root cause.

Result: PASS for source/build topology preservation; OPEN for visible Jak,
stable depth ordering, and controllable gameplay. The independent renderer
review task remains unavailable after repeated service-demand failures.
