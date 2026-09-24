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

Proven in the **Simulator only**: all 518 code modules are signed, `OTTSEL_STRICT_EXEC` makes runtime code
loading fatal, and the strict build plays the whole intro to Geyser Rock on OpenGOAL's real IOP/OVERLORD
with a 0-byte fault log. The `iphoneos` build compiles and links; installing it needs the user's Apple ID
and iPad (G2).

Renderer: OpenGOAL's **own OpenGL renderer** is the only renderer, on OpenGL ES 3.0. Its 92 shaders are
cross-compiled at build time by
`scripts/translate-gl-shaders.py` (glslang + SPIRV-Cross: `brew install glslang spirv-cross`), and
`game/graphics/ottsel_gles_compat.h` maps the few desktop-only GL calls. The title screen matches the
macOS build and the whole intro plays to Geyser Rock on it ([evidence](evidence/G3/upstream-gl-renderer-title-2026-09-24.md)).
The custom Metal renderer (~25k lines, CPU VU1 emulation, broken particles) was deleted on 2026-09-24; its
last state is commit `df31425`. The Simulator's GL is a CPU rasterizer (1-10 fps, game resolution capped
at 800 px wide there), so frame rate is measured only on the device.

## One round

Rule that follows from how this project drifted: run OpenGOAL's own subsystems (IOP/OVERLORD, loaders,
game code) exactly as desktop does. Do not emulate a subsystem or patch GOAL around a symptom; find why
the upstream path fails on iOS and fix that.

1. **Preflight.** `df -h / | tail -1` (stop below 40 GB), zero `.git/objects/pack/tmp_pack_*`,
   `git status` clean or explained, at most one booted Simulator, Stage 0 guards green:
   `python3 scripts/translate-gl-shaders.py out/jak-project/game/graphics/opengl_renderer/shaders /tmp/ottsel-es`
   `&& bash scripts/test-link-begin-args.sh`.
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

**G1 The whole game is signed, and runtime code loading is fatal** - *met 2026-09-24 (Simulator).* Grow `config/signed-game-strict.json`
(the one strict list) level by
level in play order (Training/Geyser Rock first, then Sentinel Beach, Forbidden Jungle, Misty Island, ...) until
`scripts/signed-coverage.py` reports `unsigned 0`, including load/unload/reload across level
transitions. Add a strict switch that aborts, naming the module, at every runtime `PROT_EXEC` site, so
the Simulator enforces what a device will. *Exit:* coverage exit 0; two strict Simulator runs route to
Training and through one level transition with the switch on and a 0-byte fault log; then remove the
`#error` device guard in `ottsel_signed_gstate.cpp`.

**G2 Runs on a physical iPad.** User-owned once: sign in to Xcode with an Apple ID (a free Personal Team
is enough), connect and trust the iPad, enable Developer Mode. Then
`scripts/install-ios-device.sh <pack-directory>` finds the identity, has Xcode create the development
profile if needed (generated stub project), builds the strict `iphoneos` app, installs it, copies the
pack into the app's Documents and launches it. *Exit:* two cold launches reach Training on the iPad
with a 0-byte fault log.

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
