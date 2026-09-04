# I1 Merc snapshot retention — 2026-09-03

Status: OPEN. Retaining the latest Merc buffer prevents an empty producer
interval from erasing it, but does not yet produce playable Jak.

Question:

- Does the presentation-thread empty-queue clear cause the actor to disappear
  during the title-to-Village1 transition?

Change:

- Added an explicit Merc snapshot-retention policy and changed
  `drainMercUploads` to preserve an existing active buffer when no replacement
  upload is pending. A nonempty replacement still atomically replaces it.

Verification:

- Signed executable SHA-256:
  `0db0b6c6a10093407d854289a001fcb722d29171a4c45c706a4f1bc48fc8e730`.
- Full goalc suite passed: 782 tests from 51 suites.
- Fresh frame: `/tmp/ottsel-video/bot36-merc-retain-2026-09-03.png`.
- Frame SHA-256: `13dfd7e8b0e77dfc07de46c8f5d34d68d9a73ac6ae46193069b610ac0fbc0575`.
- `eichar-lod0` was captured at 9942 vertices / 2253 triangles before the
  Village1 camera marker; PCM later reached 12030 and no fault was reported.

Result:

- The frame remains rotated/over-zoomed and Jak is not visibly identifiable or
  controllable. Retention alone is insufficient; the actor snapshot needs an
  explicit frame/level owner and a verified Metal draw-consumer record.
- Follow-up file-backed probe proved the Metal consumer did encode a Merc mesh
  (`projection=1`, 5216 indices); the first encoded mesh had coordinates
  `(45010.852,-160.674,-22078.443)`. This rules out a total upload loss, but
  does not identify the mesh as Jak or prove its transform is scene-correct.
- Owner-tag tracing showed the active five-draw batch after the Eichar capture
  did not contain its 13-draw owner group. A later presentation drain replaced
  the actor aggregate with another batch, confirming cross-chain Merc loss.
- I1 remains OPEN; no playability claim is made.

Follow-up architecture trial:

- A per-owner aggregate with scene reset was tested in a signed Simulator run;
  it worsened composition to edge fragments/black space and was rolled back.
- The rollback builds cleanly and passes 782/782 tests. A future aggregation
  fix needs an actual game-frame boundary, not a presentation-time map.
- A `gfx_vsync`-anchored collector was then tested; its frame regressed to edge
  fragments/black space and was rolled back. Verified rollback executable:
  `10fc82945e4d9bd991786ca65a050942255f76e05ba45a48e4c72316541f6a11`.

- Actor-slot follow-up: the transition ledger showed Eichar at chain 321 while the camera was still
  `title`; Village1 camera packets began at chain 637.
- The signed actor-slot build isolated `eichar-lod0` into a persistent Metal
  snapshot so later title/logo batches cannot erase the player model.
- Build executable SHA-256:
  `1bd57df9ed05b3812d0d58288f657bb5f1ed3730d658802f0cfa0f275a630950`.
- Fresh frame SHA-256:
  `1093c307e2bbdde65d1dd0599b4111a739cd25e6e0ed2003116b0420a568d815`.
- The frame remains malformed and Jak is not visibly identifiable; this change
  is OPEN and needs a second actor-consumer/projection probe.
