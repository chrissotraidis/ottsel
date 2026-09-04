# R1 same-route raw particle to AdGif capture — 2026-08-21

## Ledger

| Field | Result |
|---|---|
| Gate | R1 source/resource parity |
| Source/build identity | Outer `6706617afa1335b8f0382563d7f8f957835195f1`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `c66fb549f4442f1ffe7426d3e7de0964c905c943d3b407428d34c512c521f091` |
| Environment | One iPad Pro 11-inch (M4) Simulator, iOS 18.5, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; validated durable user pack |
| Before failure | Page/index and allocator traces proved a different resident particle family, but the prior GOAL formatter did not preserve the full raw texture-ID word |
| Change | Armed the existing diagnostic-only MIPS2C `particle-adgif` trace after title-wait and captured raw 32-bit ID plus post-setup AdGif TEX0/TEX1/CLAMP/ALPHA; no product lookup, TBP, camera, shader, or Metal change |
| Live proof | Start → Cross → Down×4 → Cross; `GAMEPLAY: enter village1` appeared twice; first captured mobile family included `raw=0x00200f00` → `TEX0=0x2005a0455530ac8d` and `raw=0x00203600` → `TEX0=0x20159da4cd40abd2` |
| Evidence | Fresh screenshot `/tmp/ottsel-r1-particle/post-route.png`; runtime evidence `/tmp/ottsel-r1-particle/runtime-evidence.log`; fault log 0 bytes; audio callback observed but `pcm-peak=0` |
| Verdict | OPEN — producer phase/data-family divergence localized further; Simulator remains blank/partially corrupted and non-playable |

## Comparison

The completed macOS mapping begins with producer-family outputs such as
`raw=0x00200400` → `TEX0=0x2004cfe55530a518` and
`raw=0x00201e00` → `TEX0=0x2004d1e59930a4f2`. The iPad route instead emits
the `0x2005...`/`0x2015...` family before the native Sprite3 boundary. Both
platforms preserve their producer TEX0 into the native boundary. The first
mismatch is therefore upstream phase/spec ownership or DMA handoff ordering,
not page-directory failure and not a native TBP mapping problem.

The iPad-only page-2 family remains resident and hit under
`texture-page-default-allocate`; shared/common entries use
`texture-page-common-allocate`. This rules out a failed allocation/login as
the primary cause. Do not remap TBP or change camera, shader, or Metal policy.

## Next experiment

Add a bounded same-chain discriminator at the Sprite3 producer boundary that
stamps the first particle/adgif family, frame setup hash, matrix hash, DMA
chain/VSYNC, and first `MSCAL=211`/`MSCAL=3` group together on macOS and iPad.
Use that to identify the phase/data-family handoff before any renderer fix.
