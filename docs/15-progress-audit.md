# 15 — Progress audit and realignment

Date: 2026-08-09. Scope: repository-wide review of the research, gate docs,
implementation, patch state, evidence, and current S2.1 debugger work.

## Verdict

**The project is technically on track, but the execution order drifted off the
product path.** Keep the ARM64 compiler/runtime work, S1 proof, Metal spike, and
GAME.CGO progress. Do not start the renderer port, touch controls, or packaging
handoff until the signed-native execution model chosen at H2.5 is proven with a
real OpenGOAL artifact.

The Simulator RX-blob path is useful research infrastructure. It is not the
iOS product execution model and must not be described as one.

## What is solid

- H1, H2, H2.5, H3, and S1 have concrete commands and evidence.
- S2.0 is honestly scoped as a Metal shell/log-surface spike, not a game frame.
- GAME.CGO now compiles for ARM64 and its 346 objects pass encoding validation.
- Simulator linking advanced to object 204, exposing real ABI, emitter,
  relocation, mips2c, and heap-integration defects.
- The upstream pin, no-asset boundary, one-runtime rule, one-Simulator rule,
  and windowed-only host rule have been preserved.
- The canonical OpenGOAL delta is kept in
  `patches/h3-jak1-host-boot.patch`; work is committed in small checkpoints.

## Findings that require realignment

### A1 — H2.5 selected signed Mach-O, but S1/S2 still execute RX blobs

`docs/10-code-packaging-and-signing.md` explicitly selects generated native
code compiled by clang into the signed app. It also says the runtime RX-blob
path is Simulator research only and should not expand into S2 content work.

The current app instead bundles `KERNEL.CGO` and `GAME.CGO`, copies their code
into the EE mapping, patches it, and uses `mprotect(..., PROT_EXEC)` before
calling it. That is a good compatibility probe, but it does not prove the
chosen product path. First-frame, touch, and handoff work would compound risk
on an execution model that normal iOS devices may reject.

**Decision:** insert Gate A1 before more S2 runtime/renderer expansion.

### A2 — Syntax validation is passing while semantic ARM64 defects remain

The emission validator catches illegal A64 words. Most recent defects emitted
perfectly legal but wrong instructions: STR instead of LDR, xzr instead of sp,
scaled LDRH offsets, swapped ABI argument pairs, and return/control-flow
corruption. A 3.8-million-word syntax PASS therefore does not imply correct
codegen.

**Decision:** every emitter/ABI fix now requires a focused semantic regression
test. The current object-204 fault must be reduced below the full GAME.CGO boot
loop before more one-off fixes are accepted.

### A3 — The source-of-truth docs became stale and contradictory

- `README.md` still said build work starts at Bot 2.
- `STATUS.md` still said H1 was active and contained multiple stale S2 rows.
- `13-current-state.md` had a Bot 3 date while later S2 updates were appended.
- `BOT5_PROMPT.md` said GAME.CGO loading and 15 IRs were still unproven after
  both claims had changed.
- The roadmap omitted a gate for the signed-native integration it had already
  selected as the product path.

This audit updates the read-first route and creates `BOT6_PROMPT.md` as the
current continuation loop.

### A4 — Debug probes are accumulating in the product shell

The current dirty worktree contains a deliberately temporary signal-handler
experiment plus assembly/object probes. Preserve it until the current run is
understood, but do not commit hard-coded addresses and large fault-time dumps
as the permanent debugging architecture. Capture the evidence, convert the
failure into a deterministic test or bounded trace tool, then remove the
probe-only code and scratch artifacts.

## Corrected gate order

| Gate | Purpose | Exit bar |
|---|---|---|
| **A1.0** | Semantic ARM64 regression layer | The recent legal-but-wrong emitter/ABI defects have focused tests; the object-204 failure is reproducible below a full GAME.CGO boot or by a bounded deterministic trace |
| **A1.1** | Real signed-native artifact | A non-trivial real OpenGOAL artifact (minimum: linked KERNEL.CGO dispatcher slice, not a toy leaf) is emitted as assembly/native objects, linked into the iOS app's Mach-O `__TEXT`, code-signed, and executes on the Simulator |
| **A1.2** | Product-path permission proof | The A1 target has no CGO code copied into executable anonymous memory, no runtime instruction patching, and no `mprotect(PROT_EXEC)` path; only writable data relocations remain |
| **S2.1** | Resume engine integration | GAME.CGO links all 346 objects and reaches a stable game-process/renderer-ready boundary in the research transport, with fixes covered by regression tests |
| **S2.2** | First real game frame | A frame produced by Jak 1 game systems is presented through a narrow Metal backend on the Simulator |
| **S3** | Touch and lifecycle | Start, move, pause, background, and resume on the Simulator |
| **R1** | ROM-safe handoff | Clean-checkout instructions, reproducible build/package checks, verified canonical patch, and honest device/signing boundaries |

The RX-blob Simulator transport may remain alongside A1 as a diagnostic oracle.
It cannot satisfy A1, physical-device proof, or the product completion claim.

## Immediate next action

1. Let the current dirty object-204 experiment finish; capture its exact
   result without overwriting it.
2. Checkpoint or discard only the probe-specific changes after preserving the
   useful evidence.
3. Execute A1.0, then A1.1/A1.2.
4. Resume S2.1 only after A1 passes.

The paste-ready loop is `docs/BOT6_PROMPT.md`.
