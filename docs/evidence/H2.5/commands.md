# H2.5 proof commands (2026-08-07)

Pin: `641fb572e876750d8618434d9f7c1a531b43b366` (worktree `out/jak-project`)

1. Build the packaging proof tool (after applying `patches/h2-noemit-runtime-host.patch`):
   ninja -C build/h1 ottsel-h25-proof

2. Run it (writes .s/.o into the evidence dir):
   ./build/h1/goalc/ottsel-h25-proof <evidence-dir>
   # -> [H2.5] MACH-O PACKAGING PATH PASS cases=3

3. Link + run one packaged AOT function as native code:
   cd <evidence-dir>
   xcrun clang -target arm64-apple-macos -c run_loop.c -o run_loop_main.o
   xcrun clang -target arm64-apple-macos loop.o run_loop_main.o -o aot_loop_native
   ./aot_loop_native        # -> aot_loop(10) = 45

4. Signed-code checks:
   xcrun llvm-objdump --macho --section-headers loop.o   # __TEXT,__text (TEXT)
   xcrun llvm-objdump --arch=arm64 --disassemble loop.o  # AOT instructions
   xcrun codesign -s - -f aot_loop_native               # ad-hoc sign succeeds

Expected: PASS line, aot_loop(10)=45, __TEXT section, valid signature.
