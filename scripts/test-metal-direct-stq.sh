#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_output_dir="${1:-/tmp/ottsel-recovery-2026-09-12}"
if [ "$#" -gt 0 ]; then shift; fi
mkdir -p "$test_output_dir"
python3 - "$repo_root" "$test_output_dir" <<'PY'
import hashlib
import pathlib
import sys

root, output = map(pathlib.Path, sys.argv[1:])
shell = (root / 'src/shell/metal_shell.mm').read_text()
gfx = (root / 'src/shell/metal_gfx.mm').read_text()
start = shell.index('NSString* kDirectFixtureShaderSource = @""')
end = shell.index('NSString* kTieShaderSource = @""', start)
fixture_start = shell.index('struct DirectFixtureVertex {')
fixture_end = shell.index('\n};', fixture_start) + 3
shader = shell[start:end] + shell[fixture_start:fixture_end]
layout_start = shell.index('MTLVertexDescriptor* directLayout =')
layout_end = shell.index('MTLRenderPipelineDescriptor* directPd =', layout_start)
vertex_start = gfx.index('OttselMetalSpriteVertex vertex{};', gfx.index('const float x_off = rst ?'))
uv_start = gfx.index('if (source.has_uv || source.has_st) {', vertex_start)
uv_end = gfx.index('vertex.color[0]', uv_start)
pieces = {'direct_shader_source.inc': shader,
          'direct_vertex_layout.inc': shell[layout_start:layout_end],
          'direct_uv_mapping.inc': gfx[uv_start:uv_end]}
for name, source in pieces.items():
    (output / name).write_text(source)
    print(name + ' sha256=' + hashlib.sha256(source.encode()).hexdigest(), flush=True)
PY
xcrun --sdk macosx clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Werror \
  -I "$test_output_dir" "$repo_root/test/metal_direct_stq_test.mm" \
  -framework Foundation -framework Metal -o "$test_output_dir/metal_direct_stq_test"
"$test_output_dir/metal_direct_stq_test" "$@"
