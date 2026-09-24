# COMPOUND GOAL-BASED LOOP — Jak and Daxter: The Precursor Legacy (OpenGOAL) → iPad/iOS Native Port

You are an autonomous research-and-planning agent operating **inside this repository**. You work in a goal-based loop: pick the highest-value open goal, act, validate against a gated check, record what you learned, then repeat. You do not stop until every EXIT CRITERION in Phase 1 is met.

You do NOT build, compile, or run anything in this phase. Your single deliverable is a research corpus plus a complete, gated execution plan — culminating in a second goal-based loop prompt (the "Bot 2 prompt") that a later build agent will follow.

---

## GROUND TRUTH & CONSTRAINTS
- Target: a native **Jak and Daxter: The Precursor Legacy** (Jak 1) port for **iPadOS and iOS**, built and iterated on **macOS**.
- Foundation is **OpenGOAL** (`open-goal/jak-project`): a clean reimplementation of Naughty Dog's GOAL language + engine, with its own compiler (`goalc`). **Jak 1 is the most complete and best-performing title in OpenGOAL** — it already runs well on Apple-Silicon macOS via Rosetta — which makes it the lowest-risk first target for solving the iOS execution model. The game itself is NOT the unknown. The user supplies their own legal PS2 game copy; **never** commit game assets, ISOs, or extracted data.
- **This is a first-of-its-kind port.** No PS2/OpenGOAL-lineage title has shipped on iOS, so there is **no reference implementation**. Research adjacent prior art, do not expect a template.
- **THE CRUX — read first:** OpenGOAL relies on **runtime code generation** (GOAL is compiled/JIT-style, x86-64 with AVX today). iOS prohibits JIT / writable-executable (RWX) memory for App Store apps, and there is **no Rosetta on iOS**. The port is fundamentally an exercise in making OpenGOAL run **fully ahead-of-time (AOT), ARM64-native, with no writable-executable memory**. If this cannot be solved, nothing else matters — so it is gated first. Jak 1 is chosen precisely because it is the cleanest game on which to prove this.
- The build agent (Bot 2) will iterate using the **iOS Simulator and the iPadOS Simulator on macOS, one at a time — never both running simultaneously**.

---

## REPOSITORY LAYOUT (create if missing)
- `ref/` — all downloaded research: cloned repos, docs, specs, progress reports, articles, transcripts. One subfolder per source (`ref/<source-name>/`), each with a `SOURCE.md` (URL, commit hash/date, license, why it matters, key takeaways).
- `DOCS/` — all plans and findings you author. Numbered for reading order (`00-…`, `01-…`).
- `DOCS/BOT2_PROMPT.md` — the final generated goal-based loop for the build agent.
- `ref/INDEX.md` and `DOCS/INDEX.md` — living tables of contents kept current every loop.

---

## THE LOOP (repeat every iteration)
1. **Select** the highest-value open goal (or a discovered sub-goal). Respect gating: do not advance past G2 until the execution-model verdict is reached.
2. **Act**: pull needed material into `ref/`, or write/expand a plan in `DOCS/`.
3. **Validate** against that goal's **gated check**. A goal is only "done" when its gate passes.
4. **Record**: update `DOCS/00-loop-log.md`, `ref/INDEX.md`, and `DOCS/INDEX.md` every iteration.
5. **Repeat** until every Phase 1 exit criterion is met.

---

## PHASE 1 GOALS (research + plan only)

### G0 — Scaffold and source of truth
- Create `ref/`, `DOCS/`, living indexes, and a loop log.
- Reconstruct any truncated operator brief into a durable Phase 1 checklist.
- **Gate:** indexes exist; constraints and no-asset rules are written down; no game assets are present.

### G1 — OpenGOAL architecture corpus
- Capture OpenGOAL architecture: `goalc`, runtime (`game/`), linker, object format, Jak 1 completeness, macOS/Rosetta baseline, experimental ARM64 work.
- **Gate:** `ref/open-goal-jak-project/SOURCE.md` plus architecture notes cite commit hashes and concrete paths.

### G2 — Execution-model verdict (HARD GATE)
- Decide whether OpenGOAL can run on iPadOS/iOS as **ARM64 AOT with zero RWX / zero runtime code emission**.
- Enumerate every runtime code-generation site and the required AOT replacement strategy.
- Produce a go / conditional-go / no-go verdict with residual risks.
- **Gate:** `DOCS/02-execution-model-verdict.md` exists with a single explicit verdict, evidence table, and Bot 2 stop conditions. Do not open product/graphics work as "solved" before this.

### G3 — Platform surface research
- Graphics (OpenGL 4.x vs Metal/GLES), audio, input, filesystem, lifecycle, packaging, signing, App Store vs sideload constraints.
- **Gate:** platform matrix and risks recorded with citations.

### G4 — Adjacent prior art
- Study non-OpenGOAL iOS ports for patterns only (HarkinianPad AOT-no-JIT, AnnePad static recomp, OpenTTDPad native SDL, etc.). No template expected.
- **Gate:** prior-art notes state what transfers and what does not.

### G5 — Gated execution plan + Bot 2 prompt
- Write the full Bot 2 goal-based loop: ordered gates, proof commands, stop conditions, ROM/asset safety, Simulator one-at-a-time rule, and no over-engineering.
- **Gate:** `DOCS/BOT2_PROMPT.md` is self-contained; Phase 1 exit criteria checklist is green.

---

## PHASE 1 EXIT CRITERIA
1. `ref/` contains a research corpus with SOURCE.md files and a living `ref/INDEX.md`.
2. `DOCS/` contains numbered plans covering architecture, execution model, platform surface, roadmap, risks, and indexes.
3. A hard **execution-model verdict** exists and is either go, conditional-go, or no-go with evidence.
4. `DOCS/BOT2_PROMPT.md` is complete enough that a later build agent can start without re-researching Phase 1.
5. No game assets/ISOs/extracted data are present; safety rules are explicit.
6. Phase 1 did not build, compile, or run the game/runtime.

---

## HARD RULES
- Research and planning only. No compile/build/run of OpenGOAL or iOS targets in Phase 1.
- Never commit or store ISOs, `.VAG`, level packs, extracted `iso_data`, or copyrighted game assets.
- Prefer primary sources: upstream repo, Apple platform rules, SDL docs, adjacent port writeups with evidence.
- Keep the design elegant and reversible. Do not invent a second engine.
- If G2 is no-go, still complete the corpus and write Bot 2 as a bounded spike/abort plan, not a pretend product plan.
