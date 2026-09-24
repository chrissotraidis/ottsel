# P1: the 667x375-point phone profile passes the accepted route once its data is imported - 2026-09-23

G2.5's remaining piece.  Question: does the accepted route hold on the older phone profile?

**The profile is real and its surface is the documented one.**  A fresh iPhone SE (3rd generation)
simulator (created as "Ottsel iPhone SE3", 7357D8E4-245A-4500-8123-77ECA72A4425) logs
`OTTSEL TOUCH: class=phone surface=667x375 min-region=37x43 safe-lrtb=0x0x0x0` - exactly the
667x375-point profile the loop names, and that device reports no safe-area inset.

**The first run found a data-import gap, not a profile defect.**  Installed with an empty container the
lane boots, serves its modules and keeps a 0-byte fault log, but never reaches `title-wait-ready`: it
loops with 2638 `OTTSEL STR: chunked animation not found name=ndi-intro` warnings, loads no FR3 level,
and its only scene-level samples are empty.  The iPad lane's container holds 1.5 GB of
`OttselUserData`; the phone's held none.  Copying the accepted data (`OttselUserData` contents plus
`OpenGOAL` saves/settings) into the phone container makes the same binary reach `title-wait-ready` and
route normally, so the missing user-data family is what stalled it.  The failure mode is a silent loop
that names nothing, which is exactly the G2.6 question and is recorded there.

**With the data present the accepted route holds.**  title -> NEW GAME -> CONTINUE WITHOUT SAVING ->
Training: `scene-level='village1'` then `'training'`, 346 SIGNED MODULE ENTER = 346 RETURNED, 0-byte
`ottsel-fault.log`, and the save menu draws the copied save's own metadata (`GEYSER ROCK 9/22/2026
18:21`, `0%`, `EMPTY`, CONTINUE WITHOUT SAVING, BACK) at 667x375 with no clipping in the capture.
The in-level frame is clean and the sky renders, matching the iPad lane's composition.

**Named, not fixed: the fan's first-frame garbage on this profile.**  In the title's first seconds the
sky fan draws whatever the registry holds for its key: a live `ottsel-trace-sky-skip-draw` A/B at that
same early moment moves 329322 pixels (94.227% of the frame, mean |delta| 120.1).  The new SKY SHAPE
fields show why the honest fix is not the obvious one: the fan's setup packet names `tbp0 0x0` - the
level's own sky page, real sky data - while the composite this lane produces lives at 0x1f80/0x1fa0, so
the fan legitimately renders the level's sky (`drawn=as-sky`, blue in-level, from the same key), and
only its first frames are unresident.  Two gates were tried and refuted in the same session: requiring
the producer's composite (`composite-ready`), and requiring the fan's key to name a composite
destination - the second would remove the legitimate in-level sky (measured `fan-tbp=0x0` with the fan
both drawn and skipped), so the landed code keeps the verified condition and logs
`composite-ready` / `fan-tbp` / `fan-psm` / `own-composite` as observability.  The residency defect
is carried forward as its own item.

Also landed with the probe work: the SkyBlend destination constants (`kSkyDims`/`kSkyTbp`) moved to
file scope so the bucket and the producer share one definition, and `g_mobile_sky_composite_ready` is
maintained by the producer and cleared on level selection.

Not claimed: no physical-device, audio or playability claim.
