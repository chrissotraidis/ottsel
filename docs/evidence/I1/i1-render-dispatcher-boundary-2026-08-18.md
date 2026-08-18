# I1 renderer dispatcher boundary — 2026-08-18

## Scope

One rebuilt iPad Pro 11-inch (M4) Simulator run. No macOS `gk` process was
running. The app was launched through the Simulator host:

```sh
xcrun simctl install 08636791-2675-4675-8335-EF72EF954DCF \
  out/jak-project/out/ios/app/OttselShell.app
xcrun simctl launch --terminate-running-process \
  08636791-2675-4675-8335-EF72EF954DCF com.ottsel.shell
```

The app was then terminated with `simctl terminate` before any desktop work.

## Observed result

The live Simulator surface was black with only the shell's small loading
indicator. The dispatcher did not crash: `village1` and `title` were active,
and the log reached a real nonzero TFRAG entry:

```text
OTTSEL VU1DRAW: imm=0x6 top=0x0 ...
OTTSEL VU1DRAW: result executed=50000 capped=true pc=1694 xgkicks=0 gif=0
OTTSEL VU1STAT: chain=900 vu1-runs=5976 capped=5886 xgkicks=0 ... draws=0
```

The corrected VU setup state was present (`vf3 = 0x2a0, 0x350, 0x2a0,
0x350`), so this is not the previous MFIR lane/shift defect and not a failure
to reach the TFRAG producer.

## Decision

Do not replay the stashed scratchpad source bytes through the ordinary VIF
decoder: the current shell disables that path because it overwrites live VU
memory. The initial bridge had captured the wrong `tfragment+32` payload
field. The corrected bridge captures the actual mips2c `spad_to_dma` result:
64 qwords copied into fake scratchpad `0x1d0010`. Its first qwords are TFRAG
metadata and pointers, not VIF/DMA instructions. A subsequent bounded
`spad_from_dma` trace proves the mips2c builder emits VIF DMA buffers carrying
`MSCAL 0x6`; the shell consumes that dispatcher call without its frag-header
upload at VU address zero. The next probe is output-buffer ordering and VIF
state lifetime, then a nonzero GIF/XGKICK packet before changing more buckets
or treating the diagnostic rasterizer as a renderer pass.

The supplied `OttselShell` dyld crash report is unrelated to this run: it is
the expected result of launching a Simulator binary directly outside its
Simulator environment (`DYLD_ROOT_PATH not set`).

## VIF and sprite progress

Processing zero-qword VIF control tags restored `BASE`/`OFFSET` state and
produced six XGKICKs, two nonempty GIF outputs, and a composed raster frame.
The next trace showed that the GIF stream is primarily two-vertex `SPRITE`
primitives; the shell had dropped them because it accepted only triangles.
Sprites now expand to two triangles and the signed Simulator build executes
that path. The live surface remains black, so sprite texture decoding or final
presentation content—not absence of geometry—is the next bounded gate.

The focused PSMT8 texture/CLUT trace then ruled out empty sprite textures:
the sampled 16x16 pages contain nonuniform RGBA data. Their GIF coordinates
cover only tiny HUD/debug elements, while the generated strips are nearly
transparent. The next renderer gate is a scene-bearing TFRAG/TIE/Merc bucket,
not further sprite work.
