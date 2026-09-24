# L3: MERC packets now skin and upload only the vertex slice they reference - 2026-09-22

Gate: L3 (cadence).  Follow-on to `l3-merc-packet-hot-path`, which removed the per-packet allocations and
the per-packet trigger probe.  The remaining per-packet cost was structural: `capture_mobile_merc` skinned
**every vertex in the level's shared MERC pool** and handed the whole array to Metal, even though a packet
only references the vertices of the model it names.

**Change.**  Before skinning, the handler now scans the enabled effects' draw index ranges for the referenced
vertex span (`span_min`..`span_max`, skipping `0xffffffff` strip sentinels); it skins only that span, and
after the existing index validation it rebases the built indices by `span_min` and uploads
`vertices + span_min` and `lit_colors + span_min * 4` with `span_max - span_min + 1` vertices.  The Metal
contract is a straight copy of `count * 32` bytes of vertices and `count * 16` bytes of lighting, so the
slice is exact; validation still runs on the absolute indices before the rebase, so an index that is not
skinned for this packet still fails the packet exactly as before.

**How much of the per-packet work that removes** (from the lane's own `OTTSEL MERC NATIVE` line, which now
prints the uploaded count against the pool):

| model | uploaded (span) | pool | share |
|---|---|---|---|
| eichar-lod0 (the player) | 3328 | 9942 | 33% |
| sidekick-lod0 | 1311 | 9942 | 13% |
| ndi-lod0 | 1123 | 22518 | 5% |
| sagesail-lod0 | 209 | 50764 | 0.4% |

So skinning and the vertex/lighting copies shrink by 3x for the player and by up to 240x for a small model,
and those copies were the frame's largest leaves (`_platform_memmove` 412 and `capture_mobile_merc` 369 of a
1578-sample game thread before the previous change).

**Correctness.**  `/tmp/ottsel-span-gameplay.png` shows the training level with Jak rendered in the right
colours (blue tunic, tan wraps, yellow hair) after a touch-only route into the level; zero MERC rejections in
the log, `ottsel-fault.log` 0 bytes, 346 ENTER = 346 RETURNED, the overlay-coverage guard passes and all 8
guarded `.ret` sites still validate.

**Cadence, and why it is not offered as a resolved speed-up.**  Two 30 s training windows with continuous
stick+Cross input measure **30.0 fps** and **26.1 fps** on this build (host load 3.58 and 3.39), against
**24.0 fps** on the previous build (load 4.3-4.7) and the pre-change soak's **22.5-30.0 fps** at ratio 3.0.
The work removed is proven and the cadence is at or above every earlier measurement, but the host load was
never the same twice and the same build has measured 6 and 12 fps in title/menu windows minutes apart, so the
fps effect is consistent-with-mechanism rather than controlled.  A quiet-window A/B remains queued.

Operational note: the four test saves this container had accumulated were deleted so the NEW GAME flow stops
prompting to overwrite; the save/load evidence in `i2-saves-and-lifecycle-2026-09-22.md` stands as measured.
