#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$repo_root/out/jak-project"
slice_dir="${OTTSEL_A11_SLICE_DIR:-$source_dir/out/ios/app/a11-slice}"
output_dir="${1:-/tmp/ottsel-recovery-2026-09-12/a11-static-export}"
for required in "$slice_dir/slice.s" "$slice_dir/a11_slice_map.h"; do
  if [ ! -s "$required" ]; then
    echo "Missing generated A1.1 artifact: $required" >&2
    exit 1
  fi
done
mkdir -p "$output_dir"
# Reassemble existing GOAL output for macOS; do not rebuild the emitter/runtime
# or run the iOS app. The runner and ABI assembly are actual current sources.
xcrun --sdk macosx clang -arch arm64 -c "$slice_dir/slice.s" -o "$output_dir/slice.o"
xcrun --sdk macosx clang -arch arm64 -c "$source_dir/game/kernel/asm_funcs_arm64.s" -o "$output_dir/abi.o"
xcrun --sdk macosx clang++ -arch arm64 -std=c++20 -O2 -fobjc-arc \
  -Wall -Wextra -I"$slice_dir" "$repo_root/src/shell/a11_slice_runner.mm" \
  "$repo_root/test/a11_static_export_test.mm" "$output_dir/slice.o" "$output_dir/abi.o" \
  -framework Foundation -o "$output_dir/a11_static_export_test"
codesign --force --sign - "$output_dir/a11_static_export_test"
codesign --verify --strict "$output_dir/a11_static_export_test"
shasum -a 256 "$slice_dir/slice.s" "$slice_dir/a11_slice_map.h" "$output_dir/a11_static_export_test"
"$output_dir/a11_static_export_test"
