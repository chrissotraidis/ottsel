#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdio>
#include <deque>
#include <map>
#include <memory>
#include "../src/shell/mobile_scene_policy.h"
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>
using u32=uint32_t; using u64=uint64_t; using s32=int32_t;
#include "mobile_level_state.inc"
struct PendingMeshUpload { bool tfrag; int geometry_token; std::string level; };
struct PendingColorUpload { bool tfrag; int color_token; std::string level; };
std::deque<PendingMeshUpload> _pendingMeshUploads;
std::deque<PendingColorUpload> _pendingColorUploads;
void queue_tfrag(PendingMeshUpload upload) {
#include "mobile_level_queue_tfrag_mesh.inc"
}
void queue_tie(PendingMeshUpload upload) {
#include "mobile_level_queue_tie_mesh.inc"
}
void colors_tfrag(PendingColorUpload upload) {
#include "mobile_level_queue_tfrag_colors.inc"
}
void colors_tie(PendingColorUpload upload) {
#include "mobile_level_queue_tie_colors.inc"
}
using SceneKey=std::pair<std::string,bool>;
struct InstalledSceneMesh { int vertices=0,indices=0,colors=0;unsigned index_count=0;std::vector<int> draws; };
std::map<SceneKey,InstalledSceneMesh> _sceneMeshes, _sceneStagingMeshes;
void install(const char* level, bool tfrag, int vertex_buffer) {
 const int index_buffer=vertex_buffer,indexCount=3,drawCount=1;const int*draws=&vertex_buffer;
#include "mobile_level_install.inc"
}
void install_colors(const char* level,bool tfrag,int buffer) {
#include "mobile_level_colors.inc"
}
struct TieUniforms { int camera_token=0; };
struct SceneFrameReference {SceneKey key;TieUniforms uniforms;};
struct SceneFrameTransaction {
 std::vector<SceneFrameReference> refs;
 std::deque<PendingMeshUpload> meshes;
 std::deque<PendingColorUpload> colors;
};
std::unique_ptr<SceneFrameTransaction> _completedSceneFrame;
std::deque<int> _pendingTieUploads;
std::vector<SceneFrameReference> _buildingSceneFrame,_activeSceneFrame;
std::mutex _tieUploadMutex,_tieUniformMutex;
TieUniforms _tieUniforms;
void begin_frame() {
#include "mobile_level_beginSceneFrame.inc"
}
void reference(const char* level,bool tfrag) {
#include "mobile_level_referenceScene.inc"
}
void publish() {
#include "mobile_level_publishSceneFrame.inc"
}
bool fail_mesh_allocation=false,fail_color_allocation=false;
void drain() {
#include "mobile_level_drainSceneFrame.inc"
}
int family_for_bucket(int bucket_id) {
#include "mobile_level_bucket.inc"
 return tfrag_bucket ? 1 : tie_bucket ? 2 : 0;
}
unsigned failures=0;
void check(bool ok,const char*name){if(!ok){++failures;std::fprintf(stderr,"FAIL %s\n",name);}}
int main(){
 for(int b:{6,13,32,39,34,41,36,43})check(family_for_bucket(b)==1,"desktop TFRAG bucket emits TFRAG");
 for(int b:{9,16})check(family_for_bucket(b)==2,"desktop TIE bucket emits TIE");
 for(int b:{-1,5,10,11,12,49,50,66,67})check(family_for_bucket(b)==0,"unknown-camera, textures, actors, overlays do not activate resident world");
 unsigned tie_builds=0,tfrag_builds=0;
 for(const char* name:{"village1","misty","village1","misty"}){
  select_mobile_scene_level(name);
  if(!g_mobile_tie_visibility_ready)++tie_builds;
  if(!g_mobile_tfrag_visibility_ready)++tfrag_builds;
  if (g_mobile_tie_visibility_ready) {
   check(g_mobile_tie_color_ranges.size()==1 && g_mobile_tie_color_ranges[0].color_offset==(name[0]=='v'?71u:72u),"restored level owns its TOD ranges");
  }
  g_mobile_tie_color_ranges={{0,0,name[0]=='v'?71u:72u}};
  g_mobile_tie_visibility_ready=g_mobile_tfrag_visibility_ready=true;
  g_mobile_tie_visibility_level=g_mobile_tfrag_visibility_level=g_mobile_tfrag_level=name;
 }
 check(tie_builds==2&&tfrag_builds==2,"resident A/B/A/B builds each level/family once");
 for(bool tfrag:{false,true}){
  _pendingMeshUploads.clear();auto queue=tfrag?queue_tfrag:queue_tie;
  queue({tfrag,11,"village1"});queue({tfrag,22,"misty"});
  check(_pendingMeshUploads.size()==2,tfrag?"retain both pending TFRAG levels":"retain both pending TIE levels");
  queue({tfrag,33,"village1"});
  check(_pendingMeshUploads.size()==2&&_pendingMeshUploads.front().geometry_token==22,"same owner replaces only itself");
  install("village1",tfrag,11);install("misty",tfrag,22);
  check(_sceneStagingMeshes[{"village1",tfrag}].vertices==11&&_sceneStagingMeshes[{"misty",tfrag}].vertices==22,tfrag?"retain both installed TFRAG levels":"retain both installed TIE levels");
  auto colors=tfrag?colors_tfrag:colors_tie;_pendingColorUploads.clear();
  colors({tfrag,71,"village1"});colors({tfrag,72,"misty"});colors({tfrag,73,"village1"});
  check(_pendingColorUploads.size()==2&&_pendingColorUploads.front().color_token==72,"TOD replacement preserves other level palette");
  install_colors("village1",tfrag,71);install_colors("misty",tfrag,72);
  check(_sceneStagingMeshes[{"village1",tfrag}].colors==71&&_sceneStagingMeshes[{"misty",tfrag}].colors==72,"installed palettes are level-owned");
 }
 _pendingMeshUploads.clear();queue_tfrag({true,11,"village1"});queue_tie({false,22,"village1"});
 check(_pendingMeshUploads.size()==2,"family isolation");
 // Seed installed snapshots via the actual transaction consumer.
 _sceneStagingMeshes.clear();_pendingMeshUploads.clear();_pendingColorUploads.clear();
 begin_frame();
 queue_tfrag({true,11,"village1"});colors_tfrag({true,71,"village1"});
 queue_tfrag({true,22,"misty"});colors_tfrag({true,72,"misty"});
 queue_tie({false,23,"misty"});colors_tie({false,73,"misty"});
 queue_tie({false,14,"village1"});colors_tie({false,74,"village1"});
 _tieUniforms.camera_token=1;reference("village1",true);_tieUniforms.camera_token=2;reference("misty",true);reference("misty",false);publish();
 check(_activeSceneFrame.empty(),"publication alone never mutates active frame");
 _pendingTieUploads.push_back(1);drain();check(_completedSceneFrame&&_activeSceneFrame.empty(),"missing texture preserves pending complete frame");_pendingTieUploads.clear();
 drain();
 check(!_completedSceneFrame&&_activeSceneFrame.size()==3&&_activeSceneFrame[0].uniforms.camera_token==1&&_activeSceneFrame[1].uniforms.camera_token==2,"ready transaction promotes both levels and camera snapshots together");
 check(_sceneMeshes[{"village1",true}].vertices==11&&_sceneMeshes[{"misty",true}].vertices==22,"both final installed TFRAG owners survive one transaction");
 check(_sceneMeshes[{"village1",false}].vertices==14&&_sceneMeshes[{"misty",false}].vertices==23,"both final installed TIE owners survive one transaction");
 const auto encoding=_activeSceneFrame;const int encoded_palette=_sceneMeshes[{"village1",true}].colors;
 begin_frame();colors_tfrag({true,99,"village1"});_tieUniforms.camera_token=3;reference("village1",true);
 drain();check(_sceneMeshes[{"village1",true}].colors==71&&_activeSceneFrame.size()==3,"unfinished future palette cannot alter active older frame");
 publish();fail_color_allocation=true;drain();
 check(_completedSceneFrame&&_activeSceneFrame.size()==3&&_sceneMeshes[{"village1",true}].colors==71,"failed allocation retains previous complete frame and palette");
 fail_color_allocation=false;drain();
 check(!_completedSceneFrame&&_activeSceneFrame.size()==1&&_sceneMeshes[{"village1",true}].colors==99,"new palette and frame refs promote atomically");
 check(encoding.size()==3&&encoding[0].uniforms.camera_token==1&&encoded_palette==71,"encoding snapshot survives late publication");
 // Two completed frames before one drain: retain first immutable geometry,
 // accept the newer palette and latest references, never lose ready CPU mesh.
 begin_frame();queue_tfrag({true,33,"training"});colors_tfrag({true,81,"training"});reference("training",true);publish();
 begin_frame();colors_tfrag({true,82,"training"});reference("training",true);reference("training",true);publish();
 check(_completedSceneFrame->meshes.size()==1&&_completedSceneFrame->colors.size()==1,"latest complete transaction inherits uninstalled geometry and replaces palette");
 fail_mesh_allocation=true;drain();check(_completedSceneFrame&&_activeSceneFrame[0].key.first=="village1","mesh allocation failure retains ready prior frame");fail_mesh_allocation=false;
 drain();check(_activeSceneFrame.size()==1&&_activeSceneFrame[0].key.first=="training"&&_sceneMeshes[{"training",true}].vertices==33&&_sceneMeshes[{"training",true}].colors==82,"superseded-frame geometry survives with newest palette");
 begin_frame();publish();drain();check(_activeSceneFrame.empty(),"empty completed frame clears membership");
 if(failures)return 1;std::puts("PASS actual-source resident reuse, keyed buffers/TOD and atomic complete-frame transactions");
}
