# Gate A/C evidence - the app is parked in the intro; the player mesh stops being submitted

> **PARTLY REFUTED 2026-09-11 by BOT43.** Three claims below are disproven by
> re-measurement on the same device: the app *does* leave the intro
> (`enter village1` then `enter misty` then `enter training`; the scene-level
> ledger reads `village1`), host input *does* reach the shell, and the player
> mesh *does not* stop being submitted (`merc-submits` rises one per frame).
> The camera and scene are live. See
> `docs/evidence/I1/BOT43-camera-live-sprite-defect.md` for the corrected state.
> The rest of this document is retained as measurement history, not current fact.

Measured 2026-09-11 on iPad Pro 11-inch M4 Simulator,
UDID `08636791-2675-4675-8335-EF72EF954DCF`, bundle `com.ottsel.shell`,
binary `9ed4a91f01fff23337c2fbf58335c7519f363b88080003d7976044a49c674d01`.
`ottsel-fault.log` 0 bytes at every check.

## Refuted: the Village1 clip-z framing

`capture_mobile_camera` gates the clip ledger on
`level == "village1" && g_mobile_eichar_village_clip_logs < 32`
(`src/shell/metal_gfx.mm:1482`). It is a bounded 32-sample probe that fires
only during the ~6 s title->Village1 window, then stops. It is not a per-frame
trace, so "byte-identical every frame" was the cap, not a frozen camera. The
samples also carry the title perspective, which reproduces the recorded
`z=-1.044, x=0.49..1.37, y=-0.42..0.64` analytically. Transition artifact.

## Proven: the player mesh stops being submitted

`OTTSEL MERC NAMES` (trigger `ottsel-trace-merc-names`, re-touchable):

| time | logo-english-lod0 | eichar-lod0 | submits |
|------|-------------------|-------------|---------|
| 54:36 | 484 | 313 | 4862 |
| 54:42 | 532 | **313** | 4910 |

The player mesh freezes while other models keep arriving. Over a ~10 min
launch, `eichar-lod0` is submitted 313 times, all inside the transition.
`sidekick-lod0` stops at the same point.

## Proven: the app is still in the intro

`OTTSEL MERC NATIVE` resolves every model that keeps arriving to level
`title`: `logo-english / logo-black / logo-volumes-english / ndi / ndi-cam /
ndi-volumes` (`levels/title/title-obs.gc`, `dgos/tit.gd`). `OTTSEL STR:
loaded LOLOOP.STR chunk=N` streams an endless 17-chunk cycle every ~65 s;
`LOLOOP` is the intro-camera logo loop
(`out/jak-project/goal_src/jak1/game.gp:381`). Village1 TIE/TFRAG geometry
does render (textured grass, cliffs, waterfall, huts, palms), so scene
correctness is not the blocker.

## Proven: input and log health

- `OTTSEL MOBILE INPUT` fired exactly once in a 10 min run
  (`source=lifecycle`). Synthesized Simulator clicks and `System Events`
  keystrokes produced no SDL events.
- The hermetic trigger works: `ottsel-press-start` was consumed by the loop
  (`src/shell/main.cpp:980-1040`). This is the route-driving path for BOT42.
- `ottsel-runtime.log` reached 545 MB in ~1 h and grew 18 MB per 15 s
  (~1.2 MB/s) with no rotation and no default-off guard.

## Next falsifiable question

Does a single `ottsel-press-start` change observable game state, and does the
transition to gameplay re-submit `eichar-lod0`? If the model never returns,
the cause is upstream of the renderer: the intro never completes, or the actors
are never loaded for the destination level.
