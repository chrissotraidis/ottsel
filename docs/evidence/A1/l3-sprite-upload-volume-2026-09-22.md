# L3: the sprite upload volume, and the withdrawn in-renderer dedup - 2026-09-22

Gate: L3.  With the base upload skipped (previous change), the sprite path is the largest single named
cost of frame production, so it was measured before changing it again.

Measured (bounded per-frame accounting inside `appendSpriteMeshNow:`, one line per 90 presents, iPad
strict lane, window before village1):

```
OTTSEL SPRITEUPLOAD: calls=1231 bytes=1165766656 dup-bytes=1089200128 hashes=1231
OTTSEL SPRITEUPLOAD: calls=1196 bytes=1141587968 dup-bytes=1059778560 hashes=1196
OTTSEL SPRITEUPLOAD: calls=1247 bytes=1165918208 dup-bytes=1080958976 hashes=1247
OTTSEL SPRITEUPLOAD: calls=1353 bytes=1258512384 dup-bytes=1192427520 hashes=1353
```

So the sprite path performs **~13-15 uploads and ~13 MB per frame**, of which **92-95% of the bytes are
byte-identical repeats of an upload earlier in the same frame** (word-wise 64-bit hash over the pixels).
At the measured ~5.5 fps that is ~70 MB/s of synchronous `MTLSimTexture replaceRegion` XPC, which matches
the ~25% of the game thread the profile attributes to `appendSpriteMeshNow`.

Attempt (one variable, withdrawn): a **frame-scoped** texture cache - hash the pixels, reuse an upload
already made *this* frame, clear the table on every present (so no texture is ever shared with a frame
still in flight, which is what made the earlier cross-frame cache 2x slower).  Result: the sprite
pipeline broke (`SPRITE FRAME ... drawn=0` on every line, against 14-26 before), the atlas path ran 7x
less often (11689 vs 84786 `native World2D atlas` lines in the same 115 s window) and the lane degraded
after the first ~270 chains.  Reverted, and the revert is verified healthy: `drawn=14`, 97069 log lines,
chain 810+ and a 0-byte `ottsel-fault.log` in the same window, with the L0 window fps back to
5.62 (baseline 5.51, base-skip 5.29).

Reading: the sprite path in this renderer does not tolerate two batches sharing one texture within a
frame either, so the duplication must be removed *upstream* of the renderer rather than cached in it -
the open question is why the same 512x512 atlas (`vertices=288 sprites=48 textures=5 atlas=512x512`) is
built and uploaded ~13 times per frame at all.  That is the next single investigation: instrument the
callers (`render_mobile_sprite_bucket` / `render_mobile_sprite_group0` / the three atlas flush sites in
metal_gfx.mm) to attribute the 13 uploads per frame, then collapse the duplicate work at its source.

State: the base-upload skip is the only landed L3 change; no fps improvement is claimed and the sprite
path is byte-for-byte the original again (the `SPRITEUPLOAD` probe is removed).
