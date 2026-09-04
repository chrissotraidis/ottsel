# R1 TFRAG composition isolation — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 native Direct/Sprite/material composition discriminator |
| Environment | One iPad Pro 11-inch (M4) Simulator, `08636791-2675-4675-8335-EF72EF954DCF`; one runtime at a time; no macOS runtime concurrent. |
| Build | Signed iPad diagnostic build SHA-256 `e072833d2347cbe63e81bda175cc5cfcafb29968d18d8040d813cd5ad12ad2ab`. |
| Route | Fresh title-wait → Start → Cross → Down×4 → Cross; Village1 entered twice. |
| Before failure | Normal frame had oversized/dislocated textured world geometry and large black regions. |
| Discriminator | Existing trigger-only `scene no-TIE` and `scene no-TFRAG` probes; no product renderer policy change. |
| Fault/audio | Fault log 0 bytes; audio remained non-audible (`pcm-peak=0` in the retained runtime path). |
| Verdict | OPEN — the oversized world disappears when TFRAG is disabled, while disabling TIE leaves it present. TFRAG or TFRAG composition is the next source boundary. |

## Observation

- `no-tie.png` retains the oversized textured world, so TIE is not the primary
  source of the observed wall/terrain corruption.
- `no-tfrag.png` removes that world and exposes only the remaining diagnostic
  Sprite3/font/color blocks, so TFRAG is causally implicated.
- `normal.png` restores the ordinary product path and remains visibly partial;
  none of these frames is playability proof.

The trace-only raw-range probe reported Village1 TIE source coordinates of
approximately `x=-806106..891680`, `y=-88614..387437`, and
`z=-782543..949407`, with PC scales near `7.6e-5/-8.9e-5/3.6e-5`. These are
large world-space values, not by themselves a malformed-resource result; the
TFRAG isolation is the stronger discriminator.

## Artifacts

- `artifacts-2026-08-22-ipad-tfrag-isolation/no-tie.png`
- `artifacts-2026-08-22-ipad-tfrag-isolation/no-tfrag.png`
- `artifacts-2026-08-22-ipad-tfrag-isolation/normal.png`
- `artifacts-2026-08-22-ipad-tfrag-isolation/first-batch.png`
- `artifacts-2026-08-22-ipad-tfrag-isolation/first-batch-integrity.png`
- `artifacts-2026-08-22-ipad-tfrag-isolation/first-batch-integrity-system.log`
- `artifacts-2026-08-22-ipad-tfrag-isolation/all-draw-clip.png`
- `artifacts-2026-08-22-ipad-tfrag-isolation/all-draw-clip-system.log`
- `artifacts-2026-08-22-ipad-tfrag-isolation/ottsel-runtime.log`
- `artifacts-2026-08-22-ipad-tfrag-isolation/ottsel-fault.log`

The first-batch probe produced `first-batch.png` (SHA-256
`b3f758cc4806ff4f61203ba3dcc5a47fe63a27d5a272d36044dcabf193bbbd84`) and
still showed fragmented TFRAG geometry. The defect is therefore already
present in the earliest TFRAG draw, not only in a later material batch. The
probe was cleared by terminating and relaunching the clean signed app.

A trigger-only Metal-side integrity check on that first TFRAG draw reported:

```text
indexOffset=0 indexCount=3984 vertexCount=76264
indexRange=592..2921 outOfRange=0
position=(-820865.0..1120447.1,-65473.5..433599.1,-787842.0..958142.1)
```

The earliest submitted indices are in range, so an out-of-range index read is
not the current explanation. The next discriminator is TFRAG transform/material
interpretation for this valid mesh. The temporary system-log probe was removed
after capture.

The widened trigger-only clip probe found finite, bounded projected coordinates
for every captured TFRAG draw: approximately `x=-0.53..1.60` and
`y=-1.47..0.77`, with positive finite depth. Together with the valid index
range, this rules out a gross vertex-transform or out-of-range-index failure.
The next boundary is triangle connectivity/material submission or composition
state. The widened probe was removed after capture.

The temporary raw-range trace was removed after capture. No TBP remap, camera
rewrite, shader change, culling change, or Metal policy change was made.
