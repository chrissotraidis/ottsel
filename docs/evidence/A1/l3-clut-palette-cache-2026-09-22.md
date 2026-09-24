# L3: the texture decode fetches each palette entry once instead of per pixel - 2026-09-22

Gate: L3 (cadence).  Follow-on from `l3-bounded-per-frame-logging`, where `decode_texture_pixels_raw` had
become the largest identified app leaf (330 of 3535 chain+main samples, 9.3%).

**What the decode was doing.**  Every CLUT format branch (PSMT8/`0x13`, PSMT4/`0x14`, PSMT4HL/HH/
`0x24`/`0x2c`) walked the texture pixel by pixel and, for each pixel, computed the palette address through the
PSMCT32/PSMCT16 swizzle and fetched the entry through the `get_clut32`/`get_clut16` lambdas - each of which
does a bounds check, flips the `reading_clut` flag, updates the CLUT read window and memcpys four bytes.
A 64x64 texture therefore re-fetched the same handful of palette entries thousands of times.

**Change.**  Each CLUT branch now keeps a small lazily-filled table (`u32 clut_cache[256]` with a
`bool clut_cached[256]` companion for PSMT8, `[16]` for the 4-bit formats) and a `clut_for(index)` helper:
the first use of an index computes its address and fetches it exactly as before, later uses read the cached
word.  The addresses actually read - and so the CLUT window the decode memo records for invalidation - are
**exactly** the ones the per-pixel path read, because the same indices are requested in the same pass; only
the repeat fetches are gone.  The texel fetch (`get8`) is untouched, so the texel window is unchanged too.

**Measured** (driver route into the training level, then a 4 s `sample`; same protocol as the previous
document):

| leaf | before | after |
|---|---|---|
| `decode_texture_pixels_raw` | 330 (9.3%) | **89 (2.4%)** |
| `gfx_texture_upload_now` | 94 (2.7%) | 78 (2.1%) |
| `access` | 216 (6.1%) | 166 (4.5%) |
| `capture_mobile_merc` | 91 (2.6%) | 92 (2.5%) |
| `_platform_memmove` | 137 (3.9%) | 151 (4.1%) |

chain+main totals 3535 and 3679, so the decode falls 3.7x in absolute samples on the same workload.

**Correctness.**  Decoding is colour-critical, so it was checked visually as well as by counters: the training
level still renders the same scene with the same palette - the armoured character with the orange companion,
the wooden log, the cyan mosaic bridge edge, palm foliage, rocky terrain, red fruit and purple enemies
(`/tmp/ottsel-clut-level.png`) - and `OTTSEL GFX: decoded texture 512x256 ...` still reports sane decodes,
`ottsel-fault.log` is 0 bytes and 346 modules enter and return.

**Next.**  `access` is now the largest remaining identified leaf (4.5%) and is spread across the main loop's
own trigger polls, `presentRGBA:` and the nested particle launcher; `_platform_memmove` 4.1% is next, mostly
the per-frame mesh/upload copies.

Not claimed: no fps number - these are sample shares in a fixed state, which is what this host's load
behaviour supports.
