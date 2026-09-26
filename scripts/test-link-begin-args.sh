#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${OTTSEL_SOURCE_DIR:-$ROOT/out/jak-project}"
OUTPUT="${OTTSEL_TEST_OUTPUT_DIR:-/tmp/ottsel-recovery-2026-09-12}"
mkdir -p "$OUTPUT"
xcrun --sdk macosx clang++ -std=c++17 -Wall -Wextra -I"$SOURCE" \
  "$ROOT/test/link_begin_args_test.cpp" -o "$OUTPUT/link_begin_args_test"
"$OUTPUT/link_begin_args_test"
