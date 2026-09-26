# G1: every code module signed; strict exec holds through the intro - 2026-09-24

Question: with all of Jak 1's compiled code in the signed list and runtime code loading made fatal, does
New Game still play through to Geyser Rock?

**Change.** `config/signed-game-strict.json` grows from 372 to all 518 code modules (the 146 added in play
order: Sentinel Beach, Forbidden Jungle, ... ). `OTTSEL_STRICT_EXEC` (klink.cpp): a v3 object with code that
reaches the runtime linker aborts with its name instead of being made executable. `build-ios.sh` turns it on
for every device build and on request (`OTTSEL_STRICT_EXEC=1`) for the Simulator; device builds no longer
hit the `#error` guard unless strict is off.

**Measured.** `python3 scripts/signed-coverage.py` -> `518 signed, 0 unsigned` (exit 0). Build: all 518
modules emitted and linked (app binary 23 MB -> 34 MB). Strict Simulator run (iPad Pro 11-inch (M4)
`08636791`, fresh pack, New Game):

    title -> village1 -> misty -> village1 -> training; levels added: village1 x2, misty, intro, training, beach
    STRICT EXEC aborts 0; 68 streamed modules taken by the signed loader; 14 reloads; fault log 0 bytes
    the 138 remaining "legacy fallback" names are art/texture objects (no code, so strict does not fire)

`/tmp/ottsel-strict1-end.png`: Jak and ottsel Daxter at the Geyser Rock warp gate.

Limits: levels not on this route (Jungle, Snowy, Citadel, ...) are signed but not yet loaded in a run; a
strict abort there would name the module. Physical device still untested.
