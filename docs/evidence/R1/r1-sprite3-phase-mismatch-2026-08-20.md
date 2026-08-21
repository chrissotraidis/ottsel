# R1 Sprite3 macOS/mobile phase comparison — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 — Sprite3 renderer parity |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; current signed app Mach-O `c4228d159cc58fbb546457ccf2ddd79a0d0d3686edb584f7eadefb2d5deb235b` |
| Before failure | The mobile in-bounds candidate used native state compatible in shape with the desktop Sprite3 contract, but its texture phase had not been compared against a fresh macOS reference. |
| macOS reference | Fresh three-frame trace after Village1 activation: frame 4 world group `tbp=9458` (`0x24f2`), 64×64, TCC/filter/clamp enabled, `blend=2`, `ztest=2`, `zwrite=false`, `alpha-test=2`, `aref=0.000`; 20 sprites. Later groups deliberately differ (`tbp=9710`, zwrite true, aref 0.299). |
| iPad candidate | Fresh pre-Metal route probe selected group 0/index 0 `tbp=0x2bc1`, 64×64, source-over blend, GEQUAL/2 alpha test, CPU raster skipped, bounds `(0.437,0.484)..(0.618,0.789)`, alpha max 128, 2,615 nonzero-alpha texels. |
| Comparison | `0x2bc1` and `0x24f2` are different texture phases. The compatible-looking state shape is not enough to justify a mapping change, and the iPad run did not cleanly reach `village1.DGO`; it faulted after the DGO was absent from the staged pack. |
| Focused proof | Existing 18-test Direct/Sprite/input/compiler filter passed; strict codesign and `git diff --check` passed. |
| Verdict | OPEN — phase mismatch, not a Sprite3 state bug and not a visual/playability pass. The Simulator remained blank/non-audible. |
| Next gate | Use the real New Game route with an observable Cross trigger and a clean generated-DGO path, then compare a matching texture/state tuple before changing native alpha/depth/blend semantics. |

No external renderer, MAP_JIT path, runtime executable code, or protected asset was imported.
