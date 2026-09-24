#define main bootstrap_identity_previous_main
#include "a11_bootstrap_identity_test.cpp"
#undef main
#include "game/mips2c/mips2c_private.h"
#include <array>
extern "C" void ottsel_slot_0(),ottsel_slot_1(),ottsel_slot_2(),ottsel_slot_3(),ottsel_slot_end(),ottsel_slot_driver();
extern "C" u64 ottsel_export_targets[8],ottsel_export_selected,ottsel_export_observed[18];
extern "C" u64 _call_goal_on_stack_asm_arm64(void*,u64,u64,void*,void*,void*) asm("_call_goal_on_stack_asm_arm64");
// Only upper64 lanes are clobbered: legal C ABI behavior that GOAL helpers must protect.
static void clobber_vectors() {
  asm volatile("mov x9,#0x55\nins v8.d[1],x9\nins v9.d[1],x9\nins v10.d[1],x9\nins v11.d[1],x9\nins v12.d[1],x9\nins v13.d[1],x9\nins v14.d[1],x9\nins v15.d[1],x9" ::: "x9","v8","v9","v10","v11","v12","v13","v14","v15");
}
static u64 normal(u64 a,u64 b,u64 c,u64 d,u64 e,u64 f,u64 g,u64 h) {
  clobber_vectors();return a+2*b+3*c+4*d+5*e+6*f+7*g+8*h;
}
static u64 rebound(u64 a,u64 b,u64 c,u64 d,u64 e,u64 f,u64 g,u64 h) {
  return normal(a,b,c,d,e,f,g,h)+1;
}
static u64 process(u64 a,u64 b,u64 c,u64 pp) {
  clobber_vectors();return pp==0x12340 && a==1 && b==2 && c==3?0xabcdef01:0;
}
static u64 stacked(u64* args) {
  u64 result=0;for(int i=0;i<8;++i)result+=(i+1)*args[i];
  clobber_vectors();return result+0x100000000ull;
}
static bool context_ok=false, fake_stack_ok=false;
static size_t expected_stack_size=0;
static u64 mips(void* pointer) {
  auto* ctxt=static_cast<Mips2C::ExecutionContext*>(pointer);
  u64 result=0;for(int i=0;i<8;++i)result+=(i+1)*ctxt->gprs[Mips2C::a0+i].du64[0];
  auto sp=ctxt->gprs[Mips2C::sp].du64[0];
  context_ok=sp<EE_MAIN_MEM_SIZE && sp>0x7000000 &&
      ctxt->gprs[Mips2C::s6].du64[0]==0x12340 && ctxt->gprs[Mips2C::s7].du64[0]==s7.offset;
  // Actual translated functions store below the EE-relative SP. Exercise the
  // complete reserved area without touching the context or native C stack.
  auto* fake = g_ee_main_mem + sp - expected_stack_size;
  for(size_t i=0;i<expected_stack_size;++i) fake[i]=static_cast<u8>(i ^ 0xa5);
  fake_stack_ok=true;
  for(size_t i=0;i<expected_stack_size;++i)
    fake_stack_ok = fake_stack_ok && fake[i]==static_cast<u8>(i ^ 0xa5);
  ctxt->gprs[Mips2C::v0].du64[0]=result+0x200000000ull;
  clobber_vectors();return 0xdeadbeef; // helper must return context v0, not C x0
}
static bool vectors_ok() {
  for(int reg=8;reg<=15;++reg)for(int b=0;b<16;++b)
    if(reinterpret_cast<u8*>(ottsel_export_observed+2)[(reg-8)*16+b]!=reg)return false;
  return true;
}
#ifndef OTTSEL_SIGNED_EXPORT_BANK_ABI_TEST
int main() try {
  g_ee_main_mem=ottsel_bootstrap_arena;run(false,false);
  std::array<void(*)(),4> entries={ottsel_slot_0,ottsel_slot_1,ottsel_slot_2,ottsel_slot_3};
  const auto start=reinterpret_cast<uintptr_t>(entries[0]);
  const size_t size=reinterpret_cast<uintptr_t>(&ottsel_slot_end)-start;
  std::vector<u8> text(size);std::memcpy(text.data(),reinterpret_cast<void*>(start),size);
  size_t used=0;
  auto register_slot=[&](u64 target,u64 stack)->Ptr<Function> {
    if(!target || used==entries.size() || stack%16 || stack>4096)
      throw std::runtime_error("slot registration rejected");
    auto fn=function(entries[used]);
    if(*Ptr<u32>(fn.offset-4).c()!=*Ptr<u32>(s7.offset+FIX_SYM_FUNCTION_TYPE).c())
      throw std::runtime_error("slot Type mismatch");
    ottsel_export_targets[2*used]=target;ottsel_export_targets[2*used+1]=stack;++used;return fn;
  };
  std::array<Ptr<Function>,4> slots={register_slot((u64)&normal,0),register_slot((u64)&process,0),
      register_slot((u64)&stacked,0),register_slot((u64)&mips,256)};
  bool exhausted=false;try{register_slot((u64)&normal,0);}catch(const std::runtime_error&){exhausted=true;}
  require(exhausted,"four-slot pool fails closed on exhaustion");
  auto execute=[&](int index,u64 expected){
    ottsel_export_selected=reinterpret_cast<u64>(slots[index].c());
    _call_goal_on_stack_asm_arm64(g_ee_main_mem+0x7ff0000,0,0,(void*)&ottsel_slot_driver,
                                 reinterpret_cast<void*>(uintptr_t(s7.offset)),g_ee_main_mem);
    require(ottsel_export_observed[0]==expected,"ABI argument ordering and return value");
    require(ottsel_export_observed[1]==0,"helper restores arena-backed stack exactly");
    bool preserved=vectors_ok();
    if(!preserved) for(int r=0;r<8;++r) std::printf("q%d=%016llx:%016llx\n",r+8,ottsel_export_observed[3+r*2],ottsel_export_observed[2+r*2]);
    std::printf("slot=%d vectors=%s\n",index,preserved?"PASS":"FAIL");
    return preserved;
  };
  bool all=execute(0,204);all=execute(1,0xabcdef01)&&all;
  all=execute(2,0x1000000ccull)&&all;
  for(size_t stack_size : {size_t(0),size_t(16),size_t(256),size_t(4096)}) {
    expected_stack_size=stack_size;ottsel_export_targets[7]=stack_size;
    context_ok=false;fake_stack_ok=false;
    all=execute(3,0x2000000ccull)&&all;
    require(context_ok && fake_stack_ok,"mips2c fake-stack writes preserve context, return and unwind");
  }
  require(context_ok,"mips2c real ExecutionContext has arguments/pp/st and in-arena fake SP");
  ottsel_export_targets[0]=(u64)&rebound;all=execute(0,205)&&all;
  require(std::memcmp(text.data(),reinterpret_cast<void*>(start),size)==0,"all signed slot instructions unchanged after target rebinding");
  for(auto fn:slots)require(*Ptr<u32>(fn.offset-4).c()==0x1bfec4,"signed slot header unchanged");
  require(all,"all four helpers preserve complete GOAL q8-q15 state");
  std::puts("EXPORT SLOTS PASS; isolated host fixture, no product registry changes");return 0;
}catch(const std::exception& e){std::fprintf(stderr,"FAIL %s\n",e.what());return 1;}

#endif
