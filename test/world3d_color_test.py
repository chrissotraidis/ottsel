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
for(float W:{-.5f,-1.f,-4.f,.5f,1.f,4.f})for(float raw:{0.f,63.9f,128.f,255.f,256.f,-1.f})for(float area:{.25f,2.f}){
 m.camera[3].w=W;f.inv_area=area;for(auto&x:v)x.rgba={raw,raw,raw,raw};uploaded.clear();render_mobile_sprite_group3d_native(f,m,v,a,16);
 double rgb=(int(raw)&255)/255.;double q=1./W;double alpha=rgb*std::min(q*q*area,1.);
 for(const auto&x:uploaded){for(unsigned i=0;i<3;++i)check(std::abs(x.color[i]-rgb)<1e-7,"World3D raw RGB conversion");check(std::abs(x.color[3]-alpha)<1e-7,"World3D normalized alpha Q-squared area");check(std::abs(x.color[3]*4-alpha*4)<1e-6,"World3D shader final alpha gains applied once");}
}
m.camera[3].w=-1;f.xyz[0]={-128,-112,0,0};f.xyz[1]={128,-112,0,0};f.xyz[2]={128,112,0,0};f.xyz[3]={-128,112,0,0};f.st[0]={0,0,1,0};f.st[1]={1,0,1,0};f.st[2]={1,1,1,0};f.st[3]={0,1,1,0};uploaded.clear();render_mobile_sprite_group3d_native(f,m,v,a,16);
auto edge=[](const OttselMetalSpriteVertex&a,const OttselMetalSpriteVertex&b,float x,float y){return(b.pos[0]-a.pos[0])*(y-a.pos[1])-(b.pos[1]-a.pos[1])*(x-a.pos[0]);};
for(int iy=0;iy<17;++iy)for(int ix=0;ix<19;++ix){float x=-.5f+(ix+.23f)/19,y=-1.f+2*(iy+.37f)/17;unsigned hits=0;for(unsigned tri=0;tri<2;++tri){auto&A=uploaded[tri*3];auto&B=uploaded[tri*3+1];auto&C=uploaded[tri*3+2];float area=edge(A,B,C.pos[0],C.pos[1]),wa=edge(B,C,x,y)/area,wb=edge(C,A,x,y)/area,wc=edge(A,B,x,y)/area;if(wa>0&&wb>0&&wc>0){++hits;check(std::abs(wa*A.uv[0]+wb*B.uv[0]+wc*C.uv[0]-(x+.5f))<1e-5,"World3D continuous U");check(std::abs(wa*A.uv[1]+wb*B.uv[1]+wc*C.uv[1]-(1-y)*.5f)<1e-5,"World3D continuous V");}}check(hits==1,"World3D rectangle exact coverage");}

'''
code+='if(!errors)std::puts("PASS actual World3D '+mode+' producer contract");return errors?1:0;}\n'
(out/'actual.inc').write_text(body);(out/'test.cpp').write_text(code);subprocess.run(['clang++','-std=c++20','-I'+str(root/'src/shell'),'-I'+str(root/'out/jak-project'),'-I'+str(root/'out/jak-project/third-party/fmt/include'),str(out/'test.cpp'),'-o',str(out/'test')],check=True);r=subprocess.run([str(out/'test')],capture_output=True,text=True);(out/'result.txt').write_text(r.stdout+r.stderr);print('failures',r.stderr.count('FAIL'),r.stdout,'source-sha256',hashlib.sha256(body.encode()).hexdigest());sys.exit(r.returncode)
