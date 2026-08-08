# H1 proof commands (2026-08-07)

Pin: `641fb572e876750d8618434d9f7c1a531b43b366`

1. Full worktree:
   git clone --filter=blob:none --sparse --branch master https://github.com/open-goal/jak-project.git out/jak-project
   cd out/jak-project
   git fetch --depth 1 origin 641fb572e876750d8618434d9f7c1a531b43b366
   git checkout 641fb572e876750d8618434d9f7c1a531b43b366
   git sparse-checkout disable

2. Apply patch:
   git apply ../patches/h1-arm64-goal-function-codegen.patch

3. Configure (Apple Silicon host):
   cmake -S . -B build/h1 -G Ninja \
     -DCMAKE_BUILD_TYPE=Release \
     -DCMAKE_OSX_ARCHITECTURES=arm64 \
     -DCMAKE_APPLE_SILICON_PROCESSOR=arm64 \
     -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
     -DSTATICALLY_LINK=OFF -DINSTALL_GTEST=OFF

4. Build + run proof:
   ninja -C build/h1 ottsel-h1-proof
   ./build/h1/goalc/ottsel-h1-proof

5. CLI check:
   ninja -C build/h1 goalc
   ./build/h1/goalc/goalc --isa x86 -c '(defun t () 42)'   # no crash
   ./build/h1/goalc/goalc --isa arm64 -c '(defun t () 42)'  # no crash
   ./build/h1/goalc/goalc --isa mips -c '(defun t () 1)'    # clean rejection

Expected H1 output: `[H1] PASS cases=5`
