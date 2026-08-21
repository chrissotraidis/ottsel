# M1 fresh macOS current-audit route and move — 2026-08-21

## Verdict

**PARTIAL PASS — another bounded increment.** This is not a claim that macOS is
stable/playable or complete.

- One runtime: native Windowed `gk` PID 47438, launched via `launchctl submit`
  at 14:34:42 with audio output device `MacBook Air Speakers`.
- Same-boot route replay completed Start → Cross → Down×4 → Cross using real
  System Events keyboard events; runtime logged `GAMEPLAY: enter village1`
  twice after the final Cross.
- A separate bounded synthetic left-stick hold (`x=255 y=127`, 900 pad reads)
  was accepted by the same runtime and released to neutral; before/after
  captures show Jak visibly relocated near the blue eco platform.
- No booted Simulator existed during any part of this run.
- Fault scan found no matching new crash report and no fault/assert/panic line
  in the retained runtime logs during this window.

## Ledger

| Field | Required value |
|---|---|
| Gate | M1 current-checkout reproducibility/stability (partial) |
| Source/build identity | Outer HEAD `d5e12ccdb21af2e3d409611648f14064379a5392`; upstream pin `641fb572e876750d8618434d9f7c1a531b43b366`; `gk` SHA-256 `26bdcbc8e2e2864adc5a2e178e55529d6d107b3a5633cf13e6825cc5e2be0b68`; launch label `ottsel-m1-repro`. |
| Environment | macOS 26.5.2 build `25F84`; Apple M1 arm64; one Windowed native runtime; no Simulator. |
| Before failure/limitation | Prior status still pointed to outer commit `b2e36fc`; prior proof lacked retained raw logs/audio and explicit move/lifecycle acceptance on the exact launch harness. |
| Change | Audit-only: fresh stable `launchctl submit` run, file-trigger route replay, and synthetic left-stick move. No source/renderer/camera/shader/Metal-policy change. |
| Focused proof | Runtime accepted every injected edge and the left-stick hold; marker lines are captured in `route-marker-lines.txt`, `gameplay-marker-lines.txt`, and `move-marker-lines.txt`. |
| Live proof | Title screenshot `04-attempt4-title.png`; post-intro composed cinematic `06-post-intro.png`; Village1 composition `07-gameplay-candidate.png`; before/after move pair `08-before-move.png` / `09-after-move.png` with SHA-256s in `move-image-hashes.txt`. Raw stdout/stderr retained under `current-audit/`. |
| Fault scan | `crash-report-scan.txt`: no matching new DiagnosticReports entry; `fault-scan.txt`: no fault/assert/panic match in retained logs. |
| Verdict | PARTIAL PASS as defined above. |
| Next gate | Continue M1 only: human audible-output acceptance, neutral background/resume/input lifecycle, longer physical-controller soak, then repeat cold-start reproducibility. Only the full clause set unblocks iPad R1. |

## Boundaries

- Input remains keyboard/System Events; no physical controller acceptance yet.
- Audio device selection and PCM liveness were established earlier, but no
  human listener confirmed audible correctness in this run.
- The move soak is short and synthetic, not endurance or thermally constrained.
- This does not unblock iPad/iPhone work.
