# I1.1f — Direct texture registry was never populated

Gate: I1 (iPad scene correctness). Experiment: I1.1f. Date: 2026-09-11.
Installed SHA before/after: `8ca711c9…` / `512ad025…`

## Question

The three live sky blend sources report `registry=0`. Is that a missing
upload, or a lookup keying mismatch?

## Method

One bounded NSLog in the existing `sky_source_dumps < 3` block printing
`reloc-size`/`key-present`/`meta-size`, plus a one-shot census of every
`g_direct_texture_metadata` entry below dest `0x200`; then one bounded source
change, one relink, one install, one launch.

## Evidence

- Before: `reloc-size=4` with `meta-size=478`, `key-present=0` on tbp
  `0x10`/`0x14`/`0x20`. The keyed cache held only the three relocated pages
  and the two generated sky buffers, so **every** Direct draw fell back to a
  raw GS-VRAM decode.
- The census (`OTTSEL SKY META`) lists 64 records below dest `0x200`;
`dest=0x20 64x64 psm=19 cpsm=0 clut=0x30` is present, so the record exists.
- The ADGIF agrees with the record on tbp (`0x20`) and differs on the CLUT base
  (`cbp=0x40` vs record `clut=0x30`). A raw decode therefore reads the wrong
  palette; a record decode reads the right one.
- After: `reloc-size=486`, `key-present=1` on all three sources, and
`OTTSEL SKY BLEND: source from registry tbp=0x10 key=0x1013` (and `0x1413`,
`0x2013`). Sky sources now come from the game's own texture records.
- Generated destinations: `tbp=0x1f80 32x32 nonzero=4096/4096 alpha-peak=251`,
`tbp=0x1fa0 64x64 nonzero=16384/16384 alpha-peak=250`.
- `ottsel-fault.log` 0 bytes; app stable at PID 91342.
- Composed frame at `/tmp/ottsel-video/f.png` (SHA-256 prefix `4a32d23cb53da428`,
`nonblack(mx>40)=0.5603`) shows textured Village1 huts, roof tiles, palms and
water. The sky region still reads as background clear colour.

## Result — PASS (structural), sky content still OPEN

The registry was genuinely unpopulated, not mis-keyed, and that is now fixed:
upstream `TexturePool` keys its slots by `tex.dest[mip]` exactly as native
`handle_upload_now` does, and native now mirrors the slot contents the way
`TexturePool::copy_texture_data` exposes them. The fix is byte-budgeted at
256 MiB, and all three consumers (sky blend, IR decode, native Direct) validate
width/height/rgba before use.

The generated sky buffer is still not a sky gradient, so **I1 stays OPEN**. The
remaining suspect is record selection: `g_direct_texture_metadata` is keyed by
`dest` alone, so any page reusing `dest=0x20` overwrites the entry and the
draw can resolve a different texture than the one the ADGIF intended.

File: `src/shell/metal_gfx.mm` — registry insert in the `handle_upload_now`
direct-upload loop; `OTTSEL SKY REGISTRY` / `OTTSEL SKY META` diagnostics.

## Next

Give the metadata map texture provenance (page + tex index) so a `dest` reused
by several pages cannot alias, and confirm the sky record is the one the ADGIF
meant before touching the blend math.
