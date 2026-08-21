# R1 fresh Village1 raw-span retry — 2026-08-20

## Gate

Validate the mobile 66→68 raw producer ledger at a genuinely fresh
`village1 display-self` route marker, separating producer shortfall from
consumer rejection.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed Simulator executable SHA-256:
  `7bdeca9e5c5347c83ae1951ea85cbd012a053af6dd44ddf4b9273e5ff9011dbf`.
- One iPad Pro 11-inch (M4) Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`.
- Fresh process PID `11699`; the log was anchored at its current boot marker.

## Before failure

Earlier trigger runs either consumed the phase window in title/progress or
matched stale lines in the append-only runtime log. They could not establish
that a raw-span count belonged to the current Village1 route.

## Live proof

The current process emitted two fresh `village1 display-self` markers before
the armed product window. The same route then emitted:

```text
OTTSEL SPRITE RAW SPAN: label=product-66-to-68 chain=25389 transfers=33 headers=10 rejected=0 boundary-stops=0
OTTSEL SPRITE PHASE: label=product-66-to-68 chain=25389 vsync=25390 groups=10 sprites=448 world=320 hud=128 3d=0 other=0
```

The split interval agreed: bucket 66 contained setup only, and bucket 67→68
contained the ten accepted groups. Ordered resources were six world groups at
`0x2c8d`, one final 32-sprite world record whose decoded texture fields were
zero, and HUD groups at `0x2bd2`, `0x2be8`, and `0x28b8`. The zero-TBP record is
now a concrete producer/data-shape anomaly to inspect; it is not remapped or
discarded by this diagnostic.

## Focused and fault proof

- `goalc-test --gtest_filter='Sprite3Native.*'`: 12/12 passed.
- `scripts/build-ios.sh` and strict codesign: passed for this executable.
- `ottsel-fault.log`: 0 bytes.
- Simulator was blank/non-audible; no visual, audio, or playability claim is
  made.

## Verdict and next gate

OPEN. The mobile consumer accepted every candidate in this fresh Village1
span, so silent rejection is not the explanation for the missing macOS phase.
The next slice is the producer/data-shape audit for the zero-TBP world record
and the missing macOS 51-block sequence. Preserve the current bucket boundary,
texture policy, camera, and shader semantics until that source record is
attributed.

## Follow-on discriminator

The signed build was then rebuilt with a capped `OTTSEL SPRITE ZERO TEX` raw
ADGIF dump in `trace_mobile_sprite_phase_bucket`. It records the first
`tex0/tex1/clamp/alpha` words when a candidate's decoded `TBP` is zero, without
discarding the group. The focused `Sprite3Native.*` suite remained 12/12,
strict codesign passed, and the new executable SHA-256 is
`fd172a49f458e96b0a0b5804401786c2e825aa55bdf9b2ce37edbd65d0ab0f6a`.

At this stage the live raw ADGIF dump was still pending; that earlier build was
only a source/build discriminator, not a claim that the zero-TBP record was
fixed.

The discriminator was extended into the normal retained product walker so the
raw words are captured whenever a zero-TBP group is encountered, even if a
phase trigger lands on setup-only chain 1. The rebuilt signed executable is
`987424be0184687714b327632b292ccebbdb1ae359c2450e159dc0b0b9181c3b`;
`Sprite3Native.*` remains 12/12 and strict codesign passes.

## Follow-on live attempt

The rebuilt executable (`fd172a49...`) launched as PID `13679` on a fresh
Simulator process and reached the current `village1 display-self` markers.
The armed trigger produced only an early setup-only interval (`chain=1`,
`headers=0`, `groups=0`) before the bounded run stopped. No zero-TBP ADGIF
line was emitted; the fault log remained 0 bytes. The Simulator was shut down.
This leaves the discriminator valid but its required live zero-TBP sample
uncollected.

## Decisive raw ADGIF capture

The normal product walker was then run through the supported prelaunch
`ottsel-bg-village1` diagnostic route with signed executable
`0254b74bfa66b9373379655edb0a65b243478bf3497436235eea7dcb2661d45c` (PID
`17930`). It captured eight repeated zero-TBP groups with a zero-byte fault
log. The first was:

```text
chain=6 group=0 count=16 size=1280 vif0=0x00000000 vif1=0x6c508091
tex0=0x0000000000000000 tex0-addr=0x0000000000000006
tex1=0x0000000000000060 tex1-addr=0x0000000000000014
clamp=0x0000000000000005 alpha=0x0000000000000048
raw q0..4=0/6/0x60/0x14/0 q5..9=0x34/5/8/0x48/0x42
```

`0x6c508091` is the expected VIF `UNPACK_V4_32` command for 80 qwords at
the Sprite3 ADGIF destination (`0x91`), matching `16 * sizeof(AdGifData)`.
The raw qwords are valid `(GS value, GS register address)` pairs:
`TEX0/TEX0_1`, `TEX1/TEX1_1`, `MIPTBP1/MIPTBP1_1`, `CLAMP/CLAMP_1`, and
`ALPHA/ALPHA_1`. The zero TEX0 therefore represents a legitimate TCC=0
untextured state in this phase, not a misaligned or random read.

This is source/producer evidence only. The native Metal path still needs a
before-failing TCC=0 regression and an explicitly bounded color-only
implementation before it can contribute to product rendering.
