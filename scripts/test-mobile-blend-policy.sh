#!/bin/bash
# Ottsel G2.2 regression: the GS ALPHA -> blend-key decode that selects the
# native Sky/Direct pipeline.  Host-only, no device or Simulator needed.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
output="${1:-/tmp/ottsel-mobile-blend-policy}"
mkdir -p "$output"
xcrun --sdk macosx clang++ -arch arm64 -std=c++20 -O1 -Wall -Wextra \
  -I"$repo/src/shell" \
  "$repo/test/mobile_blend_policy_test.cpp" -o "$output/mobile-blend-policy"
"$output/mobile-blend-policy"
