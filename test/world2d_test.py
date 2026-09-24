from pathlib import Path
import sys,subprocess,hashlib
root=Path(sys.argv[1]).resolve();s=Path(sys.argv[2]).read_text();out=Path(sys.argv[3]);out.mkdir(parents=True,exist_ok=True)
def block(name):
 a=s.index(name);p=s.index('{',a);n=1;i=p+1
 while n:n+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[a:i]+(';' if name.startswith('struct ') else '')+'\n'
c='''#include <algorithm>
#include <array>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <memory>
#include <vector>
#include "common/dma/gs.h"
#include "common/dma/ottsel_sprite_phase.h"
#include "common/dma/ottsel_sprite_math.h"
#include "metal_shell.h"
namespace lg {template<class... T>void info(const char*,T...) {}template<class... T>void warn(const char*,T...) {}}
OttselMetal* g_metal=reinterpret_cast<OttselMetal*>(1);
bool g_mobile_native_sprite_product_requested=true,g_mobile_native_sprite_uploaded=false;
'''
for n in ['struct MobileSpriteVec4','struct MobileSpriteFrameJak1','struct MobileSpriteMatrix','struct MobileSpriteVec2d','static MobileSpriteVec4 sprite_add','static MobileSpriteVec4 sprite_scale','static MobileSpriteVec4 sprite_matrix_transform','static std::array<float, 2> sprite_shader_clip_vertex','static bool sprite_world_shader_clips']:c+=block(n)
c+='''
struct Upload{unsigned w,h;std::vector<OttselMetalSpriteVertex> v;};std::vector<Upload>uploads;
std::shared_ptr<std::vector<u8>> download_sprite_texture_cached(u32,u32,u32 w,u32 h,u32,u32,u32){return std::make_shared<std::vector<u8>>(w*h*4,128);}
void ottsel_metal_append_sprite_mesh_n(OttselMetal*,const OttselMetalSpriteVertex*v,unsigned n,const unsigned char*,unsigned w,unsigned h,int){uploads.push_back({w,h,{v,v+n}});for(auto&x:uploads.back().v)if(x.q!=0){x.pos[0]/=x.q;x.pos[1]/=x.q;x.z/=x.q;}}
void run(bool atlas,const MobileSpriteFrameJak1&frame,const MobileSpriteMatrix&matrix,const MobileSpriteVec2d*vectors,const AdGifData*adgifs){
unsigned count=48,index=0,sprite_w=64,sprite_h=64;bool allow_native_upload=true,native_sprite_consumed=false,native_group_consumed=false;std::vector<u8>sprite_rgba(64*64*4,128);GsTex0 sprite_tex(adgifs[0].tex0_data);bool validated_product_group=true;
if(atlas){
'''
a=block('if (g_mobile_native_sprite_product_requested && count == 48 && index == 0 &&');b=block('if (validated_product_group && allow_native_upload)');c+=a+'}else{\n'+b+'}}\n'
c+='''
int main(){unsigned failures=0;auto check=[&](bool pass,const char*n){if(!pass){++failures;std::fprintf(stderr,"FAIL %s\\n",n);}};
MobileSpriteFrameJak1 f{};f.pfog0=1;f.inv_area=1;f.max_scale=1000000;f.basis_x={1,0,0,0};f.basis_y={0,1,0,0};f.xy[0]={-.5,-.5,0,0};f.xy[1]={.5,-.5,0,0};f.xy[2]={.5,.5,0,0};f.xy[3]={-.5,.5,0,0};f.st[0]={0,0,1,0};f.st[1]={1,0,1,0};f.st[2]={1,1,1,0};f.st[3]={0,1,1,0};
MobileSpriteMatrix m{};m.camera[0].x=1;m.camera[1].y=1;m.camera[2].z=1;m.camera[3].w=1;m.hvdf={2048,2048,0,0};MobileSpriteVec2d v[48]{};AdGifData a[48]{};
for(int i=0;i<48;++i){v[i].xyz_sx.w=256;v[i].flag_rot_sy.w=224;v[i].rgba={128,128,128,128};a[i].tex0_data=1ull|(19ull<<20)|(6ull<<26)|(6ull<<30)|(1ull<<34);}
for(bool atlas:{true,false}){
 for(float raw:{0.f,63.9f,128.f,255.f,256.f,-1.f}){for(auto&x:v)x.rgba={raw,raw,raw,raw};uploads.clear();run(atlas,f,m,v,a);check(uploads.size()==1&&uploads[0].v.size()==288,"actual complete World2D branch submits48sprites");float want=(int(raw)&255)/255.f;for(const auto&x:uploads[0].v)for(unsigned lane=0;lane<4;++lane)check(std::abs(x.color[lane]-want)<1e-7,"World2D raw RGBA normalization");}
 for(auto&x:v)x.rgba={128,128,128,128};f.inv_area=.25f/(256*224);uploads.clear();run(atlas,f,m,v,a);check(std::abs(uploads[0].v[0].color[3]-(128.f/255)*.25f)<1e-7,"normalized alpha keeps partial projected-area fade");f.inv_area=1;
 for(float W:{.5f,1.f,4.f})for(float gs:{-1677721.6f,0.f,4194304.f,12582912.f,16777216.f,18454938.f}){m.camera[3].w=W;for(auto&x:v)x.xyz_sx.z=gs*W;uploads.clear();run(atlas,f,m,v,a);double clip=(gs/8388608.-1)*W;double z=(clip/W+1)*.5;for(const auto&x:uploads[0].v){check(std::abs(x.z-z)<1e-6,"World2D desktop homogeneous depth");for(float scene:{0.f,.25f,.75f,1.f})check((x.z>=scene)==(z>=scene),"World2D near far occlusion");}}
 m.camera[3].w=1;for(auto&x:v)x.xyz_sx.z=0;uploads.clear();run(atlas,f,m,v,a);const auto&u=uploads[0];
 auto edge=[](const OttselMetalSpriteVertex&a,const OttselMetalSpriteVertex&b,float x,float y){return(b.pos[0]-a.pos[0])*(y-a.pos[1])-(b.pos[1]-a.pos[1])*(x-a.pos[0]);};
 for(int iy=0;iy<17;++iy)for(int ix=0;ix<19;++ix){float x=-.5f+(ix+.23f)/19,y=-1.f+2*(iy+.37f)/17;unsigned hits=0;for(unsigned tri=0;tri<2;++tri){auto&A=u.v[tri*3];auto&B=u.v[tri*3+1];auto&C=u.v[tri*3+2];float area=edge(A,B,C.pos[0],C.pos[1]),wa=edge(B,C,x,y)/area,wb=edge(C,A,x,y)/area,wc=edge(A,B,x,y)/area;if(wa>0&&wb>0&&wc>0){++hits;float scale=atlas?.125f:1.f;check(std::abs((wa*A.uv[0]+wb*B.uv[0]+wc*C.uv[0])/scale-(x+.5f))<1e-5,"World2D continuous U");check(std::abs((wa*A.uv[1]+wb*B.uv[1]+wc*C.uv[1])/scale-(1-y)*.5f)<1e-5,"World2D continuous V");}}check(hits==1,"World2D rectangle exactly once coverage");}
}
if(!failures)std::puts("PASS actual World2D atlas and same-texture fallback: raw color, depth/Q, independent quad coverage/UV");return failures?1:0;}
'''
(out/'actual-atlas.inc').write_text(a);(out/'actual-fallback.inc').write_text(b);(out/'test.cpp').write_text(c);subprocess.run(['clang++','-std=c++20','-I'+str(root/'src/shell'),'-I'+str(root/'out/jak-project'),'-I'+str(root/'out/jak-project/third-party/fmt/include'),str(out/'test.cpp'),'-o',str(out/'test')],check=True);p=subprocess.run([str(out/'test')],capture_output=True,text=True);(out/'result.txt').write_text(p.stdout+p.stderr);print('failures',p.stderr.count('FAIL'),p.stdout);sys.exit(p.returncode)
