# R1 visual runtime replay R13 — 2026-08-22

## Scope

This is a fresh visual check of the single booted iPad Pro 11-inch (M4)
Simulator and its single `com.ottsel.shell` runtime after the R12
source-boundary correlation. The app was inspected through the Simulator UI,
not inferred from build output.

## Live identity

- Simulator: iPad Pro 11-inch (M4), iOS 18.5,
  `08636791-2675-4675-8335-EF72EF954DCF`
- Exactly one booted Simulator and one Ottsel runtime were present.
- Keyboard capture was enabled in the Simulator and W/A/S/D were sent through
  the active app window.

## Fresh visual evidence

- [fresh follow-up screenshot](artifacts-2026-08-22-ipad-r1-consumer-correlation-r12/fresh-followup.png)
- [keyboard-capture follow-up screenshot](artifacts-2026-08-22-ipad-r1-consumer-correlation-r12/keyboard-capture-followup.png)
- [prior validated live route video](artifacts-2026-08-22-ipad-r1-launch-timing-r9/exact-route-timing.mp4)

The direct Simulator UI capture is landscape and shows the current failure
clearly: the world is visible but split by a horizontal seam, with dark or
offset sections and missing/incorrect composition. The initial touch overlay
obscured part of the scene; enabling Simulator keyboard capture removed that
overlay. The result is still not honestly playable.

`simctl io recordVideo` was attempted for this fresh replay, but the host
reported `Host recording is already in progress` / `Resource busy`. No second
Simulator was opened and no Simulator restart was performed. The existing R9
H.264 capture remains the available validated video artifact.

## Controls boundary

The Simulator accepted keyboard capture and delivered the W/A/S/D replay to
the active app window. This is evidence that the native keyboard route is
exercisable, not proof that gameplay movement is correct; input movement and
human mouse acceptance remain open until the scene composition is fixed.

## Decision

R1 remains open. The R12 source-side result still closes page-directory,
allocation, raw particle-to-AdGif, and AdGif-to-native TEX0/TBP identity for
the captured family. R13 adds direct visual confirmation that the next
investigation is native Direct/Sprite/TFRAG/TIE composition and presentation,
with the Simulator recorder resource separately blocked. No TBP, camera,
shader, or Metal policy remap was made in this replay.
