# R1 Sprite3 depth-write policy — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | R1 — Sprite3 and renderer parity |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app rebuilt from the current worktree; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | Maintained Jak 1 `Sprite3::opengl_setup_normal` sets GEQUAL depth testing and disables depth writes. Native Sprite3 reused `directDepthState`, whose GEQUAL state had depth writes enabled for the Direct/TIE path. |
| Change | Added `ottsel::sprite3_depth_write_enabled() == false`, a focused regression, and a dedicated native `spriteDepthState`; the native Sprite3 encoder now uses GEQUAL/no-write without changing Direct/TIE ownership. |
| Focused proof | Red test-first build failed because the new policy did not exist. After the fix, `goalc-test --gtest_filter='Sprite3Native.*'` passed 3/3; `scripts/build-ios.sh` completed and strict codesign verification passed. |
| Live proof | One rebuilt Metal launch with pre-Metal data preparation reached the title route and kernel phases with a zero-byte fault log, but did not emit a Sprite3 draw within the bounded window. No live visual claim is made. |
| Fault scan | No new fault bytes; the Simulator was shut down after the run. |
| Simulator boundary | The Simulator remains blank and non-audible; this correction is source/test/build evidence only, not image, audio, or playability proof. |
| Verdict | OPEN — the Sprite3 depth-state mismatch is corrected and regression-covered; native image parity, route completion, and R1 remain open. |
| Next gate | Capture a later native Sprite3 draw with the corrected state, then compare a stable native/desktop frame or fixture checksum and counters. |

