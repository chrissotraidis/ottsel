# I1 Sky Direct IR — 2026-09-03

Question: can Jak 1 Sky bucket 3 reuse the existing Direct/GIF decoder, or
does it require a separate packet parser?

Change: add a one-shot `ottsel-trace-mobile-sky-ir` probe. It decodes the live
Village1 bucket-3 window into the existing IR state machine, submits no Metal
fixture, and restores the shared decoder/trace state afterward.

Build: signed iOS Simulator app; runtime iPad Pro 11-inch (M4), iOS 18.5,
UDID `08636791-2675-4675-8335-EF72EF954DCF`.

Result: bucket 3 consumed 8 transfers, including 3 Direct transfers and 3 GIF
tags. The decoder reported 2 triangle-strip streams and 0 IR errors. The
`prims=300` value is the decoder's existing logging cap, not a product draw
count; the probe therefore proves packet compatibility, not final geometry
fidelity.

Fresh frame remains visibly malformed with large unrendered black regions and
debug touch rectangles: `/tmp/ottsel-video/bot36-sky-ir-village1-2026-09-03.png`.

Conclusion: OPEN. Sky can share the Direct/GIF parser, but native Metal still
needs a multi-primitive, per-frame draw list with per-draw texture/state and
ordered composition. A single overwrite-style Direct fixture cannot render
Sky correctly. No playability claim is made.
