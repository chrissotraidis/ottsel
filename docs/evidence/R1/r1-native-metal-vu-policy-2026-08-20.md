# R1 — normal-Metal native path no longer burns on diagnostic VU1 — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 renderer parity / normal-Metal route liveness |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app SHA-256 `b4c60eb1c1d7cdca8ea6f707727da96275217873fef997b1b8714499c296a3e1` |
| Environment | iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; one normal-Metal runtime; validated user pack; `OTTSEL_PREPARE_DATA_BEFORE_METAL=1`, `MTL_DEBUG_LAYER=1` |
| Before failure | The normal-Metal route repeatedly ran the diagnostic VU1/TFRAG interpreter to its 50,000-instruction cap with zero GIF output (`capped=9900`, `last-pc=1694` in a bounded period), consuming the game thread while native Metal owned the scene. |
| Change | `src/shell/metal_gfx.mm` now keeps CPU/VU diagnostics enabled for SDL-only runs and explicit `OTTSEL_ENABLE_CPU_VU_DIAGNOSTICS=1` runs, but disables that unconsumed fallback by default when native Metal is active. Native FR3/TIE/TFRAG/Sprite3 consumers remain unchanged. |
| Focused proof | `goalc-test --gtest_filter='DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*'`: 18/18 passed. iOS build, strict codesign, `git diff --check`, and product executable-marker audit passed. |
| Live proof | Normal Metal logged `OTTSEL VU1: cpu-diagnostic-path=disabled`; repeated VU1 periods recorded `capped=0`, `last-pc=6`, and the runtime remained alive. Start and both Cross trigger edges were consumed and the progress handler accepted both. |
| Fault scan | `ottsel-fault.log` remained 0 bytes. The Simulator remained blank/non-audible. No Village1 transition followed within the bounded follow-up, so this is not playability or visual proof. |
| Verdict | **PARTIAL PASS** for removing the diagnostic VU1 starvation from the normal-Metal product path; **OPEN** for the title/save/Village1 route and R1 image parity. |
| Next gate | Isolate the remaining post-second-Cross progress/loader divergence against the already-passing SDL-only route; do not re-enable CPU/VU fallback as a route workaround. |

The external Jak 2 research was not merged. This change preserves signed-native
execution, does not add runtime executable memory, and keeps the VU interpreter
available only as an explicitly labeled diagnostic route.

Follow-up input discrimination added the existing writable-trigger seam's
missing D-pad Down edge (`ottsel-press-down`, mask `0x40`). A fresh normal-Metal
diagnostic replay consumed Start (`0x8`), Cross (`0x4000`), four Down edges, and
a final Cross; the app fault log remained zero bytes, but no Village1 or
Training transition followed. This rules out the previously missing Down
injection as the remaining route explanation. The Simulator was blank and
non-audible, so no visual or playability claim is made.
