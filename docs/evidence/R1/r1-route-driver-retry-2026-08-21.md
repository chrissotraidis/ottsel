# R1 route-driver retry — 2026-08-21

## Gate

R1 phase-specific native image/readback measurement.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- App executable: the signed build documented in
  `docs/evidence/R1/r1-post-village1-bucket-ownership-2026-08-20.md`.
- One iPad Pro 11-inch (M4) Simulator, UDID
  `08636791-2675-4675-8335-EF72EF954DCF`.

## Before failure

The next slice required a fresh current-boot Village1 route, followed by the
trigger-only bucket-67 world probe and existing drawable readback trigger.

## Live result

The app reached `OTTSEL ROUTE STATE: title-wait-ready`, but the bounded
host-side `/tmp/ottsel-press-start` attempt did not produce
`OTTSEL TITLE: start edge in title-wait`. The route therefore never reached
`GAMEPLAY: enter village1`; the Metal probe and readback triggers were not
armed. No new PPM or SHA-256 image artifact exists from this attempt.

The process was stopped and the Simulator was shut down. This leaves the
existing native probe result unchanged: `drawn=640`, `candidates=640`,
`fixture-uploaded=true`, `cpu-product-frame=0`, with no visual acceptance claim.

## Verdict

OPEN. The first open product dependency remains mobile renderer composition and
phase/image parity. The next attempt must repair or replace only this route
driver synchronization seam before comparing a new readback artifact with the
macOS oracle; it must not widen bucket 67 or treat the blank Simulator as a
successful frame.

## Follow-up live discriminator

The route was replayed again with the stale-log race removed from the host
waiter and with a fresh current-boot Village1 marker. The route entered
Village1 twice and the bucket-67 phase classifier reported the expected
world tuple (`World2D`, 48 sprites, `tbp=0x2c8d`, `PSM=19`, `tw=5`, `th=5`)
seven times. The trigger-gated native probe then saw 384 candidates but
uploaded none:

```text
OTTSEL SPRITE METAL BUCKET67: chain=48943 vsync=48944 drawn=384 candidates=384 fixture-uploaded=false cpu-product-frame=0
```

Its first 32 candidate bounds were all rejected by the existing visibility
gate (`usable=false`); several were wholly outside clip space and the largest
in-view candidates were below the minimum probe size. The fault log remained
zero bytes. The existing PPM was not rewritten (its prior SHA-256 remains
`cb8ac2f5c4764fdd95ab36a4e365ff4b578972f3032758f35926f4c61c3e8683`), so
there is no fresh image-parity claim.

This changes the next experiment concretely: the tuple/resource ownership is
present, but the first native candidate divergence is now camera/transform
visibility or phase timing, not texture-key lookup. Compare the same tuple's
desktop/mobile transformed bounds and timing before changing shader or
consumer policy.
