# R1 iOS graphics-sync phase replay — 2026-08-21

| Field | Result |
|---|---|
| Gate | R1 — synchronized Sprite3 phase/resource replay |
| Identity | Signed app SHA-256 `aad4f9d9e5ddbca62bda3e13dd253c3ba84fb87f08fe27714c3665559df0eb67`; one iPad Pro 11-inch (M4) Simulator, `08636791-2675-4675-8335-EF72EF954DCF` |
| Before failure | iOS graphics sync was stub-only; the correction required proving renderer delegation and checking whether the Sprite3 phase window changed. |
| Change | Used the iOS sync-delegation correction from `patches/r1-ios-gfx-sync.patch`; no Sprite3/resource or Metal policy change. |
| Focused proof | `scripts/build-ios.sh` completed; strict codesign passed. |
| Live proof | Runtime logged `renderer-delegated=true` for VSYNC calls 1–8 and 60. The accepted frame aggregate reported `vsync=115964`, `chains=1`, `groups=5`, `sprites=192`, `world=64`, `hud=128`, `3d=0`, `other=0`; items were world `TBP=0x2c8d` (48 and 16 sprites) followed by HUD `TBP=0x2bd2`, `0x2be8`, and `0x28b8`. |
| Fault scan | `ottsel-fault.log` was 0 bytes. The Simulator remained blank and non-audible. |
| Verdict | OPEN. Sync delegation is runtime-proven, but the accepted mobile phase remains incomplete and does not match the macOS Sprite3 dispatch. The sync correction alone did not establish renderer parity. |
| Next gate | Capture the first same-transition post-sync producer sequence immediately after the Village1 display marker, then compare source ownership before selecting another fix. |
