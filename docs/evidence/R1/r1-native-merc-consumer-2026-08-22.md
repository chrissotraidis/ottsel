# R1 native Merc consumer — 2026-08-22

## Scope

This gate tests the first real native Merc composition path after the R1
producer/resource investigation. It does not claim iPad playability.

## Implementation

- Added a native PC_PORT Merc consumer using the loaded FR3 `MercModel` data.
- Parses the packet's model name, matrix-slot pointers, bone matrices, and
  effect mask; CPU-skins the real FR3 vertices and submits indexed geometry.
- Reuses the existing native Metal camera/material/texture contract and does
  not add runtime code generation, TBP remapping, camera policy, or fixtures.

## Fresh signed proof

- `scripts/build-ios.sh` completed; `codesign --verify --deep --strict` passed.
- One booted iPad Pro 11-inch (M4) Simulator and one Ottsel runtime were used.
- Fresh title submissions included `ndi-lod0` and `ndi-cam-lod0`; Metal
  accepted meshes up to 67,554 vertices / 4,430 triangles / 7 draws.
- Fault log remained 0 bytes.
- Focused input regression passed 9/9.
- Fresh route frame: `/tmp/ottsel-video/native-merc-accepted-route-20260822-1741.jpeg`.

## Disposition

Native Merc ingestion and submission are proven for real world actors. The
fresh marker-synchronized route reached `GAMEPLAY: enter village1`; native
submission accepted `medres-misty-lod0`, `medres-training-lod0`,
`warp-gate-switch-lod0`, then `balloonlurker-pilot-lod0` and
`balloonlurker-lod0` after the route transition. No player/Jak model packet
was emitted. The fresh frame remains visibly partial/corrupted with no Jak and
is not playable. Continue actor ownership, Merc materials/lighting,
lifecycle, audio, iPhone, and physical-device gates.
