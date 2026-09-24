from pathlib import Path
import sys,subprocess,hashlib
root=Path(sys.argv[1]).resolve();s=Path(sys.argv[2]).read_text();out=Path(sys.argv[3]);out.mkdir(parents=True,exist_ok=True);mode=sys.argv[4]
def block(name):
 a=s.index(name);p=s.index('{',a);n=1;i=p+1
 while n:n+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[a:i]+(';' if name.startswith('struct ') else '')+'\n'
code='''#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <memory>
#include <string>
#include <vector>
#include <unistd.h>
#include "common/dma/gs.h"
#include "common/dma/ottsel_sprite_phase.h"
#include "metal_shell.h"
namespace lg {template<class... T>void info(const char*,T...) {}}
bool ottsel_mobile_log_within_budget(unsigned a,unsigned b){return a<b;}
OttselMetal* g_metal=reinterpret_cast<OttselMetal*>(1);
bool g_mobile_sprite_3d_trace_requested=true;unsigned g_mobile_sprite_3d_trace_groups=4;
std::string ottsel_ios_writable_dir(){return "/no-probe/";}
unsigned long long ottsel_sprite_trace_hash(const void*,size_t){return 0;}
void log_mobile_sprite_texture_identity(const AdGifData&,unsigned,unsigned,unsigned){}
'''
for n in ['struct MobileSpriteVec4','struct MobileSpriteFrameJak1','struct MobileSpriteMatrix','struct MobileSpriteVec2d','static std::array<float, 2> sprite_shader_clip_vertex']:code+=block(n)
code+='''
std::vector<OttselMetalSpriteVertex> uploaded;
std::shared_ptr<std::vector<u8>> download_sprite_texture_cached(u32,u32,u32 w,u32 h,u32,u32,u32){return std::make_shared<std::vector<u8>>(w*h*4,128);}
void ottsel_metal_append_sprite_mesh_n(OttselMetal*,const OttselMetalSpriteVertex*v,unsigned n,const unsigned char*,unsigned,unsigned,int){uploaded.assign(v,v+n);}
'''
body=block('static bool render_mobile_sprite_group3d_native');code+=body
code+='''
int main(){int errors=0;auto check=[&](bool pass,const char*name){if(!pass){++errors;std::fprintf(stderr,"FAIL %s\\n",name);}};
MobileSpriteFrameJak1 f{};f.pfog0=1;f.inv_area=1;f.st[1].x=1;f.st[3].x=1;f.st[2].y=1;f.st[3].y=1;
MobileSpriteMatrix m{};m.camera[0].x=-1;m.camera[1].y=-1;m.camera[2].z=-1;m.camera[3].w=-1;m.hvdf={2048,2048,0,0};
MobileSpriteVec2d v[16]{};AdGifData a[16]{};for(int i=0;i<16;++i){v[i].xyz_sx.w=1;v[i].flag_rot_sy.w=1;v[i].rgba={.5f,.5f,.5f,.5f};a[i].tex0_data=1ull|(19ull<<20)|(6ull<<26)|(6ull<<30)|(1ull<<34);}
'''
code+='''
f.xyz[0]={-128,-112,1,0};f.xyz[1]={128,-112,1,0};f.xyz[2]={128,112,1,0};f.xyz[3]={-128,112,1,0};unsigned order[6]={0,1,3,3,1,2};
for(float translationW:{-2.f,-.05f,.05f,2.f}){m.camera[3].w=translationW;m.camera[0].w=.005;uploaded.clear();check(render_mobile_sprite_group3d_native(f,m,v,a,16),"World3D signed homogeneous upload");for(unsigned i=0;i<6;++i){auto p=f.xyz[order[i]];double W=-(translationW+m.camera[0].w*p.x);auto got=uploaded[i];check(std::abs(got.q-W)<1e-6,"World3D per-corner signed W");check(std::abs(got.pos[0]-p.x/256.)<1e-6,"World3D clipX cancels camera divide");check(std::abs(got.pos[1]+p.y/128.*512/448)<4e-6,"World3D clipY cancels camera divide");check(std::abs(got.z-1./16777216)<1e-8,"World3D clipZ cancels camera divide");}}
m.camera[0].w=0;m.camera[3].w=0;uploaded.clear();check(!render_mobile_sprite_group3d_native(f,m,v,a,16)&&uploaded.empty(),"World3D undefined Q zeroW rejects group before upload");
'''
code+='if(!errors)std::puts("PASS actual World3D '+mode+' producer contract");return errors?1:0;}\n'
(out/'actual.inc').write_text(body);(out/'test.cpp').write_text(code);subprocess.run(['clang++','-std=c++20','-I'+str(root/'src/shell'),'-I'+str(root/'out/jak-project'),'-I'+str(root/'out/jak-project/third-party/fmt/include'),str(out/'test.cpp'),'-o',str(out/'test')],check=True);r=subprocess.run([str(out/'test')],capture_output=True,text=True);(out/'result.txt').write_text(r.stdout+r.stderr);print('failures',r.stderr.count('FAIL'),r.stdout,'source-sha256',hashlib.sha256(body.encode()).hexdigest());sys.exit(r.returncode)
