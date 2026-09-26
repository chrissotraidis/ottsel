# Ottsel macOS packaging and settings

## Package

After building `out/jak-project/build/h1/game/gk`, run:

```sh
./scripts/package-macos.sh
open out/Ottsel.app
```

The script creates `out/Ottsel.app`, generates `Ottsel.icns` from the existing
Jak 1 artwork, and launches the current checkout's `gk` with external game
data. Game data remains external and is never packaged or committed.

## In-game Ottsel settings

Press Left Alt to show the existing debug toolbar, then choose `Settings →
Ottsel`:

- `Upscaling`: Native, 2x, 3x, or 4x internal render resolution.
- `Mute game audio`: toggles the Jak 1 master audio group at runtime.

The menu changes are deliberately runtime-only until a later settings-storage
gate proves safe persistence. The macOS launcher defaults audio to the local
`MacBook Air Speakers`; set `OTTSEL_AUDIO_OUTPUT_DEVICE` explicitly for a
remote or different output route.

## Acceptance boundary

The macOS build still requires fresh visible gameplay, input/lifecycle/fault
evidence, and human audible confirmation before the iPadOS/iOS loop is promoted.
