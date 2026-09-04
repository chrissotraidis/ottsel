# R1 phase-aligned raw producer parity — 2026-08-21

## Ledger

| Field | Result |
|---|---|
| Gate | R1 source/resource parity → native Sprite composition |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed iPad executable SHA-256 `db906342b3d45d7fe3c9beb6ef5059a9ebec2bec0d0d028cf203a2d9ef5ebba7`; macOS `gk` log `jak1.2026-08-21T16-52-36.log` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; validated durable pack |
| Before failure | The earlier lookup comparison mixed pre-Start/title-stream records with the post-Start route and falsely treated them as one sequence. |
| Change | Armed the particle AdGif trace before Start, replayed title-wait → Start → Cross → Down×4 → Cross, and compared aligned raw IDs, AdGif TEX0, page allocation, and native source-boundary output. No TBP remap or renderer policy change. |
| Focused proof | iPad and macOS both produced aligned raw/TEX0 pairs, including `0x00203500 → 0x2004d0e59930a506`, `0x00200400 → 0x2004cfe55530a518`, `0x00201200 → 0x2004d0e59930a506`, and `0x00200f00 → 0x2004c8e55530a5d2`; iPad page 2 relocated once to `601152/632576/633664`. |
| Live proof | Route reached `GAMEPLAY: enter village1` twice; a fresh source-boundary capture completed 8 records; screenshot `/tmp/ottsel-r1-phase-aligned-raw-parity.png` hash `9f0ad9c78ec7d353def29d7dd0df7118578086824e8659cb7d606670922f8a8a` |
| Fault/audio | Fault log 0 bytes; audio mixed frames but reported `pcm-peak=0` |
| Verdict | Source/resource identity is aligned for the captured same-route families. R1/native composition remains OPEN: iPad source-boundary phase and visible frame are not macOS-equivalent, and the Simulator remains corrupted/non-playable. |

## Aligned result

The post-Start macOS page-2 window begins with `54,49,48,42,44`, matching the
iPad post-Start lookup window. The earlier iPad-only `28,27,3` and macOS-only
`30,0,35,31,36` records occur before the Start boundary and are not a valid
same-transition comparison.

The raw producer and post-setup AdGif data also match across the aligned
families. For example, both platforms preserve raw `0x00200f00` as
`TEX0=0x2004c8e55530a5d2`; the iPad native source boundary consumes that same
TEX0. The iPad package-ledger fix leaves only one page-2 relocation and no
duplicate `ART.CGO` load.

This closes the current page-directory/texture-object mismatch hypothesis. It
does not make the iPad TBP/phase stream equivalent: the macOS aggregate uses a
different first 3D/world phase (`first-tbp=0x2506` in this reference window),
while the fresh iPad source capture after the route trigger was world-only at
`TBP=0x25d2`. The remaining work belongs at producer phase/DMA selection and
native Sprite/TIE/TFRAG composition, not texture remapping.

## Boundaries and next gate

The fresh screenshot is materially more textured than prior captures but still
has large missing regions and diagnostic control blocks. It is not a playable
Jak frame. iPad audio remains non-audible, and iPhone/device gates have not
started.

Next: capture the first iPad `MSCAL=211` source item in the same transition,
compare its frame/matrix and DMA ownership with macOS, then continue the
smallest before-failing native Sprite/material composition fixture. Keep TBP,
camera, shader, and Metal policy unchanged until that phase comparison is
complete.
