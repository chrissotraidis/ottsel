# R1 fresh iPad launch-owner correlation — 2026-08-22

## Ledger

| Field | Result |
|---|---|
| Gate | R1 producer phase/data-family selection before native composition |
| Source/build identity | Signed iPad executable `f3b2759a0cce1859ba36a1c0f032f55e954a6f96fb4a2f38519295b33fee53c6`; outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366` |
| Environment | One iPad Pro 11-inch (M4) Simulator; one runtime PID `24865`; one booted Simulator |
| Change | Armed the existing iOS sandbox `ottsel-trace-mips2c-3d` diagnostic seam before the title route; no product texture, TBP, camera, shader, or Metal-policy change. |
| Live proof | The route logged title-wait → Start → Cross → Down×4 → Cross and `GAMEPLAY: enter village1` twice. |
| Fault/audio | Fault log 0 bytes; the route remained non-audible (`pcm-peak=0`). |
| Verdict | OPEN — producer owner/phase divergence is identified, but the iPad frame remains visibly corrupted/partial and is not playability proof. |

## Owner/raw-ID result

The route-aligned iPad owner trace selected, among other entries:

```text
launcher-id=336 -> raw=0x00203600 page=0x2 index=0x36
launcher-id=334 -> raw=0x40800000 page=0x408 index=0x0
launcher-id=335 -> raw=0x40800300 page=0x408 index=0x3
launcher-id=341 -> raw=0x00203100 page=0x2 index=0x31
launcher-id=347 -> raw=0x00201200 page=0x2 index=0x12
launcher-id=337 -> raw=0x00203000 page=0x2 index=0x30
```

The completed macOS owner reference instead includes the accepted first
world-family pair `raw=0x00201e00` (page 2/index 30) under a different
system/launcher sequence, followed by macOS `0x24f2` /
`0x2004d1e59930a4f2`. The iPad lookup path resolves its selected objects as
resident hits, but it is resolving a different producer-selected phase before
native Sprite3 consumes it.

This is the falsifiable source-side R1 result: page-directory lookup is not
the first divergence; launch-owner/phase selection is. The next gate is to
reconcile that handoff and add a before-failing producer fixture or regression.
No TBP remap, camera rewrite, shader adjustment, or Metal-policy change is
justified by this trace.

## Host follow-up boundary

A single macOS owner-trace follow-up was run only after the iPad Simulator was
shut down. Its trigger fired during title-side activity before the exact
same-transition route was successfully replayed, so its raw owner sequence is
not promoted to a new macOS parity oracle. It did independently reproduce the
known macOS family entry `raw=0x00201e00` / page 2/index 30 and was stopped
before any concurrent Simulator run. The completed macOS artifacts cited
above remain the authoritative comparison.

## Artifacts

- Runtime log: `artifacts-2026-08-22-ipad-r1-owner-replay/ottsel-runtime.log`
- Fault log: `artifacts-2026-08-22-ipad-r1-owner-replay/ottsel-fault.log`
- Screenshot: `artifacts-2026-08-22-ipad-r1-owner-replay/post-route.png`
