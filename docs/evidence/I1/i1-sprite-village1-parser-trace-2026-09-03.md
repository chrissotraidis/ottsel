# I1 Sprite3 Village1 parser trace — 2026-09-03

## Question

Does the previous Sprite3 trace fail because its one-shot trigger is consumed
during title traffic rather than Village1?

## Change

The trigger consumer was gated on the live `village1` camera phase. The focused
policy test passed 2/2, then a fresh signed iPad Simulator build was installed.

## Route

One iPad Pro 11-inch M4 Simulator (`08636791-2675-4675-8335-EF72EF954DCF`).
The bounded route was title → Start → Cross → Down ×4 → Cross; the trigger was
created only after `OTTSEL LEVEL MARKER: level=village1` appeared.

## Evidence

The parser probe armed at chain 299 / vsync 300 in Village1. It captured:

```text
frame transfer=9 size=656 imm=0x3d4
matrix transfer=12 size=80 imm=0x384
header transfer=13 count=48
payload run-vif=0x14000003 run-kind=20 run-imm=3
header transfer=14 count=16
payload run-vif=0x14000003 run-kind=20 run-imm=3
hud matrix transfer=16 size=1280 imm=0x384
bucket complete groups=2 sprites=64 hud-sprites=0 3d-sprites=0 other-sprites=0
```

The first group reports camera-t `(104070.54, 25300.473, -9.2589e9,
-40.293346)` and first camera `( -2638016.8, -5743057.5, 2.9208e10,
126.80606)`. The resulting frame is severely rotated/malformed, with large
black regions and no visible Jak or HUD.

PCM was nonzero in this run (`pcm-peak=3966`); no fault marker was observed.
Frame: `/tmp/ottsel-video/bot36-sprite-village-trace-live-2026-09-03.png`
SHA-256: `2138ec9998d5242cc8f248e1317d012970330fb669248361083a5f68202eadbe`

## Result

OPEN. The original title-consumption hypothesis is falsified. Village1 really
does provide two MSCAL-3 groups and no HUD/3D group in this captured bucket,
while the inherited 2D camera data is implausible. Next investigation should
trace Sprite3 bucket ownership/transfer semantics and the producer’s 2D camera
contract before changing rendering math.

## Bucket-67 follow-up

The diagnostic-only second-bucket probe reproduced a 48-sprite MSCAL-3 group
and the 80-qword matrix, still with no MSCAL-109/211 payload. Its frame hash is
`9553bec4ce872fec75a9acb2762c0171fb8d8f2f2646f6760c1a806c094e9bcc`.

The phase-window replay resolved the address ambiguity: bucket 66 had zero
groups; bucket 67 contained the 48-sprite MSCAL-3 group plus a zeroed 16-sprite
tail. There was no screen-space group 1 payload in this Village1 frame, so the
missing HUD is producer-side for this route, not an unhandled MSCAL-109
consumer. This shifts the next product investigation to Merc/Jak visibility
and the native scene camera contract.
