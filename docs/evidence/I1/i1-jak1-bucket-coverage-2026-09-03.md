# I1 Jak 1 bucket coverage — 2026-09-03

Question: is the broken Village1 frame caused by one bad native draw, or by
missing renderer families at the Metal boundary?

Change: add a one-shot `ottsel-trace-mobile-bucket-coverage` census. It only
walks the existing 70 bucket windows after the live Village1 marker and counts
VIF/DIRECT/PC_PORT/UNPACK/MSCAL traffic; it submits no new pixels.

Build: signed iOS Simulator app, hash
`aee3d543337a99cd30abee5f07580fc16efa6b2b8866f6003f86aadeb8cea6d1`.
Runtime: iPad Pro 11-inch (M4), iOS 18.5, UDID
`08636791-2675-4675-8335-EF72EF954DCF`.

Fresh Village1 census: bucket 3 Sky had 6 DIRECT packets; bucket 4 Ocean had
331 transfers, 149 V4_32 uploads, and 69 MSCALs. Buckets 11/18/24/30/46/50/
53/56/59/62 carried generic payloads; 20/26 shrub; 32/39 alpha/trans; 47
shadow; 48–64 prism/water/depth; and 66 Sprite3. The remaining five-transfer
scaffolding is the normal empty-bucket envelope.

Fresh frame remains malformed/rotated-encoded, with black unhandled regions and
debug touch rectangles: `/tmp/ottsel-video/bot36-bucket-coverage-village1-2026-09-03.png`.
Audio telemetry reached `pcm-peak=11470`; no fault/crash marker appeared.

Result: OPEN. The failure is systemic renderer coverage/composition, not only
Merc geometry. The next implementation should establish a per-frame bucket
dispatch/draw-list boundary, beginning with Sky (bucket 3), while preserving
the existing TFRAG/TIE/Merc ownership and no-fixture product rule. Do not claim
playability until the full route is coherent and Jak is visible/control-tested.
