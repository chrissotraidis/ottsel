#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir=${1:-/tmp/ottsel-recovery-2026-09-12/multilevel-test}
mkdir -p "$output_dir"
python3 - "$repo" "$output_dir" <<'PY'
import hashlib
import re
from pathlib import Path
import sys
root, output = map(Path, sys.argv[1:]); gfx=(root/'src/shell/metal_gfx.mm').read_text(); shell=(root/'src/shell/metal_shell.mm').read_text()
def balanced(text,start):
 first=text.index('{',start); depth=1;end=first+1
 while depth:
  depth+=(text[end]=='{')-(text[end]=='}');end+=1
 return text[start:end]
parts={'mobile_level_state.inc':gfx[gfx.index('std::string g_mobile_tie_level;'):gfx.index('std::array<float, 4> g_mobile_fog_color')]}
for family in ['Tfrag','Tie']:
 for kind in ['Mesh','Colors']:
  start=shell.index('- (void)set'+family+kind+':',shell.index('@implementation'))
  queue='_pending'+('Mesh' if kind=='Mesh' else 'Color')+'Uploads'
  start=shell.index('    '+queue+'.erase(',start)
  end=shell.index('    '+queue+'.push_back(std::move(upload));',start)+len('    '+queue+'.push_back(std::move(upload));')
  parts['mobile_level_queue_'+family.lower()+'_'+kind.lower()+'.inc']=shell[start:end]
start=shell.index('- (void)setMeshNow:',shell.index('@implementation'));start=shell.index('  auto& installed =',start)
parts['mobile_level_install.inc']=shell[start:shell.index('  NSLog(',start)]
for method in ['beginSceneFrame','referenceScene','publishSceneFrame']:
 start=shell.index('- (void)'+method,shell.index('@implementation'));block=balanced(shell,start)
 parts['mobile_level_'+method+'.inc']=block[block.index('{')+1:-1]
start=shell.index('- (void)setColorsNow:',shell.index('@implementation'));start=shell.index('  _sceneStagingMeshes[',start)
parts['mobile_level_colors.inc']=shell[start:shell.index('\n}',start)]
start=gfx.index('  const bool tfrag_bucket =',gfx.index('void capture_mobile_camera'))
parts['mobile_level_bucket.inc']=gfx[start:gfx.index('  if (!finite)',start)]
# Check the actual adapter: the generic camera pass has no emitting owner;
# the bounded bucket walker supplies it and one completed chain publishes once.
chain=gfx[gfx.index('void gfx_send_chain'):gfx.index('// Read the tpage id back out')]
assert chain.count('ottsel_metal_begin_scene_frame(g_metal);') == 1
assert chain.count('ottsel_metal_publish_scene_frame(g_metal);') == 1
assert chain.count('capture_mobile_camera(t.data, t.size_bytes, (int)bucket_id);') == 1
assert 'if (!tfrag_bucket && !tie_bucket) return;' in gfx
assert 'mesh.draws, true, false, ref.uniforms' in shell
assert 'mesh.draws, false, false, ref.uniforms' in shell
start=shell.index('- (void)drainSceneFrame {')
block=balanced(shell,start); body=block[block.index('{')+1:-1]
# GPU allocations are host spies; all production lock, preparation, dependency
# checks, promotion and transaction-retention code stays exact.
body,n=re.subn(r'\[self setMeshNow:upload.vertices.data\(\).*?level:upload.level.c_str\(\)\];',
    'install(upload.level.c_str(), upload.tfrag, fail_mesh_allocation ? 0 : upload.geometry_token);',body,flags=re.S);assert n==1
body,n=re.subn(r'\[self setColorsNow:upload.rgba.data\(\).*?level:upload.level.c_str\(\)\];',
    'install_colors(upload.level.c_str(), upload.tfrag, fail_color_allocation ? 0 : upload.color_token);',body,flags=re.S);assert n==1
parts['mobile_level_drainSceneFrame.inc']=body
for name,body in parts.items():
 (output/name).write_text(body);print(name+' sha256='+hashlib.sha256(body.encode()).hexdigest())
PY
c++ -std=c++17 -Wall -Wextra -Werror -O2 -I "$output_dir" "$repo/test/mobile_level_ownership_test.cpp" -o "$output_dir/mobile_level_ownership_test"
"$output_dir/mobile_level_ownership_test"
