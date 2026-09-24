#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_output_dir="${1:-/tmp/ottsel-recovery-2026-09-12}"
mkdir -p "$test_output_dir"
python3 - "$repo_root" "$test_output_dir" <<'PY'
from pathlib import Path
import hashlib, sys
root, output = map(Path, sys.argv[1:])
source = (root / 'src/shell/metal_gfx.mm').read_text()
types = source[source.index('struct DirectTextureMetadata {'):source.index('// Source texture-page descriptors')]
start = source.index('void gfx_texture_relocate(')
function = source[start:source.index('void gfx_set_levels(', start)]
(output / 'texture_relocation_types.inc').write_text(types)
(output / 'texture_relocation_function.inc').write_text(function)
print('actual relocation sha256=' + hashlib.sha256((types + function).encode()).hexdigest())
PY
xcrun --sdk macosx clang++ -std=c++17 -Wall -Wextra -Werror \
  -I "$test_output_dir" "$repo_root/test/texture_relocation_test.cpp" \
  -o "$test_output_dir/texture_relocation_test"
"$test_output_dir/texture_relocation_test"
