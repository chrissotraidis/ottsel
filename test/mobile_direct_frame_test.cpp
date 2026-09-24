#include <cstdio>
#include <vector>
#include "mobile_resource_retirement.h"
#ifdef LEGACY_DIRECT
#include "mobile_snapshot_store.h"
#else
#include "mobile_direct_frame.h"
#endif
struct Batch {int vertices;};
#ifdef LEGACY_DIRECT
// Existing product behavior: append immediately; presentation erases encoded tags.
class Store {
 OttselMobileSnapshotStore<Batch> store;
 public:
 struct Snapshot {std::vector<Batch> batches;std::vector<int> retired;};
 void begin(){} void publish(){} void clear(){store.clear();}
 void append(Batch b){store.append(b);}
 Snapshot snapshot(){Snapshot s;auto captured=store.snapshot_tagged();std::vector<unsigned long long> tags;
 for(auto& p:captured){s.batches.push_back(p.second);s.retired.push_back(p.second.vertices);tags.push_back(p.first);}
 store.erase_tags(tags);return s;}
};
#else
using Store=OttselMobileDirectFrame<Batch>;
#endif
int failed=0;
void check(bool ok,const char* label){printf("%s %s\n",ok?"PASS":"FAIL",label);failed+=!ok;}
bool image(const Store::Snapshot& s,int value){return s.batches.size()==1 && s.batches[0].vertices==value;}
int main(){
 Store f;check(f.snapshot().batches.empty(),"startup has no invented image");
 f.begin();f.append({1});f.publish();auto first=f.snapshot();
 check(image(first,1) && first.retired.empty(),"first completed frame owns its buffer");
 check(image(f.snapshot(),1),"unchanged display replays last completed frame");
 f.begin();f.append({2});auto waiting=f.snapshot();
 check(image(waiting,1) && waiting.retired.empty(),"next in-progress geometry is invisible and cannot retire active image");
 f.publish();auto next=f.snapshot();
 check(image(next,2) && next.retired==std::vector<int>{1},"replacement retires only previous complete frame");
 std::vector<int> borrowed{1,2,99},free;
 auto callback=ottsel_mobile_take_encoded_resources(borrowed,next.retired);
 check(borrowed==std::vector<int>({2,99}) && free.empty(),"active replay and future borrowed resources remain unavailable to pool");
 check(callback==std::vector<int>{1},"replacing command buffer captures exact retired resources");
 // Existing completion callback is the only event allowed to make these reusable.
 free.insert(free.end(),callback.begin(),callback.end());
 check(free==std::vector<int>{1},"completion releases retired buffer without exposing active replay");
 f.begin();f.append({3});f.publish();f.begin();f.append({4});f.publish();
 auto latest=f.snapshot();
 check(image(latest,4) && latest.retired==std::vector<int>({3,2}),"newest completed frame supersedes older pending image safely");
 f.begin();f.publish();auto empty=f.snapshot();
 check(empty.batches.empty() && empty.retired==std::vector<int>{4},"explicit empty frame erases previous labels");
 check(f.snapshot().batches.empty(),"empty completed frame remains empty on replay");
 f.begin();f.append({5});f.begin();f.append({6});f.publish();auto clean=f.snapshot();
 check(image(clean,6) && clean.retired==std::vector<int>{5},"abandoned chain never leaks into replacement");
 f.begin();f.append({7});f.clear();auto reset=f.snapshot();
 check(reset.batches.empty() && reset.retired==std::vector<int>({7,6}),"explicit clear retires building and active buffers");
 return failed?1:0;
}
