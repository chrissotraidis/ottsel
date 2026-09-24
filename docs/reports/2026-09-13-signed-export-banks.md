# Signed export banks — host gate and app continuation

Applied default-off banks replace runtime bridge generation with279 immutable64-byte slots and one RW descriptor table.
Actual cold bootstrap binds177 normal,3 process-pointer,4 stack-array,1 nothing and1 zero entries; real reachable Mips2C callbacks bind93 more.
Existing rpc-call normal→stack replacement and Mips2C replay idempotence are preserved.
One generation only; exhaustion and second bootstrap reject before descriptor/counter/text or registry mutation. Warm restart remains unsupported in this experiment.
Host actual-bootstrap/aggregate-module proof: `/tmp/ottsel-export-bank-test/runtime.log`.
Applied-bank ABI proof: `/tmp/ottsel-export-bank-abi-run.log`, provenance `/tmp/ottsel-recovery-2026-09-12/a11-export-bank-abi-applied/sha256.json`.
ABI checks cover normal argument order, pp, stack arrays, Mips2C return/context, stack0/16/256/4096, full q8–q15 preservation, unwind, leaves, exact tags/entry membership and unchanged bank text.
Maintain with `scripts/test-a11-signed-exports.py`, `scripts/test-a11-export-bank-abi.sh`, `scripts/emit-signed-export-banks.py`, and `patches/a11-signed-export-banks.patch`.
Build flag `OTTSEL_SIGNED_EXPORT_BANKS=1` requires signed module mode1/2; exact cached flags reject shell-only mode changes.
First app command: `OTTSEL_SIGNED_GSTATE_EXPERIMENT=2 OTTSEL_SIGNED_EXPORT_BANKS=1 bash scripts/build-ios.sh`.
Root added bounded generation/full-bank logs. Build/install02315601f820be761b5d7983bf7f1163793b157c302c511544bbbc2604325452, PID2671, sole iPad Simulator proves all six banks full279, Gstring/Gstate signed tops returning and exact Gstate references. Normal Training forward/reverse/Cross/neutral samples pass; stopped fault0. Evidence `/tmp/ottsel-recovery-2026-09-12/signed-banks-product-{activation.log,input.log,runtime/}`; screenshot `/tmp/ottsel-video/recovery-signed-banks-product-training.png`.
Other KERNEL/GAME/level modules still use research RX loading. This gate does not prove whole-game signed execution or devices.
