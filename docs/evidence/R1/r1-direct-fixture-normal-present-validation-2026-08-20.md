# R1 — corrected Direct fixture completes on normal drawable path (2026-08-20)

| Field | Result |
|---|---|
| Gate | R1 Metal renderer parity and resource lifetime |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed Simulator executable SHA-256 `5423c6f7ae8e4afee8ae7af99604aafbe309a9f54fe43fdac5d26326e637adad` |
| Environment | iPad Pro 11-inch (M4) Simulator, UDID `08636791-2675-4675-8335-EF72EF954DCF`; one runtime; fresh validated local user pack; `OTTSEL_PREPARE_DATA_BEFORE_METAL=1`; `MTL_DEBUG_LAYER=1` |
| Before failure | Before the pass-contract fixes, the normal Metal route aborted with a generic command-buffer error and lost SimMetalHost. Validation had identified mismatched pipeline/depth and overlay state. |
| Change | Rebuilt with the generic `Depth32Float` declaration, valid no-depth diagnostic binding, and dedicated `Always`/no-write overlay depth state. Replayed only the generated Direct fixture on the normal drawable/present path. |
| Focused proof | Focused `DirectFixture.*:Sprite3Native.*:PlatformInput.*:ARM64EmitterFloatMath.*` passed 18/18; `scripts/build-ios.sh`, strict deep codesign, and `git diff --check` passed. |
| Live proof | The validated route logged `OTTSEL METAL DIRECT: fixture accepted image=2x2 ... cpu-raster=0` and unified validation logs recorded `Direct draw contract draws=1 triangles=2 ... depth=gequal/write ... final-target=same-pass`. No Metal validation error, command-buffer error, or XPC interruption appeared in the bounded capture. |
| Fault scan | `ottsel-fault.log` was 0 bytes. The Simulator was blank/non-audible and shut down afterward. No screenshot, PPM, visual, audio-quality, or playability claim. |
| Verdict | PARTIAL R1 PASS — the corrected generated Direct fixture now reaches a clean native draw submission on the normal drawable/present path under Metal validation. Image visibility, same-phase desktop parity, full scene ownership, audio, and playability remain open. |
| Next gate | Capture a diagnostic GPU readback or same-phase native/desktop image and verify the normal untriggered scene path before widening Direct/Sprite3 rendering. |

No MAP_JIT, runtime executable pages, external Metal shell, Jak 2 game-specific
source, protected asset, or repository-packaged user data was added.
