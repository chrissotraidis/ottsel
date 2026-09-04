# R1 fresh iPad lookup replay — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 source/resource parity before native composition |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; `patches/r1-texture-lookup-trace.patch` SHA-256 `846ccf40bcb01cbb9f4d3da54e2314bf7c95bf40db721f3d21cbc407a479863a`; signed Simulator executable SHA-256 `f3b2759a0cce1859ba36a1c0f032f55e954a6f96fb4a2f38519295b33fee53c6` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime PID `24273`; one fresh validated pack outside the repository |
| Before failure | Earlier iPad frames were visibly partial/corrupt and the intended iPad lookup-trace replay was missing from the original R1 note. |
| Change | Rebuilt `scripts/build-ios.sh` from the canonical lookup trace, installed the signed app fresh, imported a validated user-data pack, and replayed title-wait → Start → Cross → Down×4 → Cross. No TBP, camera, shader, or Metal-policy change. |
| Live proof | Current-boot route logged `start edge in title-wait`, `incoming complete`, and `GAMEPLAY: enter village1` twice. Fresh screenshot: [post-route.png](artifacts-2026-08-22-ipad-r1-lookup-replay/post-route.png), SHA-256 `2852593f6a26cee079ca317af08a3c250b12c0ee4f0015e5f33173ca53fdec72`. |
| Fault/audio | `ottsel-fault.log` 0 bytes; audio mix windows were present but reported `pcm-peak=0`. |
| Verdict | OPEN — diagnostic source/resource evidence only; the Simulator image is visibly corrupted/partial and is not iPad playability proof. |

## Lookup and source-side comparison

The complete page-2 lookup sequence captured on iPad was:

```text
4,53,4,18,0,15,28,27,3,54,49,48,42,44,24,10,41,25,30,34,9
```

The phase-aligned post-Start window is `54,49,48,42,44`, matching the
completed macOS reference. Page 2 remained a resident hit with directory
length `1610` and segment destinations `601152/632576/633664`, matching the
known corrected mobile/macOS page state. The pre-Start/title stream contains
different records and is not a valid same-transition comparison.

The producer-side texture-object/TEX0 trace then remains the next boundary.
The iPad captured representative page-2 objects including index 54 at TBP
9495 (8×8 PSM 20), index 49 at TBP 9517 (16×16 PSM 19), index 48 at TBP 9518
(64×64 PSM 19), index 42 at TBP 9666, and index 44 at TBP 9586. The first
native 3D groups were:

```text
iPad:  TBP=0x24d2 TEX0=0x2004d2e59930a4d2 size=64x64
       TBP=0x2525 TEX0=0x2014cd655530a525 size=32x32
macOS: first accepted world reference TBP=0x24f2
       TEX0=0x2004d1e59930a4f2 size=64x64
```

Thus the aligned lookup/page-directory path is not the first divergence.
The remaining mismatch is producer phase/data-family selection before native
Sprite composition. This does not justify remapping TBP or changing camera,
shader, or Metal policy. The next experiment is a source-side comparison at
the first `MSCAL=211`/Sprite3 producer selection and its data-family handoff.

## Artifacts

- Runtime log: `artifacts-2026-08-22-ipad-r1-lookup-replay/ottsel-runtime.log`
- Fault log: `artifacts-2026-08-22-ipad-r1-lookup-replay/ottsel-fault.log`
- Screenshot: `artifacts-2026-08-22-ipad-r1-lookup-replay/post-route.png`

