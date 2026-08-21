# R1 mobile Sprite3 record ledger — 2026-08-20

## Result

The bounded ledger makes the current mismatch attributable. In a clean signed
normal-Metal iPad Simulator replay, the live bucket-66 stream reached Village1
and emitted populated `MSCAL 3` / `Sprites2dGrp0` groups, but the first six
populated groups consistently used texture page `0x2c8d`. The macOS Village1
reference group uses `0x24f2`/9458. This is a route/phase mismatch, not enough
evidence to change Metal alpha, depth, or blend policy.

## Build and live evidence

| Field | Result |
|---|---|
| Signed app | SHA-256 `a24ba7af1d2298560e1bcfacbe3f67be8d159bd6b0d657cc46abe11c3d7b6a04` |
| Validation | `scripts/build-ios.sh`, strict codesign, focused 18-test filter, product executable-marker scan, and `git diff --check` passed |
| Runtime | One iPad Pro 11-inch (M4) Simulator; it reached Village1 FR3 camera records and was shut down after the bounded replay |
| Ledger | Trigger-gated, 64-record maximum; armed at chain `2537`, completed exactly 64 records, then disarmed |
| Mobile stream | Bucket 66, `MSCAL 3`, groups of 48 populated records; first populated group `tbp=0x2c8d`, PSM 19, 32×32, TCC 1, TFX 0 |
| Mobile raw state | `TEX0=0x2005a0455530ac8d`, `TEX1=0x0000000000000120`, `CLAMP=0x00000001010001c0`, `ALPHA=0x0000000000000048`; the same tuple repeated across the populated groups sampled |
| Same-chain camera state | The canonical iPad route records `pc-level='village1'`, `pc-trans=(-482016.1,218586.67,1151304.5)`, `pc-fog=-0.05945198`, `rot.r0=(-0.95494163,0.056473088,-0.2913713)`, `rot.r2=(0.29679358,0.18197167,-0.93744326)`, and frame `pfog0=-0.05945198`. A fresh like-for-like macOS route records `intro-start` expected/stored r0 `(0.6381,0,0.7699)`, then stable update math-inv r0 `(0.6385,0,0.7695)` and r2 `(-0.7695,~0,0.6385)` from target position `(164316.78,15128.576,3390588.0)` |
| Fault boundary | `ottsel-fault.log` remained 0 bytes |
| macOS reference | Frame 4/5 world group `TBP=9458` (`0x24f2`), 64×64, `TEX0=0x2004d1e59930a4f2`, blend 2, ztest 2, zwrite false, alpha-test 2, aref 0.000; 23 sprites |

## Interpretation

The current mobile capture remains a different Sprite3 texture/resource phase
(`0x2c8d`, 32×32, raw `TEX0=0x2005a0455530ac8d`) from the macOS reference
(`0x24f2`, 64×64, raw `TEX0=0x2004d1e59930a4f2`). The fresh-marker camera
replay falsifies the earlier camera-divergence theory: the iPad `PC_PORT` rows
match the route's `math-rot` rows, with only normal frame-to-frame movement.
The remaining mismatch is therefore resource/bucket phase or Sprite3 state,
not a justified Metal camera transform change. The Simulator was blank and
non-audible, so this remains diagnostic evidence only.

The subsequent Sprite3 synchronization attempt is deliberately excluded from
the ledger: its synthetic Start was logged before the `title-play received
wait; entering title-wait` boundary, so the route was not in the intended
canonical state when the later taps were sent. No texture/resource conclusion
is drawn from that run. The next driver must wait for the fresh boot's
`GAMEPLAY: enter title`, inject Start, then wait for the new title-wait marker
before sending Cross/Down/accept.

A later fresh-marker attempt did satisfy that ordering (`GAMEPLAY: enter
title` → synthetic Start → new title-wait), but produced no subsequent
progress edge after Cross. It was stopped without arming or interpreting a
Sprite3 ledger. This is route-driver liveness evidence only; it does not change
the camera correction or prove a new blocker.

The next bounded Metal attempt used the stronger `OTTSEL TITLE: start edge in
title-wait` marker and did not observe it after synthetic Start; it only logged
fresh `GAMEPLAY: enter title`, synthetic Start, and the title-play wait
transition. It was also stopped without blind taps. The current open boundary
is therefore post-Start Metal route progression; Sprite3 resource attribution
must wait for a valid Village1 entry.

The source audit confirms the title handler only logs `start edge in
title-wait` when `cpad-pressed? start` is sampled inside that state. A further
watcher keyed to the title-play log still observed synthetic Start before that
log line in the persisted/asynchronous runtime file, so it was rejected as a
state-synchronization mechanism. The next discriminator must arm from an
in-runtime state/edge, not log-file ordering.

## Canonical-route confirmation

A follow-up replay with the actual file-trigger sequence consumed Start, Cross,
four Down taps, and the final Cross through the canonical keyboard latch. The
runtime logged progress edge/accept records, `GAMEPLAY: enter village1`, and
the `intro-start` camera handoff before the bounded ledger captured the
populated Sprite3 chain. The fresh macOS replay consumed the same route and
logged the matching `intro-start` handoff plus stable camera updates.
This proves the normal-Metal route boundary and same-chain camera/resource
identity, and the fresh-marker replay now proves the active camera packet is
consistent with the route's own math-rotation trace. It does not prove visual
parity or playability. The Simulator remained blank and non-audible and the
fault log stayed at 0 bytes.

## Next falsifiable slice

Use the fresh-marker route boundary and exact Sprite3 ledger to identify why
the active iPad group uses `0x2c8d` while the accepted macOS Village1 reference
uses `0x24f2`. Capture the first Sprite3 group immediately after the new boot's
`GAMEPLAY` marker with the same reliable marker, then compare ordered packet
state and resource ownership. Do not change camera, batching, or shader
semantics until that resource-phase comparison falsifies a specific mismatch.
Retain the one-runtime/one-Simulator rule and do not call this R1 or mobile
playability.

No MAP_JIT, runtime executable page, dynamic trampoline, external Metal shell,
or protected game data was imported.

## Camera-transition follow-up — corrected attribution

The source increment added a trigger-gated 64-packet ledger at
`capture_mobile_camera`, after the `PC_PORT` packet has been copied and before
`set_mobile_tie_camera`. It does not modify the packet or renderer. The new
`OTTSEL RUNTIME BOOT: pid=...` marker made the route timing unambiguous. When
the camera ledger was armed immediately after that boot's first
`GAMEPLAY: enter village1`, the first packet was:

`trans=(194774.03,28030.99,3365348.0)`,
`r0=(0.63854456,-0.028522143,-0.76905614)`,
`r2=(0.76958483,0.02366561,0.63810587)`.

The route's adjacent `math-rot` diagnostics were
`r0=(0.6385,0.0015,-0.7695)` and `r2=(0.7695,-0.0012,0.6385)`, followed by
smooth packet movement. The earlier comparison had compared packet rotation
to `math-inv`/combiner rows, which use the opposite basis convention. Camera
transition is therefore OPEN only as a future visual-parity measurement, not
the current cause of the Sprite3 resource mismatch. The reliable next slice is
the same-marker Sprite3 packet/resource capture.
