# BOT67 PROMPT — reorient: get past the intro, then measure the oracle gap

Status 2026-09-12. Supersedes BOT66's lane ordering. Gates map to
docs/16-ipados-ios-goal-loop-2026-08-23.md (M0/I0/I1/I2/I3/P1/D1).

## Why the last day produced nothing (read this first)

The sky bucket is a real defect and it is **bounded**: with `-sky-debug-fill` the same
batch0 that yields zero fragments paints 99.5 % magenta from the same vertex buffer,
pipeline, depth state and pass position. So every stage executes and only the sampled
value differs. That has been stable for two days, and it is one bucket.

What actually blocked progress is elsewhere, and it is not a shader:

- The app was **not running** for the whole review. `kernel: machine shutdown` at
  19:56:44 ended a 56-minute run, and the 06:56 screenshot is the **intro/logo** state
  ("the Precursor Legacy" + Jak), not `village1`. We have no deterministic way to
  navigate past the intro, so every measurement downstream of it is unreproducible.
  Earlier `village1` claims came from a `-press-start` trigger and were never
  re-asserted per frame.
- 715 uncommitted lines of diagnostics and 60 rounds sit on the product path. The
  `saturate()` early return at `metal_shell.mm:85` currently makes `metal_shell.mm:86-100`
  dead code, so the shipping fragment path is not the product path.
- The container is **2.3 GB** (760 MB runtime log) on 11 GiB free. The scaffolding writes
  ~2 GB/day, which is why the disk gate keeps tripping.

The shell boots and draws the world; the gap to the oracle is scope of coverage, not one
constant. Stop adding probes.

## Corrections to carry forward

- The shell transform **is** algebraically identical to the oracle. Roundtrip:
  ndc 4.0 -> game 0.75 -> `(0.75-0.5)*16 = 4.0`. Do not re-open this.
- The "sky is off-screen" hypothesis is **refuted** for batch0: its logged
  `ndc x in [0,4], y in [-0.009,3.99]` maps to the right half above vertical centre, a
  large on-screen region, and it still yields zero fragments.
- `regions.py`/`mask.py` (r12) use an unrotated portrait map. Screenshots are
  1668x2420 portrait while the drawable is 1210x834 landscape, so all their region
  numbers are wrong. Use `/tmp/ottsel-r13/reg2.py` and `land.py`.

## Lane (in order; one probe per run)

1. **Navigate the intro deterministically.** Find the exact trigger that reaches
   `village1` and log the scene level every frame. Nothing after this is measurable
   until `scene-level='village1'` can be asserted from the log, not inferred from a
   picture. If the trigger is timing-dependent, make it a scripted input sequence.
2. **Revert the diagnostics, then commit.** Restore the real `direct_fs` body (drop the
   `saturate` early return), drop `direct_fs_debug_tex`/the probe pipelines, and publish
   the tree so the product path is the product path again. Truncate the 760 MB log and
   cap it.
3. **One bounded BEFORE/AFTER against the oracle.** Run the macOS oracle
   (`/tmp/ottsel-diag/mac/`, Return=START, Space=CROSS, Down=DOWN) to `village1`, capture
   it, then capture the same scene on the iPad and diff the two by named region. Fix the
   **largest** region first, not the sky.
4. **Only then the sky sample.** The one untested step is
   `setFragmentTexture`/`setFragmentSamplerState`/`setFragmentBytes`. BOT66 item 1
   (`return float4(fract(in.uv),0.5,1.0)`) is still the right splitter. Carry BOT65's open
   CLUT anomaly (`tbp=0x10 cbp=0x50` reads an all-zero CLUT; `tbp=0x14`/`0x20` are real).

## Exit bars (unchanged, do not move)

One fresh **inspected** frame per experiment with SHA-256; assert the scene level before
interpreting any frame; paired controls so a win cannot be coincidental overdraw;
`ottsel-fault.log` at 0 bytes; signed-native, ROM-safe, non-JIT. A Mac boot, counters,
logs, title screen or first frame is not playability proof. Playability needs sustained
gameplay with input, camera follow, stability and audio.

## Evidence

`/tmp/ottsel-r14/live.png` (06:56 intro state), `/tmp/ottsel-r13/{now.png,reg2.py,land.py,grid.py}`,
`/tmp/ottsel-r10/mag.py`, `$W/ottsel-runtime.log` (lg::info only), probes via unified log.
