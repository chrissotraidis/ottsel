# R1 level-login owner ledger — 2026-08-22

## Gate

Fresh signed iPad replay using the validated durable pack and one booted
iPad Pro 11-inch (M4) Simulator. Route: title-wait → Start → Cross → Down×4
→ Cross. The app reached `GAMEPLAY: enter village1`; `MIS.DGO` had 61
objects; fault log remained 0 bytes.

## Source-side result

Full ARM64 `(mi)` regenerated all 546 targets before the signed build. The new
bounded producer trace recorded:

`TEX LEVEL LOGIN: level=village1 max-kind=5 id-array=present`

`village1` IDs were stable and explicit: `(398,0) (400,0) (399,0) (401,0)
(1470,0)` for page kinds 0–4. The later `misty` login recorded
`(516,0) (521,0) (518,0) (520,0) (0,0)`. This is not a missing page-directory
entry or an absent DGO texture-ID array.

The fresh post-world page-2 consumer order was
`24,10,41,25,30,34,9` (all resident hits; allocators 6/2/1). The retained
macOS route contains the corresponding family in a different order and also
contains `0,3,31,35,36`. This keeps the discriminator at producer/link/login
ordering or consumer/data-family state, not lookup remapping.

## Visual boundary

Fresh CUA screenshot:
`/var/folders/b1/t1t38j255k53b4j97j63gfkh0000gp/T/com.openai.sky.CUAService/Simulator Screenshot 2026-08-22 at 4.24.24 PM.jpeg`

Bounded video: `/tmp/ottsel-video/r1-level-ledger-replay-20260822-1624.mov`
(8.8 MB; SIGINT stopped; no live SimRender recording). The frame remains
visibly malformed with missing geometry and no Jak. It is not playability proof.

The existing one-shot generic-VU probe then logged `MSCAL 46 executed=50000
capped=true pc=314 xgkicks=0 gif=0`; the first live nonzero VU draw had zeroed
input memory and `gif=0`. This is a source/consumer boundary failure, not a
Metal presentation drop. Fresh post-probe screenshot:
`/var/folders/b1/t1t38j255k53b4j97j63gfkh0000gp/T/com.openai.sky.CUAService/Simulator Screenshot 2026-08-22 at 4.29.30 PM.jpeg`.

## Disposition

R1 remains OPEN. No TBP, camera, shader, culling, or Metal-policy remap was
made. Next trace is the producer/data-family consumer boundary after the
stable level-ID proof.
