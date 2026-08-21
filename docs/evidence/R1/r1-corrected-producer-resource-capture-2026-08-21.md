# R1 corrected producer/resource capture — 2026-08-21

## Gate

R1 first post-setup Sprite3 resource divergence, using the corrected 16-byte
producer-table diagnostic.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed iOS Simulator executable SHA-256:
  `4e6f61bac9ba471bfcae7b2093c50317246d3e001f33efc88bbe35636230db7d`.
- Strict deep code-signature verification passed.
- One iPad Pro 11-inch (M4) Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`, Process `67985`.
- Runtime log: the app container's
  `Library/Application Support/local.ottsel/OttselShell/ottsel-runtime.log`.

## Before failure

The prior producer trace used an incorrect 8-byte stride when interpreting
16-byte DMA table entries. The corrected binary had to prove both that the
route still reaches the phase and that the first resource divergence survives
proper slot alignment.

## Live proof

The fresh title-wait route consumed Start, Cross, four Down edges, and the final
Cross, then logged `GAMEPLAY: enter village1` twice. The corrected producer
trace captured 64 alternating submissions from chains `0x50a0f0` and
`0x50c820`; every logged slot 65–69 was read at `chain + index * 16` and was a
valid nonzero DMA entry. The prior even-slot-zero anomaly did not recur.

The phase-window and frame aggregate then recorded:

```text
groups=9 sprites=384 world=320 hud=0 3d=64 other=0
item 0: 3d    count=48 tbp=0x2b8d psm=19 tw=6 th=6
item 1: 3d    count=16 tbp=0x2be0 psm=19 tw=5 th=5
item 2: world count=48 tbp=0x2c8d psm=19 tw=5 th=5
item 3: world count=48 tbp=0x2c8d psm=19 tw=5 th=5
item 4: world count=48 tbp=0x2c8d psm=19 tw=5 th=5
item 5: world count=48 tbp=0x2c8d psm=19 tw=5 th=5
item 6: world count=48 tbp=0x2c8d psm=19 tw=5 th=5
item 7: world count=48 tbp=0x2c8d psm=19 tw=5 th=5
item 8: world count=32 tbp=0x2d8c psm=19 tw=6 th=6
```

The first stable post-setup producer record was chain `23537`, with frame
transfer `9`, matrix transfer `12`, first `MSCAL=3` at transfer `15`,
`pfog0=-0.2847222`, `inv-area=0.09339085`, and first world texture
`TEX0=0x2005a0455530ac8d` (`TBP=0x2c8d`, 32×32). The same setup and resource
tuple repeated on chain `23538`.

The macOS same-route oracle begins with a 3D item at `TBP=0x25ee` and its
first accepted world draw at `TBP=0x24f2`, `TEX0=0x2004d1e59930a4f2`, 64×64,
55 sprites, with `pfog0` near `-0.0587` and `inv-area=0.036767285`.

The source audit identifies the next shared field to compare. Desktop
`Sprite3::handle_sprite_frame_setup` consumes and validates the three-qword
Direct setup, Jak 1 frame packet, `MSCALF Init/FLUSHE`, and `BASE/OFFSET`
transfers before `render_3d` and the first 2D group. The mobile diagnostic
parser locates the same frame and matrix transfers at indices 9 and 12 and the
first `MSCAL=3` at index 15, but currently only decodes the frame/matrix values
and sprite payload; it does not yet record the preceding setup words or phase
ownership fields. This is a comparison gap, not proof that the mobile parser is
wrong.

## Verdict

OPEN. Correct 16-byte table alignment falsifies the producer-table boundary
hypothesis, while the repeated aggregate and post-setup record prove a real
mobile producer/resource-phase divergence before native Metal composition.
The app remained blank and non-audible in the Simulator; this is not visual or
playability proof. The fault log was 0 bytes and no new link-version assertion,
Metal validation marker, or crash appeared during this route.

No TBP remap, texture substitution, camera sign change, shader change, native
consumer widening, or CPU fallback is justified. The next experiment is a
source-side capture of those setup words and phase/ownership fields on both
platforms, using the already-proven data-root and frame/matrix setup
boundaries.

## Setup-transfer follow-up

The next signed build added only a trigger-gated dump of the transfers before
the frame packet. On chain `18333`, the mobile stream recorded the desktop
Direct setup at transfer 8:

```text
size=48
q0=0x2000000000008001
q1=0xeeeeeeeeeeeeeeee
q2=0x000000000005126b
```

The remaining qwords in that 48-byte transfer are the known desktop values
`0x47`, `0x5`, and `0x8`. Transfer 9 was the 656-byte frame packet; transfer
12 was the matrix packet; and transfer 13 was the first `MSCAL=3`. The same
sequence repeated on chain `18334`. The mobile setup tuple was
`pfog0=-0.040725242`, `inv-area=0.036767285`, with first resource
`TBP=0x2c8d`; the source setup itself therefore matches the desktop contract
while the resource phase still differs.

That run's trigger timing captured a six-group / 256-sprite world-only subset,
not a complete-frame aggregate, so it is not used as a new parity count. It
did, however, reproduce the same first resource and had a zero-byte fault log.

The setup-transfer comparison rules out the preceding Direct/frame/matrix
setup words as the first shared defect. The next slice is the first
post-`MSCAL=3` source/phase ownership decision that selects `0x2c8d` instead
of macOS's `0x24f2`; no consumer or camera change is justified.
