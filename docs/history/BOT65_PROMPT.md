# BOT65 - Sky fan texture identity, then whole-frame parity against the macOS oracle

## Why this round exists (BOT64 lane correction)

BOT64 concluded: "the iOS shell hand-rolled a VU1 interpreter; run the desktop's
mips2c VU1 programs instead and port the opengl_renderer runner." Recon this
round refutes that as the *world-geometry* blocker:

| | desktop | iOS shell |
|---|---|---|
| static world geometry | prebuilt `out/jak1/fr3/*.fr3` (`tfrag3::Level`) | prebuilt `<userdata>/fr3/<level>.fr3` -- SAME FILES |
| who loads it | `opengl_renderer/loader/Loader.cpp:249` | `src/shell/metal_gfx.mm:1342-1360` `load_mobile_level()` |
| who draws it | `TFragment`/`Tie3`/`Merc` | `metal_gfx.mm` tfrag/tie/merc producers |
| Mips2C refs in the drawing code | **zero** in `game/graphics/opengl_renderer/**` | `register_all_jak1()` only (`src/shell/ios_boot.cpp:1985`) |

The desktop does not get world geometry out of VU1 emulation; it consumes
prebuilt tfrag3 data. The shell already consumes the same prebuilt data and
already draws it. VU1/mips2c is relevant only to dynamic effects (particles,
ocean, shadow, blit, merc animation, the sky quad), most of which the shell
already reimplements directly in Metal.

So: stop looking for a missing VU1 engine. The shell is a parallel renderer
that already renders the world. Close its remaining per-class defects.

## Measured state at BOT65 start

- iPad, own eyes, `/tmp/ottsel-look2/vu-rot.png` (2026-09-11 20:41): textured
  Village1 terrain, huts, palms, water, Jak shaded blue/tan, Jak controllable.
- macOS oracle, own eyes, `/tmp/ottsel-diag/mac/v1crop2.png`: same scene with a
  blue sky.
- Dominant defect = the sky. 20:35 frame is 29.9% near-black plus a 26.1%
  hard-edged pure-yellow wedge with a diagonal boundary.
- Sky submission is healthy and is NOT the defect: `SKYFRAME batches=44`,
  pre-world block `metal_shell.mm:1464-1465` is entered, and `SKYBOUND` shows the
  fans reaching the drawable at `ndc=(-4.000,-4.009)..(4.000,3.991)`.
- The sky blend itself produces a populated dest, not a black one:
  `OTTSEL SKY BLEND: dest tbp=0x1f80 32x32 bytes=4096 nonzero=4087 peak=254 mean=134`
  and `dest tbp=0x1fa0 64x64 bytes=16384 nonzero=16384 peak=252 mean=119`.
- One measured abnormality to keep in view: the sky source `tbp=0x10` (32x32,
  `cbp=0x50`) reads an **all-zero CLUT block** from the shell's VRAM mirror,
  while `tbp=0x14` (`cbp=0x4c`) and `tbp=0x20` (`cbp=0x40`) read real CLUTs.

## Gate S1 - the falsifiable question for this round

**Does the sky fan sample the blended sky texture, or something else?**

The shell submits sky fans from `submit_mobile_native_sky_bucket()`
(`src/shell/metal_gfx.mm:4038`), which appends
`primitive.texture->data()` with the decoder's own width/height. The desktop's
`SkyRenderer` instead draws the fans with `tex0: tbw=1, th=5, hw=5, sky-base-block`
through a `DirectRenderer`, i.e. the texture is the **blended sky dest**
(`tbp 0x1f80`/`0x1fa0`), not a level texture.

Method (one probe per run - see the probe rule below):

1. Log, once per frame for the first 8 sky submissions, the fan's resolved
   `tex0`/`tbp0`/`psm`/`cbp` and whether it equals `0x1f80` or `0x1fa0`.
   Compare against `decoder.native_tex0_last` which is already tracked.
2. If the fan samples the blended dest, the defect is UV/tint/blend math in
   the fan and the next experiment is the fan vertex/UV chain.
3. If the fan samples a level texture or a raw VRAM block, the defect is fan
   texture identity and the fix is to bind the blended dest for the sky fans.

Exit bar: name the exact tbp the fans sample. Either answer is a result; a
missing log is not.

## Probe rule (learned the hard way, 2026-09-11)

Diagnostic probes are one-shot trigger files that set a **sticky** flag, and the
`SKYCOPY` probe path allocates a fresh `MTLBuffer` per frame
(`src/shell/metal_shell.mm:1532-1550`). Four cumulative sky probes armed together
produced a GOAL-space type-tag fault at 20:24 that does not occur with zero
probes armed (210 s clean run, `fault before: 0` / `after ~90 s: 0` /
`after ~210 s: 0`, process alive throughout).

**Arm one diagnostic probe per run.**

## Ladder after S1 (in order, do not skip)

1. **S2 sky fan geometry/UV/blob** - land the fan on the blended dest and confirm
   a blue-gradient sky in a fresh inspected frame with a SHA-256.
2. **S3 camera/tilt parity** - the 20:41 frame reads as a tilted ground plane with
   Jak floating off a cliff; compare the camera matrix against the macOS oracle
   before touching `set_mobile_tie_camera` math (still frozen without a proven
   source mismatch).
3. **S4 audio RPC/lifecycle I2**, then **S5 PS2 touch I3**, then **S6 iPhone P1**,
   then **S7 physical device D1**. These stay queued behind S1-S3.

## Exit bars that do not move

- One fresh **inspected** Simulator frame with SHA-256 per experiment.
- Paired no-Merc / no-TIE controls so a fix cannot be a coincidental overdraw.
- 0-byte fault log, signed-native, ROM-safe, non-JIT.
- Never claim playability from a build, a log, a counter, a title screen, a first
  frame, or a Simulator-only result.

## Hypotheses that are stale and must not be re-litigated

- "Village1 is frozen" (BOT60) - refuted; consecutive frames differ.
- "the sky block is skipped" - refuted; it is entered and 44 batches are submitted.
- "the VU1 interpreter works" in gameplay (BOT57) - the interpreter's numbers that
  round were the title spool; in gameplay chains it emits `xgkicks=0 gif=0`.
- "zero PCM" (BOT35/BOT37) - refuted; sustained `pcm-peak` 5921-10000.
- "sky region 88.4%" (BOT58) - that was the yellow HUD banner, not sky coverage.
