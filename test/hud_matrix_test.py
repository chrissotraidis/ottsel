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
 MobileSpriteFrameJak1 f{};f.pfog0=1;f.min_scale=0;f.basis_x={1,0,0,0};f.basis_y={0,1,0,0};f.xy[0]={-1,-1,0,0};f.xy[1]={1,-1,0,0};f.xy[2]={1,1,0,0};f.xy[3]={-1,1,0,0};f.st[0]={0,0,0,0};f.st[1]={1,0,0,0};f.st[2]={1,1,0,0};f.st[3]={0,1,0,0};
 MobileSpriteHudMatrix h{};h.matrix[0].x=1;h.matrix[1].y=1;h.matrix[2].z=1;h.matrix[3].w=1;h.hvdf={2048,2048,0,0};
 MobileSpriteVec2d v[5]{};AdGifData a[5]{};for(auto&x:v){x.xyz_sx.w=128;x.flag_rot_sy.w=64;x.rgba={64.f,128.f,192.f,128.f};}
 for(const auto&dims:std::vector<std::array<unsigned,2>>{{7,9},{8,9},{7,7}}){
  uploads.clear();a[0].tex0_data=tex(dims[0],dims[1],true);
  check(append_mobile_sprite_hud_native(f,h,v,a,1),"oversized real HUD identity submitted");
  check(uploads.size()==1,"one oversized sprite produces one upload");if(uploads.empty())continue;
  const auto&u=uploads[0];check(u.w==(1u<<dims[0])&&u.h==(1u<<dims[1])&&u.v.size()==6,"original texture dimensions and six vertices retained");
  check(u.rgba[0]==17&&u.rgba[1]==31&&u.rgba[2]==49&&u.rgba[3]==64,"TCC1 full RGBA preserved");
  check(u.v[0].uv[0]==0&&u.v[0].uv[1]==0&&u.v[2].uv[0]==0&&u.v[2].uv[1]==1,"original full UV corners retained");
  check(u.v[0].color[0]==64.f/255&&u.v[0].color[1]==128.f/255&&u.v[0].color[2]==192.f/255&&u.v[0].color[3]==128.f/255,"HUD vertex color and alpha contract retained");
  check(std::abs(u.v[0].pos[0]+.5f)<1e-6f&&std::abs(u.v[0].pos[1]-4.f/7.f)<1e-6f,"same HUD clip transform retained");
 }
 uploads.clear();a[0].tex0_data=tex(7,9,false);append_mobile_sprite_hud_native(f,h,v,a,1);
 check(!uploads.empty()&&uploads[0].rgba[0]==17&&uploads[0].rgba[3]==255,"TCC0 preserves RGB and overrides texture alpha");
 uploads.clear();a[0].tex0_data=tex(6,6,true);a[1].tex0_data=tex(7,9,true);a[2].tex0_data=tex(6,6,true);a[3].tex0_data=tex(8,9,true);a[4].tex0_data=tex(6,6,true);
 check(append_mobile_sprite_hud_native(f,h,v,a,5),"mixed-size HUD group submitted");
 check(uploads.size()==5,"atlas flush preserves small-large-small-large-small packet order");
 if(uploads.size()==5){check(uploads[0].w==512&&uploads[1].w==128&&uploads[2].w==512&&uploads[3].w==256&&uploads[4].w==512,"exact upload order");for(auto&u:uploads)check(u.v.size()==6,"flush submits each sprite exactly once");}
 // Actual HUD submission depth versus independent desktop homogeneous clip oracle.
 for(float W:{.5f,1.f,4.f})for(float gs:{-1677721.6f,0.f,4194304.f,12582912.f,16777216.f,18454938.f})for(unsigned tw:{6u,7u}){
  uploads.clear();h.matrix[3].w=W;v[0].xyz_sx.z=gs*W; a[0].tex0_data=tex(tw,tw,true);
  append_mobile_sprite_hud_native(f,h,v,a,1);
  const double gl_clip=(double(gs)/8388608.0-1.0)*W;
  const double oracle=(gl_clip/W+1.0)*.5;
  check(!uploads.empty(),"depth test submits atlas and standalone HUD");
  if(!uploads.empty())for(const auto& vertex:uploads[0].v){
   check(std::abs(vertex.z-oracle)<1e-6,"HUD depth preserves GS/Q and desktop GL to Metal mapping");
   for(float scene:{0.f,.25f,.75f,1.f})check((vertex.z>=scene)==(oracle>=scene),"near/far greater-equal occlusion parity");
   check((vertex.z>=0&&vertex.z<=1)==(oracle>=0&&oracle<=1),"depth clip range retained without clamping");
  }
 }
 // Desktop vertex packs raw Y integer bits into u16 matrix; X only selects XY bank.
 h.matrix[3].w=1;v[0].xyz_sx.z=0;
 h.hvdf={2048,2048,4194304,0};h.user_hvdf[0]={2112,2080,8388608,0};h.user_hvdf[74]={1984,2016,12582912,0};
 for(int i=0;i<4;++i){f.xy[i+4]=f.xy[i];f.xy[i+4].x+=.5f;}
 for(unsigned raw_matrix:{0u,1u,75u,65537u})for(unsigned flag:{0u,4u})for(unsigned tw:{6u,7u}){
  memcpy(&v[0].flag_rot_sy.x,&flag,4);memcpy(&v[0].flag_rot_sy.y,&raw_matrix,4);a[0].tex0_data=tex(tw,tw,true);uploads.clear();append_mobile_sprite_hud_native(f,h,v,a,1);
  unsigned matrix=raw_matrix&65535;auto offset=matrix? h.user_hvdf[matrix-1]:h.hvdf;
  unsigned order[6]={0,1,3,3,1,2};
  for(unsigned i=0;i<6;++i){auto corner=f.xy[order[i]+flag];double gx=offset.x+corner.x*128;double gy=offset.y+corner.y*64;
   const auto&got=uploads[0].v[i];check(std::abs(got.pos[0]-(gx-2048)/256)<1e-6,"HUD raw Y matrix selects exact HVDF independently of X flag");check(std::abs(got.pos[1]-(gy-2048)/-128*512/448)<1e-6,"HUD matrix Y offset and corner bank remain independent");check(std::abs(got.z-offset.z/16777216.)<1e-6,"HUD selected matrix depth preserved");
  }
 }
 if(!failures)std::puts("PASS actual HUD function: real oversized assets, full RGBA/UV/color, ordered atlas flush");return failures?1:0;}
'''
(out/'actual_hud.inc').write_text(body);(out/'test.cpp').write_text(code)
cmd=['clang++','-std=c++20','-I'+str(root/'src/shell'),'-I'+str(root/'out/jak-project'),'-I'+str(root/'out/jak-project/third-party/fmt/include'),str(out/'test.cpp'),'-o',str(out/'test')]
subprocess.run(cmd,check=True);r=subprocess.run([str(out/'test')],capture_output=True,text=True);print(r.stdout+r.stderr,end='');(out/'result.txt').write_text(r.stdout+r.stderr);print('actual-source-sha256',hashlib.sha256(body.encode()).hexdigest());sys.exit(r.returncode)
