# R1 earliest Village1 source boundary — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 Sprite3 producer/phase ownership |
| Source/build identity | Outer checkout `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed executable SHA-256 `a3af1793efce65018e3829358bb49740e0805388079485167aa07bf39823da69` |
| Environment | One iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; fresh data container `E511E90A-666C-4F59-A528-F8E29BE00EC0`; normal Metal; Simulator shut down after capture |
| Before failure | A post-entry source trace showed only world groups, while a later aggregate showed a 3D-bearing window. The earliest eligible Village1 window needed separate capture. |
| Change | No product-source change. Armed `ottsel-trace-mobile-sprite-source-boundary` before launch, synchronized Start/Cross/Down×4/Cross from the current marker-file mtime, and retained the first eligible trace. |
| Focused proof | Fresh runtime logged the title-wait marker, Start edge, Village1 entry twice, and a complete 8-item source trace. `ottsel-fault.log` was 0 bytes. |
| Live proof | Chains 142–145 / VSYNC 143–146 each began at transfer 13 with `MSCAL=3`, 48 sprites at `TBP=0x2bc1`, PSM 19, 64x64, then transfer 14's 16-sprite zero-texture tail. Frame transfer was 9 and matrix transfer 12. Chains 142–144 used camera translation `(227569.38,47488.31,-5.7278464e9,-31.885628)`; chain 145 changed to `(-389687.25,58981.883,1.02667206e9,5.6293917)` with camera source transfer 281. |
| Verdict | OPEN — the earliest captured mobile Village1 window contains no `MSCAL=211` family, so the macOS first phase is not present in this mobile window. This is producer/phase evidence only; the Simulator remained blank/non-audible. |
| Next gate | Reconcile the exact source chain/table and phase-state ownership against the macOS `MSCAL=211` → `MSCAL=3` sequence; do not remap TBPs or alter camera/shader semantics without that ownership result. |

This does not constitute visual, audio, or playability acceptance.
