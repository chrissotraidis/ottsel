#include "game/kernel/common/kmalloc.h"
#include "game/kernel/common/memory_layout.h"
#include "common/goal_constants.h"
#include <mach/mach.h>
#include <cstdio>
#include <cstring>
#include <stdexcept>
#include <string_view>
u8* g_ee_main_mem = nullptr;
GameVersion g_game_version = GameVersion::Jak1;
s32 NumSymbols = 0;
void Msg(s32,const char*,...) {} // Expected exhausted-heap diagnostics only.
void MsgErr(const char*,...) { throw std::runtime_error("allocator error"); }
[[noreturn]] void private_assert_failed(const char* e,const char*,int,const char*,const char*) { throw std::runtime_error(e); }
[[noreturn]] void private_assert_failed(const char* e,const char*,int,const char*,const std::string_view&) { throw std::runtime_error(e); }
extern "C" u8 ottsel_module_arena[];
#include "aggregate_fixture.inc"
static void require(bool ok,const char* label) {
 if(!ok) throw std::runtime_error(label);
 std::printf("PASS %s\n",label);
}
static void protection(u8* p,size_t n,int expected) {
 auto cursor=reinterpret_cast<uintptr_t>(p),end=cursor+n;
 while(cursor<end) {
  vm_address_t address=cursor;vm_size_t size=0;
  vm_region_basic_info_data_64_t info{};
  mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
  mach_port_t object=MACH_PORT_NULL;
  auto rc=vm_region_64(mach_task_self(),&address,&size,VM_REGION_BASIC_INFO_64,
                       reinterpret_cast<vm_region_info_t>(&info),&count,&object);
  if(object!=MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),object);
  require(rc==KERN_SUCCESS && address<=cursor && address+size>cursor &&
          info.protection==expected && info.max_protection==expected,"actual current/max VM permissions");
  cursor=address+size;
 }
}
int main() try {
 g_ee_main_mem=ottsel_module_arena;
 require(kReservation>HEAP_START && kReservation+kDataSpan<=GLOBAL_HEAP_END,"actual memory_layout heap tail fits both modules");
 protection(g_ee_main_mem,EE_MAIN_MEM_SIZE,VM_PROT_READ|VM_PROT_WRITE);
 for(const auto& segment:kSegments) {
  auto data=uintptr_t(segment.data)-uintptr_t(g_ee_main_mem);
  require(data==segment.offset && !(data&15),"actual linked RW label offset/alignment");
  if(segment.text_size) {
   auto code=uintptr_t(segment.code)-uintptr_t(g_ee_main_mem);
   require(code>=EE_MAIN_MEM_SIZE && code+segment.text_size<=UINT32_MAX,"signed code within common pointer window");
   protection(segment.code,segment.text_size,VM_PROT_READ|VM_PROT_EXECUTE);
  }
 }
 for(const auto& tag:kTags) {
  u32 value;std::memcpy(&value,tag,4);
  require(value==kFunctionType,"actual immutable function tag identity");
 }
 std::memset(g_ee_main_mem+kReservation,0xA5,kDataSpan);
 kmalloc_init_globals_common();
 kinitheap(kglobalheap,Ptr<u8>(HEAP_START),kReservation-HEAP_START);
 require(kglobalheap->top.offset==kReservation,"actual kinitheap reserves aggregate tail");
 auto allocation=kmalloc(kglobalheap,kReservation-HEAP_START,0,"fill-to-reservation");
 require(allocation.offset==HEAP_START && kglobalheap->current.offset==kReservation,"actual bottom allocator stops exactly at reservation");
 require(kmalloc(kglobalheap,16,0,"overflow").offset==0,"actual allocator rejects crossing reserved module bytes");
 bool untouched=true;
 for(u32 i=0;i<kDataSpan;++i) untouched &= g_ee_main_mem[kReservation+i]==0xA5;
 require(untouched,"reserved data unchanged by heap init/allocation");
 std::puts("AGGREGATE VM/ALLOCATOR PASS; no GOAL code executed, no loader activation");
 return 0;
} catch(const std::exception& e) {std::fprintf(stderr,"FAIL %s\n",e.what());return 1;}
