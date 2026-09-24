#!/bin/bash
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
bash "$script_dir/test-metal-direct-stq.sh" "${1:-/tmp/ottsel-recovery-2026-09-12}" --fst
