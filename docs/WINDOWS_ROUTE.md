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
- **The disc pipeline completes on ARM64 Windows.** With the owner's Black
  Label disc, the Windows ARM64 extractor validated it (serial SCUS-97124, ELF
  hash 7280758013604870207) and the decompiler finished. `goalc --isa arm64` at
  first crashed with an access violation in `dma-disasm.gc`, the first file
  that declares `(declare-file (debug))`. The compiler throws an exception for
  that declaration and recompiled the whole file inside the `catch` block. On
  Windows a `catch` block runs as a separate funclet, and doing that much work
  inside it corrupted memory in the optimized ARM64 build. The patch now leaves
  the handler first and retries afterwards, with the same result. With that
  change `goalc` built all 1,068 targets. The Mac output is unchanged.
- **Windows output is close to the Mac's, not identical.** Of 321 `out/jak1/iso`
  files, 304 match the Mac byte for byte, and so do 959 of 1,039 object files.
  The other 80 objects, which make up the 17 code containers including
  `KERNEL.CGO` and `GAME.CGO`, have the same sizes and differ in a few
  instruction fields: register choices and stack-slot offsets. That points to
  the compiler visiting something in a different order on Windows. It should
  behave the same, but that is unproven until the source of the difference is
  found or a Windows-built game is tested on a device.

## Next steps

1. Find why register and stack-slot choices differ between Windows and Mac
   (likely container iteration order), make the 80 objects identical, then
   repeat the comparison on a real x64 PC.
2. Design the module boundary: which symbols the signed modules need from the
   app and which the app needs from them, the loader and identity check, and
   how `build-ios.sh` builds the game-free shell.
3. Generate and compile the modules on Windows with PadMint's LLVM and iOS SDK,
   then run PadMint's import, compatibility and insertion checks.

Releases, catalog entries and device checks remain separate decisions.
