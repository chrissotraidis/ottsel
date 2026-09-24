# L3: the MERC packet handler stops allocating per packet - 2026-09-22

Gate: L3 (cadence).  Question: with the frame set by `T = R / (1 - 60*S)`, can `R` be cut without touching
gameplay?  A fresh 3 s `sample` of the training lane put the top leaves on the game thread at
`_platform_memmove` 412, `capture_mobile_merc` 369 (23% of the 1578-sample thread), `access` 161,
`__bzero` 126, `std::vector<unsigned char>::__insert_with_size` 114 and `decode_texture_pixels_raw` 101.

**What `capture_mobile_merc` was doing per packet.**  It runs for every MERC setup transfer in the chain
walk - several per frame - and, before this change, each call

- probed `ottsel-trace-merc-names` with `access()` (a stat per packet for a diagnostic that is only read
  when a trigger is armed), and
- allocated **three vectors sized to the whole level's MERC vertex set** (`vertices`, `lit_colors`,
  `lighting_valid`) before skinning every vertex of the level.

```
trigger:  probed once per chain in gfx_send_chain and latched (g_merc_names_trace_pending); the
          histogram still accumulates on every packet, so an armed read still reports the lane
scratch:  three file-scope vectors, resized only when the level's vertex count changes, with
          lighting_valid refilled each call - it is the gate the index validation already uses, so
          stale bytes in entries that stay invalid can never be read
ledger:   the two eichar diagnostic loops (clip ledger, clip probe) now skip entries that are not
          valid for this call, which is what makes reusing the scratch honest
```

**Correctness re-checked.**  `scene-level='training'` with `eichar=17` and the level, actors, terrain, fruit
and bridge all rendering normally in `/tmp/ottsel-l3-correctness.png`, `ottsel-fault.log` 0 bytes, and the
re-gated diagnostic still fires when armed: `OTTSEL MERC NAMES: distinct=50 submits=48639
eichar-submits=1569`, with the trigger consumed.

**Effect on the targeted work.**  A second 3 s sample shows the leaves this change targets dropping hard -
`capture_mobile_merc` 369 -> 130 and `_platform_memmove` 412 -> 184 - but that sample was taken in the title
state rather than the training state, so the counts are not a like-for-like A/B; the *share* of the chain
walk is what improved.

**Cadence.**  Post-change, the training lane measures **24.0 fps at `game-time-ratio` 3.000** over a 30 s
window with continuous stick+Cross input, against the pre-change soak's 22.5-30.0 fps at ratio 3.0 - i.e.
the same cadence held under a *heavier* host (load average 4.3-4.7 with other processes at 10-35% CPU,
against the soak's lighter window).  That does not prove a speed-up and is not offered as one: the host was
busy, the same build measured 6 and 12 fps in title/menu windows minutes apart, and the pre-change lane was
already at ratio 4.000 (about 18 fps) in the same window before this build existed.

Not claimed: no fps improvement is proven; a clean A/B needs a quiet host window and is queued.  What is
shown is that per-packet allocation and a per-packet stat are gone, the targeted leaves fell, and the lane
still renders and runs correctly.
