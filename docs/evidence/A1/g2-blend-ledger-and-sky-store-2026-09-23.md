# G2.2 items 1-2 closed by measurement: the sky store publishes, and only the sky asks for additive - 2026-09-23

Question (item 1): where are the Sky batch store's two submitted strips lost, and is the block meant to
draw at all?  Question (item 2): which live sites actually request an additive blend, so that additive
pipeline states are landed only where a ledger proves them?

Method: one accepted route on this source (346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte
`ottsel-fault.log`), reading the NSLog ledgers from the unified log and decoding the register values with the
port's own enum (`common/dma/gs.h:419-428`: 1 = `SRC_DST_SRC_DST` = source-over, 2 = `SRC_0_SRC_DST` =
additive) and `src/shell/mobile_blend_policy.h`.

## Item 1: the store is not losing anything

    SKYSTORE probe=1 begin=1 append=40 publish=1 rollback=0 empty-publish=0 empty-replace=0
             published-batches=40 pre(building=0 completed=40 active=0) snapshot=40
    SKYSTORE probe=3 begin=1 append=34 publish=1 rollback=0 empty-publish=0 ... snapshot=34
    SKYSTORE probe=5 begin=0 append=0 publish=0 rollback=0 ... snapshot=34

Every frame the producer runs, the store begins, appends every batch and publishes with
`published-batches == snapshot` (40 then 34), `empty-publish=0` and `rollback=0`; on a frame where the
producer does not run the previous snapshot is still there (34), not an empty store.  So the "submitted=2
but the published store reads empty" reading does not reproduce on this source and there is no lost
strip to chase.

Related correction: the 2026-09-22 "this block never executes" reading no longer holds - the same run logs
`SKYLOOP` 72 times, `SKYBOUNDFRAME` 9 and `SKYFRAME` 334 (`SKYLOOP frame=1 batches=40 textured=36`), so
`docs/evidence/A1/g2-sky-batch-path-inert-2026-09-22.md` is superseded on this source.

## Item 2: additive is only ever requested by the sky

| site | ledger line | what the live population requests |
| --- | --- | --- |
| Sky | `SKYREG-MIX arm=2 n=40 ... r0=0x44:4 r1=0x48:36 other=0` | 0x44 source-over and 0x48 additive only |
| Sky draw | `SKYBLEND additive-drawn=32 unspec=0 source-over=4 additive=32 unsupported=0` | every additive-keyed batch is already drawn additively (32/32) |
| TIE | `TIEREG draws=200 enable=196/4 blend=196/4 preset=0,199,0,0,1,0,0,0` | preset 1 (source-over) 199-200 of 200; **preset 2 (additive) 0 of 600 across three windows** |
| Direct | `DIRECTREG-MIX arm=2 n=464 r0=0x0:464 other=0` | no ALPHA register written at all (0x0 = `Unspecified`, not a copy) |

So the loop's TIE premise - that `draw.mode >> 24` collapses the additive enum value 2 into source-over -
has no live population to fix: 0 of 600 TIE draws request preset 2, and the population that does request
additive (the sky) is already drawn additively, which is exactly the "only where the ledger proves it" rule.

The decode itself is regression-covered: `bash scripts/test-mobile-blend-policy.sh` -> `PASS 12/12`
(including the FIX-set forms, `S/S/S/S` as copy, and the three unsupported combinations).

## The carried-forward sky item: the fan is not what fills the title's sky

Same run, same probes.  The fan's own line (`OTTSEL SKY SHAPE`, an `lg::info` line in
`ottsel-runtime.log`) reports `drawn=skipped` with `after-setup-qwc=6` for all 57 title-window samples and
`drawn=as-sky` with `qwc=5` for the 67 in-level ones - so the fan does not draw at the title, yet the title's
sky region shows diagonal purple bands in one capture and bright facets 6 s later.  Two A/Bs bound what that
means: at the title a no-op A/B 6 s apart already moves 62.8% of the sky band (mean|delta| 44.1) because the
scene animates, so a capture diff there attributes nothing; in-level the scene is stable (no-op A/B 0.66% of
the frame, mean|delta| 0.78) and `ottsel-trace-sky-skip-draw` moves only 0.25-1.02%, so the fan is a thin
band, not the sky fill.  Next: name what fills the title's sky (the sky-bucket store, whose `SKYSTORE` line
publishes 40 batches, or the Direct path) with a frame-matched A/B at a static moment.

## What is left in G2.2

Item 3 (dynamic MERC eyes) and the carried-forward sky item above; HUD/menu was closed as correct earlier.

