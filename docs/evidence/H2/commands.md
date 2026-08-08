# H2 proof commands (2026-08-07)

Pin: `641fb572e876750d8618434d9f7c1a531b43b366` (worktree `out/jak-project`)

1. Apply combined patch:
   cd out/jak-project && git apply ../patches/h2-noemit-runtime-host.patch

2. Configure (Apple Silicon host, no-emit flag available):
   cmake -S . -B build/h1 -G Ninja \
     -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 \
     -DCMAKE_APPLE_SILICON_PROCESSOR=arm64 \
     -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
     -DSTATICALLY_LINK=OFF -DINSTALL_GTEST=OFF [-DOTTSEL_NO_EMIT=ON]

3. Build:
   ninja -C build/h1 ottsel-h2-proof ottsel-h2-bridge ottsel-h2-shim goalc

4. Run proofs:
   ./build/h1/goalc/ottsel-h2-proof   # RX-only exec: [H2] RX-ONLY EXEC PASS cases=5
   ./build/h1/goalc/ottsel-h2-bridge  # C->GOAL bridge: [H2-bridge] PASS cases=3
   ./build/h1/goalc/ottsel-h2-shim    # static shim:   [H2-shim] PASS

5. Compile checks for kernel wiring:
   clang++ -std=gnu++20 -arch arm64 -fsyntax-only -I. ... game/kernel/common/kscheme.cpp
   clang++ -std=gnu++20 -arch arm64 -fsyntax-only -DOTTSEL_NO_EMIT -I. ... game/kernel/jak1/klisten.cpp

Expected: all three PASS lines above; kscheme/klisten compile clean.
