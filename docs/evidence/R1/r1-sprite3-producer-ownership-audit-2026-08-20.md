# R1 Sprite3 producer/consumer ownership audit — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 renderer parity; Sprite3 producer phase attribution |
| Source identity | Ottsel outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; local OpenGOAL base `641fb572e876750d8618434d9f7c1a531b43b366` |
| macOS producer | Jak 1 `OpenGLRenderer` assigns bucket 66 to `Sprite3`. `Sprite3::render_jak1` consumes, in order, the pre-sprite Direct segment, distorter, frame setup, 3D matrix, group-0/world MSCAL 3 chunks, shadow boundary, and group-1/HUD chunks before ending the bucket. The same-route macOS trace counted `51` group-0 blocks and `2,432` world sprites. |
| Mobile consumer | `render_mobile_sprite_bucket` is called only for bucket 66 and currently recognizes frame/matrix transfers plus group-0 headers whose run is MSCAL 3. Bucket 67 is separately sent to the Direct decoder. The mobile path has no independently attributed Sprite3 pre-Direct, distorter, shadow, or HUD phase ledger. |
| Live evidence | A current signed binary contains the bounded parser-summary probe and a fresh prepared-pack launch armed it on the first bucket call (`chain=1`, `groups=0`, `sprites=0`), proving the diagnostic is present. The later route helper used the wrong input-trigger location and did not yield a new Village1 parser summary; that attempt is excluded from renderer interpretation. |
| Interpretation | The mobile `TBP=0x2c8d` versus macOS `TBP=0x24f2` difference cannot yet be assigned to a texture-owner defect. The first missing discriminator is phase ownership: identify the same Sprite3 call/segment and group index on both platforms, then compare its first TBP and sprite count. No shader, alpha, depth, camera, or texture remap change is justified. |
| Verdict | OPEN — producer ownership is narrowed but not yet matched. |
| Next gate | Re-run one valid prepared-pack Village1 route with the trigger placed in the app writable root, capture one full bounded mobile Sprite3 phase ledger (pre-Direct/distort/group-0/shadow/group-1), and align it to the macOS `Sprite3::render_jak1` phase sequence. |

The Simulator was blank and non-audible. This audit is source/trace attribution only,
not visual parity, audio, or playability proof. No MAP_JIT, runtime executable page,
dynamic trampoline, external Metal shell, or protected game data was imported.
