#!/bin/bash
# Ottsel S1.2 — build the iOS Simulator app shell.
#
# Produces out/ios/OttselShell.app (relative to the OpenGOAL worktree at
# out/jak-project) for the iPad Pro 11-inch (M4) Simulator.
#
# Builds (idempotently):
#   1. SDL3 static for iphonesimulator arm64 (third-party/SDL via CMake)
#   2. the shell app: src/shell/main.cpp + Info.plist -> .app bundle
#
# Usage: scripts/build-ios-shell.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKTREE="$REPO_DIR/out/jak-project"
SDL_SRC="$WORKTREE/third-party/SDL"
SDL_BUILD="$WORKTREE/out/ios/sdl"
APP_BUILD="$WORKTREE/out/ios/app"
APP="$APP_BUILD/OttselShell.app"

SDK=iphonesimulator26.5
TARGET=arm64-apple-ios18.5-simulator
DEPLOY=18.5

echo "== [1/3] SDL3 static (iOS Simulator) =="
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

echo "== [2/3] compile shell =="
mkdir -p "$APP_BUILD"
SYSROOT="$(xcrun --sdk "$SDK" --show-sdk-path)"
INCS=(-I"$SDL_SRC/include")
FRAMEWORKS=(-framework UIKit -framework Foundation -framework CoreGraphics \
  -framework QuartzCore -framework Metal -framework AudioToolbox \
  -framework CoreHaptics -framework CoreMotion -framework AVFoundation \
  -framework GameController -framework CoreText -framework ImageIO \
  -framework UniformTypeIdentifiers -framework CoreBluetooth \
  -framework CoreMedia -framework CoreVideo -framework OpenGLES \
  -framework VideoToolbox -framework CoreImage -framework Vision \
  -framework MetalKit)

xcrun --sdk "$SDK" clang++ -std=c++17 -O2 -target "$TARGET" \
  -isysroot "$SYSROOT" -mios-version-min="$DEPLOY" \
  "${INCS[@]}" \
  -c "$REPO_DIR/src/shell/main.cpp" -o "$APP_BUILD/main.o"

xcrun --sdk "$SDK" clang++ -target "$TARGET" -isysroot "$SYSROOT" \
  -mios-version-min="$DEPLOY" \
  "$APP_BUILD/main.o" "$SDL_BUILD/libSDL3.a" \
  "${FRAMEWORKS[@]}" -lobjc \
  -o "$APP_BUILD/OttselShell"

echo "== [3/3] assemble + sign bundle =="
mkdir -p "$APP"
cp "$APP_BUILD/OttselShell" "$APP/"
cp "$REPO_DIR/src/shell/Info.plist" "$APP/"
plutil -lint "$APP/Info.plist" >/dev/null
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "OK: $APP"
file "$APP/OttselShell"
