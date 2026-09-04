# R1 TIE-only projection replay R16 — 2026-08-22

## Source result

The CPU clip ledger established that the current native TIE consumer produced
`(68.374,-14.092,0.036,34.744)` for the first Village1 vertex while the
desktop shader equations produced `(-0.012,-0.005,-0.034,34.744)`. The TIE
consumer was therefore changed to apply the reference Q/HVDF/GS projection.
TFRAG deliberately retains the prior path in this experiment so the two
composition families remain distinguishable.

## Build/runtime proof

- `scripts/build-ios.sh`: passed.
- `codesign --verify --deep --strict`: passed.
- One booted iPad Pro 11-inch (M4) Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`.
- One `com.ottsel.shell` runtime only.
- No ROM, TBP/page lookup, runtime-codegen, or second-Simulator change.

## Fresh live visual evidence

- [fresh clean signed frame](artifacts-2026-08-22-ipad-r1-tie-only-projection-r16/fresh-clean-signed.png)
- [fresh runtime log](artifacts-2026-08-22-ipad-r1-tie-only-projection-r16/ottsel-runtime.log)

The direct Simulator UI was actively inspected after the Village1 transition
and after a W keyboard event hid the touch overlay. The scene is now
recognizable and no longer becomes the prior full blank/dislocated result, but
it still has visibly incorrect geometry/material composition and cannot be
called playable. Audio logs continue to report mixed frames with
`pcm-peak=0`; audio acceptance remains open.

## Decision

Retain this TIE-only source correction as a bounded progress point. R1 remains
open. The next falsifiable slice is TFRAG’s separate projection/sign/depth
contract and its interaction with TIE/material ordering; do not remap TBP or
resource lookup.
