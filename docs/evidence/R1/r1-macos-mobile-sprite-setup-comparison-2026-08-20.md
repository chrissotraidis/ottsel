# R1 macOS/mobile Sprite3 setup comparison — 2026-08-20

| Field | Result |
|---|---|
| Gate | R1 producer/frame-state attribution before native composition |
| Source/build identity | Outer Ottsel `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; macOS executable rebuilt from upstream `641fb572e`; mobile signed app remains `0a59e57670cc502cae179a6c3185db1dbad5344135bb78f6a8db30691b00a597` |
| Environment | One Windowed native arm64 macOS `gk` runtime; no Simulator concurrently; stopped after trace |
| Before failure | Mobile’s native candidate gate rejected all retained `0x2c8d` candidates, but no desktop Sprite3 frame-setup tuple existed for a direct timing/state comparison. |
| Change | Added one bounded diagnostic `OTTSEL SPRITE3 SETUP` log after the desktop Jak 1 frame and matrix setup are both decoded. It records `pfog0`, `inv_area`, camera translation, HVDF, and basis vectors; no renderer behavior changed. |
| Focused proof | `ninja -C build/h1 gk` passed with only pre-existing override warnings. `git diff --check` passed for the diagnostic source. |
| Live proof | After a fresh Village1 display-self marker, macOS trace frames 4–6 repeatedly emitted the first world draw as `TBP=9458 (0x24f2)`, 64×64, 55 sprites, with setup tuples: frame 4 `pfog0=-0.05868248`, `inv_area=0.036767285`, camera-t `(42597.83,-3494.7246,-7.871884e9,-55.23716)`; frame 5 `camera-t=(42436.184,-3324.4604,-7.867625e9,-55.290413)`; frame 6 `camera-t=(42274.613,-3154.3977,-7.863352e9,-55.343662)`. The frame setup was stable across the three traced frames. |
| Mobile comparison | The stable post-transition mobile ledger emitted the retained world `0x2bc1`/`0x2c8d` resources and recorded matrix camera-t approximately `(-389687.25,58981.883,1.02667206e9,5.6293917)` with `pc-level='village1'`; the earlier transition tuple was also distinct and stale. |
| Fault scan | The macOS trace completed three frames without crash/fault markers. No Simulator was booted; no mobile screenshot or playability claim is made. |
| Verdict | OPEN. The first divergence is now concrete at the producer/frame-state/resource boundary before native Metal: stable desktop setup/resource state and stable mobile setup/resource state are not equivalent. This does not justify a camera sign, shader, TBP remap, or visibility-gate change. |
| Next gate | Trace the mobile Sprite3 frame/matrix producer immediately before the first stable `MSCAL=3` group and compare its source setup fields against the desktop `handle_sprite_frame_setup` tuple. Select a code fix only if one shared field/producer contract is falsifiably wrong. |

The initial pre-Village1 desktop trace frames with zero setup values were excluded;
the accepted comparison begins only after the Village1 display-self marker.
