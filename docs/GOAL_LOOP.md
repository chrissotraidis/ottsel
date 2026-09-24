# Ottsel goal loop

This is the only execution authority. It replaces the numbered BOT prompts, `RECOVERY_GOAL_LOOP.md` and
`PROJECT_COMPLETION_PLAN.md`, which now live in [history/](history/). `AGENTS.md` and the user's
current instructions still govern. Read this file and [STATUS.md](STATUS.md); open older material only
when a specific question needs it.

## Goal

Jak 1 honestly playable on a **physical iPad**, running OpenGOAL's own game code compiled ahead of time to
signed ARM64, with no JIT, no writable+executable memory and no runtime code patching, using game data the
player supplies. Then the same on a physical iPhone. This is the original PRD
([jak1-researchloop.md](../jak1-researchloop.md), [02-execution-model-verdict.md](02-execution-model-verdict.md)).

Out of scope: Jak 2/3, App Store submission, a new engine, and polish that no playtest has asked for.

## Where it stands (2026-09-24)

Proven in the **Simulator only**: the strict build runs signed code for 350 of the game's 518 code modules
(KERNEL, ENGINE, GAME, the title, Village1 and Training) and routes title -> New Game -> Training by touch
with input, sound events and background/foreground recovery. The other 168 - the remaining levels' own
code - go through the runtime linker, which writes code into memory and flips it executable (`klink.cpp`,
`kscheme.cpp`). The Simulator allows that; a device does not, so `ottsel_signed_gstate.cpp` refuses
`iphoneos` builds until coverage is complete. `python3 scripts/signed-coverage.py
config/signed-game-strict.json` prints the split. Until 2026-09-24 user packs carried the disc's PS2
DGOs for every level except TIT/VI1, so that level code was silently skipped; packs now carry the
compiled containers. The iPad Simulator presents at ~5-10 fps against 60 on macOS; the renderer
(`src/shell/metal_gfx.mm`) re-implements OpenGOAL's buckets in Metal with CPU-side VU1 emulation and
MERC skinning.

## One round

1. **Preflight.** `df -h / | tail -1` (stop below 40 GB), zero `.git/objects/pack/tmp_pack_*`,
   `git status` clean or explained, at most one booted Simulator, Stage 0 guards green:
   `bash scripts/test-metal-encoder-guard.sh && bash scripts/test-link-begin-args.sh`.
2. **Pick** the lowest open gate below. Work on nothing from a later gate unless it blocks this one.
3. **State** one question, the predicted observation and the single test that decides it.
4. **Change** the smallest thing; add a regression only when it tests a real contract.
5. **Run** the decisive test once on a fresh install. Evidence is what a player would see or hear, or a
   device measurement; a counter or log line alone closes nothing.
6. **Record** at most one evidence file per proven gate (60 lines max, under `evidence/`) and replace the
   STATUS board; its log keeps the last eight lines only.
7. **Commit** exact paths (never `git add -A`). If `out/jak-project` changed, run
   `scripts/snapshot-jak-project.sh write` and commit `patches/ottsel-jak-project.patch` in the same commit.
   Stop only at a clean tree.

Build and drive the current strict lane:

```sh
OTTSEL_SIGNED_GSTATE_EXPERIMENT=0 OTTSEL_SIGNED_MODULE_LIST=config/signed-game-strict.json \
OTTSEL_SIGNED_EXPORT_BANKS=1 bash scripts/build-ios.sh
python3 scripts/replay-ios-normal-route.py <udid>     # Simulator: title -> New Game -> Training
```

## Gates, in order

**G0 Repository hygiene** - *done 2026-09-23.* Work committed; nested source is one verified patch
(`scripts/snapshot-jak-project.sh verify` PASS); one authority; evidence media ignored by git.
Keep it done: every round ends committed and `verify` passes.

**G1 The whole game is signed, and runtime code loading is fatal.** Grow `config/signed-game-strict.json`
(the one strict list) level by
level in play order (Training/Geyser Rock first, then Sentinel Beach, Forbidden Jungle, Misty Island, ...) until
`scripts/signed-coverage.py` reports `unsigned 0`, including load/unload/reload across level
transitions. Add a strict switch that aborts, naming the module, at every runtime `PROT_EXEC` site, so
the Simulator enforces what a device will. *Exit:* coverage exit 0; two strict Simulator runs route to
Training and through one level transition with the switch on and a 0-byte fault log; then remove the
`#error` device guard in `ottsel_signed_gstate.cpp`.

**G2 Runs on a physical iPad.** `OTTSEL_PLATFORM=device` with the strict profile builds for `iphoneos`
into `out/ios-device/`; set `OTTSEL_SIGN_IDENTITY` and `OTTSEL_PROVISIONING_PROFILE` (a free Personal
Team is enough; signing in to Xcode with an Apple ID and attaching the iPad once are the user-owned
steps) and install with `xcrun devicectl device install app`. *Exit:* two cold launches reach Training
on the iPad with a 0-byte fault log.

**G3 Plays at a usable frame rate on the iPad.** Measure presented fps over five minutes of Training on
the device (the Simulator number is not a product measurement). *Exit:* 30 fps or better sustained. If it
misses, profile on device and move the hot work to the GPU the way OpenGOAL's own renderer does
(`merc2.vert`, `tfrag3`/`tie3` shaders); do not add more CPU emulation of PS2 units.

**G4 A real playtest on the iPad.** A person plays from New Game through Geyser Rock into Sandover and
one full neighbouring level: level transitions, touch and a paired controller, save then relaunch and
continue, audible music and dialogue, backgrounding. Anything that stops the playtest (for example the
intro cutscene spool stall) is in scope. *Exit:* a 20-minute recorded session with no crash or soft-lock.

**G5 Fix what the playtest showed**, ranked by how much it hurts play. Visual fidelity work outside that
list waits.

**G6 iPhone device parity** - G2 to G4 on one physical iPhone.

**G7 Reproducible delivery** - a fresh clone + pin + `patches/ottsel-jak-project.patch` + the user's own
disc data builds and runs by following `README.md` alone, and the app bundle carries no game data. Known
gap: `out/ios/zstd-project/CMakeLists.txt` is hand-placed and not generated by any script.

## Held until G4 passes

VoiceOver routing, touch layout editing, per-group volume accuracy, additional phone profiles, sky/eye
fidelity and other polish. Pick one up earlier only if it blocks the current gate.
