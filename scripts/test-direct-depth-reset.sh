#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_output_dir="${1:-/tmp/ottsel-recovery-2026-09-12}"
mkdir -p "$test_output_dir"
python3 - "$repo_root" "$test_output_dir/direct_depth_reset.inc" <<'PY'
import hashlib
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
gfx = (root / 'src/shell/metal_gfx.mm').read_text()
desktop = (root / 'out/jak-project/game/graphics/opengl_renderer/DirectRenderer.h').read_text()
gs = (root / 'out/jak-project/common/dma/gs.h').read_text()

def braced(source, marker):
    start = source.index(marker)
    opening = source.index('{', start)
    depth, end = 1, opening + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    return source[start:end]

types = '\n'.join([braced(gs, 'struct GsTest {') + ';',
                    braced(desktop, 'struct TestState {') + ';',
                    braced(gfx, 'struct OttselDrawState {') + ';'])
ad = braced(gfx, 'void handle_ad(u64 value, u8 addr) {')
cases = ''
for name in ['TEST_1', 'ZBUF_1']:
    start = ad.index('case GsRegisterAddress::' + name + ':')
    end = ad.index('break;', start) + len('break;')
    cases += ad[start:end] + '\n'
capture = gfx[gfx.index('primitive.depth = {st.test, st.zbuf};'):]
capture = capture[:capture.index(';') + 1]
actual = (types + '\nvoid write_ad(OttselDrawState& st, GsRegisterAddress addr, u64 value) {\n'
          + 'switch(addr) {\n' + cases + '} }\n'
          + 'OttselMetalDirectDepthState capture_depth(const OttselDrawState& st) {\n'
          + 'struct { OttselMetalDirectDepthState depth; } primitive;\n'
          + capture + '\nreturn primitive.depth; }\n')
pathlib.Path(sys.argv[2]).write_text(actual)
print('actual reset/write/capture source sha256=' + hashlib.sha256(actual.encode()).hexdigest(), flush=True)
PY
xcrun --sdk macosx clang++ -std=c++17 -Wall -Wextra -Werror \
  -I "$test_output_dir" "$repo_root/test/direct_depth_reset_test.cpp" \
  -o "$test_output_dir/direct_depth_reset_test"
"$test_output_dir/direct_depth_reset_test"
