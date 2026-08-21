# R1 post-Village1 bucket ownership dump — 2026-08-20

## Gate

R1 producer/consumer ownership after the frame-boundary join.

## Live identity and route

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed app executable SHA-256:
  `71e885c0d9d29654359c8cc018e0d214071b474626741385c9681271179206be`.
- One iPad Pro 11-inch (M4) Simulator, UDID
  `08636791-2675-4675-8335-EF72EF954DCF`.
- The route reached `GAMEPLAY: enter village1` twice before the dump trigger
  was armed. The Simulator was shut down afterward.

## Before failure

The frame-aligned mobile Sprite3 samples were stable at 320 group-0 sprites,
while the same-route macOS complete-frame oracle reports 2,432 group-0 sprites
across 51 blocks. The earlier bucket-67 aggregate was interpreted as a
separate Direct stream, but that interpretation was not sufficient to explain
the complete-frame count.

## Live bucket evidence

The bounded `ottsel-trace-mobile-buckets` trigger captured a post-Village1
chain with these table entries:

```text
index=65 addr=0xd02950
index=66 addr=0xd02970
index=67 addr=0xd00f40
index=68 addr=0xd01b50
index=69 addr=0xcdcf70
```

Both bucket 66 and bucket 67 are zero-qword `NEXT` entries. Their bounded
transfer walks contain the same Sprite3-shaped structure: frame transfer,
matrix transfer, 48-byte headers, 656-byte frame data, 80-byte matrix data,
then repeated 16-byte vector headers, 2,304-byte vector payloads, and
3,840-byte ADGIF payloads. Bucket 66 begins with the frame/matrix setup at
transfers 5–15; bucket 67 begins with the corresponding setup at transfers
0–10. The dump did not change either consumer or render bucket boundary.

The new read-only bucket-67 classifier then ran on a fresh Village1 frame and
reported:

```text
chain=40111 vsync=40112 groups=13 sprites=576
world=384 hud=128 3d=64 other=0
```

This is direct evidence that bucket 67 owns distinct Sprite3 phases,
including HUD and 3D work; it is not safe to treat the whole bucket as the
Direct-only stream.

The ordered phase/resource tuples from a second fresh Village1 capture were:

```text
3d 48 tbp=0x2be0 psm=19 tw=5 th=5
3d 16 tbp=0x2be0 psm=19 tw=5 th=5
world 48 tbp=0x2c8d psm=19 tw=5 th=5  (seven groups)
world 48 tbp=0x2d8c psm=19 tw=6 th=6
hud 48 tbp=0x2bd2 psm=20 tw=3 th=3
hud 48 tbp=0x2d9c psm=19 tw=6 th=6
hud 32 tbp=0x2c8d psm=19 tw=5 th=5
```

The phase order is structurally 3D → world → HUD, but its resources differ
from the macOS complete-frame order, which begins world at `tbp=0x24f2` and
contains 51 world blocks. This is a resource/ownership mismatch, not yet a
shader-space diagnosis.

## Interpretation

This is now a concrete producer ownership result. Bucket 67 contains distinct
world/HUD/3D Sprite3 phases, but it is still not proof that all of those
phases should be fed to the current bucket-66 world renderer. The existing
mobile consumer remains bucket-66-only, and the Direct diagnostic remains
separate. No camera, texture, shader, or native consumer widening is justified
from this result alone.

## Focused/live proof

- The rebuilt app passed strict signing and the 22-test focused suite,
  including `Sprite3Native.MatchesBucket67WorldTupleFixture`.
- The maintained patch passed reverse-apply checking.
- The fault log was 0 bytes; no JIT/executable-page markers were found.
- The Simulator remained blank and non-audible.

## Next falsifiable slice

The before-failing tuple fixture now passes for one bucket-67 world tuple
(`tbp=0x2c8d`, 48 sprites) and rejects HUD/count variants. The next slice is
the phase-specific native upload contract for that tuple, still trigger-gated
and still excluding bucket-67 HUD/3D ownership. Do not merge bucket 67
wholesale.

A fresh Village1 route then consumed the trigger-only native probe and logged:

```text
chain=53052 vsync=53053 drawn=640 candidates=640
fixture-uploaded=true cpu-product-frame=0
```

The route reached `GAMEPLAY: enter village1` twice and `ottsel-fault.log` was
0 bytes. This proves the bounded signed-Metal upload seam and its fixture
guard; it does not prove a visible frame, image parity, or playability. The
Simulator remained blank and non-audible.

## Verdict

OPEN. The frame boundary, bucket-67 phase ownership, tuple fixture, and
trigger-gated native upload contract are proven. Image parity, full phase
composition, and product playability remain open.
