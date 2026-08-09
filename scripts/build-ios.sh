#!/bin/bash
# Ottsel S1.3 — build the iOS Simulator app with the no-emit runtime.
#
# Produces out/jak-project/out/ios/app/OttselShell.app (with KERNEL.CGO
# bundled as a resource) for the iPad Pro 11-inch (M4) Simulator.
#
# Layers:
#   1. SDL3 static for iphonesimulator arm64 (third-party/SDL via CMake)
#   2. runtime static lib: common (kernel subset) + game/kernel + sce +
#      mips2c table + ios_stubs, compiled with -DOTTSEL_NO_EMIT -DOTTSEL_IOS
#   3. the app: src/shell/main.cpp + src/shell/ios_boot.cpp
#   4. .app bundle + KERNEL.CGO resource + ad-hoc codesign
#
# Usage: scripts/build-ios.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKTREE="$REPO_DIR/out/jak-project"
SDL_SRC="$WORKTREE/third-party/SDL"
SDL_BUILD="$WORKTREE/out/ios/sdl"
APP_BUILD="$WORKTREE/out/ios/app"
OBJ="$APP_BUILD/obj"
APP="$APP_BUILD/OttselShell.app"

SDK=iphonesimulator26.5
TARGET=arm64-apple-ios18.5-simulator
DEPLOY=18.5
SDKROOT="$(xcrun --sdk "$SDK" --show-sdk-path)"

COMMON_FLAGS=(-std=c++20 -O2 -fno-omit-frame-pointer -D_CRT_SECURE_NO_WARNINGS -D_XOPEN_SOURCE \
  -DOTTSEL_NO_EMIT -DOTTSEL_IOS \
  -target "$TARGET" -isysroot "$SDKROOT" -mios-version-min="$DEPLOY")
INCS=(-I"$WORKTREE" \
  -I"$WORKTREE/third-party/fmt/include" \
  -I"$WORKTREE/third-party/fmt/src" \
  -I"$WORKTREE/third-party/json" \
  -I"$WORKTREE/third-party/replxx/include" \
  -I"$WORKTREE/third-party/lzokay" \
  -I"$WORKTREE/third-party/tree-sitter/lib/include" \
  -I"$WORKTREE/third-party/tinyfiledialogs" \
  -I"$SDL_SRC/include")
FRAMEWORKS=(-framework UIKit -framework Foundation -framework CoreGraphics \
  -framework QuartzCore -framework Metal -framework AudioToolbox \
  -framework CoreHaptics -framework CoreMotion -framework AVFoundation \
  -framework GameController -framework CoreText -framework ImageIO \
  -framework UniformTypeIdentifiers -framework CoreBluetooth \
  -framework CoreMedia -framework CoreVideo -framework OpenGLES \
  -framework VideoToolbox -framework CoreImage -framework Vision \
  -framework MetalKit)

compile() {
  local src="$1" out="$2"
  xcrun --sdk "$SDK" clang++ "${COMMON_FLAGS[@]}" "${INCS[@]}" -c "$src" -o "$out"
}

compile_objc() {
  local src="$1" out="$2"
  xcrun --sdk "$SDK" clang++ "${COMMON_FLAGS[@]}" -fobjc-arc \
    "${INCS[@]}" -c "$src" -o "$out"
}

echo "== [1/4] SDL3 static (iOS Simulator) =="
if [ ! -f "$SDL_BUILD/libSDL3.a" ]; then
  cmake -S "$SDL_SRC" -B "$SDL_BUILD" -G Ninja \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$SDK" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOY" \
    -DCMAKE_BUILD_TYPE=Release \
    -DSDL_SHARED=OFF -DSDL_STATIC=ON \
    -DSDL_TEST_LIBRARY=OFF -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF -DSDL_INSTALL=OFF
fi
ninja -C "$SDL_BUILD" 2>&1 | tail -1

echo "== [2/4] runtime static lib (no-emit, OTTSEL_IOS) =="
mkdir -p "$OBJ"

COMMON_SRC="
  common/cross_sockets/XSocket.cpp
  common/cross_sockets/XSocketClient.cpp
  common/cross_sockets/XSocketServer.cpp
  common/cross_os_debug/xdbg.cpp
  common/global_profiler/GlobalProfiler.cpp
  common/log/log.cpp
  common/util/Assert.cpp
  common/util/BitUtils.cpp
  common/util/crc32.cpp
  common/util/dgo_util.cpp
  common/util/diff.cpp
  common/util/FileUtil.cpp
  common/util/font/dbs/font_db_jak1.cpp
  common/util/font/dbs/font_db_jak2.cpp
  common/util/font/dbs/font_db_jak3.cpp
  common/util/font/dbs/font_db_jakx.cpp
  common/util/font/font_utils.cpp
  common/util/font/font_utils_korean.cpp
  common/util/json_util.cpp
  common/util/os.cpp
  common/util/string_util.cpp
  common/util/Timer.cpp
  common/util/unicode_util.cpp
  common/versions/versions.cpp
"
KERNEL_SRC="
  game/kernel/common/fileio.cpp
  game/kernel/common/kboot.cpp
  game/kernel/common/kdgo.cpp
  game/kernel/common/kdsnetm.cpp
  game/kernel/common/klink.cpp
  game/kernel/common/klisten.cpp
  game/kernel/common/kmachine.cpp
  game/kernel/common/kmalloc.cpp
  game/kernel/common/kmemcard.cpp
  game/kernel/common/kprint.cpp
  game/kernel/common/kscheme.cpp
  game/kernel/common/ksocket.cpp
  game/kernel/common/ksound.cpp
  game/kernel/jak1/fileio.cpp
  game/kernel/jak1/kboot.cpp
  game/kernel/jak1/kdgo.cpp
  game/kernel/jak1/klink.cpp
  game/kernel/jak1/klisten.cpp
  game/kernel/jak1/kmachine.cpp
  game/kernel/jak1/kprint.cpp
  game/kernel/jak1/kscheme.cpp
  game/kernel/jak1/ksound.cpp
  game/mips2c/mips2c_table.cpp
  game/mips2c/jak1_functions/bones.cpp
  game/mips2c/jak1_functions/collide_cache.cpp
  game/mips2c/jak1_functions/collide_edge_grab.cpp
  game/mips2c/jak1_functions/collide_func.cpp
  game/mips2c/jak1_functions/collide_mesh.cpp
  game/mips2c/jak1_functions/collide_probe.cpp
  game/mips2c/jak1_functions/draw_string.cpp
  game/mips2c/jak1_functions/generic_effect.cpp
  game/mips2c/jak1_functions/generic_effect2.cpp
  game/mips2c/jak1_functions/generic_merc.cpp
  game/mips2c/jak1_functions/generic_tie.cpp
  game/mips2c/jak1_functions/joint.cpp
  game/mips2c/jak1_functions/merc_blend_shape.cpp
  game/mips2c/jak1_functions/ocean.cpp
  game/mips2c/jak1_functions/ocean_vu0.cpp
  game/mips2c/jak1_functions/ripple.cpp
  game/mips2c/jak1_functions/shadow.cpp
  game/mips2c/jak1_functions/sky_tng.cpp
  game/mips2c/jak1_functions/sparticle.cpp
  game/mips2c/jak1_functions/sparticle_launcher.cpp
  game/mips2c/jak1_functions/test_func.cpp
  game/mips2c/jak1_functions/texture.cpp
  game/mips2c/jak1_functions/tfrag.cpp
  game/mips2c/jak1_functions/tie_methods.cpp
  game/mips2c/jak1_functions/time_of_day.cpp
  game/sce/deci2.cpp
  game/sce/libcdvd_ee.cpp
  game/sce/libdma.cpp
  game/sce/libgraph.cpp
  game/sce/libpad.cpp
  game/sce/libscf.cpp
  game/sce/sif_ee.cpp
  game/sce/sif_ee_memcard.cpp
  game/sce/stubs.cpp
  game/system/Deci2Server.cpp
  game/ios_stubs.cpp
  third-party/fmt/src/format.cc
  third-party/fmt/src/os.cc
  third-party/lzokay/lzokay.cpp
  game/kernel/asm_funcs_arm64.s
"

OBJS=()
for src in $COMMON_SRC $KERNEL_SRC; do
  name="$(echo "$src" | tr '/' '_' | sed 's/\.\(cpp\|cc\|s\)$/.o/')"
  compile "$WORKTREE/$src" "$OBJ/$name"
  OBJS+=("$OBJ/$name")
done

ar rcs "$APP_BUILD/libottsel-runtime.tmp.a" "${OBJS[@]}"
mv -f "$APP_BUILD/libottsel-runtime.tmp.a" "$APP_BUILD/libottsel-runtime.a"
echo "runtime lib: $APP_BUILD/libottsel-runtime.a ($((${#OBJS[@]})) objects)"

echo "== [3/4] compile + link app =="
SLICE_DIR="$APP_BUILD/a11-slice"
mkdir -p "$SLICE_DIR"
echo "== [3a/4] generate A1.1 slice (offline linker) =="
"$WORKTREE/build/h1/goalc/ottsel-a11-slice" "$SLICE_DIR"
xcrun --sdk "$SDK" clang "${COMMON_FLAGS[@]}" -c "$SLICE_DIR/slice.s" -o "$OBJ/a11_slice.o"
compile "$REPO_DIR/src/shell/main.cpp" "$OBJ/shell_main.o"
compile "$REPO_DIR/src/shell/ios_boot.cpp" "$OBJ/ios_boot.o"
compile_objc "$REPO_DIR/src/shell/metal_shell.mm" "$OBJ/metal_shell.o"
xcrun --sdk "$SDK" clang++ "${COMMON_FLAGS[@]}" -fobjc-arc \
  "${INCS[@]}" -I"$SLICE_DIR" -c "$REPO_DIR/src/shell/a11_slice_runner.mm" -o "$OBJ/a11_slice_runner.o"

xcrun --sdk "$SDK" clang++ "${COMMON_FLAGS[@]}" \
  "$OBJ/shell_main.o" "$OBJ/ios_boot.o" "$OBJ/metal_shell.o" \
  "$OBJ/a11_slice_runner.o" "$OBJ/a11_slice.o" \
  -I"$SLICE_DIR" \
  "$APP_BUILD/libottsel-runtime.a" "$SDL_BUILD/libSDL3.a" \
  "${FRAMEWORKS[@]}" -lobjc \
  -o "$APP_BUILD/OttselShell"

echo "== [4/4] assemble + sign bundle =="
mkdir -p "$APP"
cp "$APP_BUILD/OttselShell" "$APP/"
cp "$REPO_DIR/src/shell/Info.plist" "$APP/"
cp "$WORKTREE/out/jak1/iso/KERNEL.CGO" "$APP/KERNEL.CGO"
cp "$WORKTREE/out/jak1/iso/GAME.CGO" "$APP/GAME.CGO"
plutil -lint "$APP/Info.plist" >/dev/null
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "OK: $APP"
ls -la "$APP"
