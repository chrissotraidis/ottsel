from pathlib import Path
import sys,subprocess
root=Path(sys.argv[1]).resolve();source=Path(sys.argv[2]).read_text();out=Path(sys.argv[3]);out.mkdir(parents=True,exist_ok=True)
def block(name):
 a=source.index(name);p=source.index('{',a);i=p+1;d=1
 while d:d+=(source[i]=='{')-(source[i]=='}');i+=1
 return source[a:i]
a=source.index('  std::vector<tfrag3::PreloadedVertex> vertices(level->merc_data.vertices.size());');b=source.index('  if (name == "eichar-lod0")',a);capture=source[a:b]
light_read='  '+source[source.index('memcpy(&lights, setup.data + 128'):source.index('memcpy(&lights, setup.data + 128')+len('memcpy(&lights, setup.data + 128, sizeof(lights));')]
assert 'index >= lighting_valid.size() || !lighting_valid[index]' in source
assert source.count('lit_colors.front().data()')==2
code='''#include <array>
#include <vector>
#include <cstdint>
#include <cstring>
#include <cassert>
#include <cmath>
#include <cstdio>
#include "mobile_merc_math.h"
#include "mobile_merc_lighting.h"
using u8=uint8_t;using u32=uint32_t;
namespace tfrag3{struct PreloadedVertex{float x,y,z;u8 r,g,b,a;float s,t;u32 nor;uint16_t color_index;};}
struct Source{float x,y,z;float normal[3],weights[3],st[2];u8 rgba[4],mats[3];};
struct Level{struct{std::vector<Source>vertices;}merc_data;};
'''+block('struct MobileMercMatrix')+';\n'+'''
int main(){Level storage;Level*level=&storage;level->merc_data.vertices.resize(2);for(auto&v:level->merc_data.vertices){v.x=1;v.y=2;v.z=3;v.normal[2]=1;v.weights[0]=1;v.rgba[0]=v.rgba[1]=v.rgba[2]=v.rgba[3]=128;v.mats[1]=v.mats[2]=255;}
level->merc_data.vertices[1].normal[2]=-1;
std::array<MobileMercMatrix,128>matrices{};std::array<bool,128>matrix_valid{};matrix_valid[0]=true;for(int i=0;i<4;++i)matrices[0].tmat[i][i]=1;for(int i=0;i<3;++i)matrices[0].nmat[i][i]=1;
ottsel_mobile_merc_lighting::Lights lights{};lights.directions[2][0]=1;for(int i=0;i<4;++i)lights.ambient[i]=.25;lights.colors[0][0]=3;lights.colors[0][1]=.25;lights.colors[0][2]=.125;lights.colors[0][3]=.5;
'''+'std::array<u8,240> packet{};memcpy(packet.data()+128,&lights,112);lights={};struct{const u8*data;}setup{packet.data()};\n'+light_read+'\n'+capture+'''
assert(lighting_valid[0]&&lighting_valid[1]);assert(std::abs(lit_colors[0][0]-(128.f/255)*3.25f)<1e-6);assert(lit_colors[0][0]>1);assert(std::abs(lit_colors[1][0]-(128.f/255)*.25f)<1e-6);for(auto&v:vertices){float w;memcpy(&w,&v.nor,4);assert(w==-1&&v.x==-1&&v.y==-2&&v.z==-3);assert(v.r==128);}puts("PASS actual capture loop: normal lighting/HDR, slot garbage, source bytes and homogeneous skinW");}
'''
(out/'capture.inc').write_text(capture);(out/'test.cpp').write_text(code);subprocess.run(['clang++','-std=c++17','-I'+str(root/'src/shell'),'-I'+str(Path(sys.argv[2]).parent),str(out/'test.cpp'),'-o',str(out/'test')],check=True);subprocess.run([str(out/'test')],check=True)
