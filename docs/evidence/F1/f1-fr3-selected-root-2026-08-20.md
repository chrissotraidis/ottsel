# F1 validated-root FR3 loading — 2026-08-20

| Field | Evidence |
|---|---|
| Gate | F1 — legal user-data import and save persistence; R1 renderer dependency |
| Source/build identity | Outer `dc60af38433879ccf65ac30d0c16a5f155e9541e`; upstream `641fb572e876750d8618434d9f7c1a531b43b366`; app executable SHA-256 `6133d2f315057b1fdd2f687bf7835874ca1e7e88e38da9cf035d9c62723601b8`; iPad Pro 11-inch (M4) Simulator, iOS 18.5 |
| Before failure | The validated pack imported, but mobile Metal level loading always resolved `title.fr3`/`village1.fr3` from the bundle path and logged both as missing. The renderer therefore could not consume the user-owned FR3 levels. |
| Change | Added a ROM-free selected-root helper regression and changed `load_mobile_level` to prefer `ee::ottsel_iso_data_dir()`—the validated durable root—with the bundle `iso_data` root retained as clean-install fallback. |
| Focused proof | Red test-first compile failed because `select_user_data_root` did not exist. After the fix, `goalc-test --gtest_filter='Sprite3Native.*'` passed 4/4; `scripts/build-ios.sh` and strict codesign verification passed. |
| Live proof | One fresh pre-Metal launch logged validated-pack import into Application Support, then loaded `title` (`3,446,727` bytes; TFRAG normal `3/3/12`) and `village1` (`36,673,019` bytes; TIE `12/626/1,563,934`; TFRAG normal `3/240/148,180`; transparent `3/3/220`) with no missing-level warning. |
| Fault scan | Fault log remained 0 bytes. No runtime-created executable code or protected data was added. |
| Simulator boundary | The Simulator was blank and non-audible; FR3 load/geometry logs are diagnostic data-path proof only, not rendered-frame, audio, or playability proof. |
| Verdict | OPEN — validated FR3 data now reaches the mobile renderer; legal Files delivery, native image parity, and the remaining R1 bucket work remain open. |
| Next gate | R1 native Metal composition: capture a stable native TIE/TFRAG/Sprite3 draw/counter comparison from the selected root without CPU-frame publication. |
