# G2.2 item 1: the Sky batch store is not losing the submitted strips - 2026-09-22

Gate G2.2 item 1.  Question (re-scoped after the premise check): the live Sky decode reports
`candidates=2 ... submitted=2` while the published store was reported to read empty, so name where
those two strips are lost.

**Answer: they are not lost.**  A ledger inside `OttselMobileDirectFrame` (`debug_take`/`debug_sizes`
in `src/shell/mobile_direct_frame.h`) plus one bounded `SKYSTORE` record per consumption window
(`src/shell/metal_shell.mm`, the draw pass' `_skyFrameStore.snapshot()` site, eight lines per process)
shows every publish reaching the snapshot the pass consumes:

```
SKYSTORE probe=1 begin=1 append=2  publish=1 rollback=0 empty-publish=0 empty-replace=0
                 published-batches=2  pre(building=0 completed=2  active=0) snapshot=2
SKYSTORE probe=2 begin=1 append=40 publish=1 rollback=0 empty-publish=0 empty-replace=0
                 published-batches=40 pre(building=0 completed=40 active=2) snapshot=40
SKYSTORE probe=4 begin=1 append=34 publish=1 rollback=0 empty-publish=0 empty-replace=0
                 published-batches=34 pre(building=0 completed=34 active=40) snapshot=34
SKYSTORE probe=6 begin=1 append=2  publish=1 rollback=0 empty-publish=0 empty-replace=0
                 published-batches=2  pre(building=0 completed=2  active=34) snapshot=2
```

`empty-replace` counts a publish that retires a non-empty ready population with an empty one - the
signature of the empty-bucket clear dropping already-submitted strips.  It is 0 in every window, as are
`rollback` and `empty-publish`, so no clear ever overtook a submitted population.  Two runs
(21:09:57 and 21:13:10 on the same install, iPad Pro 11-inch M4 `08636791-...`, strict signed profile
`config/signed-game-cgo-tit-vi1-control.json`) are identical.

**The earlier "the block never runs / the store reads empty" premise was a log-channel artifact.**
The records that premise used are `NSLog` (unified log): `SKYLOOP`, `SKYBOUNDFRAME`, `SKY ALPHA`,
`SKY ENCODE`, `SKYFRAME`.  `ottsel-runtime.log` carries only the port's `lg::info` records
(`OTTSEL SKY PRODUCT`, `OTTSEL SUBMITSTAT`, `OTTSEL DIRECT FRAME`).  Measured in one run:

| record | `ottsel-runtime.log` | unified log (`simctl spawn log show`) |
| --- | --- | --- |
| `SKYLOOP` | 0 | 24 (`frame=1 batches=2 textured=0 small=2` ... `frame=5 batches=34 textured=28`) |
| `SKYBOUNDFRAME` | 0 | 3 (`n=40`, `n=34`) |
| `OTTSEL SKY PRODUCT` | 8 | - |

The Sky batch draw block is live: `SKYLOOP frame=1 batches=2`, then `batches=40/40/34/34`, and
`SKY ENCODE batches=2 n=3 blend=1 ... col=(0.00,0.50,0.50,0.50) tex=1x1` on the first textured frame.
So G2.2 item 1's question is answered by refuting its premise: the strips are published, consumed and
encoded, and the block the previous round called inert has been running all along.

**Consequence.**  The store and its clears are not the renderer defect, so item 1 needs no renderer
change (none was made).  The live population's blend registers were measured next - see
`evidence/A1/g2-live-blend-register-ledger-2026-09-22.md`.

Not claimed: anything about the blend equation, the MERC-eye or HUD/menu items, or playability.  The
ledger is observability only; no rendering behaviour changed.

