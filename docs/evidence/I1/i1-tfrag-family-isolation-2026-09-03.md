# I1 TFRAG family isolation — 2026-09-03

Status: OPEN. TFRAG-only composition is not coherent and supplies no visible
Jak 1 scene in this runtime.

Question: are the scattered pixels in the normal frame caused primarily by TIE
or Merc, with TFRAG providing a valid background underneath?

Build under test: signed `out/jak-project/out/ios/app/OttselShell.app` with the
bucket-table PC_PORT tail; focused PlatformInput suite passed 27/27.

Route: one iPad Pro 11-inch Simulator
(`08636791-2675-4675-8335-EF72EF954DCF`), bounded title → New Game route with
both `scene-no-tie` and `scene-no-merc` triggers.

Fresh frame: `/tmp/ottsel-video/bot36-tfrag-only-bucket-tail-2026-09-03.png`.
SHA-256: `2bf802ee2629ff9b36872a2b2f1bbe46559212db19ee811a454a0a21c7ff22e2`.

Observed: only the debug rectangles remain; no coherent TFRAG world appears.
This does not prove TFRAG geometry is absent—the runtime still reports the
Village1 TFRAG snapshot—but it rules out TIE/Merc as the sole composition cause.

Texture ledger: Village1 selected 84 TFRAG draws with nonnegative texture IDs
and zero negative animated-slot IDs. Therefore the upstream animated-slot
binding mismatch is not the explanation for this TFRAG-only blank frame.

Metal skip ledger: the signed runtime emitted no TFRAG out-of-range or
not-uploaded texture skips while reaching Village1; valid texture objects were
available to the draw loop. FIFO upload starvation is therefore not proven.

Runtime remained fault-free and the packet-level camera ledger was live. No
camera matrix, TBP/lookup, or strip-restart code changed.

Next: compare a known TFRAG draw's source texture/color bytes with fragment
alpha/material state before a renderer correction; do not implement animated
slots based on this refuted hypothesis.
