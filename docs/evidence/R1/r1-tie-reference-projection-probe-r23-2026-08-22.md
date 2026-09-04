# R1 TIE reference-projection probe R23 — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 native TIE/TFRAG composition |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618344d9f7c1a531b43b366`; signed executable `7875e22db54f1bdca058dfe80ba3347698d09dd0d1c22bd675739cf1fd0bce6d` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime PID `80398` |
| Before failure | The maintained native TIE-only isolation produced radial/stretched geometry. The OpenGL normal TIE path uses `ShaderId::TFRAG3` and consumes `pc_camera` directly. |
| Change | Added trigger-gated `ottsel-trace-metal-scene-tie-reference-projection`; only when armed, native TIE uses the same direct `pc_camera` path as TFRAG. The product default remains unchanged. |
| Focused proof | `scripts/build-ios.sh` completed; strict deep signing passed. |
| Live proof | Fresh F1 promotion succeeded, title-wait route reached Village1, and the trigger was consumed. Fresh frames: `artifacts-2026-08-22-ipad-live-visual/ipad-tie-reference-projection-111941.jpeg` and settled `.../ipad-tie-reference-projection-settled-112004.jpeg`. |
| Fault/audio | Fault log was 0 bytes. Audio remains non-accepted; prior route windows report `pcm-peak=0`. |
| Verdict | OPEN / PARTIAL SIGNAL — radial stretching disappeared and textured geometry remained, but the captured camera was a close-up and the full Village/playability comparison did not pass. Do not promote the probe to the product default yet. |
| Next gate | Same-phase normal-vs-reference TIE replay, then decide whether to retain the direct `pc_camera` path as the native TIE implementation. |

## Source basis

Maintained `Tie3::draw_matching_draws_for_tree` selects `ShaderId::TFRAG3` for
normal TIE categories, and `tfrag3.vert` performs the `pc_camera` transform
without the extra Q/HVDF block used by the temporary native TIE path. The probe
therefore tests a source-defined difference rather than an arbitrary camera
remap. No TBP, lookup, resource allocation, TFRAG path, or global Metal policy
was changed.

## Same-phase replay boundary

The clean product-default replay reached Village1 and was actively inspected
at 11:23:13. Its frame was still a close-up with blue/missing upper-scene
content, so it was not playable evidence. The reference-projection replay
reached Village1 twice after the trigger was armed before the final Cross;
the durable settled frame is
`artifacts-2026-08-22-ipad-live-visual/ipad-tie-reference-same-phase-sky-112412.jpeg`.
It retained textured geometry and did not reproduce the radial symptom, but
it remained a close-up/missing scene and did not establish playable parity.

A later clean-default retry is explicitly excluded: its touch trigger failed
with `No space left on device` after duplicate 1.5 GiB pack copies exhausted
the host volume. The nested imported copy was deleted, the durable Documents
pack was preserved, and a clean relaunch re-promoted that pack successfully.
This does not alter the R23 verdict or promote the probe to the product
default.

## Fresh visual capture after cleanup

At 11:30:51 the clean product-default runtime was captured and inspected in
the Simulator. The frame showed more of the Village than the earlier
radial-only isolation, but still had conspicuous flat/missing material blocks
and an incorrect close framing; it is not playable proof:
`artifacts-2026-08-22-ipad-live-visual/ipad-clean-default-current-113051.jpeg`.
A bounded 4-second Simulator recording was also captured for motion/lifecycle
inspection:
`artifacts-2026-08-22-ipad-live-visual/ipad-clean-default-current-1131-attempt.mov`.
