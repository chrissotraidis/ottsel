# M1 fresh macOS bounded stability increment — 2026-08-21

## Verdict

**PARTIAL PASS — macOS remains the active product queue.**

This is a fresh current-checkout stability increment, not a declaration that
the whole macOS stability gate or the game is complete. It establishes visible
retail progression, real keyboard-driven movement/action response, a bounded
active interaction soak, continued live composition after the soak, and no
matching fault report. Human-audible acceptance, repeated cold-start
reproducibility, physical-controller replay, and explicit background/resume
lifecycle coverage remain open.

## Platform order

The authoritative order remains:

1. **macOS stable and visibly playable first.**
2. **iPadOS parity/playability second.**
3. **iPhone parity and physical-device readiness third.**

No Simulator was booted during this run. This result does not by itself
unblock new iPad implementation or R1 traces; mobile stays paused behind the
remaining macOS-stable-reference clauses.

## Ledger

| Field | Required value |
|---|---|
| Gate | M1 — current-checkout bounded macOS stability |
| Source/build identity | Outer HEAD `b2e36fc8037f3f1a7984ede59f7114cd03604b2f`; maintained upstream worktree pinned at `641fb572e876750d8618434d9f7c1a531b43b366`; `gk` SHA-256 `26bdcbc8e2e2864adc5a2e178e55529d6d107b3a5633cf13e6825cc5e2be0b68`; lookup-trace patch SHA-256 `b4c71ec08a87af02a1dc2233acfc2bb176ddf31d3e1104990a825cb88aab8f27`. |
| Environment | macOS 26.5.2 build `25F84`, Apple M1 arm64, one Windowed native `gk`; no booted Simulator. |
| Before failure | The corrected board had no fresh current-branch end-to-end proof and explicitly said neither platform was proven stable/playable. |
| Change | Audit-only fresh launch and interaction replay; no source, renderer, camera, shader, texture-map, or Metal-policy change. |
| Focused proof | Identity files and timestamped screenshots under `docs/evidence/M1/artifacts-2026-08-21-macos-stability-gate/`. |
| Live proof | PID 44189 launched at 13:51:05 with `OTTSEL_AUDIO_OUTPUT_DEVICE='MacBook Air Speakers' build/h1/game/gk -v --game jak1 -- -boot -fakeiso`. Real keystrokes completed title → New Game → overwrite-save YES → retail A/B/C/D1/D2 cinematics → Village1 → Training. Held-W visibly moved Jak. Ten interaction cycles used W, camera-right, and jump; captures `soak-01..10.png` cover roughly four minutes of active interaction. Post-soak captures `11-post-soak-neutral.png` and `12-fresh-post-ledger-check.png` show coherent animated Training/water composition with the character present. |
| Fault scan | No matching `gk`/OpenGOAL report in `~/Library/Logs/DiagnosticReports` during the run window. At 14:13, PID 44189 remained alive after 22 minutes; the fresh screenshot SHA-256 is recorded in `gk.sha256`. |
| Verdict | PARTIAL PASS as defined above. |
| Next gate | Continue M1 on macOS only: repeat the cold-start path, retain raw audio/log artifacts, obtain human audible-output acceptance, exercise explicit neutral/background-resume lifecycle, then run a longer bounded controller/keyboard soak. Only the completed macOS-stable clause set unblocks iPad. |

## Evidence boundaries

- Input was delivered through real System Events keyboard events, not a
  physical controller.
- Audio selected the speakers and nonzero PCM was observed on the live log
  stream during the cinematic sequence, but the raw stream was not retained and
  no human listener confirmed audible correctness.
- The soak is bounded and active, not an overnight or thermally constrained
  endurance test.
- Build success, title visibility, counters, and earlier stale historical runs
  are not treated as proof here.
