# G2.2 item 2: the GS ALPHA decoder and the additive Sky state, landed and gated - 2026-09-22

Gate G2.2 item 2.  Question: the ledger proved the live Sky cloud batches request ALPHA 0x48
(S/Z/S/D = `(Cs-0)*As + Cd`) while the shell drew every blended batch through the source-over
`directBlendPipeline`.  Land the decode and the additive state at that proven site, prove the change
with a matched capture, and leave every other path untouched.

**Landed.**  `src/shell/mobile_blend_policy.h` decodes the GS ALPHA register's four 2-bit sources
(`common/dma/gs.h`: a=bits0-1, b=bits2-3, c=bits4-5, d=bits6-7, `fix=data>>32`) into the six
combinations the desktop's DirectRenderer supports plus an explicit `Unsupported`, and treats a zero
register as `Unspecified` (both native capture paths reset the decoder's draw state before walking a
bucket, so zero means the bucket wrote no ALPHA_1 - not a decoded copy).  `metal_shell.mm` gains
`directAdditivePipeline` (`rgb: SrcAlpha/One/Add`, `alpha: One/Zero`) and the Sky site now selects
`directPipeline` (opaque) / `directAdditivePipeline` (0x48) / `directBlendPipeline` (everything else)
from the batch's own register.  The Direct site now carries `diagnostic_alpha` too (plumbing only;
its selection is unchanged, because a Direct bucket reports 0 = no register seen).

**Regression (host, no device).**  `bash scripts/test-mobile-blend-policy.sh` compiles
`test/mobile_blend_policy_test.cpp` with `xcrun --sdk macosx clang++ -std=c++20` and checks the six
desktop combinations, 0x00 as `Unspecified`, a FIX-only register as `Copy`, 0x48/0x44 with FIX set,
and three values the desktop rejects: **PASS 12/12**.

**Live selection (one run, iPad Pro 11-inch M4, strict signed profile).**
```
SKYBLEND register-drive=0 additive-drawn=0  unspec=0 source-over=6 additive=31 unsupported=0   <- default
SKYBLEND register-drive=1 additive-drawn=31 unspec=0 source-over=6 additive=31 unsupported=0   <- gate on
```
The 31 additive-key batches are switched; the 6 source-over-key (0x44) batches are never switched, and
the key mix matches `SKYREG-MIX` (0x48 on the textured cloud tiles, 0x44 on the untextured full-screen
strips).  The gate is `ottsel-trace-sky-blend-register`, re-read every pass so both states can be
captured in one run at one camera and one time-of-day.

**Matched capture (static Training camera, same run, seconds apart).**  Region x 0.85-1.0, y 0.15-0.40
of the 1668x2420 capture (151855 px) - the visible sky in the rotated frame:
```
default (source-over):  85.882 / 88.208      register-driven (additive): 110.523 / 111.669
cross-state diff: 47.163% of the region's pixels changed by >24, mean|delta| 50.46/channel,
                  box (1417,363)-(1667,967) = exactly the measured region
```
Visually the sky strip is black under source-over and light blue under the additive equation
(`/tmp/ottsel-g22/train-so-1.png` against `train-add-1.png`).  Tool:
`scripts/measure-png-region-mean.py` (region mean, or two captures to diff).

**Why the gate is on by default (no product behaviour changed).**  The village1/title backdrop's sky
tiles decode to garbage colour data on this lane.  `SKYREG-MIX` shows the whole sky population's
vertex colours are grey 0.5 (some vertices black), so the colour comes from the *texture*; additive
blending then turns that pre-existing artefact from muted into vivid (alternating sweep pair
`/tmp/ottsel-g22/sweep/a15.png` additive against `b15.png` source-over, 1 s apart, same camera: the
same large cloud quads, vivid rainbow against muted dark).  The Training level's sky decodes
correctly and is strictly improved by the change, so the gate exists only until the village1 sky
texture/CLUT decode is fixed.

Not claimed: no default behaviour change, no fix for the village1 sky texture defect, no playability,
audio or device claim.  Evidence for the ledger this builds on:
`evidence/A1/g2-live-blend-register-ledger-2026-09-22.md`.
