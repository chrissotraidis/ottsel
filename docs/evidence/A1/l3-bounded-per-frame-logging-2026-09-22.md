# L3: the per-call diagnostics that dominated the log are bounded - 2026-09-22

Gate: L3 (cadence) plus the standing rule that diagnostics are bounded.  A fresh 4 s sample of the training
lane (1664 chain-walk samples) put `decode_texture_pixels_raw` (276) and `access` (191) at the top, with
`__write_nocancel` at 70 - so the next question was what the lane is writing.

**Counting the log first.**  Grouping the last 6000 lines by shape gave:

```
5014  OTTSEL SPRITE METAL: native World2D atlas vertices=... sprites=... textures=... atlas=WxH
 345  OTTSEL SPRITE FRAME: n=... drawn=...
 193  OTTSEL MERC MATRIX LEDGER: model=eichar-lod0 ...
 192  OTTSEL MERC SHADE LEDGER: model=eichar-lod0 ...
 192  OTTSEL MERC MOD LEDGER: model=eichar-lod0 ...
```

So 83% of the log was one line written **per sprite-atlas call**, several times a frame, for values that
change call to call; and the three eichar ledgers were ungated per packet, one of them (SHADE) scanning the
whole MERC vertex pool each time.

**Change.**  The atlas line reports the first eight calls and then one call in ninety (my first attempt -
"log when the values change" - was wrong and refuted by the rebuild: the values change every call, so it
logged every call).  Each eichar ledger is capped at eight lines per process, and the shade ledger's scan is
inside that cap, so the pool scan runs eight times instead of every packet.  Findings these ledgers produced
are already recorded in `evidence/A1`, so nothing is lost.

**Measured.**  Two comparable windows (driver route into the training level, then a 4 s sample):

| metric | before | after |
|---|---|---|
| log bytes written | 6.20 MB | **1.81 MB** |
| atlas lines per 6000 | 5140 | **326** |
| `__write_nocancel` leaf | 70 (1.7%) | **27 (0.8%)** |
| `decode_texture_pixels_raw` | 276 (6.7%) | 330 (9.3%) |
| `access` | 191 (4.7%) | 216 (6.1%) |

The unchanged leaves *rise* in share because the totals fell (chain+main 4104 -> 3535), which is what removing
work from the same thread does.

**Correctness.**  The lane still reaches `scene-level='training'` through the maintained driver, still draws
its sprites (`SPRITE FRAME ... drawn=10` at close, atlas sizes reported in the surviving lines),
`ottsel-fault.log` is 0 bytes and 346 modules enter and return.

**Next from the same sample.**  `decode_texture_pixels_raw` is now the largest identified app leaf (9.3%) and
`access` is 6.1%, spread across the main loop's own trigger polls, `presentRGBA:` and the nested particle
launcher.  Those are the remaining bounded targets.

Not claimed: no fps number; these are share and volume measurements in a fixed state.
