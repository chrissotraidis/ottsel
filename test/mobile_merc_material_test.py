#!/usr/bin/env python3
"""Actual MERC effect-mask transport and single-pass material policy regression."""
from pathlib import Path
import re, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
g = (root/'src/shell/metal_gfx.mm').read_text()
s = (root/'src/shell/metal_shell.mm').read_text()
header = root/'src/shell/metal_shell.h'
# Execute actual producer and draw material initialization; numeric controls
# independently expect the selected effect bit and desktop single-pass policy.
a=g.index('      draws.push_back({index_offset, native_index_count,',g.index('bool capture_mobile_merc('))
b=g.index(';',a)+1
push=g[a:b]
a=s.index('      TieMaterial material{alpha_min, 10.f,')
b=s.index(';',a)+1
material=s[a:b]
condition=re.search(r'if \((!?merc_mesh && )?alpha_test && alpha_test_kind == 2 && alpha_fail == 1 &&\s*source_depth_write_enabled\)',s).group()[4:-1]
code='''#include <cstdint>
#include <string>
#include <vector>
#include <functional>
#include <cstdio>
using u32=uint32_t;using u64=uint64_t;
__DRAW_ABI__
__MATERIAL_ABI__
int ottsel_mobile_scene_texture_slot(u32 base,int id){return base+id;}
int main(){int failures=0;for(unsigned effect_index: {0u,5u,63u})for(bool ignored:{false,true}){
struct {u64 ignore_alpha_mask;} flags{ignored?(u64(1)<<effect_index):(u64(1)<<((effect_index+1)%64))};
const u32 index_offset=3,native_index_count=6,texture_base=100;
struct Mode{u32 as_int()const{return 0;}};struct {int tree_tex_id;Mode mode;}source_draw{7,{}};
std::string name="eichar-lod0";std::vector<OttselMetalTieDraw>draws;
'''+push+'''
const auto& draw=draws.front();const float alpha_min=.75f;bool fog_enable=false,decal=false,merc_mesh=true;
'''+material+'''
if(material.merc_ignore_alpha!=unsigned(ignored)||draw.texture_index!=107)++failures;
bool alpha_test=true;unsigned alpha_test_kind=2,alpha_fail=1;bool source_depth_write_enabled=true;
if('''+condition+''')++failures;
merc_mesh=false;if(!('''+condition+'''))++failures;
}std::printf("actual producer/material transport and second-pass isolation failures=%d\\n",failures);return failures?1:0;}
'''

material_abi = re.search(r'^struct TieMaterial \{.*?^};', s, re.M | re.S).group()
code = code.replace('__DRAW_ABI__', '#include "'+str(header)+'"').replace('__MATERIAL_ABI__', material_abi)
with tempfile.TemporaryDirectory(prefix='ottsel-merc-material-') as output:
    out = Path(output)
    (out/'transport.cpp').write_text(code)
    subprocess.run(['xcrun', '--sdk', 'macosx', 'clang++', '-std=c++17',
                    str(out/'transport.cpp'), '-o', str(out/'transport')], check=True)
    subprocess.run([str(out/'transport')], check=True)
