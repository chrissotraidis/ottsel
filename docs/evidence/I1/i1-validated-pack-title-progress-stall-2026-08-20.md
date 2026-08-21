# I1/F1 validated-pack title progress stall — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | I1 input route / F1 data-backed title transition dependency |
| Environment | iPad Pro 11-inch (M4) Simulator, iOS 18.5; one SDL-only runtime; validated pack imported into durable Application Support; no macOS runtime |
| Before failure | The real route previously could not reach `title-play received wait` on a fresh no-pack install. With the pack present, the remaining question was whether Start/Cross/Left timing or the progress state blocked New Game. |
| Live proof | Current-launch logs reached `title-play received wait`, consumed Start, entered normal progress, then consumed Cross and Left. Cross logged `PC PROGRESS: accept`; the next state values were `0x1b` (title) and `0x12` (save-game-title), which are valid `progress-screen` enum values despite the diagnostic `~A` formatter rendering them as `#<invalid object ...>`. The same pending display line repeated for more than 60 seconds and no `GAMEPLAY: enter village1` followed. A full transition wait did not change the result. |
| Fault scan | `ottsel-fault.log` remained 0 bytes. No crash/assert/unsupported/placeholder/bounds marker was observed. |
| Interpretation | The input seam and pack/data boundary are live; this is a persistent progress-transition/runtime-state stall, not an input timing miss. The normal-Metal follow-up was discarded because its stale persistent log caused premature Start injection; it is not evidence. |
| Simulator boundary | Blank/non-audible Simulator; no visual, audio, or playability claim. |
| Verdict | OPEN — isolate the transition state/clock or generated progress path before claiming real New Game. |
| Next gate | Add a raw-value diagnostic at the progress transition boundary or compare the same `progress-pc` path on macOS, then make one minimal correctly adapted fix only after a red discriminator. |

