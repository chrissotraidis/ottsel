# BOT63 — stop re-implementing the PS2 pipeline class by class

Active continuation prompt for `/Users/chrissotraidis/GitHub/ottsel`. Supersedes
`docs/BOT62_PROMPT.md`. Read `AGENTS.md`, then this file, then the tail of
`docs/STATUS.md`, then `docs/16-ipados-ios-goal-loop-2026-08-23.md`.

This loop is assigned to itself. Run it; do not hand it back for approval.

## Product goal (unchanged, from the PRD and the gate loop)

An honestly playable native Jak 1 build on iPadOS first, then iPhone parity,
then physical-device readiness. "Playable" means a coherent
`title -> New Game -> Village1 -> Training` route with Jak visible **and
controllable** under real input, a stable and correct camera, nonzero game PCM,
clean lifecycle, and sustained frame pacing. Signed-native and ROM-safe.
A log line, a counter, a still frame, a menu, or a Simulator-only result is not
playability.

## The honest zoom-out: why ten rounds each moved one class and no further

The presented frame is a **hand-written re-implementation of the PS2 pipeline,
one primitive class at a time**. Five independent implementations of the same
semantics live in `src/shell/metal_gfx.mm` (8805 lines):

| class | writer | owns |
|---|---|---|
| TFRAG/TIE | `ottsel_metal_set_tie_mesh` | vertex+Hvdf transform, TBP/CLUT lookup, fog, alpha test |
| MERC | `ottsel_metal_append_merc_mesh` | skinning, clip fix-up, shade, effects |
| Sky | `ottsel_metal_append_sky_mesh_n` | NDC mapping, wrap sampling, vertex colour |
| Direct/HUD | `ottsel_metal_append_direct_mesh_n` | glyph/quad transform, scissor |
| Sprite3 | `ottsel_metal_append_sprite_mesh_n` | atlas, HUD matrix, blend |

Each class carries its **own copy** of camera math, texture resolution, blend
and alpha-test rules. Correctness in one class proves nothing about the others,
so every round has repaired exactly one class and then discovered the next. That
is the shape of the record, not bad luck:

- BOT59 MERC sat behind the near plane (`z -= 1.0` on an already-normalised z).
- BOT62 MERC shades correctly now; the sky still does not.
- BOT57/58/62 sky: vertex colour, then submission scope.
- HUD Sprite3 rendered as a giant quad (its own transform bug).

Meanwhile the frame is still mostly wrong: the sky band is the render-pass clear
colour to the byte, and the game's own VU1->GIF rasteriser has never executed
(`vu1-runs=0 raster-draws=0`). Ten rounds of per-class repair have not produced a
coherent frame, and the repair surface grows with each class touched.

## The second world is already built, and its output is thrown away

There is a **generic** path in the same file that does not have this problem:

1. `decode_gif_packets` (`metal_gfx.mm:3638`) is a class-agnostic GIF parser:
   PACKED/REGLIST/IMAGE tags -> `OttselNativeDirectPrimitive` (positions, uv,
   rgba, resolved texture, blend, ta0). It already drives the sky and Direct
   buckets correctly enough to be indistinguishable in code from the classes
   above.
2. The shell also executes **the game's own VU1 microcode**
   (`tools/ottsel_vu1/vu1.cpp`) and feeds its XGKICK output to that same parser
   at `metal_gfx.mm:7168`.
3. BOT57 measured that interpreter working: `vu1-runs` 3485/10206/8538 per
   90-chain period, `gif-words` 433564/496580/190744, `last-pc` reaching 1694
   (the strip-output phase).

Two things stop it from mattering:

- **It is switched off.** `run_cpu_vu_diagnostics` comes from
  `OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS`; without it the interpreter is skipped and
  `g_vu.gif_out` is cleared (`metal_gfx.mm:7136-7142`).
- **Its output is discarded.** The decoded primitives go to `g_raster`, a CPU
  framebuffer. `ottsel_metal_gfx_game_frame` returns 0 and
  `ottsel_metal_present` runs the Metal pass, so `g_raster.fb` is never
  presented.

So the game-accurate producer exists and works, and the presented renderer is
the hand-rolled one. That inversion is the real blocker.

## Reorientation (this is the change of lane)

The primary lane is no longer "repair the next class". It is: **make the
presented frame come from the decoded GIF stream**, so a primitive's correctness
is decided once, in the parser and one generic draw, instead of five times in
five writers. Class differences become draw state (PRIM type, TME, ABE, alpha
test, TBP/wrap, depth) which the GIF stream already carries.

Per-class repair continues only where it is the cheaper instrument for a
specific, already-localised defect, and must be recorded as such.

### Gate N2 (first falsifiable step)

**Question.** With a gameplay level resident, does enabling the VU1 interpreter
put its decoded geometry on screen through the generic path?

**Method (bounded, flag-gated, no product default change).**

1. Add a trigger file (not an env var) that runs the interpreter with the
   existing instruction cap for a bounded number of chains, and routes its
   `gif_out` through the **native-capture** mode of the existing parser into
   `ottsel_metal_append_direct_mesh_n` (the same generic submission the Direct
   bucket already uses), behind a default-off switch.
2. Capture an A/B pair with the trigger present and absent at a matched boot
   offset, and classify the frames (clear-colour share, painted share).

**Exit bar.**

- **Presented frame changes in a way the parser explains** -> the lane is
  confirmed; the next step is to replace one World-1 writer with the generic
  path and re-measure.
- **No change** -> find out whether it is `gif_out` empty, primitives rejected
  by texture resolution, or the Metal append dropping them, and say which.
  Do not fall back to per-class repair without saying so.

### Secondary (only as instruments, not as the lane)

- Q-sky: if the sky still does not paint after the generic lane is wired, the
  question is "which bucket does training's sky live in", not "which constant is
  wrong".
- Q-strip: the corrupted top band. Measure the constant y-range first.
- Q-VU1STAT: `vu1-runs=0 raster-draws=0` in the default build remains the
  headline number to move.

## Loop rules (unchanged)

- One runtime at a time. Never launch the desktop oracle while Simulator.app runs.
- Read the desktop reference renderer and the shell source before hypothesising.
- Capture a sequence, never one frame, and always region-resolve it.
- The app stays signed-native, ROM-safe and non-JIT; `ottsel-fault.log` stays
  0 bytes. Frozen without a proven source mismatch: `set_mobile_tie_camera`
  math, TBP/lookup, strip-restart, the touch frontend, and all iPhone work.
- Evidence is capped at one concise document per proven gate (60 lines) plus at
  most eight appended `STATUS.md` lines. Append-only.
- Never `git add -A`. Keep every worktree file below 100 MB. Do not use
  `rm -f`; overwrite with `: > file`.

## Stop conditions (unchanged)

Stop and report, without claiming playability, on any of: a `tmp_pack_*` in the
repo, free space below 5 GiB, a nonzero `ottsel-fault.log`, an unsigned or
non-verifying bundle, three consecutive failed launches, or a route stage that
needs a product change in a frozen area.

