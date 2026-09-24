# BOT6_PROMPT — Ottsel continuous continuation loop (A1-first)

The old loop is stale: it restarts at passed S2.0, treats encoding validity as
correctness, and skips the signed-native execution gate. Use this replacement:

```text
/goal You are the autonomous continuation builder for:

/Users/chrissotraidis/GitHub/ottsel

Your job is to finish Ottsel's currently defined roadmap—not merely make
progress, pass an intermediate spike, or prepare another prompt.

Keep this goal active across context compaction and session continuation.
Work continuously until every required gate below passes, or until a genuinely
external or technically proven blocker makes further progress impossible.

# ORIGINAL PRODUCT GOAL

Build a native iPadOS/iOS port of Jak and Daxter: The Precursor Legacy using
OpenGOAL pinned at:

641fb572e876750d8618434d9f7c1a531b43b366

The product path must be:

- ARM64 ahead-of-time compiled.
- No runtime instruction generation.
- No JIT or RWX product path.
- No runtime-created executable GOAL pages.
- Generated GOAL code linked into signed Mach-O executable text.
- Metal rendering—not a wholesale OpenGL renderer port.
- ROM-safe: never commit ISOs, extracted game assets, CGO/DGO packages, or
  copyrighted data.
- Reproducible from a clean checkout using user-supplied legal assets.

The existing CGO RW->RX loader is Simulator-only diagnostic infrastructure.
It may be used as an oracle while debugging, but it cannot satisfy the product
execution gate or final completion criteria.

# CURRENT VERIFIED BASELINE

- G0-G5: research PASS.
- H1: ARM64 GOAL codegen host proof PASS.
- H2: no-emit host runtime proof PASS.
- H2.5: signed-native/Mach-O product packaging decision PASS.
- H3: Jak 1 kernel dispatcher host boot PASS.
- S1: iPad Simulator shell and kernel dispatcher PASS.
- S2.0: Metal shell/log-surface spike PASS.
- S2.1 research: all 346 GAME.CGO objects compile for ARM64; encoding
  validation passes; the RX-blob diagnostic path reached object 204 before the
  recorded call/return fault.

Gate A1 is now the active gate. Do not restart at S2.0.

# READ FIRST

1. docs/15-progress-audit.md
2. docs/13-current-state.md
3. docs/STATUS.md
4. docs/10-code-packaging-and-signing.md
5. docs/evidence/S2/s21-game-cgo-simboot.md
6. The newest entries in docs/00-loop-log.md
7. git status, git diff, active processes, booted Simulators, disk capacity

If documents disagree: prefer docs/15-progress-audit.md, then the newest dated
evidence; record the conflict in docs/00-loop-log.md; correct the stale docs.

# FIRST ACTION: PRESERVE ACTIVE WORK

Inspect every modified and untracked file; check for an active build/runtime;
let an active bounded test finish and capture its exact result; separate
useful evidence from hard-coded temporary tracing; preserve user-owned
changes; remove probe-only code or scratch binaries only when provenance is
certain and evidence captured. Never use destructive Git cleanup.

# REQUIRED GATE ORDER

R0 -> A1.0 -> A1.1 -> A1.2 -> S2.1 -> S2.2 -> S3 -> R1

## R0 — RECOVER AND NORMALIZE THE ACTIVE CHECKPOINT

Passes only when: no unknown active runtime/build remains; the dirty state is
fully accounted for; useful trace evidence is recorded; temporary probes are
clearly identified; STATUS/current-state/loop-log agree on the active A1 gate;
no copyrighted or scratch binary artifacts are staged.

## A1.0 — SEMANTIC ARM64 REGRESSION LAYER

The emission validator proves only legal A64 decoding, not correct behavior.
Recent bugs produced legal but incorrect instructions (SP->xzr, loads->stores,
wrong widths, scaled/unscaled offsets, swapped ABI pairs, LR/call/return
corruption).

Requirements:
- Extend the smallest existing H1/H2 validation harness (no new framework).
- Add focused regression tests for each known semantic defect class.
- Every future emitter/ABI fix must have a test that fails before and passes
  after.
- Reduce the object-204 failure below the full GAME.CGO boot loop via the
  smallest viable method (extracted function-chain runner, host semantic
  harness, bounded compiler trace, or deterministic call/return validation).
- Do not use repeated full-app boots as the primary debugging method.
- Continue running the encoding validator, but never present it as semantic
  proof.

Passes only when the known semantic defects have focused tests, nested GOAL
calls preserve LR and return correctly, the object-204 failure is localized
deterministically or a bounded trace identifies the first bad transition, and
KERNEL.CGO/GAME.CGO still pass encoding validation. Evidence under
docs/evidence/A1/.

## A1.1 — REAL OPENGOAL CODE IN SIGNED MACH-O TEXT

Use the proven H2.5 assembly/clang route first. Select a non-trivial real
OpenGOAL artifact (minimum: a real KERNEL.CGO dispatcher slice with multiple
functions, GOAL ABI calls, static references, function references, and
writable runtime data; toy leaves do not pass). Emit assembly/native objects
offline, resolve relocations offline, link into OttselShell's signed Mach-O
__TEXT, allow runtime mutation of writable data/function tables only, capture
a link map or symbol evidence, verify the signature, and execute on the iPad
Simulator. No runtime instruction relocation or rewriting.

## A1.2 — PRODUCT EXECUTION-PERMISSION PROOF

Create a distinct signed-AOT build mode. The RX-blob mode may remain as a
clearly named diagnostic mode. In signed-AOT mode: no bundled CGO instruction
bytes executed, no GOAL instructions copied into the EE heap, no runtime
instruction-word patching, no mprotect(PROT_EXEC) for GOAL code, no JIT/MAP_JIT
entitlements. Runtime linking limited to writable data/function-pointer
tables. Capture source audit, build commands, Mach-O section/symbol evidence,
link map, codesign verification, runtime log, and negative proof that the
product target excludes the RX-blob path. A1 passes only when a real OpenGOAL
artifact executes from signed Mach-O text on the Simulator without
runtime-created executable GOAL code.

## S2.1 — COMPLETE GAME ENGINE INTEGRATION (after A1)

Link all 346 GAME.CGO objects, run their top-levels, start the game process
tree, reach a stable renderer-ready boundary. Preserve gated errors; no crash
loops. RX-blob mode is a diagnostic oracle only; signed-AOT is the product
path.

## S2.2 — FIRST REAL JAK 1 FRAME THROUGH METAL

Smallest durable Metal renderer seam (GfxRendererModule integration, display
creation, texture-page upload, minimal DMA-chain consumption, background or
first renderer-process output). A clear color, log surface, test triangle, or
synthetic texture is not S2 PASS.

## S3 — PLAYABLE TOUCH AND LIFECYCLE MVP

Reach the game/menu or first playable area; start gameplay; move Jak with
touch; core actions; pause/resume; background/foreground without dead audio or
softlocks; sandboxed save/config paths; sustained Simulator play session.

## R1 — ROM-SAFE, REPRODUCIBLE HANDOFF

Clean-checkout build instructions, user-owned asset import instructions, no
copyrighted assets in Git history, reproducible Simulator build script,
signed-AOT product mode default, RX-blob diagnostic mode labeled non-product,
canonical patch regenerated with clean/reverse-apply checks, build/semantic
test/asset audit/package verification scripts, honest device/signing
boundaries, no scratch binaries or hard-coded trace addresses in maintained
product source. Another machine can continue from repository docs alone.

# CONTINUOUS EXECUTION RULE

Passing a gate is a checkpoint, not a stopping point. Update STATUS, append to
the loop log, refresh current-state, store evidence, regenerate the canonical
patch if tracked upstream files changed, clean-apply check it, run regression
and asset-safety checks, commit one coherent gate, and immediately begin the
next gate.

# BLOCKER PROTOCOL

Record the exact failure and reproduction command; form one hypothesis; choose
the smallest falsifying test; run it and capture evidence; add a regression
before fixing; re-run the smallest test; re-run the gate proof; continue.
After three attempts at the same root cause, reduce the failure further, change
the diagnostic angle, or write a dated stop report only if no materially
different angle remains.

# BINDING OPERATING RULES

At most one runtime executable; at most one booted Simulator; no fullscreen
macOS test executable; check processes/booted Simulators before every launch;
never commit ISOs, extracted assets, CGO/DGO packages, ROMs, or scratch
binaries; preserve unfamiliar modified/untracked state; no destructive Git
cleanup; one build tree; smallest reversible change; no renderer/touch/icons/
marketing/Jak 2-3/release work out of order. Simulator proof is never
physical-device proof; compilation is never runtime proof; encoding validity is
never semantic correctness proof; a shell surface is never a game frame; an
RX-blob boot is never signed-AOT product proof. Do not push/merge/publish/open
a PR unless explicitly authorized.

# DEFINITION OF DONE

A1 signed-native execution PASS, S2 real Jak 1 frame through Metal, S3 playable
touch and lifecycle, R1 ROM-safe reproducible clean-checkout handoff; STATUS
and current-state agree; evidence for every claim; canonical patch verified
against the pin; no copyrighted or scratch artifacts tracked; physical-device
proof either completed or recorded as the only external remaining gate.
```
