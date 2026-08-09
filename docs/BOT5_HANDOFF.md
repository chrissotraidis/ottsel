# BOT 5 HANDOFF — Ottsel / Jak 1 (OpenGOAL) → iPadOS/iOS

You are **Bot 5**, the continuation build-and-proof agent for this repository
(`ottsel`). Gates H1–H3 are PASS (host), and **Gate S1 is now PASS on the
iPad Simulator** (2026-08-08). Your goal is **Gate S2: first frame / first
room proof** — see the roadmap bar below and `docs/05-roadmap.md` (P5).

## 0. Read first, in order

1. `docs/13-current-state.md` — authoritative technical snapshot (update it
   if needed; the S1 PASS must be reflected).
2. `docs/STATUS.md` — gate board (S1 PASS with evidence paths).
3. `docs/evidence/S1/s13-dispatcher-loop.md` — the S1.3 proof + the root
   cause and fix (unregistered pc-prof + order-dependent intern fallback
   scan) you are building on.
4. `docs/05-roadmap.md` — the S2 acceptance bar (P5) and phase ordering.
5. `docs/BOT4_HANDOFF.md` + `docs/14-progress-review.md` — the S1 plan that
   completed; the sub-gate discipline carries forward.
6. `docs/00-loop-log.md` — full iteration history.

If this prompt conflicts with the docs, prefer the docs and record the
conflict in `docs/00-loop-log.md`.

## 1. Ground truth (unchanged)

- Target: native Jak and Daxter on iPadOS/iOS, OpenGOAL pinned at
  `641fb572e876750d8618434d9f7c1a531b43b366`, Jak 1 first.
- Execution model: ARM64 AOT, no runtime instruction emission, no RWX
  (proven H1–H3, and now running on the Simulator under S1).
- Product packaging path: generated-native code in the signed app (H2.5,
  doc 10).
- Work on macOS (Apple Silicon). One Simulator at a time. No game assets in
  git, ever. Legal ISO at `~/ottsel-user/iso/`; extracted data under
  gitignored `out/`.
- Disk is tight: one build dir, no extra Simulator runtimes.

## 2. Operator constraints (binding, unchanged)

1. **NEVER fullscreen.** Test apps/game windows stay Windowed on macOS and in
   the Simulator. (On iOS the app view fills the device display by platform
   design; no `SDL_WINDOW_FULLSCREEN`.)
2. **At most ONE runtime process at a time.** `pgrep -fl "gk -fakeiso"`
   before launching; never leave stale gk/lldb/Simulator apps.
3. **One booted iOS Simulator at a time.**
4. No asset/ISO commits; no claiming device completion from Simulator
   evidence; no touch polish/icons/marketing before the shell gates are
   green.

## 3. Gate board

| Gate | Status | Evidence |
|---|---|---|
| H1–H3 | PASS (host) | `docs/evidence/H{1,2,2.5,3}/` |
| **S1** | **PASS (2026-08-08)** — shell + no-emit runtime boot to the GOAL kernel dispatcher loop on the iPad Simulator | `docs/evidence/S1/s13-dispatcher-loop.md`, `docs/evidence/S1/s13-dispatcher-loop.log`, `s11-*`, `s12-*` |
| **S2 first frame** | **YOUR GOAL** | `docs/evidence/S2/` (create) |
| S3 touch MVP + lifecycle | not started | — |
| R1 handoff package | not started | — |

## 4. Your goal (single objective)

**Gate S2: first frame proof** per the roadmap bar — "evidence of either
first rendered frame from game renderer or a clearly defined intermediate
milestone approved in STATUS (default target is first frame)". The durable
product path is **Metal** (iOS has no desktop OpenGL; docs 03/11). Do NOT
try to make the ~45k-line OpenGL renderer run as-is.

Scope note (2026-08-09): `docs/BOT5_PROMPT.md` supersedes the
stop-after-S2 behavior of this handoff. S2 remains your first gate and
this document remains its spec, but after S2 is checkpointed PASS you
continue directly into S3 and R1 per the prompt's continuation rule.

Suggested decomposition (keep the sub-gate discipline from S1):

- **S2.0** — Metal spike: a minimal Metal/MTKView first frame in the shell
  (clear color is NOT "victory" — state it as a sub-gate if used), or an
  approved intermediate milestone recorded in STATUS.
- **S2.1** — wire the runtime's existing renderer-abstraction seams to Metal
  where cheap; identify the first real drawable (background/TIE/texture
  page path) that can produce a genuine Jak 1 frame.
- **S2.2** — first real frame evidence on the Simulator: screenshots + logs
  under `docs/evidence/S2/`, STATUS.md S2 PASS, patch verified, handoff.

## 5. What S1 left behind (read before changing anything)

- The iOS build: `scripts/build-ios.sh` (SDL3 static + runtime lib + app),
  shell sources in `src/shell/` (`main.cpp` renders the log surface with a
  5x7 bitmap font — S2 will replace/extend this surface), `ios_boot.cpp`
  (the no-emit boot driver), `ios_boot.h`, `font5x7.h`, `Info.plist`.
- Worktree OTTSEL_IOS patches (all in `patches/h3-jak1-host-boot.patch`,
  regenerated and `git apply --check`-verified against the pin):
  - `game/kernel/jak1/kscheme.cpp` — kernel loads from the bundle
    (`ottsel_ios_load_kernel_from_bundle`), C exports interned before the
    kernel link, full-table fallback scan in `find_symbol_from_c`.
  - `game/kernel/common/kmachine.cpp` + `jak1/kmachine.cpp` — PC-port
    exports registered (heavy subsystems stubbed by `game/ios_stubs.cpp`),
    InitMachine skips IOP/gfx/sound/listener-connect under OTTSEL_IOS.
  - `game/kernel/jak1/klisten.cpp` — listener sentinel kept as `s7.offset`
    (the GOAL when-test skips when equal).
  - `game/kernel/jak1/kboot.cpp` — OTTSEL_IOS dispatcher-iteration logging
    + boot diagnostics.
  - `game/mips2c/mips2c_table.cpp` — empty table under OTTSEL_IOS.
  - `game/ios_stubs.cpp` — headless stubs (Gfx, InputManager, DisplayManager,
    IOP, compression, Discord, zstd...).
- The gated signal handler in `ios_boot.cpp` remains as the "no crash loop"
  safety net.
- S1.1 tooling: `scripts/validate-arm64-emission.py` — run it before any
  boot-fault debugging; it catches invalid ARM64 encodings in seconds.

## 6. Reproduce the S1 proof

    ./scripts/build-ios.sh
    xcrun simctl boot <iPad Pro 11-inch (M4) UDID>
    xcrun simctl install <udid> out/jak-project/out/ios/app/OttselShell.app
    xcrun simctl launch <udid> com.ottsel.shell

The runtime log lands in the app bundle's `ottsel-runtime.log`; the visible
log surface renders its tail. Expect `Got correct kernel version 2.0`,
`kernel: machine started`, and continuous
`GOAL kernel dispatcher iteration N (running)` lines.

## 7. Hard rules (still binding)

- No RWX product path; no "temporary JIT"; no goalc listener/REPL in iOS
  builds; no asset commits; one Simulator at a time; no device claims from
  Simulator evidence; upstream pin unchanged; keep `docs/STATUS.md` current.
- Document every step in `docs/00-loop-log.md` in the same turn; commit per
  sub-gate; regenerate `patches/*.patch` and verify clean apply on a fresh
  pin worktree whenever tracked OpenGOAL files change.
- Honest stopping: same root cause three times with no new angle -> write
  `docs/reports/YYYY-MM-DD-stop-S2.md` and stop.

## 8. Prime directive

> Finish Gate S2: first real Jak 1 frame on the iPad Simulator via the Metal
> path, with captured evidence, honest STATUS, and verified patches. Then
> checkpoint and continue into S3 per `docs/BOT5_PROMPT.md` (no BOT6
> handoff needed unless the session must stop). If you cannot prove S2,
> write the stop report with options rather than drifting.
