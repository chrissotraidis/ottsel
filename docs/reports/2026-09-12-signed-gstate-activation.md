# Complete signed Gstate activation — isolated host gate

PASS: `python3 scripts/test-a11-gstate-activation.py`.
Stage rehearsal evidence: `/tmp/gstate-signed-activation/maintained-verification/`.
The runner regenerates/verifies the genuine module, compiles current bootstrap/
linker/helpers, links the existing host runtime and executes only the host fixture.
No Simulator, app, product loader or product allocator was changed by this gate.

Actual full bootstrap follows init_output→InitHeapAndSymbol and reserves the
global heap tail before allocation. Function Type0x1bfec4 matches signed headers.
All seven genuine prerequisite tops execute in KERNEL order: gcommon,gstring-h,
gkernel-h,gkernel,pskernel,gstring,dgo-h. Real state inherits protect-frame.

Complete signed Gstate top registers four exact functions: inherit-state0x8000134,
enter-state0x80002d4, send-event-function0x8000a94, looping-code0x8000c04.
Production method_set installs state.new0x8000004 and state.print0x8000244.
Wrong-Type and active-reload requests reject before data writes or execution.
All32KiB signed Gstate code/tags remain byte-identical; codeRX and dataRW verified.

A genuine typed call fetches state.new from the actual Type method table and
passes its documented eight arguments on an arena-backed stack: global symbol,
state Type, interned name, and five real nothing-function values. The constructor
uses the real global allocator; result0x4fd154 has state Type0x1c2af4, size36,
and the requested name. No constructor, Type, allocator or method semantics stubbed.

This is explicitly mixed-runtime dependency proof. The linked zero-fill __ARENA
starts maxRW; original prerequisite RX sealing failed EACCES and instruction
fetch faulted. The fixture verifies ownership of the complete128MiB zero-fill
segment, then replaces only that range with anonymous RW memory BEFORE bootstrap.
Linked labels remain unchanged; actual maximum protection becomesRWX, permitting
research-runtime prerequisite seals. Signed Gstate stays outside the replacement
in immutable __GOAL with maxRX. No MAP_JIT or no-runtime-emission claim is made.
First-failure logs remain under `/tmp/gstate-signed-activation/`.

The fixture source/driver, all genuine input hashes, binary hash, commands,
build.log and activation.log provide the continuation record. Build tools and
existing h1 runtime archive are prerequisites; output files remain under /tmp.
Product opt-in integration, general unload/reactivation, signed dependencies,
whole-game signed-code execution and physical-device acceptance remain open.

## Product-loader integration follow-up
The default-off product path is now applied. Root maintained `scripts/test-a11-gstate-loader.py` passes actual link_and_exec interception, genuine registrations/typed allocation, compiled valid? function/basic/#f acceptance and wrong-Type/interior/64-bit-alias rejection. Unsupported call-stack/heap modes and bad protections reject with child-side data/heap immutability checks. See `/tmp/ottsel-recovery-2026-09-12/gstate-loader-applied/activation.log`.
Active ARM64 `(mi)` regenerated546 targets; KERNEL contains exact new gcommon c18831eb2a50fd30c088be1679fc179bd24bf282f0e6c205ca89d286788a38e6, Gstate object SHA remains unchanged. Default research buildb34ad619 reached normal Training with zero fault bytes; this does not exercise the opt-in loader. Opt-in build initially rejected macOS-only mach_vm_region at compile time; vm_region_64 preserves the same protection checks and host loader regression passes again. Hash-matched c224b0aeda91329ab1ee83bb43e644f9c066e4ce3df5eb2d452c8bbd4990885a, PID91684 reached normal-route Training with zero fault bytes. Screenshot `/tmp/ottsel-video/recovery-signed-gstate-product-training.png`, logs `signed-gstate-product-runtime/`. Signed initializer return was not logged, so direct activation observability is being added before accepting this product gate. Do not combine standalone Gstate/Gstring arena objects; aggregate data reservation is separate work.

Product activation proof: build/install6cc5e92efb57416fa01f1298abd7833f202ed0d96c63b27f300e055cefb20233 emits SIGNED GSTATE ENTER/RETURNED. Main0x8000000, top0x8004004; all four functions and both methods exactly match the offsets above. Source SHA is exact; loader protection/Type/hash guards precede this call.
Fresh normal menus reach Training; held forward/reverse/Cross each followed by neutral samples. Fault bytes0 at stop. Evidence `/tmp/ottsel-recovery-2026-09-12/signed-gstate-observed-{activation.log,input.log,runtime/}`; screenshot `/tmp/ottsel-video/recovery-signed-gstate-observed-training.png`. This closes this one-module Simulator activation gate, not whole-game signed execution, visual acceptance or physical devices.

Aggregate host extension: applied two-module Gstring→Gstate loader passes root `test-a11-gstate-loader.py ... --aggregate` at `aggregate-loader-applied/activation.log`. Genuine Gstring length/equality operations and exact registrations pass, followed by Gstate typed constructor/validity checks; both modules' every text/tag segment stays unchanged. Per-module order/hash/size/Type/protection/reload guards pass. Aggregate Simulator build/install399dea2331dd4f36ad80bbffb701517ca8262dcd932d156814fb0e52c40e7697, PID98237 now reports both signed tops returned and exact Gstate registrations/methods. Normal Training controls with neutral releases pass; stopped fault0. Evidence `aggregate-product-{activation.log,input.log,runtime/}`, screenshot `/tmp/ottsel-video/recovery-aggregate-product-training.png`. Other kernel/game code still uses research RX loading.

Gcommon extension (2026-09-13): root actual-loader `--gcommon` and combined279-bank tests pass under `/tmp/ottsel-recovery-2026-09-12/gcommon-{loader,banks}-applied/`. Genuine release-debug source remains authenticated, debug code omitted, three address references resolve to GOAL zero. Its exact signed top registers compiled `valid?`; malformed/runtime-debug/reload guards reject before mutation, all three module text/tag snapshots remain unchanged. Legacy and pair compatibility pass. Mode3 fresh appbf7ac085 installed with matching SHA and signed Gcommon top0x8018004 returned, followed by Gstring/Gstate and all279 banks. PID6540 reached normal Training and accepted forward/reverse/Cross/neutral; inspected Training screenshot still shows material/Sky defects, fault0 at stop. Evidence `signed-gcommon-product-{activation.log,input.log,runtime/}`.

Full-KERNEL applied host gate (2026-09-13): canonical gcommon/gstring-h/gkernel-h/gkernel/pskernel/gstring/dgo-h/gstate,631 checks; with279 signed export slots657 checks. All205 entries,1426 linked references and six pair-tagged RW relocations pass. Actual signed process.new/process-tree.new/change-parent create and reparent a process; all eight signed tops return and code stays immutable. Root evidence: `/tmp/ottsel-recovery-2026-09-12/kernel-loader-applied/` and `kernel-banks-applied/`. This host gate does not exercise live dispatcher scheduling or GAME/level execution. Explicit-list app build/cache wiring and pre-SDK rejection checks are applied; full app9ea8a4ca/PID18187 now passes hash-matched install, all eight tops/279 banks, normal Training and recorded jump/forward/reverse/release, fault0. Actual app all1426 codewords pass; `kernel-full-product-*` evidence under the recovery directory. GAME/level signed execution remains open.
