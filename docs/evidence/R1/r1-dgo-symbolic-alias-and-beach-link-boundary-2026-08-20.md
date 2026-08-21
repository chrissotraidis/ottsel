# R1 DGO symbolic-name boundary and next linker blocker — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 active-level route/data prerequisite |
| Source/build identity | Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; signed app executable SHA-256 `ffcca705fd2c687d2237b885d913805129c451fa18e34b770b26ede12a8947e3` |
| Environment | One iPad Pro 11-inch (M4) Simulator `08636791-2675-4675-8335-EF72EF954DCF`; PID `27838`; Simulator shut down after capture |
| Before failure | The prior run stopped before Village1 because the validated pack contained retail `VI1.DGO`/`BEA.DGO` while the GOAL route requested symbolic `village1.DGO`/`beach.DGO`. |
| Change | Added `common/dma/ottsel_dgo_alias.h` and applied the alias only in the iOS DGO loader: `village1→VI1`, `village2→VI2`, `village3→VI3`, `beach→BEA`. Added focused assertions for the mapping. No files were copied, renamed, or embedded. |
| Focused proof | `ninja -C out/jak-project/build/h1 goalc-test`; `out/jak-project/build/h1/goalc-test --gtest_filter='Sprite3Native.ResolvesJak1SymbolicDgoNamesToRetailTokens'` passed 1/1. `scripts/build-ios.sh` completed and strict codesign passed. |
| Live proof | Fresh import resolved `vi1.DGO → .../DGO/VI1.DGO`; the Village1 DGO linked through `village1-part`, `village1-part2`, and `sequence-a-village1`. The subsequent symbolic `beach.DGO → .../DGO/BEA.DGO` alias also resolved and linked through object 49 `beach-vis`. |
| Fault scan | The runtime then logged `OTTSEL LINK VERSION MISMATCH: object= major=0 minor=0 expected=1.0` and hit the existing assertion `klink.cpp:81`, `link_control::jak1_jak2_begin`, after `Elapsed time for level = 0.3333s`; `ottsel-fault.log` was 0 bytes. The blank object name and zero header version indicate the failure is not yet safely attributable to a valid `beach-vis` GOAL object. No active `slot1` Village1 proof or renderer comparison is claimed. |
| Verdict | OPEN — the symbolic DGO naming dependency is fixed and test-proven; the next blocker is retail `BEA.DGO` object/link-version compatibility before the active-level gate. |
| Next gate | Trace the DGO object pointer/name and header at the `beach-vis` completion boundary; reconcile the maintained runtime/linker contract only after the exact object is identified. Do not skip it, relax the version assertion, or change Sprite3/camera/shader behavior without a falsifiable compatibility test. |

The macOS/iPadOS split remains material: macOS can reach a visually plausible scene, whereas iPadOS is still stopped in data/link activation before a fair active-level renderer comparison. Audio remains unaccepted on macOS, and this iPad Simulator run remained blank/non-audible.
