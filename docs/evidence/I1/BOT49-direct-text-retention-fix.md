# BOT49 — the menu text was being erased mid-encode, not mis-drawn

Proven live on iPad Pro 11-inch M4, iOS 18.5, UDID
`08636791-2675-4675-8335-EF72EF954DCF`, app `com.ottsel.shell`, screen 1668x2420
(rotate screenshots with `sips -r 270`).

## Question

BOT48 left Gate G1 as "why does the light glyph pass drop intermittently". Two
mechanisms had been proposed for it. Which one, if either, is real?

## Both proposed mechanisms are refuted (measured)

1. The hardcoded count gate in `append_mobile_sprite_hud_native` drops glyph
   groups. Refuted. Every group logged `orig_pass=1`; arriving counts are only
   ever 48 or 32 (`OTTSEL HUD GATE: count=48 orig_pass=1 product=1 metal=1`).
2. `clearSpriteBatches()` in `setSpriteMeshNow` wipes earlier HUD groups.
   Refuted. A discard counter there logged zero non-empty clears over 4.6 MB.

## The real defect: the terminal clear erased groups appended during encode

`presentRGBA` snapshots the sprite and Direct/GIF stores, builds the command
buffer, commits, then calls `clearTransientSpriteBatches`, which erases every
non-persistent batch in the store. The game thread keeps appending while the
render thread is still encoding, so any group appended in that window is erased
before it is ever encoded.

Measured before the fix, over one 5,433-frame menu session:

- `OTTSEL SPRITE FRAME`: `drawn=1` in 3,681 frames, `drawn=0` in 936, the rest
  2..16. One retained group per frame.
- The HUD appends 3 groups per frame on the title menu (`sprites=48`, `48`,
  `32`), so roughly two of every three submitted groups died unencoded.

That is why labels appeared only in fragments that changed frame to frame: each
frame kept a different single group.

## Fix (tag-based erase, scoped to the text paths)

`mobile_snapshot_store.h`: each `append` records a monotonic tag;
`snapshot_tagged()` returns (tag, value) pairs and `erase_tags()` removes exactly
those. `erase_if` became a parallel-array compaction so tags stay in step.
`metal_shell.mm`: `presentRGBA` snapshots tagged, collects the non-persistent
tags it encodes, and ends with `erase_tags(...)` instead of a whole-store clear.
Sky keeps its whole-store clear. Anything appended mid-encode survives to the
next frame.

## Result (measured on the installed build)

- Retained `OTTSEL DIRECT FRAME` groups rose from 1 to 18-22 per frame on the
  settled title menu; the `drawn=0` tail collapsed.
- `NEW GAME` renders complete and stable across consecutive frames
  (`/tmp/b49/s6_rot.png`), where previously only fragments ever appeared.
- Fault log 0 bytes, no crash.

## Still open

The other five entries do not all appear in one frame yet, and Gate N1 (Village1
gameplay with Jak visible and input-accepted) is unproven; the route reaches the
loading screen (`/100`, `9%`). Do not call this playability.
