# BOT51 — the route reaches training gameplay; the player actor is never drawn

Proven 2026-09-11 against a continuously-running `com.ottsel.shell` on the booted
iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`, HEAD
`c66a139`, tree clean apart from the four untracked BOT46/BOT48 docs. Disk 9.2 GiB
free, zero `.git/objects/pack/tmp_pack_*`. No source edits, so no rebuild.

## Proven: the menu route completes into gameplay

Injected through the file-trigger input contract, verified from the container
`ottsel-runtime.log`:

1. `ottsel-press-start` -> PC title menu, `OTTSEL PROGRESS: entering screen=27 state=27`.
2. `ottsel-press-cross` -> `save-game-title` list, `screen=18`.
3. `down` x3 -> `OTTSEL PC PROGRESS: edge screen=18 index=0 -> 1 -> 2 -> 3`.
4. `cross` at index 3 -> two `****** CALL TO kopen() ******`, then
   `OTTSEL PCSETLEV: levels -> 'none' 'village1'`, `'misty'`, `'training'`,
   `begin load training-vis [tra.DGO]`, `GAMEPLAY: enter training`.

Exit-bar note: the correct `CONTINUE WITHOUT SAVING` branch is index **4**
(`out/jak-project/goal_src/jak1/pc/progress-pc.gc:2842`), so this run took the
save-slot branch one short of the intended one. Correct that in the next route run.

## Proven: gameplay HUD text renders

A fresh frame over the loaded training level shows `FIND THE CELL ON THE PATH` and
`GEYSER ROCK`. BOT46 had only proved menu text, so this extends text legibility to
the gameplay objective banner.

## Proven: the presented frame is animating, not frozen

Spaced screenshots 3 s apart differ, and two back-to-back bursts produced 13 distinct
images in about 2.5 s. The earlier "frozen frame" reading came from sampling twice
inside one presented-frame window.

## Proven: the player actor is not submitted by the game

`ottsel-trace-merc-names` on the whole run:
`distinct=29 submits=132397 eichar-submits=401`, with `eichar-lod0 packets=401`.
Every eichar packet belongs to the title/village1 phase; the training phase submits
`scarecrow-a-lod0` (18540), `scarecrow-b-lod0` (7416), `money-lod0` (33689) and
`crate-wood-lod0` (33529) and no eichar.

Because `g_mobile_merc_name_counts[name]` increments at `src/shell/metal_gfx.mm:1633`,
before any model lookup, this is the game not submitting the player, not the mobile
renderer dropping him.

## Candidate cause: the target process is suspended

`OTTSEL PROGRESS: request screen=0 allowed=#t target=#<target target suspended
:state target-stance :stack 224/1024 :heap 34832/49152 @ #x1f6434> existing=#f`

The sequence-B fallback fires at
`out/jak-project/goal_src/jak1/levels/village1/sequence-a-village1.gc:277`
(`OTTSEL INTRO: sequence B unavailable; entering normal play`), and it issues
`(start 'play (get-continue-by-name *game-info* "game-start"))`. The falsifiable
question for BOT51 is why the target still reads suspended after that.

## Carried measurements

- Pacing: `SUBMITSTAT` chain 13860 -> 16470 across `[28:28]`..`[33:52]`, about
  8.1 chains/s in training; village1 measured ~9.5. `raster-draws=0` in most lines.
- Character transform (stale, last at `[03:47]` chain 970, level village1):
  `MERC MATRIX LEDGER model=eichar-lod0 slots=79 valid=79`
  `source-bounds=(-7127.006,-1893.693,-5243.745)..(7099.166,13293.536,5202.778)`
  `skinned-bounds=(10166.861,-11565.121,-50536.234)..(24067.197,7414.107,-37709.477)`
  `first-tmat-translation=(-15882.562500,-5357.578125,47290.937500,1.000000)`.
  Skinned z is negative while the bone translations are positive; the `px -= tx * weight`
  accumulation at `src/shell/metal_gfx.mm:1740-1742` is the first suspect.
- Audio is alive: `OTTSEL AUDIO: mixed 48000 frames, pcm-peak=16383`, with
  `breath-in-loud`/`breath-out-loud`/`jak-stretch` player RPCs firing.
- `ottsel-fault.log` is 0 bytes for this run; no `presentRGBA:` or
  `_MTLCommandEncoder` crash observed.
- Diagnostic defect: `ottsel-trace-native-merc` prints
  `bounded PC_PORT ledger armed` and then logs no VALID and no ignored entry even
  though merc packets keep flowing. Explain before trusting that probe.
