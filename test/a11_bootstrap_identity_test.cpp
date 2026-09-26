#include "game/kernel/jak1/kscheme.h"
#include "game/kernel/common/kprint.h"
#include "game/kernel/common/memory_layout.h"
#include "common/symbols.h"
#include <cstdio>
#include <cstring>
#include <stdexcept>
#include <string_view>
using namespace jak1_symbols;
u8* g_ee_main_mem = nullptr;
GameVersion g_game_version = GameVersion::Jak1;
u32 MasterDebug=0, DebugSegment=0;
s32 NumSymbols=0;
Ptr<u32> s7, SymbolTable2, LastSymbol;
Ptr<u8> MessBufArea, OutputBufArea, PrintBufArea;
size_t PrintBufSize=0;
static int reset_count=0;
// Only non-allocating output transport is stubbed. Allocator diagnostics fail.
void reset_output() { ++reset_count; }
void Msg(s32,const char*,...) { throw std::runtime_error("unexpected allocator diagnostic"); }
void MsgErr(const char*,...) { throw std::runtime_error("unexpected allocation error"); }
[[noreturn]] void private_assert_failed(const char* e,const char*,int,const char*,const char*) {
  throw std::runtime_error(e);
}
[[noreturn]] void private_assert_failed(const char* e,const char*,int,const char*,const std::string_view&) {
  throw std::runtime_error(e);
}
#include "bootstrap-current-source.inc"
extern "C" u8 ottsel_bootstrap_arena[];
extern "C" void ottsel_bootstrap_release(), ottsel_bootstrap_debug();
extern "C" u64 _call_goal_asm_arm64(u64,u64,u64,void*,void*,void*) asm("_call_goal_asm_arm64");
static void require(bool condition,const char* label) {
  if (!condition) throw std::runtime_error(label);
  std::printf("PASS %s\n",label);
}
static Ptr<Function> function(void (*entry)()) {
  const auto host=reinterpret_cast<uintptr_t>(entry),base=reinterpret_cast<uintptr_t>(g_ee_main_mem);
  if(host<base || host-base>UINT32_MAX) throw std::runtime_error("invalid signed function window");
  return Ptr<Function>(static_cast<u32>(host-base));
}
static int executed_calls=0;
static u64 checked_call(Ptr<Function> fn) {
  if (*Ptr<u32>(fn.offset-4).c()!=*Ptr<u32>(s7.offset+FIX_SYM_FUNCTION_TYPE).c())
    throw std::runtime_error("signed function Type identity mismatch");
  ++executed_calls;
  return _call_goal_asm_arm64(40,2,0,fn.c(),reinterpret_cast<void*>(uintptr_t(s7.offset)),g_ee_main_mem);
}
static bool rejects(Ptr<Function> fn) {
  try { (void)checked_call(fn); }
  catch(const std::runtime_error& e) {
    if(std::string_view(e.what())=="signed function Type identity mismatch") return true;
    throw;
  }
  return false;
}
static void run(bool debug,bool perturb) {
  MasterDebug=debug;
  kmalloc_init_globals_common();
  kinitheap(kglobalheap,Ptr<u8>(HEAP_START),GLOBAL_HEAP_END-HEAP_START);
  const u32 debug_end=(0xffffffff-DEBUG_HEAP_SPACE_FOR_STACK+1)&0x7ffffff;
  if(debug) kinitheap(kdebugheap,Ptr<u8>(DEBUG_HEAP_START),debug_end-DEBUG_HEAP_START);
  else kdebugheap.offset=0;
  init_output(); // extracted unmodified function, actual kmalloc implementation
  if(perturb) (void)kmalloc(kglobalheap,16,KMALLOC_MEMSET,"fixture-order-perturbation");
  jak1::fixture_bootstrap_prefix(); // actual source through four fundamental Types
  auto fn=function(debug?ottsel_bootstrap_debug:ottsel_bootstrap_release);
  const u32 actual=*Ptr<u32>(s7.offset+FIX_SYM_FUNCTION_TYPE).c();
  std::printf("MasterDebug=%u perturb=%u actual-function-Type=0x%x signed-tag=0x%x\n",
              MasterDebug,perturb,actual,*Ptr<u32>(fn.offset-4).c());
  if(perturb) {
    require(rejects(fn),"changed allocation order rejects signed header before execution");
    return;
  }
  require(*Ptr<u32>(fn.offset-4).c()==actual,"actual bootstrap allocation agrees with immutable signed header");
  auto wrong=function(debug?ottsel_bootstrap_release:ottsel_bootstrap_debug);
  require(rejects(wrong),"wrong debug configuration rejected before execution");
  require(*Ptr<u32>(actual-4).c()==*Ptr<u32>(s7.offset+FIX_SYM_TYPE_TYPE).c(),
          "allocated function Type has actual bootstrap type-Type tag");
  require(Ptr<jak1::Type>(actual).c()->num_methods==0,
          "later fixed-Type naming/method initialization intentionally not executed");
  const u32 original=*Ptr<u32>(fn.offset-4).c();
  require(checked_call(fn)==42,
          "signed GOAL add2 executes only after identity validation");
  require(*Ptr<u32>(fn.offset-4).c()==original,"signed function header unchanged");
}
int main() try {
  g_ee_main_mem=ottsel_bootstrap_arena;
  run(false,false);run(true,false);run(false,true);
  require(executed_calls==2,"only two matching configurations execute signed code");
  require(reset_count==3,"bootstrap reset-output reached for every configuration");
  std::puts("BOOTSTRAP IDENTITY PASS; no exports, later naming/intern phase, CGO or product allocation change");
  return 0;
} catch(const std::exception& e){std::fprintf(stderr,"FAIL %s\n",e.what());return 1;}
