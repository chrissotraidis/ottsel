# BOT64 — adopt the desktop's VU1 programs instead of emulating the microcode

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT63_PROMPT.md`. Read `AGENTS.md`, then this file, then the tail of
`docs/STATUS.md`, then `docs/16-ipados-ios-goal-loop-2026-08-23.md`.

This loop is assigned to itself. Run it; do not hand it back for approval.

## Product goal (unchanged)

An honestly playable native Jak 1 build on iPadOS first, then iPhone parity,
then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible **and
controllable** under real input, a stable and correct camera, nonzero game PCM,
clean lifecycle, and sustained frame pacing. A log line, counter, still frame,
menu, or Simulator-only result is not playability.

## What this session proved (evidence, not theory)

1. **The control run is clean.** 210 s of Village1 with no probes armed:
   `ottsel-fault.log` stayed 0 bytes and the process survived. The 20:24
   GOAL-tag fault was **diagnostic-induced** — four cumulative sky probes armed
   at once, each allocating a fresh `MTLBuffer` per frame
   (`metal_shell.mm:1532-1550`). Rule going forward: **one probe per run**.
2. **The frame is not frozen.** The sky-log capture at 20:35 shows textured
   huts, grass, water, HUD sprites and correctly shaded Jak, and the scene
   changed between 20:28 and 20:32 (propeller angle, banner cleared). BOT60's
   "Village1 is frozen" is stale.
3. **The sky is submitted and still wrong.** `sky_batches=44` (6x1x1, 6x32x32,
   32x64x64) reach Metal every frame; the pre-world block at
   `metal_shell.mm:1465` **is** entered. So "the block is skipped" is dead.
   The 1x1 full-screen fans carry vertex colour `(0.00,0.50,0.50,0.50)`; the
   64x64 cloud batches carry `rgba=(20,20,20,a)` with UVs 0.60-1.0. The
   failure is in the per-class transform/texture/blend math, not submission.
4. **The shell's own VU1 interpreter produces ZERO in gameplay.**
   `OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1`, same binary, live Village1:
   - chains 90-180 (logo/title spool): `xgkicks=108391 gif-words=433564 draws=177`
   - chains 270-450 (**Village1 gameplay**): `vu1-runs=7290 capped=5670
     xgkicks=0 gif-words=0 draws=0`
   BOT57's "the interpreter works" numbers were measured on the **title
   spool**. BOT63's headline premise — that the game-accurate producer "exists
   and works" and is merely unwired — is **refuted for gameplay**. Wiring it
   would present nothing.

## The actual structural finding (why 60 rounds did not converge)

The desktop and the shell solve VU1 in two different ways:

| | desktop (works) | iPad shell (does not) |
|---|---|---|
| VU1 world programs | **mips2c**: C++ emitted from each VU1 program, called directly (`game/mips2c/jak1_functions/tfrag.cpp`, `generic_tie.cpp`, `generic_merc.cpp`, `sky_tng.cpp`, `ocean.cpp`, `bones.cpp`…) | **a from-scratch VU1 interpreter** (`tools/ottsel_vu1/vu1.cpp`) fed the raw microcode blobs (`tfrag_microcode.h`, `generic_microcode.h`, loaded at `metal_gfx.mm:6990`) |
| bucket driving | `OpenGLRenderer` + per-bucket `BucketRenderer`/`DirectRenderer` runner | per-class writers inside `metal_gfx.mm` (8.8k lines) |
| result | correct frame (captured this session) | 5 hand-written writers, 6 bands of result |

**The iOS binary already contains the desktop's mips2c VU1 programs.**
`scripts/build-ios.sh` compiles all of `game/mips2c/jak1_functions/*` and
`game/mips2c/mips2c_table.cpp` into `libottsel-runtime.a`. What is missing is
`game/graphics/opengl_renderer/*` — the runner that walks the DMA chain, does
the VIF unpack, dispatches MSCAL to the matching mips2c program, and hands the
produced GIF words to a generic GS draw.

So the shell re-derives in C++ (badly, per class) what the desktop gets for free
from a validated program, and it emulates microcode where the desktop calls C++.
That inversion — not the sky constant, not the strip, not the HUD — is the
reason correctness does not accumulate.

## Reorientation (this is the change of lane)

The lane is no longer "repair the next class" and no longer "wire the VU1
interpreter". It is: **run the same VU1 programs the desktop runs, and drive the
buckets with the same runner shape, so a primitive's correctness is decided once
in shared code.**

Concretely, three layers, in dependency order:

1. **VU1 programs -> mips2c, not the interpreter.** Call the already-linked
   mips2c functions for TFRAG/TIE/MERC/Sky/Ocean instead of executing microcode.
2. **Bucket runner -> port, do not re-derive.** A renderer-agnostic walk of the
   same DMA structure `OpenGLRenderer` uses (bucket boundaries, VIF unpack,
   MSCAL -> program dispatch, XGKICK/GIF extraction). `metal_gfx.mm` already
   has the DMA follower and the GIF decoder; the missing piece is the
   program-dispatch runner.
3. **GS -> Metal becomes one generic draw.** The per-class math collapses to
   GS register state (PRIM/TME/ABE/alpha-test/TBP/wrap/ZBUF) translated into
   Metal draw state — the same table upstream encodes in `DirectRenderer`.

### Gate N3 (first falsifiable step — do this before any renderer rewiring)

**Question.** Do the mips2c VU1 programs that are already linked into
`OttselShell` execute on this runtime and produce the desktop's geometry?

**Method.**

1. The shell has already dumped a real gameplay payload to the app container:
   `tfrag-vif-replay.bin` (35 MB) and `tfrag-vu-data.bin` (3.3 MB) under
   `$TRIG`. Copy them to `/tmp`, do not read them in place.
2. Build a bounded harness (host-side preferred; an in-app trigger if not) that
   loads the captured VIF payload, drives the **mips2c** `tfrag` program the way
   `OpenGLRenderer` does, and dumps the produced words.
3. Compare against the desktop path on the same payload (the desktop already
   implements this; run it rather than re-deriving expected bytes).

**Exit bar.**

- **Output matches the desktop (or is explained)** -> the lane is confirmed.
   Next: port the bucket runner for TFRAG end to end, then TIE, then the rest.
- **Matches but the shell still cannot reach it** -> the blocker is the runner,
   not the program; say which call is missing.
- **Diverges or is empty** -> report the exact divergence (entry PC, first
   differing word, cap/limit) and whether the cause is the harness, the payload,
   or the mips2c port. **Do not fall back to per-class repair without saying so
   and recording it.**

## Loop rules (unchanged)

- One runtime at a time. Never run the macOS oracle while Simulator.app runs.
- Read the desktop reference renderer and the shell source before hypothesising.
- Capture a sequence, never one frame, and always region-resolve it.
- The app stays signed-native, ROM-safe and non-JIT (mips2c is compiled C++, it
  is not a JIT and does not need RWX — verify this claim before relying on it).
- **One diagnostic probe per run.** Cumulative probes faulted the app at 20:24.
- `ottsel-fault.log` stays 0 bytes. Frozen without a proven source mismatch:
  `set_mobile_tie_camera` math, TBP/lookup, strip-restart, the touch frontend,
  and all iPhone work.
- Evidence is capped at one concise document per proven gate (60 lines) plus at
  most eight appended `STATUS.md` lines. Append-only.
- Never `git add -A`. Keep every worktree file below 100 MB. Do not use
  `rm -f`; overwrite with `: > file`.

## Stop conditions (unchanged)

Stop and report, without claiming playability, on any of: a `tmp_pack_*` in the
repo, free space below 5 GiB, a nonzero `ottsel-fault.log`, an unsigned or
non-verifying bundle, three consecutive failed launches, or a route stage that
needs a product change in a frozen area.

