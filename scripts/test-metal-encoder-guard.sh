#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_output_dir="${1:-/tmp/ottsel-recovery-2026-09-12}"
mkdir -p "$test_output_dir"
xcrun --sdk macosx clang++ -std=c++17 -fobjc-arc -fexceptions -fobjc-exceptions \
  -Wall -Wextra -Werror "$repo_root/test/metal_encoder_guard_test.mm" \
  -framework Foundation -framework Metal -o "$test_output_dir/metal_encoder_guard_test"
"$test_output_dir/metal_encoder_guard_test"
