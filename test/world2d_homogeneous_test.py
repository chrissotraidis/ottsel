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
void ottsel_metal_append_sprite_mesh_n(OttselMetal*,const OttselMetalSpriteVertex*v,unsigned n,const unsigned char*,unsigned w,unsigned h,int){uploads.push_back({w,h,{v,v+n}});}
void run(bool atlas,const MobileSpriteFrameJak1&frame,const MobileSpriteMatrix&matrix,const MobileSpriteVec2d*vectors,const AdGifData*adgifs){
unsigned count=48,index=0,sprite_w=64,sprite_h=64;bool allow_native_upload=true,native_sprite_consumed=false,native_group_consumed=false;std::vector<u8>sprite_rgba(64*64*4,128);GsTex0 sprite_tex(adgifs[0].tex0_data);bool validated_product_group=true;
if(atlas){
'''
a=block('if (g_mobile_native_sprite_product_requested && count == 48 && index == 0 &&');b=block('if (validated_product_group && allow_native_upload)');c+=a+'}else{\n'+b+'}}\n'
c+='''
int main(){unsigned failures=0;auto check=[&](bool x,const char*n){if(!x){++failures;std::fprintf(stderr,"FAIL %s\\n",n);}};
MobileSpriteFrameJak1 f{};f.pfog0=1;f.inv_area=1;f.max_scale=1000000;f.fog_min=.2;f.basis_x={1,0,0,.003};f.basis_y={0,1,0,.002};f.xy[0]={-.5,-.5,0,0};f.xy[1]={.5,-.5,0,0};f.xy[2]={.5,.5,0,0};f.xy[3]={-.5,.5,0,0};MobileSpriteMatrix m{};m.camera[0].x=1;m.camera[1].y=1;m.camera[2].z=1;MobileSpriteVec2d v[48]{};AdGifData a[48]{};for(unsigned i=0;i<48;++i){v[i].xyz_sx.w=256;v[i].flag_rot_sy.w=224;v[i].rgba={128,128,128,128};a[i].tex0_data=1ull|(19ull<<20)|(6ull<<26)|(6ull<<30)|(1ull<<34);}unsigned order[6]={0,1,3,3,1,2};
for(bool atlas:{true,false})for(float cameraW:{.5f,1.f,4.f})for(float offsetW:{-2.f,0.f,2.f}){m.camera[3].w=cameraW;m.hvdf={2112,2016,0,offsetW};for(auto&x:v)x.xyz_sx.z=8388608*cameraW;uploads.clear();run(atlas,f,m,v,a);check(uploads.size()==1,"World2D homogeneous upload");double q=1./cameraW;for(unsigned i=0;i<6;++i){auto p=f.xy[order[i]];double W=std::max(double(cameraW+offsetW),double(f.fog_min))+f.basis_x.w*256*q*p.x+f.basis_y.w*224*q*p.y;const auto&got=uploads[0].v[i];check(std::abs(got.q-W)<2e-6,"World2D finalW includes fog and corner basis");check(std::abs(got.pos[0]-(64+256*q*p.x)/256*W)<3e-6,"World2D clipX");check(std::abs(got.pos[1]-(-32+224*q*p.y)/-128*512/448*W)<5e-6,"World2D clipY");check(std::abs(got.z-.5*W)<2e-6,"World2D clipZ");}}
m.camera[3].w=0;uploads.clear();run(true,f,m,v,a);check(uploads.empty(),"World2D undefined cameraQ rejected");if(!failures)std::puts("PASS actual World2D homogeneous atlas/fallback");return failures?1:0;}

'''
(out/'actual-atlas.inc').write_text(a);(out/'actual-fallback.inc').write_text(b);(out/'test.cpp').write_text(c);subprocess.run(['clang++','-std=c++20','-I'+str(root/'src/shell'),'-I'+str(root/'out/jak-project'),'-I'+str(root/'out/jak-project/third-party/fmt/include'),str(out/'test.cpp'),'-o',str(out/'test')],check=True);p=subprocess.run([str(out/'test')],capture_output=True,text=True);(out/'result.txt').write_text(p.stdout+p.stderr);print('failures',p.stderr.count('FAIL'),p.stdout);sys.exit(p.returncode)
