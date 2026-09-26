# 10 — Code packaging & signing options (iOS)

Research date: 2026-08-07

## Why this document exists

H2/H3 can succeed on a macOS host and still fail as an iOS product if executable code is packaged in a way iOS will not accept. This is the packaging decision Bot 2 must confront immediately after host no-emit proofs.

## Platform constraints (practical)

For normal iOS apps:

- No Rosetta.
- No general desktop-style RWX heap.
- JIT entitlements (`com.apple.security.cs.allow-jit`, unsigned executable memory) are **not** a product plan for a normal App Store game.
- Apple documentation pages for those entitlements exist and are host/specialized tooling territory; Ottsel must not depend on them for the ship path.
- CPU-executable game code should be part of the signed app image (or an equivalently signed native mechanism), not freely generated in anonymous memory.

(Apple developer doc pages were fetched under `ref/apple-ios-memory-protection/raw/`; several are JS-rendered shells, so engineering judgment is also grounded in OpenGOAL’s own Apple W^X comments and standard iOS code-signing practice.)

## Options

### Option 1 — Offline ARM64 code blob loaded once into RX memory
**Flow:** host `goalc` emits final machine code package → app loads bytes → creates RX mapping → jumps in.

Pros:
- closest to current OpenGOAL object model
- faster to prototype on Simulator if permissions allow

Cons:
- still “create executable memory from data”
- high policy/engineering risk on device/App Store
- must guarantee no later writes

**Use as:** host/Simulator research probe only, unless proven acceptable.

### Option 2 — AOT emits C/LLVM/Mach-O and clang links into the app (preferred product direction if Option 1 is shaky)
**Flow:** `goalc` becomes a frontend producing C++/LLVM or generated `.s` files → Xcode/clang builds signed binary.

Pros:
- cleanest iOS signing story
- no runtime executable creation
- aligns with App Store expectations

Cons:
- more compiler work
- object/linker semantics must be re-expressed as static data + function pointers

**Use as:** default product packaging target if any legal/policy doubt remains about Option 1.

### Option 3 — Hybrid
AOT produces native static libraries per DGO/module; runtime only links data and function-pointer tables.

Pros:
- modular builds
- still signed native code

Cons:
- build-system complexity
- careful ABI/stability needed

## Decision rule for Bot 2

1. Implement host no-emit execution first (H2) without caring about App Store packaging form.
2. Run a dedicated packaging spike:
   - attempt Option 1 on iOS Simulator with permission proof
   - if blocked or dubious for device policy, pivot to Option 2/3 before S2 content work expands
3. Record ADR in this file’s decision section (below) with evidence.

## Decision log

| Date | Decision | Evidence | Notes |
|---|---|---|---|
| 2026-08-07 | Provisional preference: host proofs independent; product packaging bias toward Option 2/3 if Option 1 is not clearly safe | Phase 1 research | No build performed yet |
| 2026-08-07 | **H2.5 DECISION — Option 2/3 (generated native code in the signed app) is the product path. Option 1 (runtime RX blob) is host/Simulator research only, not a ship path.** | `docs/evidence/H2.5/` (below) | Host proof: AOT ARM64 GOAL bytes assemble → clang Mach-O (`__TEXT`) → linked native executable → executes correctly → code-signed. No runtime executable-memory creation anywhere in the product path |

## H2.5 decision (2026-08-07)

### What was proven (host)

`ottsel-h25-proof` compiles real GOAL functions with the ARM64 backend, then
packages each function's exact emitted machine bytes as assembly
(`.word` directives), assembles with clang into a Mach-O object, and links it
into a native executable:

- `loop.o` — `__TEXT,__text` section, PURE_INSTRUCTIONS-style text segment
  (`TEXT` flag), containing the full compiled loop (prolog-free leaf body with
  `#f` symbol load `mov x8, x21`, branch patched to `b 0x18`).
- Linked executable runs: `aot_loop(10) = 45` (expected 45), exit 0.
- `codesign -s -` succeeds on the linked binary (ad-hoc; App Store signing
  would be the distribution signature).
- Same chain passes for `add2` and `submul` (`[H2.5] MACH-O PACKAGING PATH
  PASS cases=3`).

Artifacts: `docs/evidence/H2.5/{add2,submul,loop}.{s,o}`, `aot_loop_native`,
`run-h25-proof.log`.

### Decision

1. **Product packaging = generated native code compiled by clang into the
   signed app (Option 2, with Option 3's modularity as an implementation
   detail).** The AOT pipeline emits final ARM64 code; a host step turns it
   into assembler input (or generated `.c`/LLVM later if needed), and
   Xcode/clang produces the signed Mach-O. The app contains only signed
   executable code from the start — no `mprotect(PROT_EXEC)`, no anonymous
   executable mappings, no runtime instruction writes.
2. **Option 1 (runtime RX blob) is explicitly NOT a ship path.** It remains a
   host/Simulator research probe only. Even though H2 proved RX-only execution
   works on the host kernel, iOS device policy treats runtime-created
   executable memory as unsigned code; it would need JIT-style entitlements
   that are not a normal-app product plan.
3. **Symbol/type/function references resolve at AOT finalize time** (the H3
   offline prelink step), producing self-contained code images that need only
   data relocations (writable `__DATA` slots) at runtime — consistent with
   what H2's static-shim proof demonstrated.

### Accepted risks

| Risk | Accepted? | Mitigation |
|---|---|---|
| Generated-code toolchain complexity (emit `.s`/C/LLVM faithfully) | Yes | Reuse the proven byte emitter; `.s` path already proven; keep x86 emitter intact for upstream parity |
| ABI drift between AOT image and clang-assembled output | Yes | Compare emitted bytes vs assembled bytes in CI (reverse-apply check pattern) |
| App Store review of a large generated `__TEXT` game image | Yes | Standard signed-native code; no unsigned-exec path exists to explain |
| Linker model divergence (function pointers, DGO modules) | Yes | Option 3 shape: per-DGO native libraries + function-pointer tables (H3 design) |
| Simulator vs device differences remain (permissions probing) | Yes | Simulator is a confirmation surface, never completion proof |

### Not assumed (explicit)

- No assumption that the App Store accepts runtime-created RX mappings.
- No assumption that `MAP_JIT`/`allow-jit` entitlements are usable for the
  product.
- No assumption that Simulator permission behavior equals device behavior.
- No claim that the generated-code path is finished; the H3 gate must produce
  a real Jak 1 AOT boot through this packaging shape before S2.

### Consequence for H3

H3's AOT artifacts should be emitted as **self-contained code images with
offline-resolved links** (packaged as generated native code), not as blobs the
runtime must load into executable memory. The host boot proof may still use a
desktop mapping for testing, but the artifact format is the generated-native
shape from this ADR.

## Stop condition
If no packaging option can execute Jak 1 ARM64 code without runtime instruction writes or disallowed executable-memory creation, project becomes NO-GO for native iOS product.
