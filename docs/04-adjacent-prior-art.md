# 04 — Adjacent prior art (what transfers, what does not)

Research date: 2026-08-07

There is **no OpenGOAL-on-iOS reference implementation**. The sources below are adjacent only.

## 1. HarkinianPad / Ship of Harkinian lineage

Local research copy: `ref/adjacent-prior-art/harkinianpad-feasibility.md`

### What it is
Native iOS/iPadOS work on top of Shipwright/libultraship for Ocarina of Time PC ports.

### Transferable lessons
- A port is much easier when **game logic is already AOT native C** and the binary has **no CPU JIT**.
- libultraship already had iOS CMake/Metal scaffolding; work concentrated in app shell, audio gating, lifecycle, import UX.
- Files-app import into Documents is a proven onboarding pattern.
- Keep gameplay code untouched; isolate platform seams.

### Non-transferable
- OpenGOAL is not a decomp-to-C game core. It is a custom language + dynamic linker.
- HarkinianPad’s “no dynarec found” happy path does **not** exist in OpenGOAL today.
- SoH’s Metal backend does not replace OpenGOAL’s OpenGL renderer.

### One-line lesson
HarkinianPad proves iOS productization patterns; it does **not** prove OpenGOAL’s execution model.

## 2. AnnePad / static recompilation lineage

Local research copy: `ref/adjacent-prior-art/annepad-research.md`

### What it is
Pokémon Stadium via static recompilation (N64Recomp family) toward Apple targets.

### Transferable lessons
- When the original machine code model is hostile to mobile, **offline AOT generation** is the viable path.
- Host tools may need Linux-ish toolchains even if the app is Apple-native.
- Runtime must make interpreter/JIT fallback a compile-time impossibility for iOS, not an env toggle.
- Reproducible pins and generated-source discipline matter more than hero branches.

### Non-transferable
- Different ISA, different toolchain, different game.
- N64Recomp ≠ goalc.
- AnnePad still faces its own incomplete mobile runtime issues; not a drop-in template.

### One-line lesson
AnnePad reinforces Ottsel’s Strategy A/B: **precompute native code on a host; ship a no-emit runtime.**

## 3. OpenTTDPad

Local research copy: `ref/adjacent-prior-art/openttdpad-builder.md`

### What it is
Native iOS port planning/implementation around upstream OpenTTD + SDL.

### Transferable lessons
- Strict builder instructions and gates prevent UX work on top of an unproven native build.
- Never commit copyrighted game assets; user supplies content.
- Re-verify upstream facts before coding.
- SDL can be a viable iOS host if the engine already matches mobile constraints.

### Non-transferable
- OpenTTD is ordinary C++ with no custom JIT language runtime.
- Its risk profile is almost the inverse of Ottsel’s.

### One-line lesson
Steal OpenTTDPad’s **process discipline**, not its technical architecture.

## 4. Upstream OpenGOAL itself as “prior art”

Sources: `ref/open-goal-jak-project/`, opengoal.dev docs.

### Transferable
- Jak 1 is complete enough that game content is not the research problem.
- macOS tooling/docs exist.
- Experimental ARM64 emitter work is the only upstream beachhead for Ottsel.

### Non-transferable / anti-goals from upstream
- “No plans to ever make a mobile release.”
- Supported architecture remains x86_64.
- Live modification/REPL is a first-class desktop feature and must be removed from mobile product scope.

## 5. SDL3 iOS

Source: `ref/sdl3-ios/README-ios.md`

### Transferable
- SDL3 can host iOS apps (xcframework, lifecycle events, documents paths, controllers).
- Working directory is the bundle; writable state goes to Documents/pref paths.
- Background events are explicit and must be handled.

### Non-transferable
- SDL does not solve GOAL codegen, EE memory, or OpenGL 4.3 absence.

## 6. Synthesis for Ottsel

| Need | Best adjacent teacher |
|---|---|
| No-JIT conviction | HarkinianPad (positive example), OpenGOAL source (negative example) |
| Offline AOT mindset | AnnePad / static recomp world |
| Gate discipline / asset safety | OpenTTDPad + all Pad repos |
| iOS shell mechanics | SDL3 + HarkinianPad/OpenTTDPad patterns |
| Compiler work uniqueness | **No teacher** — Ottsel-specific |

Ottsel should be designed as:

> OpenGOAL Jak 1 AOT compiler program first, iOS product shell second.

Not:

> iOS shell first hoping the compiler problem shrinks.


## 7. OpenGOAL porting docs as prior art for *x86*, not iOS
Fetched under `ref/opengoal-docs/porting-info/`.

Useful:
- explicit list of what had to change from PS2→x86
- register mapping philosophy
- graphics DMA/frame model

Not useful as iOS template:
- documents assume desktop OpenGL and x86-64 register file
- no mobile/W^X chapter because upstream rejected mobile scope
