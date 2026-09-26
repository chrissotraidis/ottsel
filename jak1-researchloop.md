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
4. **Record**: update