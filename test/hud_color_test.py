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
void ottsel_metal_append_sprite_mesh_n(OttselMetal*,const OttselMetalSpriteVertex*v,unsigned count,const unsigned char*rgba,unsigned w,unsigned h,int){uploads.push_back({w,h,{v,v+count},{rgba,rgba+w*h*4}});for(auto&x:uploads.back().v)if(x.q!=0){x.pos[0]/=x.q;x.pos[1]/=x.q;x.z/=x.q;}}
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
int main(){int failures=0;auto check=[&](bool b,const char*n){if(!b){++failures;std::fprintf(stderr,"FAIL %s\\n",n);}};
MobileSpriteFrameJak1 f{};f.pfog0=1;f.basis_x={1,0,0,0};f.basis_y={0,1,0,0};f.xy[0]={-.5,-.5,0,0};f.xy[1]={.5,-.5,0,0};f.xy[2]={.5,.5,0,0};f.xy[3]={-.5,.5,0,0};f.st[0]={0,0,1,0};f.st[1]={1,0,1,0};f.st[2]={1,1,1,0};f.st[3]={0,1,1,0};
MobileSpriteHudMatrix h{};h.matrix[0].x=1;h.matrix[1].y=1;h.matrix[2].z=1;h.matrix[3].w=1;h.hvdf={2048,2048,8388608,0};MobileSpriteVec2d v{};v.xyz_sx.w=256;v.flag_rot_sy.w=224;v.rgba={128,128,128,128};AdGifData a{};
for(unsigned tw:{6u,7u})for(float raw:{0.f,1.f,63.9f,128.f,255.f,256.f,-1.f}){
 uploads.clear();a.tex0_data=tex(tw,tw,true);v.rgba={raw,raw,raw,raw};append_mobile_sprite_hud_native(f,h,&v,&a,1);float expected=(int(raw)&255)/255.f;
 for(auto&vertex:uploads[0].v)for(unsigned lane=0;lane<4;++lane)check(std::abs(vertex.color[lane]-expected)<1e-7,"raw packet byte conversion before existing shader gain");
 if(raw==128)check(std::abs(uploads[0].v[0].color[0]*2-256.f/255)<1e-7,"live128 produces reference RGB modulation gain");
}
if(!failures)std::puts("PASS actual HUD color");return failures?1:0;}

'''
(out/'actual_hud.inc').write_text(body);(out/'test.cpp').write_text(code)
cmd=['clang++','-std=c++20','-I'+str(root/'src/shell'),'-I'+str(root/'out/jak-project'),'-I'+str(root/'out/jak-project/third-party/fmt/include'),str(out/'test.cpp'),'-o',str(out/'test')]
subprocess.run(cmd,check=True);r=subprocess.run([str(out/'test')],capture_output=True,text=True);print(r.stdout+r.stderr,end='');(out/'result.txt').write_text(r.stdout+r.stderr);print('actual-source-sha256',hashlib.sha256(body.encode()).hexdigest());sys.exit(r.returncode)
