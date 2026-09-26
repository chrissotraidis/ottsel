# 05 — Gated roadmap (Phase 2+ for Bot 2)

## North star
A native Jak 1 (OpenGOAL) iPadOS/iOS app that runs ARM64 AOT with no writable-executable CPU memory, imports user-owned assets, and reaches playable Simulator proofs.

## Phase map

```
P0 Research accepted (this repo Phase 1)
  └─ G2 verdict: CONDITIONAL GO
P1 Host ARM64 compiler spine
  └─ Gate H1
P2 Host no-emit runtime spine
  └─ Gate H2
P3 Jak 1 host AOT artifacts
  └─ Gate H3
P4 iOS/iPadOS shell + load path (Simulator)
  └─ Gate S1
P4.5 Signed-native product execution
  └─ Gate A1
P5 First frame / first room proofs
  └─ Gate S2
P6 Touch MVP + lifecycle
  └─ Gate S3
P7 Packaging / safety / handoff
  └─ Gate R1
```

## P1 — Host ARM64 compiler spine
**Goal:** `goalc` can emit real ARM64 for ordinary GOAL functions.

Work:
- implement `do_goal_function_arm64` / asm variant
- implement IR `do_codegen_arm64` methods (currently 41 NYI)
- calling convention, prolog/epilog, stack, calls, branches
- keep x86 path working; add explicit `--isa arm64` (or equivalent) rather than silent host guessing
- expand CodeTester / unit tests on Apple Silicon host

**Gate H1:** compile and run a focused GOAL test suite on macOS arm64 host without throwing NYI.

## P2 — Host no-emit runtime spine
**Goal:** runtime can execute AOT ARM64 GOAL without leaving RWX memory writable.

Work:
- inventory and eliminate runtime instruction writes
- replace `make_function_from_c*` emitters with static shims
- replace mips2c dynamic stubs
- define code map vs data map permissions
- disable listener code-exec paths under a `OTTSEL_NO_EMIT` (name flexible) build flag

**Gate H2:** a host arm64 process runs linked GOAL test code with proof that code pages are not writable after load (memory permission dump / sampler).

## P2.5 — Packaging decision spike
**Goal:** choose code packaging form for iOS before investing in broad game boot assumptions that depend on it.

Work:
- probe Option 1 RX-blob on Simulator
- design Option 2/3 fallback (generated native code in app binary)
- write ADR update in `10-code-packaging-and-signing.md`

**Gate H2.5:** packaging choice recorded with evidence and accepted risks.

## P3 — Jak 1 host AOT artifacts
**Goal:** build Jak 1 game code for ARM64 offline from legal local assets.

Work:
- host tool path for extract+compile (local only)
- determine artifact format (AOT object package vs generated native libs)
- validate symbol/link completeness for boot path
- document exact commands and expected outputs

**Gate H3:** host arm64 runtime boots Jak 1 far enough to prove kernel dispatcher / initial GOAL entry using AOT artifacts. Desktop window is acceptable here.

## P4 — iOS Simulator shell
**Goal:** app target exists and can initialize the no-emit runtime.

Work:
- Xcode/CMake iOS target
- SDL3 iOS wiring
- Documents import stub
- hard-disable REPL/listener
- one simulator at a time

**Gate S1:** iPad Simulator launches app, runtime init succeeds or fails with explicit gated error (no crash loop), logs captured.

## P4.5 — Signed-native product execution
**Goal:** prove the H2.5 product decision with a real OpenGOAL artifact before
renderer and touch investment expands.

Work:
- add semantic ARM64/ABI regression tests for legal-but-wrong encodings
- emit a non-trivial real KERNEL.CGO dispatcher slice as assembly/native objects
- link generated code into the app's signed Mach-O `__TEXT`
- resolve instruction relocations offline; retain runtime data relocations only
- keep the existing CGO RW→RX loader as Simulator-only diagnostic infrastructure

**Gate A1:** the signed-AOT app executes the real artifact on the iPad
Simulator; `otool`/link-map and `codesign` evidence show generated GOAL code in
signed executable text; the product target does not copy/patch instructions
into anonymous memory or call `mprotect(PROT_EXEC)` for GOAL code.

## P5 — First frame / first playable proof
**Goal:** render something real from Jak 1 systems on Simulator.

Work:
- graphics backend decision spike (Metal product path; optional GLES dead-end check)
- audio init optional but recommended
- asset import of host-prepared legal package

**Gate S2:** evidence of either first rendered frame from game renderer or a clearly defined intermediate milestone approved in STATUS (but default target is first frame). No fake clear-color-only “victory” without stating it as a subgate.

## P6 — Touch MVP + lifecycle
**Goal:** playable control loop and suspend/resume safety.

Work:
- touch overlay controls for Jak 1 core actions
- controller support if cheap
- background/foreground pause seam
- save path in sandbox

**Gate S3:** start game, move Jak with touch, pause, background/resume without dead audio/softlock (Simulator evidence).

## P7 — Packaging / safety / handoff
**Goal:** another machine can continue.

Work:
- ROM-free package scripts
- `.gitignore` for assets/ISO/extracts
- BUILDING docs
- remaining-work list with honest external blockers (device signing, store policy if unresolved)

**Gate R1:** clean checkout instructions + Simulator proof references + no copyrighted assets in git tree.

## Explicit non-goals for early phases
- Jak 2 / Jak 3
- online multiplayer features
- texture pack marketplace
- upstreaming pressure before host proofs
- App Store submission

## Ordering rule
If a later phase looks fun but H1–H2.5–H3, S1, or A1 are red, stop and return
to those gates. The Simulator RX-blob transport cannot satisfy A1.
