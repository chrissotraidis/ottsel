#!/bin/bash
# Ottsel G2.2 regression: the SkyBlend copy equation that composes the sky
# buffers the sky bucket's fans sample.  Host-only, no device or Simulator.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
output="${1:-/tmp/ottsel-mobile-sky-blend}"
mkdir -p "$output"
xcrun --sdk macosx clang++ -arch arm64 -std=c++20 -O1 -Wall -Wextra \
  -I"$repo/src/shell" \
  "$repo/test/mobile_sky_blend_test.cpp" -o "$output/mobile-sky-blend"
"$output/mobile-sky-blend"
