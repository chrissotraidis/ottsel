import pathlib,re,subprocess,sys
# Compile only source-derived contract fixtures, not the renderer or app.
root=pathlib.Path(sys.argv[1]).resolve();out=pathlib.Path(sys.argv[2]).resolve();src=root
out.mkdir(parents=True,exist_ok=True)
s=(src/'src/shell/metal_gfx.mm').read_text();shell=(root/'src/shell/metal_shell.mm').read_text()
expr=re.search(r'bool allow_native_upload\s*=\s*(.*?);',s,re.S).group(1)
group_guard=re.search(r'if \((g_mobile_native_sprite_product_requested && count == 48 && index == 0 &&\s*allow_native_upload)\)',s).group(1)
a=s.index('if (sprite_rgba_textured && sprite_tex.tcc() == 0)') if 'if (sprite_rgba_textured && sprite_tex.tcc() == 0)' in s else s.index('const std::vector<u8>& sprite_rgba =')
b=s.index('        if (decoded) {',a);upload=s[a:b]
block=s[s.index('if (atlas_ok && !atlas_vertices.empty()'):];block=block[:block.index('} else')]
append='ottsel_metal_append_sprite_mesh_n' in block
assert 'batch.persistent = true' in shell and '[self clearSpriteBatches];' in shell
header=src/'out/jak-project/common/dma/ottsel_sprite_phase.h'
code='''#include <vector>
#include <memory>
#include <iostream>
#include "'''+str(header)+'''"
#include "'''+str(root/'src/shell/mobile_snapshot_store.h')+'''"
struct Batch {int id;bool persistent;};
int main(){int errors=0;auto test=[&](bool b,const char*n){std::cout<<(b?"PASS ":"FAIL ")<<n<<"\\n";errors+=!b;};
bool native_group_consumed=false;
bool g_mobile_native_sprite_uploaded=true,g_mobile_native_sprite_product_requested=true,g_mobile_native_sprite_color_only_probe=false,uses_texture=true;
test(('''+expr+'''),"second World2D product frame is uploadable");
int groups[2]={0,0};int count=48;g_mobile_native_sprite_uploaded=false;
for(int group=0;group<2;++group){
 native_group_consumed=false;
 for(int index=0;index<48;++index){bool allow_native_upload=('''+expr+''');if(('''+group_guard+''')){
   ++groups[group];native_group_consumed=true;g_mobile_native_sprite_uploaded=true;
 }}
}
test(groups[0]==1,"actual index-zero guard uploads same group once");
test(groups[1]==1,"next group uploads once despite prior session upload");
OttselMobileSnapshotStore<Batch> batches;batches.append({1,false});
'''+('batches.append({2,false});' if append else 'batches.clear();batches.append({2,true});')+'''
test(batches.snapshot().size()==2,"World2D group preserves already queued HUD");
std::vector<unsigned long long> tags;for(auto item:batches.snapshot_tagged())if(!item.second.persistent)tags.push_back(item.first);batches.erase_tags(tags);
test(batches.snapshot().empty(),"all product sprites retire after encoded frame");
GsTex0 sprite_tex(0);std::vector<u8> sprite_rgba_color_only;
std::shared_ptr<std::vector<u8>> sprite_rgba_textured;
if(ottsel::sprite3_uses_texture(0))sprite_rgba_textured=std::make_shared<std::vector<u8>>(std::initializer_list<u8>{20,40,60,0});
else sprite_rgba_color_only={255,255,255,255};
'''+upload+'''
test(sprite_rgba[0]==20&&sprite_rgba[1]==40&&sprite_rgba[2]==60,"TCC0 retains sampled texture RGB");
test(sprite_rgba[3]==255,"TCC0 overrides only sampled alpha");
return errors?1:0;}
'''
name='mobile-sprite-contract';cpp=out/(name+'.cpp');cpp.write_text(code)
subprocess.run(['clang++','-std=c++20','-I'+str(root/'out/jak-project'),'-I'+str(root/'out/jak-project/third-party/fmt/include'),str(cpp),'-o',str(out/(name+"-test"))],check=True)
r=subprocess.run([str(out/(name+"-test"))],capture_output=True,text=True);(out/(name+'.log')).write_text(r.stdout+r.stderr);print(r.stdout,end='');sys.exit(r.returncode)
