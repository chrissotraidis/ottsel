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
void ottsel_metal_append_sprite_mesh_n(OttselMetal*,const OttselMetalSpriteVertex*v,unsigned n,const unsigned char*,unsigned,unsigned,int){uploaded.assign(v,v+n);for(auto&x:uploaded)if(x.q!=0){x.pos[0]/=x.q;x.pos[1]/=x.q;x.z/=x.q;}}
'''
body=block('static bool render_mobile_sprite_group3d_native');code+=body
code+='''
int main(){int errors=0;auto check=[&](bool pass,const char*name){if(!pass){++errors;std::fprintf(stderr,"FAIL %s\\n",name);}};
MobileSpriteFrameJak1 f{};f.pfog0=1;f.inv_area=1;f.st[1].x=1;f.st[3].x=1;f.st[2].y=1;f.st[3].y=1;
MobileSpriteMatrix m{};m.camera[0].x=-1;m.camera[1].y=-1;m.camera[2].z=-1;m.camera[3].w=-1;m.hvdf={2048,2048,0,0};
MobileSpriteVec2d v[16]{};AdGifData a[16]{};for(int i=0;i<16;++i){v[i].xyz_sx.w=1;v[i].flag_rot_sy.w=1;v[i].rgba={.5f,.5f,.5f,.5f};a[i].tex0_data=1ull|(19ull<<20)|(6ull<<26)|(6ull<<30)|(1ull<<34);}
'''
if mode=='depth':code+='''
for(float W:{.5f,1.f,4.f})for(float gs:{-1677721.6f,0.f,4194304.f,12582912.f,16777216.f,18454938.f}){
 m.camera[3].w=-W;for(auto&x:v)x.xyz_sx.z=gs*W;uploaded.clear();
 check(render_mobile_sprite_group3d_native(f,m,v,a,16),"3D producer submits");
 double glclip=(double(gs)/8388608.-1.)*W;double oracle=(glclip/W+1.)*.5;
 for(const auto&x:uploaded){check(std::abs(x.z-oracle)<1e-6,"3D GS/Q depth parity");for(float scene:{0.f,.25f,.75f,1.f})check((x.z>=scene)==(oracle>=scene),"3D greater-equal occlusion");check((x.z>=0&&x.z<=1)==(oracle>=0&&oracle<=1),"3D unclamped clipping range");}
}
'''
else:code+='''
// Independent quaternion rotation oracle q*v*q-conjugate (not matrix coefficients).
auto rotate=[](std::array<double,3> q,std::array<double,3> p){double w=std::sqrt(1-q[0]*q[0]-q[1]*q[1]-q[2]*q[2]);std::array<double,3> t={2*(q[1]*p[2]-q[2]*p[1]),2*(q[2]*p[0]-q[0]*p[2]),2*(q[0]*p[1]-q[1]*p[0])};return std::array<double,3>{p[0]+w*t[0]+q[1]*t[2]-q[2]*t[1],p[1]+w*t[1]+q[2]*t[0]-q[0]*t[2],p[2]+w*t[2]+q[0]*t[1]-q[1]*t[0]};};
for(auto q:std::vector<std::array<double,3>>{{0,0,0},{0,0,.5},{.2,-.3,.4}}){
 for(auto&x:v){x.flag_rot_sy.x=q[0];x.flag_rot_sy.y=q[1];x.flag_rot_sy.z=q[2];}
 f.xyz[0]={2,3,4,0};f.xyz[1]={-2,1,2,0};f.xyz[2]={1,4,-2,0};f.xyz[3]={3,-2,1,0};
 uploaded.clear();render_mobile_sprite_group3d_native(f,m,v,a,16);unsigned order[6]={0,1,3,3,1,2};
 for(unsigned i=0;i<6;++i){const auto&p=f.xyz[order[i]];auto r=rotate(q,{p.x,p.y,p.z});check(std::abs(uploaded[i].pos[0]-r[0]/256)<2e-6,"3D quaternion GLSL column X parity");check(std::abs(uploaded[i].pos[1]+r[1]/128*512/448)<2e-6,"3D quaternion GLSL column Y parity");}
}
'''
code+='if(!errors)std::puts("PASS actual World3D '+mode+' producer contract");return errors?1:0;}\n'
(out/'actual.inc').write_text(body);(out/'test.cpp').write_text(code);subprocess.run(['clang++','-std=c++20','-I'+str(root/'src/shell'),'-I'+str(root/'out/jak-project'),'-I'+str(root/'out/jak-project/third-party/fmt/include'),str(out/'test.cpp'),'-o',str(out/'test')],check=True);r=subprocess.run([str(out/'test')],capture_output=True,text=True);(out/'result.txt').write_text(r.stdout+r.stderr);print('failures',r.stderr.count('FAIL'),r.stdout,'source-sha256',hashlib.sha256(body.encode()).hexdigest());sys.exit(r.returncode)
