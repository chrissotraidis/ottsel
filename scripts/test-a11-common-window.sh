#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_dir="$repo_root/out/jak-project"
simulator=false
sdk=macosx
target_flags=(-arch arm64)
default_output=/tmp/ottsel-recovery-2026-09-12/a11-common-window
# --simulator compiles/signs only. The single-Simulator owner must run it.
if [ "${1:-}" = --simulator ]; then
  simulator=true
  shift
  sdk=iphonesimulator26.5
  target_flags=(-target arm64-apple-ios18.5-simulator -mios-version-min=18.5)
  default_output+=-simulator
fi
output_dir="${1:-$default_output}"
mkdir -p "$output_dir"
# Virtual 128MiB zero-fill does not produce a 128MiB worktree file. Place the
# arena before a separate signed executable segment; never mmap MAP_FIXED.
{
  cat <<'ASM'
.globl _ottsel_window_arena
.zerofill __ARENA,__zero,_ottsel_window_arena,134217728,14
.section __GOAL,__text,regular,pure_instructions
.balign 8
.long 0x00140004
.globl _ottsel_window_add2
_ottsel_window_add2:
ASM
  # Exact retained compiler-emitted H2.5 GOAL add2 instructions.
  sed -n '/^[[:space:]]*\.word /p' "$repo_root/docs/evidence/H2.5/add2.s"
} > "$output_dir/window.s"
xcrun --sdk "$sdk" clang++ "${target_flags[@]}" \
  -isysroot "$(xcrun --sdk "$sdk" --show-sdk-path)" -std=c++20 -O2 -Wall -Wextra \
  -I"$source_dir" -I"$source_dir/third-party/fmt/include" \
  "$repo_root/test/a11_common_window_test.cpp" "$output_dir/window.s" \
  "$source_dir/game/kernel/asm_funcs_arm64.s" \
  -Wl,-segprot,__ARENA,rw,rw -Wl,-segprot,__GOAL,rx,rx \
  -o "$output_dir/a11_common_window_test"
[ "$(stat -f%z "$output_dir/a11_common_window_test")" -lt 100000000 ]
codesign --force --sign - "$output_dir/a11_common_window_test"
codesign --verify --strict "$output_dir/a11_common_window_test"
xcrun otool -l "$output_dir/a11_common_window_test" > "$output_dir/load-commands.txt"
if $simulator; then
  echo "Simulator fixture compiled and signed: $output_dir/a11_common_window_test"
  echo "No Simulator execution performed. Root may use simctl spawn on its existing device."
else
  "$output_dir/a11_common_window_test"
fi
