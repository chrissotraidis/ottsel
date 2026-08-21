# R1 active Village1 Sprite3 phase ledger — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 renderer parity / active-level producer comparison |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app executable SHA-256 `8d7262e792aaf6d3227d26af634c817ea5e8ba442289b3e8f62239ea4ce8ee20` |
| Environment | One iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; Simulator shut down after capture |
| Before failure | Earlier mobile Sprite3 captures were rejected as setup/loading intervals because `slot1` was not active. |
| Change | Added the narrow symbolic DGO alias and ran the existing signed route. After repeated `slot1=active` samples, armed the existing phase and product ledgers. No texture, camera, or shader remap was added. |
| Focused proof | Alias test passed 1/1; iOS build completed; strict codesign passed. |
| Live proof | Active Village1 state was stable: `slot0=loaded bsp=0x2481494`, `slot1=active bsp=0x2ef8754`. The bucket-67 interval recorded `group=1 phase=world count=48 tbp=0x2bc1 psm=19 tw=6 th=6`, followed by a color-only `group=2 count=16 tbp=0`. The product interval repeated the same 48+16/64-sprite structure. Raw spans were `transfers=18 headers=2` and `transfers=23 headers=2`; no rejected or boundary-stop records. |
| macOS oracle | Same-route macOS producer capture remains `55` world sprites at `TBP=0x24f2`, PSM 19, `64x64`, with the complete frame at 51 world blocks / 2432 world sprites plus HUD. |
| Fault scan | `ottsel-fault.log` was 0 bytes; no assertion, version mismatch, or crash occurred in this run. The Simulator surface remained blank, so this is producer evidence, not visual playability proof. |
| Verdict | OPEN — the active route is now valid, and it confirms a real mobile producer-phase/resource mismatch against macOS. The mobile `0x2bc1` tuple is not equivalent to the macOS `0x24f2` tuple; no mapping change is justified yet. |
| Next gate | Attribute the active mobile 48-sprite group to the macOS 55-sprite group by producer phase/ownership and source resource identity. Only make a test-first adaptation if that attribution isolates a concrete shared defect. |

This closes the earlier “not active-level” qualification on the route, not R1 itself. Audio, visible composed-frame, input/playability, iPhone parity, and physical-device readiness remain open.
