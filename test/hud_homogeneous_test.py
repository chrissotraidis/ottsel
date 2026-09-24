from pathlib import Path
import sys,subprocess,hashlib
root=Path(sys.argv[1]).resolve();source=Path(sys.argv[2]).resolve();out=Path(sys.argv[3]).resolve();out.mkdir(parents=True,exist_ok=True);s=source.read_text()
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
#include <vector>
#include "common/dma/gs.h"
#include "common/dma/ottsel_sprite_phase.h"
#include "metal_shell.h"
namespace lg {template<class... T>void info(const char*,T...) {}}
bool ottsel_mobile_log_within_budget(unsigned a,unsigned b){return a<b;}
OttselMetal* g_metal=reinterpret_cast<OttselMetal*>(1);
bool g_mobile_native_sprite_product_requested=true;
'''
for n in ['struct MobileSpriteVec4','struct MobileSpriteFrameJak1','struct MobileSpriteHudMatrix','struct MobileSpriteVec2d','static MobileSpriteVec4 sprite_add','static MobileSpriteVec4 sprite_scale','static MobileSpriteVec4 sprite_matrix_transform','static std::array<float, 2> sprite_shader_clip_vertex']:code+=block(n)
code+='''
struct Upload {unsigned w,h;std::vector<OttselMetalSpriteVertex> v;std::vector<u8> rgba;};
std::vector<Upload> uploads;
std::shared_ptr<std::vector<u8>> download_texture_cached(u32,u32,u32 w,u32 h,u32,u32,u32){
 auto p=std::make_shared<std::vector<u8>>(w*h*4);for(size_t i=0;i<p->size();i+=4){(*p)[i]=17;(*p)[i+1]=31;(*p)[i+2]=49;(*p)[i+3]=64;}return p;
}
void ottsel_metal_append_sprite_mesh_n(OttselMetal*,const OttselMetalSpriteVertex*v,unsigned count,const unsigned char*rgba,unsigned w,unsigned h,int){uploads.push_back({w,h,{v,v+count},{rgba,rgba+w*h*4}});}
'''
body=block('static bool append_mobile_sprite_hud_native')
if 'trace_mobile_hud_transform(' in body:
 code+='static void trace_mobile_hud_transform(const MobileSpriteFrameJak1&,const MobileSpriteHudMatrix&,const MobileSpriteVec2d&,u64,const std::array<float,2>[4],const float[4]) {}\n'

# Diagnostic observer does not participate in this draw-contract regression.
if 'trace_mobile_hud_identity(' in body:
 code+='static void trace_mobile_hud_identity(const GsTex0&,u64,const std::vector<u8>&) {}\n'
# Image-source selection has a separate actual-resolver regression; keep this
# test focused on unchanged geometry, ordering and TCC normalization.
if 'download_sprite_texture_cached(' in body:
 code+='std::shared_ptr<std::vector<u8>> download_sprite_texture_cached(u32 t,u32 b,u32 w,u32 h,u32 p,u32 c,u32 a){return download_texture_cached(t,b,w,h,p,c,a); }\n'
code+=body
code+='''
u64 tex(unsigned tw,unsigned th,bool tcc){return 32ull|(19ull<<20)|(u64(tw)<<26)|(u64(th)<<30)|(u64(tcc)<<34);}
int main(){int failures=0;auto check=[&](bool x,const char*n){if(!x){++failures;std::fprintf(stderr,"FAIL %s\\n",n);}};
MobileSpriteFrameJak1 f{};f.pfog0=1;f.basis_x={1,0,0,.003};f.basis_y={0,1,0,.002};f.xy[0]={-.5,-.5,0,0};f.xy[1]={.5,-.5,0,0};f.xy[2]={.5,.5,0,0};f.xy[3]={-.5,.5,0,0};MobileSpriteHudMatrix h{};h.matrix[0].x=1;h.matrix[1].y=1;h.matrix[2].z=1;MobileSpriteVec2d v{};v.xyz_sx.w=256;v.flag_rot_sy.w=224;v.rgba={128,128,128,128};AdGifData a{};unsigned order[6]={0,1,3,3,1,2};
for(float cameraW:{.5f,1.f,4.f})for(float offsetW:{-2.f,0.f,2.f})for(unsigned tw:{6u,7u}){h.matrix[3].w=cameraW;h.hvdf={2112,2016,0,offsetW};v.xyz_sx.z=8388608*cameraW;a.tex0_data=tex(tw,tw,true);uploads.clear();append_mobile_sprite_hud_native(f,h,&v,&a,1);check(uploads.size()==1,"HUD homogeneous upload");double q=1./cameraW;for(unsigned i=0;i<6;++i){auto p=f.xy[order[i]];double W=cameraW+offsetW+f.basis_x.w*256*q*p.x+f.basis_y.w*224*q*p.y;const auto&got=uploads[0].v[i];check(std::abs(got.q-W)<2e-6,"HUD exact desktop W without scaling cameraW by Q");check(std::abs(got.pos[0]-(64+256*q*p.x)/256*W)<3e-6,"HUD clipX");check(std::abs(got.pos[1]-(-32+224*q*p.y)/-128*512/448*W)<5e-6,"HUD clipY");check(std::abs(got.z-.5*W)<2e-6,"HUD clipZ");}}
f.basis_x.w=f.basis_y.w=0;h.matrix[3].w=1;h.hvdf.w=-1;uploads.clear();append_mobile_sprite_hud_native(f,h,&v,&a,1);for(auto&x:uploads[0].v)check(x.q==0&&x.pos[0]==0&&x.pos[1]==0&&x.z==0,"HUD finite zero finalW remains homogeneous origin");h.matrix[3].w=0;uploads.clear();check(!append_mobile_sprite_hud_native(f,h,&v,&a,1)&&uploads.empty(),"HUD rejects undefined cameraQ zeroW");
if(!failures)std::puts("PASS actual HUD homogeneous corners, varying/signed/zero W");return failures?1:0;}

'''
(out/'actual_hud.inc').write_text(body);(out/'test.cpp').write_text(code)
cmd=['clang++','-std=c++20','-I'+str(root/'src/shell'),'-I'+str(root/'out/jak-project'),'-I'+str(root/'out/jak-project/third-party/fmt/include'),str(out/'test.cpp'),'-o',str(out/'test')]
subprocess.run(cmd,check=True);r=subprocess.run([str(out/'test')],capture_output=True,text=True);print(r.stdout+r.stderr,end='');(out/'result.txt').write_text(r.stdout+r.stderr);print('actual-source-sha256',hashlib.sha256(body.encode()).hexdigest());sys.exit(r.returncode)
