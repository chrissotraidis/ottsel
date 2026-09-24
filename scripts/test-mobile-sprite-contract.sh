#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-${TMPDIR:-/tmp}/ottsel-mobile-sprite-contract}"
mkdir -p "$output_dir"
python3 "$repo_root/test/mobile_sprite_contract_test.py" "$repo_root" "$output_dir"
