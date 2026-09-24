# G1 round 2: Misty's code signed; streamed levels load in play order - 2026-09-24

Question: with `MIS.DGO`'s 22 unsigned modules appended to `config/signed-game-strict.json` (372), does
the strict route still reach Training with no Misty code going through the runtime linker?

**Two loader contracts were wrong for levels** (`game/kernel/common/ottsel_signed_gstate.cpp`):

1. `signed module order mismatch` - `link()` required the previous list entry to be loaded. The intro
   streams Misty before Training, so list order cannot be play order. `link()` now takes
   `streamed` (default false); only the `link-begin` hook in `klink.cpp` passes true, so KERNEL/GAME
   keep the strict order while level containers load in whatever order the game asks.
2. `source size mismatch` on `evilbro` - `MIS.DGO` carries only the 144672-byte `evilbro` art group; the
   53565-byte code lives in other levels. Art (v2/v4 link data, first word `0xffffffff`) is now declined
   and left to the data linker; a `GOAL` code object that does not match still aborts.

Both rejections were fail-closed `abort()`s whose reason goes to stderr only; `simctl launch --console-pty`
captured them (`--stderr=` writes inside the Simulator).

**Coverage meter corrected.** `scripts/signed-coverage.py` now counts a member as code only when its body
equals the compiled `.o` (name matching counted art twins). Strict list: 518 / 372 / 146; MIS 21/21, TRA
2/2, VI1 12/12, TIT 2/2, KERNEL/ENGINE/GAME complete.

**Run.** Host `test-a11-gstate-loader.py --module-list config/signed-kernel-full.json`: PASS, 0 FAIL. Full
strict build exit 0; iPad Pro 11-inch (M4) `08636791`, fresh launch, `replay-ios-normal-route.py` rc 0:

    369 SIGNED MODULE ENTER = 369 RETURNED; fault log 0 bytes; app alive after ~2 min
    GAMEPLAY: enter title x2, village1 x3, misty x1, training x2; scene-level='training' x18
    legacy fallback: 107 names, none of them unsigned code (all textures/art)

`/tmp/ottsel-g1-mis-training.png`: Jak in Training; new translucent diagonal shafts over the scene (level
effect or sprite artifact - not yet identified).

Open for G1: module **reload** (`link()` still aborts on a second load of the same module, so returning
to a level will abort), the remaining 146 modules, and the fatal runtime-`PROT_EXEC` switch.
