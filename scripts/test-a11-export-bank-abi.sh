#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
original="${2:-$repo_root}"
source_dir="$original/out/jak-project"
staged_source="$repo_root/out/jak-project"
output_dir="${1:-/tmp/ottsel-recovery-2026-09-12/a11-export-bank-abi}"
mkdir -p "$output_dir"
# Existing maintained actual-bootstrap source extraction and prefix control.
bash "$original/scripts/test-a11-bootstrap-identity.sh" "$output_dir"
python3 "$repo_root/scripts/emit-signed-export-banks.py" "$output_dir/banks.s"
xcrun --sdk macosx clang++ -arch arm64 -std=c++20 -O2 -Wall -Wextra -DFMT_HEADER_ONLY \
  -DOTTSEL_SIGNED_EXPORT_BANKS -I"$staged_source" -I"$source_dir" \
  -I"$source_dir/third-party/fmt/include" -I"$original/test" -I"$output_dir" \
  "$repo_root/test/a11_export_bank_abi_test.cpp" \
  "$staged_source/game/kernel/common/ottsel_signed_exports.cpp" \
  "$source_dir/game/kernel/common/kmalloc.cpp" \
  "$output_dir/bootstrap.s" "$output_dir/banks.s" \
  "$repo_root/test/a11_export_bank_driver.s" "$source_dir/game/kernel/asm_funcs_arm64.s" \
  -Wl,-segprot,__ARENA,rw,rw -Wl,-segprot,__GOAL,rx,rx -o "$output_dir/a11_export_bank_abi_test"
[ "$(stat -f%z "$output_dir/a11_export_bank_abi_test")" -lt 100000000 ]
codesign --force --sign - "$output_dir/a11_export_bank_abi_test"
codesign --verify --strict "$output_dir/a11_export_bank_abi_test"
"$output_dir/a11_export_bank_abi_test"
