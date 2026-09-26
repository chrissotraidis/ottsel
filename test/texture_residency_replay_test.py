from pathlib import Path
import sys,subprocess,hashlib
s=Path(sys.argv[1]).read_text();out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
a=s.index('bool handle_mobile_pc_port_texture_upload(');p=s.index('{',a);n=1;i=p+1
while n:n+=(s[i]=='{')-(s[i]=='}');i+=1
body=s[a:i]
code='''#include <cstdint>
#include <cstring>
#include <unordered_map>
#include <cstdio>
using u8=uint8_t;using u32=uint32_t;using u64=uint64_t;using s32=int32_t;
struct VifCode {enum class Kind{PC_PORT,OTHER};Kind kind;VifCode(u32 v):kind(v==7?Kind::PC_PORT:Kind::OTHER){}};
struct DmaTransfer {const u8* data;u32 size_bytes=16;u32 vif0()const{return 7;}u32 vif1()const{return 3;}};
namespace lg{template<class...A>void info(const char*,A...) {}}
u8 memory[2048]{};u8* g_ee_main_mem=memory;u32 current_slot0_owner=0,raw_uploads=0,residency_replays=0;
u32 mobile_s7_pointer(){return 123;}
void restore(const u8*p){std::memcpy(&current_slot0_owner,p+8,4);}
void gfx_texture_upload_now(const u8*p,int,u32){++raw_uploads;restore(p);}
void register_mobile_texture_page(const u8*p,int,u32){++residency_replays;restore(p);}
'''+body+'''
int main(){
 auto page=[&](u32 addr,u32 id){u32 length=1;std::memcpy(memory+addr+8,&id,4);std::memcpy(memory+addr+12,&length,4);};
 auto emit=[&](u32 addr){u8 payload[16]{};u64 ptr=addr;s32 mode=-1;std::memcpy(payload,&ptr,8);std::memcpy(payload+8,&mode,4);DmaTransfer d{payload};return handle_mobile_pc_port_texture_upload(d);};
 page(128,0x408);page(512,0x1a0);
 emit(128);emit(512);emit(128);
 bool good=current_slot0_owner==0x408&&raw_uploads==2&&residency_replays==1;
 if(!good)std::fprintf(stderr,"FAIL Hud/charHOLD/unchangedHud finalowner=0x%x raw=%u replay=%u expected408/2/1\\n",current_slot0_owner,raw_uploads,residency_replays);
 emit(128);bool reuse=raw_uploads==2&&residency_replays==2;
 if(!reuse)std::fprintf(stderr,"FAIL unchanged residency command must not redo raw upload\\n");
 if(good&&reuse)std::puts("PASS actual PC_PORT handler restores unchanged-page slot ownership without raw re-upload");return good&&reuse?0:1;}
'''
(out/'actual-handler.inc').write_text(body);(out/'test.cpp').write_text(code);subprocess.run(['clang++','-std=c++17',str(out/'test.cpp'),'-o',str(out/'test')],check=True);r=subprocess.run([str(out/'test')],capture_output=True,text=True);print(r.stdout+r.stderr,end='');(out/'result.txt').write_text(r.stdout+r.stderr);print('source-sha256',hashlib.sha256(body.encode()).hexdigest());sys.exit(r.returncode)
