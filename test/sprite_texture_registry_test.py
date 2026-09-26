from pathlib import Path
import subprocess,sys,hashlib
source=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True);s=source.read_text()
def block(name):
 a=s.index(name);p=s.index('{',a);n=1;i=p+1
 while n:n+=(s[i]=='{')-(s[i]=='}');i+=1
 return s[a:i]+(';' if name.startswith('struct ') else '')+'\n'
code='''#include <algorithm>
#include <cstdint>
#include <memory>
#include <vector>
#include <unordered_map>
#include <cstdio>
using u8=uint8_t;using u32=uint32_t;using u64=uint64_t;
namespace tfrag3 {struct Texture {};}
'''+block('struct DirectTextureMetadata')+block('struct DirectRelocatedTexture')+block('u64 direct_texture_cache_key')+'''
std::unordered_map<u32,DirectTextureMetadata> g_direct_texture_metadata;
std::unordered_map<u64,DirectRelocatedTexture> g_direct_relocated_textures;
unsigned raw_calls=0;
std::shared_ptr<std::vector<u8>> download_texture_cached(u32,u32,u32 w,u32 h,u32,u32,u32){++raw_calls;return std::make_shared<std::vector<u8>>(w*h*4,17);}
'''
name='std::shared_ptr<std::vector<u8>> download_sprite_texture_cached'
if name in s:
 body=block(name)
 sprite=s[s.index('static u32 render_mobile_sprite_group0'):s.index('static u32 render_mobile_sprite_hud')]
 assert sprite.count('download_sprite_texture_cached(')==5
 assert 'download_texture_cached(' not in sprite
 registration=s[s.index('    OttselGoalTexturePage upload_page;'):s.index('    if (direct_uploads) {')]
 assert 'download_texture_cached(' in registration and 'download_sprite_texture_cached(' not in registration

else:body='std::shared_ptr<std::vector<u8>> download_sprite_texture_cached(u32 t,u32 b,u32 w,u32 h,u32 p,u32 c,u32 a){return download_texture_cached(t,b,w,h,p,c,a);}\n'
code+=body+'''
int main(){unsigned failures=0;auto check=[&](bool v,const char*n){if(!v){++failures;std::fprintf(stderr,"FAIL %s\\n",n);}};
for(u32 tbp:{0u,256u,768u}){
 const u32 w=tbp==256?256:128,h=tbp==768?128:512;
 auto install=[&](u8 color){DirectRelocatedTexture r;r.width=w;r.height=h;r.rgba.assign(w*h*4,color);g_direct_relocated_textures[direct_texture_cache_key(tbp,19)]=std::move(r);g_direct_texture_metadata[tbp]={w,h,19,0,0,0x04080000};};
 install(34);raw_calls=0;auto first=download_sprite_texture_cached(tbp,w/64,w,h,19,0,0);auto again=download_sprite_texture_cached(tbp,w/64,w,h,19,0,0);
 check(first&&first->front()==34&&raw_calls==0,"registered image wins over raw VRAM including slot0");
 check(first==again,"unchanged registered version reuses snapshot without per-call image copy");
 install(51);auto replacement=download_sprite_texture_cached(tbp,w/64,w,h,19,0,0);
 check(replacement&&replacement->front()==51&&replacement!=first&&first->front()==34,"sameTBP re-registration changes future pixels and preserves retained old snapshot");
 for(int control=0;control<5;++control){install(34);if(control==0)g_direct_texture_metadata.erase(tbp);if(control==1)g_direct_texture_metadata[tbp].psm=0;if(control==2)g_direct_texture_metadata[tbp].width=64;if(control==3)g_direct_relocated_textures[direct_texture_cache_key(tbp,19) ].height=64;if(control==4)g_direct_relocated_textures[direct_texture_cache_key(tbp,19)].rgba.resize(4);raw_calls=0;auto fallback=download_sprite_texture_cached(tbp,w/64,w,h,19,0,0);check(fallback&&fallback->front()==17&&raw_calls==1,"missing/mismatched metadata, dimensions or payload uses raw fallback");}
}
if(!failures)std::puts("PASS actual Sprite registry resolver: exact metadata, slot0, fallback, reuse and replacement");return failures?1:0;}
'''
(out/'actual-resolver.inc').write_text(body);(out/'test.cpp').write_text(code)
subprocess.run(['clang++','-std=c++17',str(out/'test.cpp'),'-o',str(out/'test')],check=True);r=subprocess.run([str(out/'test')],capture_output=True,text=True);(out/'result.txt').write_text(r.stdout+r.stderr);print(r.stdout+r.stderr,end='');print('source-sha256',hashlib.sha256(body.encode()).hexdigest());sys.exit(r.returncode)
