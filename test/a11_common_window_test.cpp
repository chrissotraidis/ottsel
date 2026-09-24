// Isolated address-model experiment, not a replacement for runtime allocation.
#include "game/kernel/jak1/kscheme.h"
#include <mach/mach.h>
#include <mach/vm_map.h>
#include <array>
#include <cstdio>
#include <cstring>
#include <limits>
#include <stdexcept>

u8* g_ee_main_mem = nullptr;
extern "C" u8 ottsel_window_arena[];
extern "C" void ottsel_window_add2();
extern "C" u64 _call_goal_asm_arm64(u64, u64, u64, void*, void*, void*) asm("_call_goal_asm_arm64");
constexpr u32 kType = 0x140004; // Explicit fixture identity; production types are dynamic.
constexpr u32 kObject = 0x141004;
static void require(bool condition, const char* name) {
  if (!condition) throw std::runtime_error(name);
  std::printf("PASS %s\n", name);
}
static u32 checked(uintptr_t pointer, uintptr_t base) {
  if (pointer < base || pointer - base > UINT32_MAX)
    throw std::runtime_error("pointer outside unsigned32 GOAL window");
  return static_cast<u32>(pointer - base);
}
static bool protection(const void* pointer, vm_prot_t yes, vm_prot_t no) {
  vm_address_t address = reinterpret_cast<vm_address_t>(pointer);
  vm_size_t size = 0;
  vm_region_basic_info_data_64_t info{};
  mach_msg_type_number_t count = VM_REGION_BASIC_INFO_COUNT_64;
  mach_port_t object = MACH_PORT_NULL;
  auto result = vm_region_64(mach_task_self(), &address, &size, VM_REGION_BASIC_INFO_64,
                            reinterpret_cast<vm_region_info_t>(&info), &count, &object);
  if (object != MACH_PORT_NULL) mach_port_deallocate(mach_task_self(), object);
  const auto target = reinterpret_cast<uintptr_t>(pointer);
  return result == KERN_SUCCESS && address <= target && target-address < size &&
         (info.protection & yes) == yes && !(info.protection & no);
}
int main() try {
  const auto base = reinterpret_cast<uintptr_t>(ottsel_window_arena);
  const auto entry = reinterpret_cast<uintptr_t>(&ottsel_window_add2);
  // Verify linker layout before treating this memory as the EE space.
  const u32 function_offset = checked(entry, base);
  require(function_offset >= EE_MAIN_MEM_SIZE && function_offset % 8 == 4,
          "signed function follows 128MiB arena and has basic-object alignment");
  require(protection(ottsel_window_arena, VM_PROT_READ|VM_PROT_WRITE, VM_PROT_EXECUTE) &&
          protection(ottsel_window_arena+EE_MAIN_MEM_SIZE-1, VM_PROT_READ|VM_PROT_WRITE, VM_PROT_EXECUTE),
          "entire arena endpoints RW without execute permission");
  require(protection(reinterpret_cast<void*>(entry-4), VM_PROT_READ|VM_PROT_EXECUTE, VM_PROT_WRITE),
          "function and immutable type header in RX segment");
  g_ee_main_mem = ottsel_window_arena;
  Ptr<Function> function(function_offset);
  require(reinterpret_cast<uintptr_t>(function.c()) == entry,
          "actual Ptr<Function> round trip through g_ee_main_mem");
  std::array<u8,12> original{};
  std::memcpy(original.data(), reinterpret_cast<void*>(entry-4), original.size());
  const u32 tag = *Ptr<u32>(function.offset-4).c();
  require(tag == kType, "function-4 tag is the declared GOAL Type offset");
  Ptr<jak1::Type> type(tag);
  type.c()->num_methods = 9;
  type.c()->new_method = function;
  *Ptr<u32>(kObject-4).c() = tag;
  *Ptr<u64>(kObject+4).c() = 40;
  require(Ptr<jak1::Type>(*Ptr<u32>(kObject-4).c()).c() == type.c(),
          "heap object and signed function share actual Type identity");
  auto method = type.c()->get_method(0);
  const auto result = _call_goal_asm_arm64(*Ptr<u64>(kObject+4).c(),2,0,method.c(),
                                         reinterpret_cast<void*>(uintptr_t(kObject)),g_ee_main_mem);
  require(result == 42, "production entry bridge calls real H2.5 GOAL add2 through Type method Ptr");
  require(checked(base,base)==0 && checked(base+UINT32_MAX,base)==UINT32_MAX,
          "unsigned32 address boundaries round trip");
  for (uintptr_t invalid : {base-1, base+uintptr_t(UINT32_MAX)+1}) {
    bool rejected = false;
    try { (void)checked(invalid,base); } catch (const std::runtime_error&) { rejected=true; }
    require(rejected,"out-of-window address rejected before Ptr construction");
  }
  require(std::memcmp(original.data(),reinterpret_cast<void*>(entry-4),original.size())==0,
          "signed instructions and function tag unchanged");
  std::printf("COMMON WINDOW PASS base=%p fn=%p offset=0x%x; fixed fixture Type only, full runtime unmodified\n",
              g_ee_main_mem, function.c(), function.offset);
  return 0;
} catch (const std::exception& error) { std::fprintf(stderr,"FAIL %s\n",error.what());return 1; }
