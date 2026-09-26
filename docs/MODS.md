# Mods, texture packs and cheats

Ottsel runs OpenGOAL's game code compiled ahead of time and signed into the app, because iOS allows no
JIT. What you can change therefore splits in two: assets, which go into your build on the Mac, and code,
which needs its own build.

## Built in

- **Cheats.** **••• → Cheats** switches OpenGOAL's cheats on and off in one tap: invincibility, infinite
  eco of each colour, big, huge and small heads, big fist, big-headed villagers, blue Daxter, mirror world,
  real-time sky and every music flavour. The game's own **Secrets → Cheats** menu shows the same list.
- **Button codes.** The touch controls include L2 and R2, so the original codes (hold L1 + L2 + R1 + R2,
  then enter the sequence) work by touch as well as on a controller.
- **Jump to Level (Testing).** **••• → Diagnostics** starts play at any hub or level.

## Texture packs

OpenGOAL's extractor replaces a game texture with a PNG of the same name while it builds your data:

```text
out/jak-project/custom_assets/jak1/texture_replacements/<texture page>/<texture name>.png
```

Install a pack by copying its `texture_replacements` folder there, then redo step 2 of the build
(`extractor --extract --decompile`) and step 4 (the data pack), and re-import the pack. Packs made for
OpenGOAL's Jak 1 use this layout, for example
[Jak 1 – Refreshed HUD](https://github.com/Aloqas/Jak-1-Refreshed-HUD) and the HD packs listed on
[JakMods.dev](https://jakmods.dev). Replacement textures are loaded into memory with the level, so very
large packs may not fit an iPad or iPhone; try one level first.

## Model replacements

The same extractor swaps a character or object model for a `.glb` file named after the model:

```text
out/jak-project/custom_assets/jak1/merc_replacements/<model name>.glb
```

## Gameplay mods and custom levels

Mods such as [OG Randomizer](https://github.com/OpenGOAL-Mods/OG-Randomizer), Speedrun Practice or
custom levels change the game's code. Each would need Ottsel's patch applied to that mod's OpenGOAL
source and a separate signed build; none is packaged yet. Check each mod's license before sharing a build.

None of the texture or model paths above has been tested in Ottsel yet; please report results with a
[device report](https://github.com/chrissotraidis/ottsel/issues/new?template=device_report.yml).
