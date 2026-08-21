# M1: macOS versus iPadOS/iOS self-audit — 2026-08-21

## Verdict

Ottsel is not yet playable on iPadOS or iOS. macOS is the useful behavioral reference and is operational enough to exercise the retail title flow, but it is not a release-stability pass. The mobile work is a separate renderer/input/audio/lifecycle port, not a small packaging difference.

The Simulator must not be treated as proof from a blank or corrupted frame. The latest iPad capture shows visible controls and partial, heavily corrupted textured geometry; earlier captures were blank. Neither is coherent playability.

## Gate ledger

| Area | Current state | Evidence / remaining bar |
| --- | --- | --- |
| Signed native foundation | Passed | `OttselShell` is signed and contains no product runtime executable-page/JIT path. Reopen only on a correctly adapted failing regression. |
| macOS host | Partial pass | Fresh title → New Game → Village1/Training input and renderer observations exist in `docs/evidence/R1/`. Audio has PCM-liveness evidence, but audibility, teardown, and a stability soak are not closed. |
| iPadOS boot/import | Partial pass | A validated external user-data pack reaches the game route and Village1. This proves boot/data/input reachability, not a playable scene. |
| iPadOS native Metal | Open | Native producer-to-consumer AdGif/TEX0 mapping is now exact for the captured particle chain. The final composition still has missing/incorrect geometry and unresolved Sprite3/TIE/TFRAG ownership, depth, alpha, and resource sequencing. |
| iPadOS touch/controller | Open | Controls are visible and game-level input can be injected, but user-visible touch acceptance and lifecycle/reconnect behavior are not passed. |
| iPadOS audio | Open | The supplied Simulator audio runs exposed teardown/link-version failures; no honest audible mobile pass is recorded. |
| iPhone parity | Not started | No fresh iPhone boot, input, render, audio, lifecycle, or stress evidence. |
| Physical device readiness | Externally gated | Requires Apple signing/team access, physical devices and accessories, and device-side validation. It is not implied by Simulator success. |

## Why the platforms differ

macOS currently uses the broad host/OpenGL path and can execute enough of the existing renderer and retail flow to provide reference captures. iPadOS/iOS use the native Metal path, where the remaining failure is inside scene composition and resource interpretation: the native consumer receives real producer output, but the assembled frame is not yet the macOS scene. Mobile also adds touch ownership, audio-session behavior, suspend/resume, user-data import, and device/signing constraints.

Therefore the next product dependency remains the iPad native-renderer gate. The highest-value next slice is to reconcile the mobile phase/resource sequence against the macOS reference (`MSCAL=211`, accepted resource transition, and first-world texture ownership), then add one falsifiable Sprite3/TIE/TFRAG correction with a fresh screenshot and regression. No global texture remap, camera rewrite, or claim of iPhone parity is justified by the current evidence.

## Proof labels

- **Verified:** signed native executable, ROM-safe external data workflow, macOS route observations, iPad boot/import reachability, and the captured mobile producer-to-AdGif/TEX0 mapping.
- **Partial:** macOS rendering/audio behavior and iPad native Metal composition.
- **Open:** coherent iPad playability, touch acceptance, mobile audio, lifecycle/soak, iPhone parity, and physical-device readiness.

