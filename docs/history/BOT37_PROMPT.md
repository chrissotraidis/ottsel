# BOT37 — iPad Village1 scene-correctness goal (continuation prompt)

Feed this whole file to the next bot. It is the active goal until I0/I1 move.

## Goal

Honestly playable native Jak 1 on one iPad Simulator: title → New Game →
Village1 → Training with Jak visible and controllable, coherent depth and
composition, nonzero game PCM, and stable pacing. Mac remains the visual and
behavioral reference. iPhone parity and physical-device work stay paused.
A launch, log, counter, title screen, or first frame is not playability proof.

## Where the project is at (evidence, not claims)

- Prior audits: `docs/reports/2026-09-03-ipad-village1-render-audit.md` and
  `docs/reports/2026-09-06-ipad-malformed-scene-audit.md` (read both first,
  plus `docs/BOT36_PROMPT.md` and `AGENTS.md`).
- Depth (clear 0 + GreaterEqual), packet-level ownership (`title`→`village1`),
  Merc raw-perspective (giant panels gone), PLAYER RPC audio (`pcm-peak` to
  15476), and VU-diagnostic gating (container stable) are in and correct —
  but the Village1 frame is still malformed and I0/I1/I2 remain OPEN.
- Decisive narrowing: `eichar-lod0` IS captured (chain 311, 2253 tris), yet
  retained Eichar verts sit behind the near plane (clip-z ≈ −1.05,
  visible=0 over 32 packets). TFRAG/TIE share one `tie_vs`, but upstream
  splits them (`tfrag3.vert`: no Q/HVDF; `tie_wind.vert`: always Q/HVDF).
  Black regions are structural (sky/ocean/TRANS/WATER/envmap/shrub/HUD paths
  missing or gated). Title `enter-state` SIGSEGV (`x20=0`, fault `0x140`)
  still recurs intermittently.
- Disk gate currently FAILS (`Avail 4.0Gi` on 2026-09-06): free space or stop.

## Frozen (do not touch)

Camera matrix math (`set_mobile_tie_camera`), TBP/lookup, strip-restart code,
touch frontend, and iPhone work. No new R-round; no playability claims until
Jak is visible and controllable with stable ordering.

## Operating loop (every experiment)

1. Gate first: `df -h / | tail -1` and temporary-pack count. Below 40 GB
   free or any `tmp_pack_*`: report paths/sizes and stop.
2. One change per signed build, regression-first, on one booted iPad
   Simulator and one runtime. Record only under `/tmp/ottsel-video/` with
   the bounded SIGINT recipe; keep worktree files <100 MB, never `git add -A`.
3. Capture paired no-MERC / no-TIE control frames, chain rate from `VU1STAT`,
   `pcm-peak`, container delta, and 0-byte fault-log check every run.
4. Write PASS/OPEN honestly in one concise evidence doc (60 lines max).

## Ordered experiments (one at a time)

1. Merc skinning/matrix vs upstream `emerc.vert`: why is retained Eichar
   behind the near plane? Before-failing one-vertex identity-bone projection
   regression; expect clip-visible>0 and a Merc-only Village1 frame.
2. Split TFRAG/TIE vertex paths to the upstream contracts; paired
   family-isolation frames at the same camera packet.
3. Same-packet macOS-vs-native TFRAG vertex correlation before any domain or
   ownership edit (NDC extremes −422..438 remain unexplained).
4. Letterbox/aspect (`SCISSOR_ADJUST*HEIGHT_SCALE` vs 512/448 on the full
   drawable) plus depth-mode mapping review.
5. Whenever the route gates at `enter-state` (`0x140`): stop renderer work,
   identify the null process/state caller, regress the pointer contract,
   and rerun one cold launch.

## Proof required before any gate moves

Focused regressions green, fresh Village1 frames with Jak visibly moving
under input, chain rate ≥30/s, `pcm-peak>0`, container growth <1 MB/run,
fault log 0 bytes, and a 30 s bounded recording. Missing-actor, black-gap,
or debug-rectangle frames are failures even when the process stays alive.
