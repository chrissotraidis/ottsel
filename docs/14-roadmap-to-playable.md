# Roadmap to Playable (2026-08-16) — what actually stands between here and playing Jak

This document answers three questions with evidence: (1) can the game be
launched locally today, (2) are we building this the smart way, and (3)
what exactly remains for playable Jak on macOS, then iOS/iPadOS.

## TL;DR

- **macOS: the game launches locally, natively (arm64), today** — with the
  full upstream renderer/audio/IOP stack, using our recompiled ARM64 GOAL
  code via the no-emit path.  The missing pieces were *build steps, not
  engineering*: the fr3 renderer assets (5.5 s to generate) and the full
  `out/jak1/iso` (18 s incremental).  Remaining work here is verification
  and polish, not invention.
- **The iOS shell's renderer track (VU1 interpreter + software rasterizer)
  should be retired as the product path.**  Upstream solved rendering by
  extracting level geometry offline (.fr3 meshes) and drawing them with
  ~15 C++ bucket renderers; that entire stack is in our tree and already
  runs on Apple silicon (GL 4.1 on Metal, proven live).  The VU1
  interpreter remains valuable as a verification/debug tool only.
- **The unique thing Ottsel owns is iOS**: upstream says "no plans to ever
  make a mobile release," and iOS forbids JIT — our AOT no-emit runtime
  (gates A1/S1/S2.1) is exactly the piece nobody else has.  The iOS work
  becomes: port the *existing* renderers to iOS (ANGLE/Metal), un-stub the
  IOP (overlord/989snd — the same code that just ran on the host), bundle
  the full game data, and wire touch/controller input.

## 1. Ground truth established today (all verified live)

| Fact | Evidence |
|---|---|
| Fork base = upstream jak-project 641fb572, 2026-07-31 (current) | `git log 641fb572` |
| The ARM64 goalc emitter EXISTS UPSTREAM; Ottsel extends it (+564 lines) | `git show 641fb572:goalc/emitter/IGenARM64.cpp` |
| Upstream officially: x86_64 on Win/Linux/macOS-via-Rosetta; "no plans to ever make a mobile release"; macos.md has an experimental arm64 preset | README.md:55, docs/setup/system/macos.md |
| Upstream is actively landing ARM64 (July 2026: jak1 "in strong shape", jak2 playable-with-rough-edges) | opengoal.dev progress + press |
| Full iso extraction already on disk (1.4 GB: STR, VIS, MUS, SBK, VAG, TEXT, CGO, DGO) | `out/jak-project/iso_data/jak1` |
| The iOS bundle's "no STR / one VIS" wall was a hand-pruned bundle, not missing data | bundle iso_data vs iso_data/jak1 |
| fr3 renderer assets: `decompiler ... --config-override '{"decompile_code": false}'` produced all 25 .fr3 (incl. GAME.fr3, village1.fr3) in **5.53 s** | `out/jak1/fr3/` |
| Full `out/jak1/iso`: `goalc --isa arm64 -c '(load-project ...) (mi)'` built 1317 targets in **18 s** → 321 files | `out/jak1/iso/` |
| Host `gk` is a native **arm64** Mach-O; it boots with the full upstream stack: OpenGL 4.1 renderer on Apple M1, SDL3, IOP thread + CD library ("[IOP] Run!"), and links KERNEL.CGO via the **no-emit AOT** path | scratchpad gk-host logs, `log/jak1.*.log` |
| The renderer suite (game/graphics/opengl_renderer, ~38.7k lines, ~15 bucket renderers + shaders) runs within GL 4.1 (no compute/SSBO; glMultiDrawElements has a non-multidraw fallback path) | source scan + live GL 4.1 context |

## 2. Are we doing this the smart way? (honest audit)

**What was smart:** the ARM64 compiler work, the no-emit AOT runtime
(signed-text execution for iOS), the S2.1 engine bring-up, and the
evidence-gated loop.  These are the parts with no off-the-shelf answer,
and A1's "no runtime-created executable code" proof is the load-bearing
iOS enabler.

**What was not smart:** the S2.2 renderer track re-derived the PS2 GS/VU1
pipeline from scratch (VU1 microcode interpreter, XGKICK GIF decode,
software rasterizer) while the same repository contains upstream's
finished answer: offline fr3 mesh extraction + hardware bucket renderers.
Weeks of BOT16–BOT22 renderer effort went into a path that (a) upstream
deliberately abandoned for good reasons and (b) could never hit 60 fps as
a software rasterizer on an iPad.  The corrective: **adopt the fr3 +
C++ renderer pipeline everywhere; keep the VU1 interpreter only as an
offline verification tool.**

**Also previously missed:** the July 2026 fork base means upstream's own
ARM64 push is recent and converging with ours.  For macOS, the winning
move is to stay close to upstream (and upstream our emitter fixes where
possible) rather than diverge.  Our durable moat is iOS-only work:
no-emit AOT, Metal/ANGLE rendering, touch, App-Store-shaped packaging.

## 3. What playable requires — macOS (near-term)

Status: `gk -v --game jak1 -- -boot -fakeiso` launches natively today
with fr3s + full iso.  Remaining:

1. **M1 gate — verified playable title→village1 on host** (days, mostly
   verification): confirm the boot reaches the rendered title, intro
   spool plays (STR now served by the real overlord), village1 displays,
   input works (SDL keyboard/controller — note gk warned "No active game
   controllers"; keyboard bindings exist in pc-settings), audio plays
   (989snd + SBK/VAG present).  Fix what falls out; each fix also
   benefits iOS since it's the same runtime.
2. Performance sanity on arm64 (upstream jak1 is "in strong shape").
3. Optional: package a double-clickable app bundle later; not a blocker.

## 4. What playable requires — iOS/iPadOS (the real project)

In order, with the macOS-proven stack as the reference:

1. **Renderer port** (the big one, but now well-defined): bring
   game/graphics/opengl_renderer to iOS.  Two viable routes:
   - **ANGLE (GLES3-on-Metal)**: keep the C++ renderers, port
     desktop-GL-isms (glMultiDrawElements→loop path already exists;
     GL4.1→GLES3 shader/#version churn).  Fastest to first frame.
   - **Native Metal backend**: cleaner long-term; port the BucketRenderer
     framework renderer-by-renderer (Direct → Tfrag3 → Tie3 → TextureAnim
     → Merc2 → Shrub → Sky/Ocean → Sprite/EyeRenderer...).
   Recommendation: ANGLE first to de-risk and get pixels, evaluate Metal
   after.  Either way the fr3 files ship in the app bundle.
2. **IOP un-stub**: replace the OTTSEL_IOS RPC stubs with the real
   game/overlord + 989snd running against bundle files — the exact code
   that just ran on the host ("[IOP] Run!").  This deletes the DGO/STR
   shims and gives streaming (STR), VIS loading, and audio in one move.
3. **Full data bundle**: ship the complete out/jak1/iso (321 files) +
   fr3s in the app (size ~1.5–2 GB; the user supplies their own game
   data — keep the ROM-safe never-commit rule; on-device extraction or
   sideload flow is a product decision to make later).
4. **Input (S3)**: virtual touch controls + GameController framework
   (MFi/DualSense).  The BOT22 synthetic-pad bridge is the seed.
5. **Lifecycle/packaging**: background/foreground handling, save files in
   the sandbox (kmemcard already file-backed), signing (A1 model).
6. **Performance**: profile on device; the no-emit AOT code already runs;
   renderers are GPU-bound and the fr3 pipeline is what lets an iPad hit
   60.

## 5. Explicit non-goals / retired tracks

- The shell's software rasterizer + VU1-interpreter *product* path
  (S2.2 Track B as written) — retired; keep as debug tooling.
- Emulating the PS2 DMA/VIF/GIF at full fidelity — the C++ renderers
  consume the DMA stream only as control input; fr3 supplies geometry.
- Chasing the spooled-intro path on iOS before the IOP un-stub — the STR
  wall was a bundling artifact; it disappears with steps 2–3.

## 6. Sources (external review)

- Upstream README (platform support; "no plans to ever make a mobile
  release"): github.com/open-goal/jak-project
- OpenGOAL FAQ + installation docs: opengoal.dev
- July 2026 ARM64 progress coverage (jak1 strong, jak2 rough edges,
  jak3 long-term): generationamiga.com 2026-07-04 article
- In-tree: docs/setup/system/macos.md (Rosetta x86_64 official;
  arm64 preset experimental/unsupported)
