#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_output_dir="${1:-/tmp/ottsel-recovery-2026-09-12}"
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
fixture = shell.index('struct DirectFixtureVertex {')
vertex_type = gfx.index('struct OttselVertex {')
capture = gfx.index('OttselMetalSpriteVertex vertex{};', gfx.index('const float x_off = rst ?'))
capture_end = gfx.index('// I1.1b diagnostic: report the texel', capture)
actual = (shell[start:end] + shell[fixture:shell.index('\n};', fixture) + 3] + '\n'
          + gfx[vertex_type:gfx.index('\n};', vertex_type) + 3] + '\n'
          + 'OttselMetalSpriteVertex capture_vertex(const OttselVertex& source, float x, float y) {\n'
          + 'const float nx=(x+1.f)*0.5f, ny=(1.f-y)*0.5f;\n'
          + 'const unsigned int texture_width=1, texture_height=1;\n'
          + 'struct Prim { bool fst() const { return false; } } gp;\n'
          + gfx[capture:capture_end] + '\nreturn vertex; }\n')
layout = shell.index('MTLVertexDescriptor* directLayout =')
layout_end = shell.index('MTLRenderPipelineDescriptor* directPd =', layout)
(output / 'direct_depth_source.inc').write_text(actual)
(output / 'direct_depth_layout.inc').write_text(shell[layout:layout_end])
print('actual Direct depth CPU/shader source sha256=' + hashlib.sha256(actual.encode()).hexdigest(), flush=True)
PY
xcrun --sdk macosx clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Werror \
  -I "$test_output_dir" "$repo_root/test/metal_direct_depth_test.mm" \
  -framework Foundation -framework Metal -o "$test_output_dir/metal_direct_depth_test"
"$test_output_dir/metal_direct_depth_test"
