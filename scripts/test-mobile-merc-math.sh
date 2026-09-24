#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${1:-/tmp/ottsel-recovery-2026-09-12}
mkdir -p "$output_dir"
c++ -std=c++17 -Wall -Wextra -Werror -O2 "$repo/tools/mobile_merc_math_test.cpp" \
  -o "$output_dir/mobile_merc_math_test"
"$output_dir/mobile_merc_math_test"
