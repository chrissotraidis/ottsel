# G1 round 1: Training's code signed, and levels now load their compiled code - 2026-09-24

Question: with `training-obs` and `training-part` added to the signed list, does the strict Simulator build
route to Training running that code from signed text?

**Finding first: level code was never running.** The user pack copied the disc's `DGO/` family, and the app
overlays only the build's own `TIT.DGO`/`VI1.DGO`. Every other level therefore loaded Naughty Dog's PS2
objects, which the DGO shim drops: the 2026-09-23 iPad log reads
`OTTSEL DGO RPC: skip non-GOAL obj 0 (training-obs, 21760 bytes, tag=0x0)` and the same for
`training-part`. Training (and Misty during the intro) ran with geometry and engine actors but none of
the level's own GOAL code - consistent with the earlier "no Training dialogue" reading.

**Changes.**
- `scripts/prepare-user-data-pack.sh` overlays the containers compiled on this machine
  (`out/jak-project/out/jak1/iso/*.DGO`, 25 files; override `OTTSEL_BUILT_DGO_DIR`) on the disc `DGO/`
  family. The pack stays outside the repo and the app bundle.
- `config/signed-game-strict.json` = the 348-module control list + `training-obs`, `training-part` (350).

**Run.** Full strict build (`OTTSEL_SIGNED_MODULE_LIST=config/signed-game-strict.json`, banks 1, exit 0;
the new generation pruning cut `signed-gstate/` from 111 to 3 generations, disk 44 -> 58 GiB). New pack
`/tmp/ottsel-user-pack-g1-1790238445` validated (its `TRA.DGO` sha256 `4f39347d...` = the build's), imported
into iPad Pro 11-inch (M4) `08636791`, fresh launch with `OTTSEL_TRACE_INPUT=1`,
`replay-ios-normal-route.py` rc 0.

    SIGNED MODULE ENTER:    name=training-obs  entry=0x8c24004 source=522faea0...
    SIGNED MODULE RETURNED: name=training-obs  ...   OTTSEL LINKBEGIN: signed took training-obs
    SIGNED MODULE RETURNED: name=training-part ...   OTTSEL LINKBEGIN: signed took training-part
    348 ENTER = 348 RETURNED; GAMEPLAY: enter training x2; scene-level='training' x13; fault log 0 bytes

`/tmp/ottsel-g1-tra-training.png` shows Jak in the Training level (grass, warp gate, cliffs, palms).

**What the new data exposed.** With compiled containers, code the app used to skip now runs through the
runtime linker. In this route that is 22 unsigned Misty Island modules loaded by the intro (`misty-obs`,
`misty-part`, `misty-conveyor`, `misty-teetertotter`, `misty-warehouse`, `mistycannon`, `muse`, `mud`,
`babak-with-cannon`, `balloonlurker`, `bonelurker`, `quicksandlurker`, `evilbro`, `sidekick-human`,
`battlecontroller`, `blocking-plane`, `collide-reaction-racer`, `racer`, `racer-part`, `racer-states`,
`target-racer`, `target-racer-h`). The other 99 `legacy fallback` names are art/texture objects or
same-named art twins of signed code. Coverage: `signed-coverage.py config/signed-game-strict.json` ->
518 / 350 / 168.

Not claimed: in-level play, audio, or whether the intro cutscene stall changes now that Misty's code runs.
Next: sign `MIS.DGO`'s code modules.
