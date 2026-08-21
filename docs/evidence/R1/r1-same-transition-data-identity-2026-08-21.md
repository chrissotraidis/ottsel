# R1 same-transition data identity — 2026-08-21

## Gate

Rule out byte-level user-data and regenerated-CGO selection as the cause of the
same-boundary Sprite3 resource divergence.

## Hash comparison

The following hashes matched exactly between the macOS/generated checkout and
the durable iPad user root:

| Artifact | SHA-256 |
|---|---|
| `village1.fr3` | `2098e176a1a5d80b2e2b7e0a64ac3aa3d682aee48791feb7d63bfe0a36d17865` |
| `title.fr3` | `990966f3077e6de9be6640893beee2afd91eb894477768e7cde63614213ac84e` |
| `VI1.DGO` | `8910a4fcc117e966f30f76c357b68299d60024e2cf98361cd6b0763c76fe75e0` |
| rebuilt `GAME.CGO` | `abc06dfd848e6773c62c173b367843ab987296c75e904f760d74ceb8a0cc749b` |
| rebuilt `KERNEL.CGO` | `119f874125868f691e278d08e641fcc638eb06ba19fff890a1e6448f5c530177` |

The iPad app bundle’s `GAME.CGO` and `KERNEL.CGO` also match the regenerated
macOS artifacts. The durable user root contains the same FR3/DGO bytes; its
older supplementary CGO copies are not the app-bundle base `GAME.CGO`/`KERNEL.CGO`
used for this boot.

## Verdict

OPEN. Data-root selection and byte identity are no longer the leading
explanation. At the same Village1 display boundary and target position, mobile
still emits `0x2c8d`/32×32 while macOS emits `0x24f2`/64×64. The next slice is
producer phase/ownership and DMA handoff ordering, not data import or texture
remapping. The iPad was blank/non-audible and this remains diagnostic evidence.
