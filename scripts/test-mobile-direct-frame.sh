#!/bin/bash
set -eu
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/ottsel-direct-frame.XXXXXX")"
trap 'rm -rf "$work"' EXIT
xcrun clang++ -std=c++17 -I "$repo_root/src/shell" "$repo_root/test/mobile_direct_frame_test.cpp" -o "$work/test"
"$work/test"
python3 - "$repo_root" <<'PYCODE'
from pathlib import Path
import sys
root=Path(sys.argv[1]);shell=(root/'src/shell/metal_shell.mm').read_text();gfx=(root/'src/shell/metal_gfx.mm').read_text()
assert '_directFrameStore.begin();' in shell and '_directFrameStore.publish();' in shell
assert '_directFrameStore.append(batch);' in shell and '_directFrameStore.snapshot();' in shell
assert 'direct_snapshot.retired.begin()' in shell and 'direct_snapshot.retired.end()' in shell
assert '_directBatches.erase_tags' not in shell and 'native_direct_product_vsync' not in gfx
assert '[self recycleVertexBuffers:frame_vertex_buffers after:cb];' in shell
print('PASS actual renderer begins/publishes/replays Direct frames and retires via captured command buffer')
PYCODE
