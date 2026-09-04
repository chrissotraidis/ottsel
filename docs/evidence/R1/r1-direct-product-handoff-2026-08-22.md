# R1 Direct product handoff — 2026-08-22

| Field | Result |
|---|---|
| Gate | D0-NORMAL live handoff; R1 composition remains OPEN |
| Source/build | outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618344d9f7c1a531b43b366`; signed executable `bbf4597e8b4d1b648ba1819548bd14bce1c0cc0e2caa343ff665471760794816` |
| Change | Added `ottsel-enable-native-direct-product` activation. It reuses the existing D0 IR/live TEX0/decoded image/state path and native Metal draw; CPU raster remains diagnostic-only. |
| Focused proof | `goalc-test --gtest_filter='DirectFixture.*:Sprite3Native.*:PlatformInput.*:KeyboardEventEdge.*'` passed 31/31. Deep codesign passed. |
| Live proof | One booted iPad Pro 11-inch (M4), PID 99958. Trigger was armed before launch; `native product accepted at chain=1`, then title-wait, Start → Cross → Down×4 → Cross, and Village1 twice. Fault log remained 0 B. |
| R1 comparison | Fresh iPad route lookup order after Start: `(2,54) (2,49) (2,48) (2,42) (2,44)`. This matches the completed macOS route's post-Start sequence and its particle AdGif/TEX0 families: TBP `9495, 9517, 9518, 9666, 9586`; no source lookup/page-directory divergence was found. |
| Visual proof | Fresh screenshots `/tmp/ottsel-video/r1-direct-pre-route-1257.jpeg` and `/tmp/ottsel-video/r1-direct-post-route-1258.jpeg`; bounded videos `/tmp/ottsel-video/r1-direct-pre-route-10s.mov` and `/tmp/ottsel-video/r1-direct-post-route-8s.mov`. Both show incomplete native composition; post-route is a close terrain frame without a playable character. |
| Fault scan | App remained alive; fault log 0 B; no live recording after SIGINT. |
| Verdict | R1 source/resource parity is supported for the observed post-Start lookup family; D0-NORMAL composition remains OPEN. The native handoff is live, but the fresh iPad visuals are not playable and do not satisfy the goal. |

## Fresh consumer-family discriminator

The native Sprite3 data-family ledger was pre-armed before a clean launch and
the same title-wait → Start → Cross → Down×4 → Cross route was replayed. The
route reached Village1 twice with a 0-byte fault log. The post-Start lookup
sequence remained `(2,54),(2,49),(2,48),(2,42),(2,44)`, but the native 3D
consumer repeatedly received and drew `TBP=0x24d2`,
`first-tex0=0x2004d2e59930a4d2`, followed by `TBP=0x2525` /
`first-tex0=0x2014cd655530a525`. The phase-aligned reference recorded the
corresponding first family as `TBP=0x24f2` /
`first-tex0=0x2004d1e59930a4f2`, with the same `0x2525` tail.

This is a producer/data-family identity mismatch after the matched page/index
lookup, not evidence for TBP remapping. The current native product predicate
accepts the first qualifying 48-sprite 64×64 family; the next falsifiable
experiment is to trace why that family is selected and compare its launcher,
AdGif, and allocation identity against the phase-aligned macOS source. Keep
camera, shader, and Metal policy unchanged.

The texture-login ledger closes the allocation branch for the accepted route:
iPad and macOS both report page 2 resident, directory length 1610, entry/page
length 55, segment sizes `31424/1088/4352`, destinations `601152/632576/633664`,
and `alloc=1` for post-Start indices 54, 49, 48, 42, and 44. The remaining
family difference is therefore after lookup/login residency, at Sprite3
producer selection or its AdGif/TEX0 family, not FR3/DGO page allocation.

The lower-level producer trace makes that selection difference explicit:
macOS's active 3D reference uses page 2/index 30 and `TBP=9458` (`0x24f2`),
whereas the current iPad Village1 particle setup uses page 2/index 10 and
`TBP=9426` (`0x24d2`). The iPad producer vector/TEX0 then matches its native
MSCAL consumer exactly. This localizes R1 before native Metal to the launch
owner/phase family, without authorizing a TBP or renderer remap.

Fresh inspected post-route frame: `/tmp/ottsel-video/r1-consumer-family-post-route-1310.jpeg`.
Fresh bounded H.264 capture: `/tmp/ottsel-video/r1-consumer-family-post-route-6s.mov`.
Both show the same incomplete close terrain/blue-material composition and no
playable character; these are diagnostic evidence, not a playability claim.

## Normal-TIE LOD and draw-range discriminator

OpenGL normal TIE uses derived `pc_camera` and one `lod_tie` slot; native TIE
and TFRAG now follow those source rules. A bounded numeric draw-range probe
did not reproduce the normal-mode band reliably in isolated TIE or TFRAG frames,
so no batch/material change is promoted. Fresh normal frame `/tmp/ottsel-video/r1-draw-range-normal-restored-1415.jpeg`
and video `/tmp/ottsel-video/r1-draw-range-normal-restored-8s-1415.mp4` remain
malformed with no Jak; combined TIE/TFRAG phase state is OPEN.
