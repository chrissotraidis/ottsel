# S2.2 BOT18i: village-load null-call fault (the composed-frame data blocker)

Date: 2026-08-15.  Status: NEW falsifiable fault found and decoded; the fix
(identify + link the null GOAL function) is the next step toward the
composed frame.

## The discovery

The Simulator bundle previously shipped only the title subset (ART.CGO,
COMMON.CGO, TIT.DGO, TIT.VIS).  The game enters the title, then tries to
load the demo village (`vi1.DGO`) -- which was missing, leaving the title
stuck with EMPTY tfrag geometry (all vertices (0,0,0,-1792)).  The build now
copies the full DGO/CGO sets (24 DGOs + 12 CGOs, ~224MB, gitignored local
data), and the game PROGRESSES into the village load.

## The new fault (decoded from the gated handler)

The village load runs the `make-village1-light-kit` chain (mood-tables) and
crashes with a jump to the EE base (pc=0x7000000000, the null convention).
The ARM64 at the caller (lr=0x3eec878):

```
MOV  X6, X1            ; the GOAL function pointer (an EE offset)
...
MOV  X16, X6
ADD  X16, X16, X22     ; X22 = EE base
BLR  X16               ; <- fault: X16 == EE base => the offset was 0
```

So the chain calls a GOAL function whose linked offset is 0 (a null symbol /
unlinked function).  The S2.1-era evidence (s21-game-cgo-simboot.md)
verified the outer chain symbols (make-light-kit, matrix-rotate-y!,
vector-matrix*!, sin/cos, vector ops, mood-shadow functions) as valid; the
null is a deeper call in the chain.  The GOAL source:
`goal_src/jak1/engine/gfx/mood/mood-tables.gc` (make-village1-light-kit ->
make-light-kit -> matrix-rotate-y! / vector-matrix*!).

## Next step

Resolve the caller at lr=0x3eec878 to a GOAL function name (a symbol-table
scan in the gated handler), then identify which called symbol is null and
whether it is a link gap (like the S2.1 title-obs fix) or a data/runtime
issue.  That unblocks the village load -> real tfrag geometry -> the
composed frame through the VU1 interpreter + direct rasterizer.
