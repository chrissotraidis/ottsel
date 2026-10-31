# A Windows build route for Ottsel

Ottsel builds only on an Apple Silicon Mac today. This note records what a
Windows route needs and what has been checked. It is a plan, not a released
route.

## How the Mac build works

`scripts/build-personal.sh` fetches OpenGOAL at a pinned commit, applies
`patches/ottsel-jak-project.patch`, builds the host tools `goalc` and
`extractor`, extracts and decompiles the player's disc, compiles the game with
`goalc --isa arm64`, packs the player's data folder, then builds the iOS app.
iOS forbids just-in-time code, so `scripts/build-ios.sh` turns the compiled
game modules into assembly and links them into the signed app binary. The app
therefore contains code made from the player's disc: it is not a game-free
shell.

## The two halves of a Windows route

1. **Host tools on Windows.** `goalc` and `extractor` must build and run on
   the player's PC, and their output (`KERNEL.CGO`, `GAME.CGO`, the object
   files and the data pack) must match the Mac's.
2. **Module delivery.** The signed game modules must move out of the app binary
   into a private iOS library that PadMint builds on the player's PC and inserts
   into a published game-free Ottsel app, as GoldenPad, SnapPad and DinoPad do.
   The app then loads that library before starting the kernel.

## What has been checked (31 October 2026)

- **x64 Windows host tools compile.** On Windows 11 ARM64 (Parallels), the
  pinned OpenGOAL with Ottsel's patch configured and built `goalc.exe` and
  `extractor.exe` for x64 with Visual Studio 2022's clang-cl, `lld-link`, NASM
  2.16.03 and Ninja (438 steps). The patch applies cleanly on Windows.
- **That machine cannot run them.** OpenGOAL requires AVX. Windows 11 21H2's
  x64 emulation has no AVX: a two-line AVX test program stops with
  `0xC000001D` (illegal instruction), and both tools exit at startup. A real x64
  PC, or Windows 11 24H2's emulator, is needed to run them.
- **They build and run on real x64 Windows.** `.github/workflows/windows-host-tools.yml`
  builds both with Visual Studio 2022's clang-cl on GitHub's x64 Windows runner
  and starts them, using public code only. Both print their options, and
  `goalc.exe` offers Ottsel's `--isa arm64` code generation. The runner's git must
  not convert the patch to CRLF line endings.
- **Native ARM64 Windows does not configure yet.** The pinned
  `game/CMakeLists.txt` matches `CMAKE_SYSTEM_PROCESSOR` against lowercase
  `arm64`, but Windows reports `ARM64`, so it falls back to the x64 NASM path.
  The ARM64 path also assembles an Apple-style `.s` file with `-arch arm64`.
  An ARM64 Windows host would need both changed.

## Next steps

1. Run extraction and `goalc --isa arm64` on a real x64 PC with the supported
   Black Label disc and compare `KERNEL.CGO`, `GAME.CGO` and the data pack with
   a Mac build.
2. Design the module boundary: which symbols the signed modules need from the
   app and which the app needs from them, the loader and identity check, and
   how `build-ios.sh` builds the game-free shell.
3. Generate and compile the modules on Windows with PadMint's LLVM and iOS SDK,
   then run PadMint's import, compatibility and insertion checks.

Releases, catalog entries and device checks remain separate decisions.
