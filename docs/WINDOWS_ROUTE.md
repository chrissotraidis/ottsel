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
- **Native ARM64 Windows host tools build and run.** The patch now carries five
  small Windows changes: case-insensitive `ARM64` checks (Windows reports it in
  capitals), `-march=armv8.1-a` for clang-cl so the CRC32C intrinsics compile,
  the x64-only debugger and `__cpuidex` paths limited to `_M_X64` (ARM64 Windows
  uses the existing stubs), and `FlushInstructionCache` instead of
  `__clear_cache` in `CodeTester.cpp`. With them, `goalc.exe` and
  `extractor.exe` build natively on Windows 11 ARM64 with Visual Studio 2022's
  clang-cl and run there. These changes do not affect the Mac: Mac builds from
  the supported disc produced all 321 `out/jak1/iso` files byte-identical with
  and without them, including `KERNEL.CGO` (`c370e1c6…53590`) and `GAME.CGO`
  (`f8184914…66459`).
- **The disc pipeline gets partway on ARM64 Windows.** With the owner's Black
  Label disc, the Windows ARM64 extractor validated it (serial SCUS-97124, ELF
  hash 7280758013604870207) and the decompiler finished. `goalc --isa arm64`
  then stopped at 22% with an access violation while compiling
  `goal_src/jak1/engine/dma/dma-disasm.gc` (38 object files written). The Mac
  compiles the same input completely, so this is a Windows-specific compiler
  bug to find next; a 32-bit `long` on Windows is the first suspect.

## Next steps

1. Fix the Windows `goalc` crash in `dma-disasm.gc`, then compare all
   `out/jak1/iso` files and the data pack with the Mac build above, on ARM64
   and on a real x64 PC.
2. Design the module boundary: which symbols the signed modules need from the
   app and which the app needs from them, the loader and identity check, and
   how `build-ios.sh` builds the game-free shell.
3. Generate and compile the modules on Windows with PadMint's LLVM and iOS SDK,
   then run PadMint's import, compatibility and insertion checks.

Releases, catalog entries and device checks remain separate decisions.
