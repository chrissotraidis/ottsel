#!/usr/bin/env python3
"""Execute source-extracted Merc publication/drain logic; mock only Metal buffer allocation."""
import pathlib, re, subprocess, sys, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
draw_header=pathlib.Path(sys.argv[2]) if len(sys.argv)>2 else root/'src/shell/metal_shell.h'
source=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else root/'src/shell/metal_shell.mm').read_text()
def method(name):
    start=source.index('- (void)'+name,source.index('@implementation'));  a=source.index('{',start)+1; depth=1; b=a
    while depth:
        depth+=(source[b]=='{')-(source[b]=='}'); b+=1
    return source[a:b-1]
begin=method('beginSceneFrame').split('  std::lock_guard<std::mutex> lock(_tieUploadMutex);')[0]
publish=method('publishSceneFrame').split('  std::lock_guard<std::mutex> lock(_tieUploadMutex);')[0]
# Direct publication is tested separately; this fixture executes MERC ownership only.
begin=re.sub(r'^.*_directFrameStore\..*$', '', begin, flags=re.M)
publish=re.sub(r'^.*_directFrameStore\..*$', '', publish, flags=re.M)
drain=method('drainMercUploads')
drain=re.sub(r'\[self\.device newBufferWithBytes:.*?options:MTLResourceStorageModeShared\]',r'allocate()',drain,flags=re.S)
drain=drain.replace('id<MTLBuffer>', 'int')
drain=re.sub(r'NSLog\(@.*?;', '',drain,flags=re.S).replace('self.','').replace('nil','0')
# Assert geometry rendering also uses its publication camera, not latest global camera.
frozen = '_mercDraws, false, true, _mercFrameUniforms)' in source and '_mercActorDraws, false, true, _mercFrameUniforms)' in source
preamble='''#include <vector>
#include <cstring>
#include <memory>
#include <mutex>
#include <cstdio>
#include <utility>
using TieUniforms=int;
__DRAW_ABI__
constexpr bool ottsel_mobile_merc_snapshot_should_retain(bool a,bool b){return a&&b;}
struct Fixture {
struct MercFrameTransaction {
std::vector<unsigned char> vertices,colors,actor_vertices,actor_colors;
std::vector<unsigned int> indices,actor_indices;
std::vector<OttselMetalTieDraw> draws,actor_draws;
TieUniforms uniforms=0;
};
std::unique_ptr<MercFrameTransaction> _completedMercFrame;
std::mutex _mercMutex,_tieUniformMutex;
int _tieUniforms=0,_mercFrameUniforms=0,nextBuffer=0,failAt=0,allocationCalls=0;
int allocate(){return ++allocationCalls==failAt?0:++nextBuffer;}
int mercVertices=0,mercIndices=0,mercColors=0,mercIndexCount=0;
int _mercActorVertices=0,_mercActorIndices=0,_mercActorColors=0,_mercActorIndexCount=0;
std::vector<OttselMetalTieDraw> _mercDraws,_mercActorDraws;
'''
for n in ['','Actor']:
    for t,f in [('unsigned char','Vertices'),('unsigned int','Indices'),('OttselMetalTieDraw','Draws'),('unsigned char','Colors')]:
        preamble+=f'std::vector<{t}> _pendingMerc{n}{f};\n'
append_body=method('appendMercMesh:').replace('NSUInteger','size_t')
actor_body=method('setMercActorMesh:').replace('NSUInteger','size_t')
for name, logic in [('appendMesh',append_body),('setActor',actor_body)]:
    preamble+='void '+name+'(const void* vertices,size_t vertexCount,const float* litRGBA,const unsigned int* indices,size_t indexCount,const OttselMetalTieDraw* draws,size_t drawCount){'+logic+'}\n'
body=preamble+'void begin(){'+begin+'}\nvoid publish(){'+publish+'}\nvoid drain(){'+drain+'''}
void append(bool actor=false){
 unsigned char vertex[32]={}; float lit[4]={1.5f,.25f,.75f,.5f}; unsigned int indices[3]={}; OttselMetalTieDraw draw{};
 if(actor) setActor(vertex,1,lit,indices,3,&draw,1);
 else appendMesh(vertex,1,lit,indices,3,&draw,1);
}
};
int failures=0;
void check(bool pass,const char* label){printf("%s %s\\n",pass?"PASS":"FAIL",label); failures+=!pass;}
int main(){
 Fixture f;
 { Fixture q; q.begin(); unsigned char v[32]={};float light[4]={1,1,1,1};unsigned int ids[3]={};OttselMetalTieDraw draw{};draw.merc_ignore_alpha=1;
 q.appendMesh(v,1,light,ids,3,&draw,1);q.setActor(v,1,light,ids,3,&draw,1);draw.merc_ignore_alpha=0;q.appendMesh(v,1,light,ids,3,&draw,1);
 q.publish();q.drain();check(q._mercDraws.size()==2&&q._mercDraws[0].merc_ignore_alpha==1&&q._mercDraws[1].merc_ignore_alpha==0&&q._mercActorDraws[0].merc_ignore_alpha==1,"effect masks survive aggregate rebasing, source mutation, actor ownership and completed publication");
 q.begin();q.publish();q.drain();check(q._mercDraws.empty()&&q._mercActorDraws.empty(),"empty frame retires effect masks with geometry");}

 for(int failure=1;failure<=6;++failure){Fixture q;q.begin();q.append();q.append(true);q._tieUniforms=10;q.publish();q.drain();auto old=q.mercVertices,oldactor=q._mercActorVertices,oldcolor=q.mercColors;q.begin();q.append();q.append(true);q._tieUniforms=99;q.publish();q.allocationCalls=0;q.failAt=failure;q.drain();check(q.mercVertices==old&&q._mercActorVertices==oldactor&&q.mercColors==oldcolor&&q._mercFrameUniforms==10,"any candidate allocation failure retains both ready channels and camera");q.failAt=0;q.begin();q.publish();q.drain();check(q.mercIndexCount==0&&q._mercActorIndexCount==0&&q.mercColors==0&&q._mercActorColors==0,"explicit empty retires both channels without allocation");}

 { Fixture q; q.begin(); unsigned char verts[64]={};unsigned int ids[3]={0,1,0};OttselMetalTieDraw draw{};float A[4]={1.5f,.25f,.75f,.5f};float B[8]={2.5f,.5f,.25f,1.f,3.5f,.75f,.5f,.25f};q.appendMesh(verts,1,A,ids,1,&draw,1);q.appendMesh(verts,2,B,ids,3,&draw,1);
 check(q._pendingMercVertices.size()==96&&q._pendingMercColors.size()==48,"merged lighting length tracks every vertex");float colors[12];memcpy(colors,q._pendingMercColors.data(),48);check(colors[0]==1.5f&&colors[4]==2.5f&&colors[8]==3.5f,"merged HDR colors stay in vertex order");check(q._pendingMercIndices[1]==1&&q._pendingMercIndices[2]==2&&q._pendingMercDraws[1].index_offset==1,"index/draw rebasing remains aligned with lighting");A[0]=99;B[0]=99;memcpy(colors,q._pendingMercColors.data(),48);check(colors[0]==1.5f&&colors[4]==2.5f,"enqueue owns independent color copy");q.publish();check(q._completedMercFrame->colors.size()==48&&q._pendingMercColors.empty(),"publish moves companion with geometry");q.drain();auto accepted=q.mercColors;q.begin();q.publish();q.drain();check(q.mercColors==0,"empty frame retires lighting buffer");q.begin();q.append();q.publish();q.drain();accepted=q.mercColors;q.begin();q.append();q.publish();q._completedMercFrame->colors.resize(4);q.drain();check(q.mercColors==accepted,"misaligned transaction preserves prior ready frame");}

 f.begin(); f._tieUniforms=10; f.append(); f.publish(); f.drain();
 check(f.mercIndexCount==3,"title completed nonempty appears");
 auto title=f.mercVertices;
 f._tieUniforms=20; f.drain();
 check(f.mercVertices==title && f._mercFrameUniforms==10,"no completed frame retains geometry and accepted camera");
 f.begin(); f._tieUniforms=30; f.publish();
 f.begin(); f._tieUniforms=40; f.append(true); // next game frame incomplete
 f.drain();
 check(f.mercIndexCount==0 && f._mercActorIndexCount==0 && f._mercFrameUniforms==30,"completed empty menu retires title and actor");
 check(f._pendingMercActorIndices.size()==3,"empty frame drain preserves next in-progress actor");
 f.drain(); check(f._mercActorIndexCount==0,"in-progress actor cannot appear before publication");
 f.publish(); f._tieUniforms=50; f.drain();
 check(f.mercIndexCount==0 && f._mercActorIndexCount==3 && f._mercFrameUniforms==40,"game actor uses completed camera");
 f.begin(); f.publish(); f.drain();
 check(f._mercActorIndexCount==0&&f._mercActorColors==0,"completed empty clears actor and lighting too");
 f.begin(); f.append(); f._tieUniforms=60; f.publish();
 f.begin(); f._tieUniforms=70; f.publish(); f.drain();
 check(f.mercIndexCount==0 && f._mercFrameUniforms==70,"latest completed empty supersedes older nonempty");
 f.begin(); f.append(); f.begin(); f.publish(); f.drain();
 check(f.mercIndexCount==0,"abandoned building frame does not leak");
'''+f'check({str(frozen).lower()},"both draw channels use frozen frame uniforms");\nreturn failures?1:0;}}'
body=body.replace('__DRAW_ABI__', '#include "'+str(draw_header.resolve())+'"')
with tempfile.TemporaryDirectory(prefix='ottsel-merc-contract-') as out:
    cpp=pathlib.Path(out)/'test.cpp'; exe=pathlib.Path(out)/'test'; cpp.write_text(body)
    subprocess.run(['xcrun','clang++','-std=c++17',str(cpp),'-o',str(exe)],check=True)
    sys.exit(subprocess.run([str(exe)]).returncode)
