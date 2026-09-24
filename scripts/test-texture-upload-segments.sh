#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${1:-/tmp/ottsel-recovery-2026-09-12}
mkdir -p "$output_dir"
python3 - "$repo" "$output_dir" <<'PY'
import hashlib
from pathlib import Path
import sys
root, output = map(Path, sys.argv[1:])
source = (root / 'src/shell/metal_gfx.mm').read_text()
start = source.index('struct OttselGoalTexture {')
end = source.index('// The runtime\'s EE memory base', start)
structs = source[start:end]
start = source.index('    OttselGoalTexturePage upload_page;')
end = source.index('    if (direct_uploads) {', start)
registration = source[start:end]
for name, body in [('texture_upload_structs.inc', structs),
                   ('texture_upload_registration.inc', registration)]:
    (output / name).write_text(body)
    print(name + ' sha256=' + hashlib.sha256(body.encode()).hexdigest(), flush=True)
PY
c++ -std=c++17 -Wall -Wextra -Werror -O2 -I "$output_dir" \
  "$repo/test/texture_upload_segments_test.cpp" -o "$output_dir/texture_upload_segments_test"
"$output_dir/texture_upload_segments_test"
