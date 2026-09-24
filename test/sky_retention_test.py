"""Extract actual Sky producer policy and exercise it with deterministic DMA/decode inputs."""
from pathlib import Path
import sys,subprocess
repo,stage,out=map(Path,sys.argv[1:]);out.mkdir(parents=True,exist_ok=True)
gfx=(stage/'src/shell/metal_gfx.mm').read_text();shell=(stage/'src/shell/metal_shell.mm').read_text()
a=gfx.index('static u32 submit_mobile_native_sky_bucket(');b=gfx.index('// Foreground Direct/GIF consumer',a);producer=gfx[a:b]
a=producer.index('  if (g_sky_product_diag_logs < 8) {');b=producer.index('  decoder.native_primitives.clear();',a);producer=producer[:a]+producer[b:]
assert '_skyFrameStore.snapshot()' in shell and '_skyBatches' not in shell
assert 'frame_vertex_buffers = sky_snapshot.retired' in shell
assert '_skyFrameStore.append(batch);' in shell
assert 'if (complete) _skyFrameStore.publish();' in shell and 'else _skyFrameStore.begin();' in shell
assert 'if (native_capture) native_decode_failed = true;' in gfx
preamble=r'''
#include <vector>
#include <memory>
#include <algorithm>
#include <cassert>
#include <cstdio>
#include <cstdint>
#include "mobile_direct_frame.h"
using u32=uint32_t;using u64=uint64_t;
struct Vertex {float pos[2]{};};struct Depth{};
struct Primitive {std::shared_ptr<std::vector<unsigned char>> texture=std::make_shared<std::vector<unsigned char>>(4,255);std::vector<Vertex>vertices{Vertex{}};u32 texture_width=1,texture_height=1;bool blended=false;unsigned char ta0=0;Depth depth;u64 diagnostic_alpha=0;};
struct OttselDrawState{};struct OttselRaster{};
struct OttselGifDecoder {bool native_capture=false,native_decode_failed=false,direct_scissor_seen=false;OttselRaster*rst=nullptr;std::vector<Primitive>native_primitives;std::vector<int>native_texture_cache;OttselDrawState st;u32 vert_count=0,prims_logged=0,native_primitive_candidates=0,native_primitive_rejected=0,native_texture_misses=0,native_prim_starts=0,native_vertex_words=0,native_untextured_primitives=0,native_tex0_writes=0,native_tex0_last=0,native_packed_dumps=0;};
struct Trace{bool active=false;}g_mobile_direct_trace;
struct DmaTag{enum class Kind{NEXT,CALL,CNT};Kind kind;};
struct Transfer {int action=0;u32 size_bytes=0;u32 vif0()const{return 0;}u32 vif1()const{return 0;}};
struct Step{DmaTag::Kind kind=DmaTag::Kind::CNT;int action=0;};
static std::vector<Step> steps;
struct DmaFollower{u32 i;DmaFollower(const void*,u32 start):i(start){};bool ended()const{return i>=steps.size();}u32 current_tag_offset()const{return i;}DmaTag current_tag()const{return {steps.at(i).kind};}Transfer read_and_advance(){return {steps.at(i++).action,0};}};
void decode_transfer(Transfer t,OttselGifDecoder& d){if(t.action>0)for(int i=0;i<t.action;++i)d.native_primitives.push_back({});if(t.action==-1)d.native_decode_failed=true;if(t.action==-2)++d.native_texture_misses;}
struct Batch {int vertices;};static OttselMobileDirectFrame<Batch> store;static int token=0,fail_at=0,calls=0;static void*g_metal=&token;
void ottsel_metal_begin_sky_bucket(void*){store.begin();calls=0;}
void ottsel_metal_finish_sky_bucket(void*,int good){if(good)store.publish();else store.begin();}
int ottsel_metal_append_sky_mesh_n(void*,const Vertex*,u32,const unsigned char*,u32,u32,int,unsigned char,const Depth*,u64){if(++calls==fail_at)return 0;store.append({++token});return 1;}
'''
test=r'''
int main(){OttselGifDecoder d;int data=1;
auto run=[&](std::vector<Step> s,u32 end){steps=std::move(s);submit_mobile_native_sky_bucket(&data,0,end,d,1);};
using K=DmaTag::Kind;
run({{K::NEXT,0},{K::CNT,1},{K::NEXT,0}},2);auto A=store.snapshot();assert(A.batches.size()==1);int id=A.batches[0].vertices;
assert(store.snapshot().batches[0].vertices==id); // no new producer/throttled presentation
store.begin();store.append({99});assert(store.snapshot().batches[0].vertices==id);store.begin();
run({{K::NEXT,0},{K::CNT,-1},{K::NEXT,0}},2);assert(store.snapshot().batches[0].vertices==id);
run({{K::NEXT,0},{K::CNT,-2},{K::NEXT,0}},2);assert(store.snapshot().batches[0].vertices==id);
run({{K::NEXT,0},{K::CNT,1}},3);assert(store.snapshot().batches[0].vertices==id); // premature end
fail_at=2;run({{K::NEXT,0},{K::CNT,2},{K::NEXT,0}},2);auto failed=store.snapshot();assert(failed.batches[0].vertices==id&&failed.retired.size()==1);fail_at=0;
run({{K::NEXT,0},{K::CNT,1},{K::NEXT,0}},2);auto B=store.snapshot();assert(B.batches.size()==1&&B.batches[0].vertices!=id&&B.retired.size()==1&&B.retired[0]==id);
run({{K::NEXT,0},{K::CALL,0},{K::CNT,0},{K::CNT,0},{K::CNT,0},{K::NEXT,0}},5);assert(store.snapshot().batches.empty());
run({{K::NEXT,0},{K::CNT,1},{K::NEXT,0}},2);assert(store.snapshot().batches.size()==1);
ottsel_metal_begin_sky_bucket(g_metal);ottsel_metal_finish_sky_bucket(g_metal,1);assert(store.snapshot().batches.empty());
puts("PASS actual Sky producer retention, incomplete/decode/texture/allocation rollback, replacement retirement, complete CALL and explicit phase exit");}
'''
(out/'producer.inc').write_text(producer);(out/'test.cpp').write_text(preamble+producer+test)
subprocess.run(['clang++','-std=c++17','-I'+str(repo/'src/shell'),str(out/'test.cpp'),'-o',str(out/'test')],check=True)
subprocess.run([str(out/'test')],check=True)
