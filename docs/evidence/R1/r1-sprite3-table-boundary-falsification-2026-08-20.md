# R1 Sprite3 table-boundary falsification — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 DMA bucket ownership / Sprite3 traversal |
| Before failure | The mobile parser started at bucket 66's data address and stopped at bucket 68's data address, producing 7 MSCAL-3 groups / 320 world sprites versus macOS's 51 / 2,432. |
| Experiment | Changed only the mobile stop values to the bucket-table offsets (`offset + 67*16` and `offset + 68*16`) while retaining the data-address starts. Rebuilt a signed app and replayed the prepared-pack route through Village1. |
| Live result | The parser armed at chain `42717` but immediately completed with `groups=0 sprites=0`, `start=0xd029a0 next=0x50cc50`; the fault log remained `0` bytes. |
| Interpretation | Table offsets are the correct desktop dispatcher coordinate space only when the follower also consumes the current bucket-table tag. Passing table offsets to a follower already started at the data address is invalid and loses the Sprite3 payload. |
| Verdict | REJECTED experiment; source behavior reverted. |
| Follow-up experiment | Rebuilt with the mobile Sprite3 walk starting at the bucket-66 table entry, consuming that tag, and stopping at the bucket-67 table entry. Twelve successive populated-route trigger attempts all completed with `groups=0 sprites=0` (chains `34786` through `51340`), so this coordinate adaptation was also rejected and reverted. |
| Synthetic fixture | Added `Sprite3Native.Jak1BucketTableEntryReturnsToNextTableBoundary` plus `Sprite3Native.GfxSendChainReadsJak1BucketsRelativeToChainOffset`. The fixtures model table-relative 66/67/68 reads, distinct data addresses, and the bucket-67 return boundary. The focused suite now passes 20 tests. |
| Next gate | Adapt the mobile consumer against this proven offset/table contract, preserving the existing Direct path, then run one fresh prepared-route replay. |

The Simulator was blank and non-audible. No visual, audio, playability,
iPhone, or physical-device claim is made. No protected data or executable
runtime-generation path was introduced.
