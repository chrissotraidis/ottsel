# 07 — Asset safety and legal boundaries

## Rules
1. User must supply a **legally obtained PS2 copy** of Jak and Daxter: The Precursor Legacy.
2. Never commit, upload, or package:
   - ISOs / RAR/7z disc images
   - `iso_data/` contents
   - extracted music, textures, levels, VO
   - copyrighted trademark splash assets beyond what upstream already licenses for the engine
3. `ref/` is for research sources, not game content.
4. CI and release artifacts must be ROM-free / asset-free.
5. README language must not instruct piracy.

## Recommended ignore patterns (Bot 2 should add)
```
iso_data/
*.iso
*.cso
*.bin
*.cue
*.img
*.mdf
*.nrg
*.gz
*.zip
!docs/**
# extracted / local packages
/assets-user/
/user-content/
/out/game-assets/
/ref/**/iso_data/
```
Adjust to match actual tool output names once they exist.

## Onboarding copy requirements
- State clearly the app does not include the game assets.
- State the user must own the game.
- Prefer host-side extraction instructions over on-device ISO ripping complexity.

## Engine license note
OpenGOAL `jak-project` is ISC-licensed at the pinned commit. That license covers the engine/tools source, **not** Naughty Dog/Sony game content.
