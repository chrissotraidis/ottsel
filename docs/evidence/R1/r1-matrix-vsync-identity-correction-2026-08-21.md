# R1 matrix/vsync identity correction — 2026-08-21

The prior vsync note correctly recorded observations but over-interpreted the
raw frame hash as a complete frame identity. `sprite-setup-frame-data` fills a
large payload containing GIF state, screen-shader texture/TBP fields, constants,
and camera-derived fields. Therefore a changing frame hash does not by itself
prove a changing camera frame.

In the cited mobile capture, both alternating frame hashes carried the same
camera-relevant values: `pfog0=-0.046546843`, `basis-x=(0.41880882,0,0,0)`,
`basis-y=(0,0.24430515,0,0)`, and `inv-area=0.10231715`. The matrix staying
constant across those hashes is consequently not proven stale. The matrix did
change when the camera packet values changed, but the capture did not establish
that the raw frame hash represented camera identity.

| Field | Result |
|---|---|
| Verdict | OPEN, corrected. The capture proves raw payload variation and a later matrix/camera transition, but not a bad producer phase pairing. |
| Disallowed conclusion | Do not swap/reuse matrices, alter camera signs, remap TBPs, or change visibility policy from the hash/vsync observation. |
| Next gate | Add a camera-only frame signature (camera-derived fields and the exact matrix source fields) or trace the GOAL producer directly, then create the phase-pair regression only if that signature mismatches. |

This correction preserves the blank/non-audible Simulator boundary and does not
claim R1 parity.
