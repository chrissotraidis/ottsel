#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_output_dir="${1:-/tmp/ottsel-recovery-2026-09-12}"
mkdir -p "$test_output_dir"
xcrun --sdk macosx clang++ -std=c++17 -Wall -Wextra -Werror \
  "$repo_root/test/mobile_resource_retirement_test.cpp" \
  -o "$test_output_dir/mobile_resource_retirement_test"
"$test_output_dir/mobile_resource_retirement_test"
