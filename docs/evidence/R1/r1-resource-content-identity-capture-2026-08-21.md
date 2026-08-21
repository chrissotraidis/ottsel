# R1 resource-content identity capture — 2026-08-21

## Gate

R1 first mobile/macOS Sprite3 resource identity before native composition.

## Identity and environment

- Outer source: `dc60af38433879ccf65ac30d0c16a5f155e9541e`.
- Upstream worktree: `641fb572e876750d8618434d9f7c1a531b43b366`.
- Signed iPad executable: `428436d1623da0bff3ca258b1f05b8f774659dad32ab4f0472742d353b3b0e40`.
- Focused `Sprite3Native.*`: 14/14 passed; strict deep codesign passed.
- Mobile: one iPad Pro 11-inch (M4) Simulator,
  `08636791-2675-4675-8335-EF72EF954DCF`; audio disabled; fresh synchronized
  `title-wait-ready -> Start -> Cross -> Down x4 -> Cross` route.
- Mobile container: `5022F168-48B3-4362-867F-0D561C59C593`.
- macOS oracle: retained same-route `jak1.2026-08-20T20-35-37.log` and its
  `/tmp/ottsel-sprite3-tbp-9458.ppm` plus alpha PGM capture.

## Change

The environment-controlled `OTTSEL_TRACE_MOBILE_SPRITE_IDENTITY=1` arm was
added to the existing diagnostic record path. It arms once only after the
mobile camera level is `village1`; ordinary launches are unchanged. The
desktop and mobile paths log or calculate FNV over decoded RGBA bytes and a
bounded alpha summary. No product texture address, phase, shader, or draw
policy changed.

## Live proof

The mobile route reached the Village1 display marker and auto-armed at chain
243, preserving frame transfer 9 -> matrix transfer 12 -> MSCAL3 transfer 13:

```text
mobile: tbp=0x2bc1 tex0=0x2005a8459930abc1 psm=19 size=64x64
mobile: rgba-hash=0xc8679915dfac0e15 alpha-max=128 nonzero-alpha=2615
```

The macOS same-route first accepted world draw is `TBP=0x24f2`/9458, PSM 19,
64x64. Interleaving its retained decoded RGB PPM and alpha PGM bytes in RGBA
order gives:

```text
macOS: rgba-hash=0x03be77a789505b65 alpha-max=95 nonzero-alpha=1548
```

The mobile fault log was 0 bytes. The Simulator remained blank and
non-audible; this is producer/resource evidence, not visual or playability
proof.

## Verdict

OPEN. The first mobile and macOS resources are different decoded contents, not
the same texture at different TBP addresses. This is the first concrete
resource identity divergence before native composition. No TBP remap, camera
change, shader change, alpha/depth policy change, or native batch widening is
justified.

## Next gate

Trace the producer/source item that selects the mobile `0x2bc1` resource and
the desktop `0x24f2` resource at the shared New Game -> Village1 boundary.
The next falsifiable slice is a source-item/group ordinal or texture-owner
ledger; only a proven missing handoff may receive a maintained product fix.

