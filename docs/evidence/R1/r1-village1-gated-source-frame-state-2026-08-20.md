# R1 Village1-gated Sprite3 source and frame-state capture — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 renderer parity / transition and producer ownership |
| Source/build identity | Outer Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app executable SHA-256 `0a59e57670cc502cae179a6c3185db1dbad5344135bb78f6a8db30691b00a597` |
| Environment | One iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; shut down after capture |
| Before failure | An early file-triggered capture consumed the one-shot Sprite3 windows on title traffic before the Village1 marker, making the resulting source comparison invalid. |
| Change | Gated the diagnostic trigger consumption on `g_mobile_camera_level == "village1"` in `src/shell/metal_gfx.mm`. This is a probe-boundary correction only; it does not alter Sprite3 ownership, texture lookup, camera math, or Metal submission. |
| Focused proof | `scripts/build-ios.sh` passed; strict codesign passed; app hash recorded above. |
| Live proof | The runtime emitted `OTTSEL LEVEL MARKER: level=village1 display=display-self` and the gated windows were consumed at chain `250`, vsync `251`. The product and bucket-67 spans each reported `transfers=23/18`, `headers=2`, `rejected=0`, `boundary-stops=0`, and `groups=2 sprites=64 world=64`. Source group 1 was 48 sprites at `TBP=0x2bc1`, PSM 19, 64×64, `MSCAL=3`; group 2 was 16 zero-TEX sprites with zeroed vectors. The corresponding record ledger showed `pc-level='village1'`, frame `pfog0=-0.046546843`, and a first transition matrix camera translation `(227569.38,47488.31,-5727846400,-31.885628)`. A later stable chain `253` retained the same 48-sprite `0x2bc1` group and added a 32×32 `0x2c8d` pair, with matrix camera translation `(-389687.25,58981.883,1026672060,5.6293917)` and `pc-trans=(-659084.9,235454.02,677712.3)`. |
| macOS oracle | At the same display boundary, macOS’s first accepted world draw remains 55 sprites at `TBP=0x24f2`, PSM 19, 64×64, `TEX0=0x2004d1e59930a4f2`. |
| Fault scan | `ottsel-fault.log` was 0 bytes; no runtime assertion/crash/fault marker appeared. The Simulator stayed blank/non-audible and provides no playability or visual proof. |
| Verdict | OPEN. The trigger is now phase-correct. The first mobile Sprite3 source stream is genuinely different from macOS, and the initial mobile camera matrix is transition-stale before settling; this narrows the next issue to producer/frame-state sequencing or resource-family selection. It does not justify a TBP remap or renderer widening. |
| Next gate | Capture the first stable post-transition mobile group after the camera matrix settles and align its frame/matrix/resource tuple to macOS’s first `flush_sprites`; only then select a shared producer defect or renderer adaptation. |

The source-level trigger gate was necessary because title and Village1 both emit
Sprite3-shaped DMA. The earlier ungated title capture is retained as a timing
artifact, not used as Village1 evidence.
