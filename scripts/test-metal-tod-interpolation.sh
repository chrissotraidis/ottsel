#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_output_dir="${1:-/tmp/ottsel-recovery-2026-09-12}"
mkdir -p "$test_output_dir"
python3 - "$repo_root/src/shell/metal_shell.mm" "$test_output_dir/tie_shader_source.inc" <<'PY'
import hashlib
import pathlib
import sys

source = pathlib.Path(sys.argv[1]).read_text()
start = source.index('NSString* kTieShaderSource = @""')
end = source.index('struct DirectFixtureVertex {', start)
actual_source = source[start:end]
pathlib.Path(sys.argv[2]).write_text(actual_source)
print('Actual shader and ABI source sha256=' + hashlib.sha256(actual_source.encode()).hexdigest(), flush=True)
PY
xcrun --sdk macosx clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Werror \
  -I "$test_output_dir" "$repo_root/test/metal_tod_interpolation_test.mm" \
  -framework Foundation -framework Metal -o "$test_output_dir/metal_tod_interpolation_test"
"$test_output_dir/metal_tod_interpolation_test"
