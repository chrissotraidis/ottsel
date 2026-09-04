# R1 page-directory and allocation state trace — 2026-08-21

## Ledger

| Field | Result |
|---|---|
| Gate | R1 source/resource parity |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; maintained patch `patches/r1-texture-lookup-trace.patch` SHA-256 `5dcae3fedd6ba955258aa85bbc8acc9fb4e422e5acc6732164105196727d29bb`; signed iPad executable SHA-256 `db906342b3d45d7fe3c9beb6ef5059a9ebec2bec0d0d028cf203a2d9ef5ebba7`; Mac `gk` SHA-256 `5e137605f81b9b392ebb1ce8b63caa92df88d32d8fb0703898cb670d1b040c71` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; fresh retained validated pack |
| Change | Added bounded relocation/state diagnostics, then registered the native `engine`/`art`/`common` package markers after direct iPad `GAME.CGO` linking. This prevents `alloc-levels!` from loading `ART.CGO` a second time; no lookup, TBP, camera, shader, or Metal behavior changed. |
| Focused proof | GOAL `--isa arm64` rebuilt all 338 targets; `scripts/build-ios.sh` completed; strict deep codesign passed; fresh route reported one page-2 relocation set and no `ART.CGO` load |
| Live proof | Fresh title-wait → Start → Cross → Down×4 → Cross replay reached the Village1 source boundary; page-2 lookups were resident hits; source-boundary trace completed 8 items |
| Fault/audio | Fault log 0 bytes; audio callback observed and 48,000 mixed frames reported, but `pcm-peak=0` |
| Verdict | OPEN — diagnostic allocation/order evidence only; Simulator output remains blank/partially corrupted and non-playable |

## Observed state

The page directory reported `dir-length=1610`, page-2 `entry-length=55`,
`entry-status=0`, resident `page-id=2`, and `page-length=55` for every sampled
page-2 lookup. The first sampled lookup (index 4) used allocator selector 1
(`texture-page-default-allocate`) and segment destinations
`601152/632576/633664`. The next page-2 samples used selector 6
(`texture-page-level-allocate`) and the same resident page's destinations
`711424/742848/743936`. All later sampled indices, including `30,41,18,15,28,27,3,0,24`,
retained those latter destinations and were hits.

The same boot loaded `dir-tpages` first in `ART.CGO`, then the title and
Village1 DGO streams, and loaded the Village1 FR3 with the existing validated
root. The first Village1 source-boundary group remained world `MSCAL=3`,
48 sprites, `first-tex0=0x2005a8459930abc1`, `TBP=0x2bc1`; the later 32×32
group remained `first-tex0=0x2005a0455530ac8d`, `TBP=0x2c8d`.

This proves residency and previously exposed a page-segment destination
transition. The iPad boot was then corrected to register the package markers
that the native `InitMachineScheme` path installs after GAME.CGO. A fresh
replay now records exactly one page-2 relocation set at
`601152/632576/633664` and no `DGO RPC: loading ART.CGO`; the duplicate-owner
cause is fixed. The lookup order still differs from the Mac run, so the
source/resource parity question remains open. A fresh equivalent Mac trace
kept the same page-2 object at
`601152/632576/633664` for the full observed sequence, including selector 6.
The Mac lookup order was
`4,53,4,18,15,30,0,28,3,41,24,36,35,31,9,10,25,54,49,48,42,44`, while the
fresh iPad order was
`4,53,4,30,41,18,15,28,27,3,0,24`. This makes the iPad page-segment
transition and reordered producer lookup window a real platform divergence,
not merely a logging artifact. It still does not prove the allocator
transition is the root producer owner; no TBP remap or renderer-policy change
is justified.

Mac live artifacts: screenshot `/tmp/ottsel-r1-mac-page-state.png`
(`5ef14e08afb0dda2775cf9fc854c92a51fdc8bcf6fc2e479db8e64516408cf4`) and
raw log `/tmp/ottsel-r1-mac-page-state.log`. This bounded Mac capture reached
title-wait and the Start edge but did not produce a fresh Village1 marker, so
its screenshot is comparison evidence only, not a new Mac playability claim.

## Relocation-owner capture

The next signed iPad build added a bounded trace at the shared
`relocate-dests!` source boundary and replayed the same validated route. It
recorded exactly two page-2 relocation sets:

```text
seg0 old=0 new=601152; seg1 old=31424 new=632576; seg2 old=32512 new=633664
seg0 old=0 new=711424; seg1 old=31424 new=742848; seg2 old=32512 new=743936
```

This confirms the second destination set is a real second relocation of the
same resident page object, not a logging or texture lookup artifact. The
fresh route still completed the source-boundary trace, fault log was 0 bytes,
and audio reported `pcm-peak=0`; screenshot
`/tmp/ottsel-r1-relocate-post-route.png`
(`548b9162e166a4d28f2807795fdd84abfab6c6f83b00b85ecb025011819e83ff`) remains
severely corrupted/partial. The relocation trace does not identify its caller
yet, so R1 remains OPEN and no renderer policy change is justified.

## Package-ledger parity replay

The signed iPad replay after the boot fix reached `GAMEPLAY: enter village1`
twice, produced one page-2 relocation set (`601152/632576/633664`), and did
not log an `ART.CGO` load. Raw page-2 lookup order in the post-Start window
was `54,49,48,42,44` followed by `24,25,10,41,0,30,34,9`; the earlier
pre-Start samples were `4,53,4,18,15,28,27,3`. This remains different from
the completed Mac order beginning `4,53,4,18,15,30,0,28,3,41,24,...`, so
removing duplicate ART loading fixed allocation ownership but not the full
lookup/producer ordering parity.

Fresh artifacts: screenshot
`/tmp/ottsel-r1-package-ledger-post-route.png`
(`7514776a33c77d3ef2e9c66872a454b30f98301a489cac5007f10ea1ba438023`),
runtime log in the app container, and a zero-byte fault log. Audio mixed
48,000-frame windows but reported `pcm-peak=0`. The screenshot remains
severely corrupted/partial, so this is source-side R1 evidence, not
playability acceptance.

The phase-aligned follow-up corrected the remaining comparison error. With
the particle trace armed before Start, iPad and macOS shared the post-Start
page-2 window `54,49,48,42,44` and the same raw/TEX0 families, including
`0x00200f00 -> 0x2004c8e55530a5d2`. The fresh iPad source-boundary capture
consumed that same TEX0. This closes the current page-directory and
texture-object mismatch hypothesis; the remaining TBP/phase and corrupted
composition work is tracked in
`docs/evidence/R1/r1-phase-aligned-raw-parity-2026-08-21.md`.

## Next falsifiable experiment

Trace the exact iPad page-2 relocation call and its level/DGO load owner in a
bounded source-side probe, then correlate it with the first reordered producer
group using raw particle ID, AdGif TEX0, and native `first-tex0`/TBP. The Mac
baseline is now stable at the original segment destinations; do not change
TBP, camera, shader, or Metal policy while identifying that owner.
