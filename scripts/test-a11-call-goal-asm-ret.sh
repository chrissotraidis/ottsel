#!/bin/bash
# Ottsel A1.1 regression runner: the C->GOAL bridge must give IR_AsmRet-style
# asm-funcs a synthetic return slot on the GOAL stack.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
output="${1:-/tmp/ottsel-a11-call-goal-asm-ret}"
mkdir -p "$output"
xcrun --sdk macosx clang++ -arch arm64 -std=c++20 -O1 -Wall -Wextra \
  "$repo/test/a11_call_goal_asm_ret_test.cpp" \
  "$repo/out/jak-project/game/kernel/asm_funcs_arm64.s" \
  -o "$output/a11-call-goal-asm-ret"
"$output/a11-call-goal-asm-ret"

