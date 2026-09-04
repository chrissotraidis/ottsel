# R1 post-title producer-family trace — 2026-08-22

## Gate

Check the source-side texture family immediately after a fresh title-wait
marker and Start, without remapping TBP or changing camera/shader/Metal policy.

## Run integrity

- One signed `com.ottsel.shell` build, one booted iPad Pro 11-inch (M4)
  Simulator (`08636791-2675-4675-8335-EF72EF954DCF`), one runtime.
- Disk gate: 101 GiB free; zero `.git/objects/pack/tmp_pack_*`; no live
  Simulator recording after capture.
- Fresh title-wait marker was created after relaunch. Start was accepted and
  the bounded MIPS2C 3D trace completed with a zero-byte fault log.
- The earlier corrected full route remains the authoritative exact-route
  proof; this capture isolates the post-title producer window.

## Raw source result

The fresh post-Start lookup prefix was page 2 indices `54,49,48,42,44`, all
resident hits. The same producer window emitted raw IDs `0x00203600`, repeated
`0x00203100`, `0x00201200`, and `0x00203000`, plus the non-page-2 `0x4080xxxx`
family. AdGif logs resolved those IDs without a page-directory or allocation
failure; page 2 retained directory length 1610, entry/page length 55, and the
same segment destinations 601152/632576/633664.

The matching native consumer record in the validated Village1 capture is
`TBP=9478 (0x2506)`, `TEX0=0x2004d0e59930a506`, 64×64. The completed macOS
Village1 phase instead reaches its first accepted world family at
`TBP=9458 (0x24f2)`, `TEX0=0x2004d1e59930a4f2`, 64×64. The producer-selected
family/order differs before native composition; this is not a lookup miss.

## Visual boundary

Fresh screenshot:
`/var/folders/b1/t1t38j255k53b4j97j63gfkh0000gp/T/com.openai.sky.CUAService/Simulator Screenshot 2026-08-22 at 2.51.59 PM.jpeg`

Fresh bounded video: `/tmp/ottsel-video/r1-post-title-producer-family-1452.mp4`.
The frame has substantial Village1 imagery but a large horizontal seam,
missing/incorrect regions, and debug touch blocks. It is visibly partial and
not honestly playable; build, logs, and first frames are not completion proof.

## Verdict

R1 remains OPEN. The falsifiable next slice is producer phase/chain ownership
at the first post-title 3D handoff, including source table identity and DMA
ordering. No TBP remap, camera change, shader change, or Metal policy change is
justified by this result.
