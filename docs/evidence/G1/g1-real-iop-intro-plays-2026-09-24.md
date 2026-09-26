# The real IOP runs on iOS and the whole intro plays - 2026-09-24

Question: the user reported the intro "doesn't work at all" and "nothing works". Why, at the root?

**Root cause.** The iOS boot never started OpenGOAL's IOP/OVERLORD thread (it was dropped for the
August headless milestone and never restored). `sif_ee.cpp` faked the level, cutscene-art, ramdisk and
sound RPCs, and a string of GOAL workarounds papered over the gaps. The decisive one was in
`sequence-a-village1.gc`: "sequence B unavailable; entering normal play" - the intro was *skipped*, and
`mis.gd`/`game.gp` moved Evil Bro/Sis art into Misty because the fake IOP never loaded the intro level.

**Change.** iOS now runs the desktop IOP path, like macOS:
- `game/ottsel_ios_iop.cpp` (new): Jak 1 `iop_runner` equivalent, started by `ios_boot.cpp` before
  `InitMachine`; vblank from `sceGsSyncV`. `build-ios.sh` compiles the IOP kernel, the 12 missing
  overlord files and libco (`OTTSEL_NO_IOP=1` keeps the old emulation for comparison only).
- IOP-emulation guards in `sif_ee.cpp`, `kmachine.cpp`, `srpc.cpp`, `ssound.cpp`, `ios_stubs.cpp` moved
  from `OTTSEL_IOS` to `OTTSEL_NO_IOP`; Deci2 stays off on iOS; the shell no longer starts sound itself.
- `fake_iso` reads the pack's family folders; the project path is the app container (IOP memcard).
- Packs carry the compiled `CGO` too. Reverted to upstream: `sequence-a-village1.gc`, `mis.gd`,
  `game.gp`, `loader.gc` (its forced spool evictions corrupted in-flight STR RPCs:
  `RPC_STR` read `chunk_id=0x0D068544`).
- Signed loader: streamed modules may reload (data reset from `initial_data`, as a desktop relink).

**Run** (strict build, iPad Pro 11-inch (M4) `08636791`, fresh pack, New Game via route driver):

    title -> village1 (sequence A, Samos narration, real VAG clock) -> misty (sequence B, human Daxter)
    -> village1 (Samos's hut) -> training: Jak + ottsel Daxter at the Geyser Rock warp gate
    fault log 0 bytes, app alive after ~9 min, 14 SIGNED MODULE RELOAD, 0 unsigned code at runtime

Stills: `/tmp/ottsel-intro3-t2.png` (title card), `/tmp/ottsel-intro4-p3.png` (Misty, human Daxter),
`/tmp/ottsel-intro4-p5.png` (Samos's hut), `/tmp/ottsel-intro4-q.png` (Geyser Rock).

Measured along the way: the VAG stream clock advances at audio rate (~1024 units/s); `STALL-ART` lines are
normal transient waits; `#<invalid object #x1>` in that trace is the literal 1 (owner alive).

Not fixed: particle/sprite rendering (blue/purple rotated striped quads during cutscenes), 146 unsigned
level modules, frame rate, and a human listen of the narration. Host loader test PASS; Stage 0 PASS.
The committed source drops the bounded `OTTSEL VAG POS` trace used in these runs.
