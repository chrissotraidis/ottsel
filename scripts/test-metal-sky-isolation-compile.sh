#!/bin/bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
output="${1:-/tmp/ottsel-recovery-2026-09-12/sky-isolation-compile}"
mkdir -p "$output"
python3 - "$repo_root" "$output" <<'PY'
from pathlib import Path
import hashlib,json,sys
root,out=map(Path,sys.argv[1:]);shell=(root/'src/shell/metal_shell.mm').read_text();probe=(root/'src/shell/metal_sky_isolation.h').read_text()
a=shell.index('NSString* kDirectFixtureShaderSource = @""');b=shell.index('NSString* kTieShaderSource = @""',a)
c=shell.index('struct DirectFixtureVertex {');d=shell.index('\n};',c)+3
source=shell[a:b]+shell[c:d]
a=probe.index('NSString* extra=');b=probe.index('    NSError* error=',a);extra=probe[a:b]
a=shell.index('MTLVertexDescriptor* directLayout =');b=shell.index('  self.directPipeline =',a);descriptor=shell[a:b]
a=shell.index('MTLRenderPipelineDescriptor* directBlendPd =');b=shell.index('  self.directBlendPipeline =',a);descriptor+=shell[a:b]
a=probe.index('NSArray<NSString*>* names=');b=probe.index('\n',a);names=probe[a:b]
pieces={'sky_isolation_source.inc':source,'sky_isolation_extra.inc':extra,'sky_isolation_descriptors.inc':descriptor,'sky_isolation_names.inc':names}
for name,text in pieces.items():(out/name).write_text(text)
(out/'source-sha256.json').write_text(json.dumps({name:hashlib.sha256(text.encode()).hexdigest() for name,text in pieces.items()},indent=2)+'\n')
PY
xcrun --sdk macosx clang++ -std=c++17 -fobjc-arc -Wall -Wextra -Werror \
 -I "$output" "$repo_root/test/metal_sky_isolation_compile_test.mm" \
 -framework Foundation -framework Metal -o "$output/metal_sky_isolation_compile_test"
"$output/metal_sky_isolation_compile_test"
