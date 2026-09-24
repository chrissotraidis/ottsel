#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$repo_root/out/jak-project"
output_dir="${1:-/tmp/ottsel-recovery-2026-09-12/a11-relocations}"
mkdir -p "$output_dir"
xcrun --sdk macosx clang++ -std=c++20 -O2 -Wall -Wextra \
  -I"$source_dir/tools/ottsel_a1_1" "$repo_root/test/a11_relocation_test.cpp" \
  -o "$output_dir/a11_relocation_test"
"$output_dir/a11_relocation_test" \
  "$source_dir/out/ios/app/a11-slice/slice.obj" "$source_dir/out/jak1/obj/gstring.o"
