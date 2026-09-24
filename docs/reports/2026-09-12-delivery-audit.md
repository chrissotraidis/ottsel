# Ottsel delivery audit — 2026-09-12

Scope: read-only product-boundary audit plus preservation of two source overlays.
No build, GOAL regeneration, Simulator operation, or asset copy was performed.

## Full-game signed AOT remains open

The original product requires ARM64 code in the signed app with no runtime
executable-memory creation (`docs/10-code-packaging-and-signing.md:75,107`).
The current Simulator build defines `OTTSEL_NO_EMIT`, but that flag does not
establish this requirement: `game/kernel/jak1/klink.cpp:737-757` makes loaded
main-segment pages RX; further top-level/main RX changes occur at 786/813.
`game/kernel/jak1/kscheme.cpp:653-685` writes trampoline instruction words
into runtime memory; its stub sealing uses executable page permissions.
`src/shell/ios_boot.cpp:1989` loads GAME.CGO; `scripts/build-ios.sh:273-279`
links the small signed A1.1 slice alongside the runtime, not all game code.
Codesign and the slice proof therefore do not prove signed-native gameplay.
Keep this as Simulator research until full-game signed AOT replaces both
loaded executable blobs and runtime-created stubs, with fresh device proof.

## The actual bundle contains game assets

Read-only object-header inspection of `out/jak-project/out/ios/app/OttselShell.app`:
- `iso_data/DGO/TIT.DGO`: 1,468,736 bytes, 15 objects, including tpage-1609,
  tpage-416/415/397/1499 and title-vis.
- `iso_data/DGO/VI1.DGO`: 12,088,656 bytes, 55 objects, including
  tpage-398/400/399/401/1470 and village1-vis.
- `iso_data/TEXT`: approximately 4.5 MiB of copied text resources.
The title manifest `goal_src/jak1/dgos/tit.gd` explicitly includes texture,
art and visibility objects. The build's DGO/TXT copies are not code-only.
Comments now identify the local research boundary; packaging behavior is unchanged.
No IPA/ZIP was found under `out`; no data-free distributable is verified.
An 18 MiB ENGINE.CGO dated September 11 remains at the bundle root although
the current script neither copies nor removes it. Assemble release bundles
in fresh staging directories with a resource allowlist and verified provenance.
Separate generated code-only containers from legal user-imported assets.

## Reconstruction progress and remaining scope

The nested tree has 144 tracked dirty files plus untracked sources.
The sampled libpad, platform input, iOS stubs, kprint, sndshim and sequence-A
sources already reconstruct exactly from the pinned revision plus H3.
New narrow overlays preserve two remaining functional deltas:
- `jak1-soundbank-offset.patch`: fake_iso.cpp, +12/-1.
- `jak1-loader-spool-recovery.patch`: loader.gc, +30/-1, including diagnostics.
For each, pin + H3 + overlay was applied to temporary source files and compared
byte-for-byte with the current nested source; both passed. Reverse checks passed.
This proves preservation, not semantic correctness of the signature scan or
spool-buffer eviction. Add focused regressions before treating either as closed.
Apply order and scope are in `patches/README.md`; linker and platform-test
overlays are also required. Then regenerate affected GOAL outputs and full-build.
Remaining differences include title/progress/target diagnostics; audit the rest
of the nested files and untracked additions before claiming clean reconstruction.
I1 scene/input progress does not close I2 audio/lifecycle/saves, I3 frontend,
P1 iPhone, D1 devices, or the full-game signed-AOT and data-free package gates.
