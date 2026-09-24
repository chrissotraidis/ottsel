# The iPad lane's supported data path is the F1 import, not bundle staging - 2026-09-22

Gate: I0 (bootstrap robustness).  Question: what is the supported way to give the iPad lane its
ROM-derived data, and can it be made a repeatable, rebuild-proof step?

**The app already implements the right design.**  `src/shell/ios_boot.cpp`'s `select_ios_iso_data_dir()`
imports a pack from `$HOME/Documents/OttselUserData`, validates it (`manifest.txt` = `OTTSEL_USER_DATA_V1`,
`pack-version=1`, `data-version=jak1`, all nine families present and hashed), then promotes a **durable**
copy into `Library/Application Support/local.ottsel/OttselShell/OttselUserData` and overlays the build's
own generated `TIT.DGO`/`VI1.DGO` and `*.TXT` on top of it.  Without an imported pack it falls back to the
bundle's `iso_data`, which is what made the earlier bundle staging appear necessary - and which is also
why a *fresh install* dies: the bundle only ever carries the built `TIT.DGO`/`VI1.DGO` + `TEXT`, so a
missing family (`SBK`, `MUS`, ...) reaches the pack-validation path and throws instead of reporting.

**The durable path verified twice.**  Copying `/tmp/ottsel-user-pack` (built by
`scripts/prepare-user-data-pack.sh` from the repository's gitignored `out/jak-project/iso_data/jak1` plus
the derived `out/jak-project/out/jak1/fr3`) into the container's `Documents/OttselUserData` and relaunching
gives, on both attempts:

```
OTTSEL F1: imported validated user pack into .../OttselShell/OttselUserData
t=20s title=1 modules=346 fault=0 durable=1560 MB
```

Because the promoted copy lives in the container, a `build-ios.sh` rebuild no longer wipes the lane's data
the way staging into the bundle did - the bundle is only ever the diagnostic fallback now.

**New script: `scripts/import-ios-user-data.sh <udid> [pack]`.**  It validates the pack with
`validate-user-data-pack.sh`, boots the target Simulator if needed, copies the pack to the container's
`Documents/OttselUserData`, and prints the relaunch instruction.  Verified end to end this turn: it booted
the device, imported 1.5 GB in 20 s, and the following launch logged the F1 import line and reached the
title with 346 modules, a 0-byte fault log and a 1560 MB durable copy.

Staging rule worth keeping in view (measured last turn): the bundle must keep the *build's* `TIT.DGO`,
`VI1.DGO` and `*.TXT`; replacing them with the pack's originals boots to 332/346 modules and then crashes
with a held fault.  The F1 import does that overlay itself, which is the other reason to prefer it.

Still open: a fresh install with no imported pack must report the missing family by name instead of
terminating with an uncaught `ghc::filesystem::filesystem_error`.  Not claimed: no route/New Game proof,
no playability, audio or lifecycle acceptance.
