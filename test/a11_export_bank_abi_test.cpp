#define OTTSEL_SIGNED_EXPORT_BANK_ABI_TEST
#include "a11_export_slots_test.cpp"
#include "game/kernel/common/ottsel_signed_exports.h"
extern "C" u8 ottsel_export_bank_begin[],ottsel_export_bank_end[];
int main() try {
  using namespace ottsel::signed_exports;
  g_ee_main_mem=ottsel_bootstrap_arena;
  run(false,false); // Actual allocator and bootstrap Type prefix, isolated fresh process.
  begin_generation();
  std::vector<u8> text(ottsel_export_bank_begin,ottsel_export_bank_end);
  auto execute=[&](Kind kind,uintptr_t target,u32 stack_size,u64 expected) {
    auto fn=Ptr<Function>(bind(kind,target,stack_size));
    require(valid_function(fn.offset) && !valid_function(fn.offset+8),"exact published bank entry membership");
    ottsel_export_selected=reinterpret_cast<u64>(fn.c());
    _call_goal_on_stack_asm_arm64(g_ee_main_mem+0x7ff0000,0,0,(void*)&ottsel_slot_driver,
                                reinterpret_cast<void*>(uintptr_t(s7.offset)),g_ee_main_mem);
    require(ottsel_export_observed[0]==expected,"production bank argument ordering and return value");
    require(ottsel_export_observed[1]==0,"production bank restores arena stack exactly");
    require(vectors_ok(),"production bank preserves full GOAL q8-q15");
    require(*Ptr<u32>(fn.offset-4).c()==0x1bfec4,"production bank immutable function Type");
  };
  execute(Kind::Normal,reinterpret_cast<uintptr_t>(&normal),0,204);
  execute(Kind::Process,reinterpret_cast<uintptr_t>(&process),0,0xabcdef01);
  execute(Kind::Stack,reinterpret_cast<uintptr_t>(&stacked),0,0x1000000ccull);
  for(size_t size:{size_t(0),size_t(16),size_t(256),size_t(4096)}) {
    expected_stack_size=size;context_ok=false;fake_stack_ok=false;
    execute(Kind::Mips2C,reinterpret_cast<uintptr_t>(&mips),u32(size),0x2000000ccull);
    require(context_ok && fake_stack_ok,"production Mips2C context, fake stack writes and v0 return");
  }
  // Each variant consumes a new slot. No descriptor rebinding, reset, or reuse.
  execute(Kind::Normal,reinterpret_cast<uintptr_t>(&rebound),0,205);
  execute(Kind::Nothing,0,0,1);
  execute(Kind::Zero,0,0,0);
  require(usage()==std::array<uint32_t,6>{2,1,1,4,1,1},"fresh immutable bindings have exact per-kind usage");
  require(!std::memcmp(text.data(),ottsel_export_bank_begin,text.size()),"all actual signed bank code and Type tags unchanged");
  std::puts("PRODUCTION EXPORT BANK ABI PASS; isolated host fixture");return 0;
} catch(const std::exception& e) {std::fprintf(stderr,"FAIL %s\n",e.what());return 1;}
