#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <sys/mman.h>
#include <unistd.h>
#include <vector>

#include "common/common_types.h"
#include "common/goal_constants.h"
#include "common/log/log.h"
#include "common/util/FileUtil.h"
#include "game/kernel/common/kboot.h"
#include "game/kernel/common/kdgo.h"
#include "game/kernel/common/fileio.h"
#include "game/kernel/common/klink.h"
#include "game/kernel/common/klisten.h"
#include "game/kernel/common/kmachine.h"
#include "game/kernel/common/kmalloc.h"
#include "game/kernel/common/kmemcard.h"
#include "game/kernel/common/kprint.h"
#include "game/kernel/common/kscheme.h"
#include "game/kernel/common/memory_layout.h"
#include "game/kernel/jak1/kboot.h"
#include "game/kernel/jak1/kdgo.h"
#include "game/kernel/jak1/klink.h"
#include "game/kernel/jak1/kscheme.h"


#include <stdexcept>
#include <mach/mach.h>
#include <mach/mach_vm.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <fstream>
#include "tools/ottsel_a1_1/a11_module_emitter.h"
#include "common/symbols.h"
extern "C" u8 ottsel_module_arena[];
extern "C" u64 ottsel_method_target,ottsel_method_args[8];
u64 ottsel_method_target=0,ottsel_method_args[8]={};
extern "C" void ottsel_gstate_method_driver();
extern "C" u8 ottsel_module_gstate_s0_code[], ottsel_module_gstate_s2_code[];
extern "C" u8 ottsel_module_gstate_s0_data[], ottsel_module_gstate_s2_data[];
static void check(bool ok, const char* text) {
  if (!ok) throw std::runtime_error(text);
  std::printf("PASS %s\n", text); std::fflush(stdout);
}
static vm_region_basic_info_data_64_t region(uintptr_t wanted,const char* label) {
  mach_vm_address_t address=wanted; mach_vm_size_t length=0;
  vm_region_basic_info_data_64_t info{};mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
  mach_port_t object=MACH_PORT_NULL;
  auto kr=mach_vm_region(mach_task_self(),&address,&length,VM_REGION_BASIC_INFO_64,
                        reinterpret_cast<vm_region_info_t>(&info),&count,&object);
  if(object!=MACH_PORT_NULL)mach_port_deallocate(mach_task_self(),object);
  check(kr==KERN_SUCCESS && address<=wanted && wanted<address+length,"query actual VM region");
  std::printf("REGION %s begin=0x%llx size=0x%llx prot=%d max=%d\n",label,address,length,info.protection,info.max_protection);
  return info;
}
static void prepare_mixed_dependency_arena() {
  auto base=reinterpret_cast<uintptr_t>(ottsel_module_arena);
  constexpr size_t size=128u*1024u*1024u;
  const auto* header=reinterpret_cast<const mach_header_64*>(_dyld_get_image_header(0));
  check(header && header->magic==MH_MAGIC_64,"fixture Mach-O header");
  intptr_t slide=_dyld_get_image_vmaddr_slide(0);
  const auto* command=reinterpret_cast<const load_command*>(header+1);bool owned=false;
  for(uint32_t i=0;i<header->ncmds;++i) {
    if(command->cmd==LC_SEGMENT_64) {
      const auto* seg=reinterpret_cast<const segment_command_64*>(command);
      if(!std::strcmp(seg->segname,"__ARENA")) {
        owned=seg->vmaddr+slide==base && seg->vmsize==size && seg->filesize==0 &&
              seg->initprot==(VM_PROT_READ|VM_PROT_WRITE);
      }
    }
    command=reinterpret_cast<const load_command*>(reinterpret_cast<const uint8_t*>(command)+command->cmdsize);
  }
  check(owned && base%sysconf(_SC_PAGESIZE)==0,"replace only fixture-owned complete zero-fill arena");
  check(reinterpret_cast<uintptr_t>(ottsel_module_gstate_s0_code)>=base+size,
        "signed Gstate text outside replacement range");
  std::vector<u8> code(ottsel_module_gstate_s0_code,ottsel_module_gstate_s0_code+32768);
  auto before=region(base,"arena-before");
  check(before.protection==(VM_PROT_READ|VM_PROT_WRITE),"arena initially RW");
  // Fixture-specific mixed runtime: its own reserved mapping, before any GOAL
  // initialization. Product signed-AOT layout and maxRW policy stay unchanged.
  void* mapped=mmap(reinterpret_cast<void*>(base),size,PROT_READ|PROT_WRITE,
                    MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED,-1,0);
  check(mapped==reinterpret_cast<void*>(base),"anonymous mapping retains exact linked arena address");
  auto after=region(base,"arena-anonymous");
  check(after.protection==(VM_PROT_READ|VM_PROT_WRITE) &&
        (after.max_protection&VM_PROT_EXECUTE),"anonymous research arena permits future RX seals");
  auto signed_code=region(reinterpret_cast<uintptr_t>(ottsel_module_gstate_s0_code),"signed-gstate");
  check(signed_code.protection==(VM_PROT_READ|VM_PROT_EXECUTE),"signed Gstate remains RX");
  check(std::memcmp(code.data(),ottsel_module_gstate_s0_code,code.size())==0,"signed text unchanged by arena replacement");
}
static u32 checked_goal_pointer(const void* pointer) {
  uintptr_t address=reinterpret_cast<uintptr_t>(pointer),base=reinterpret_cast<uintptr_t>(g_ee_main_mem);
  if(address<base || address-base>UINT32_MAX)throw std::runtime_error("invalid GOAL pointer");
  return u32(address-base);
}
static void activate_gstate(const ottsel::a11::SignedModule& module,bool& activated) {
  if(activated)throw std::runtime_error("module already active");
  const u32 type=*(s7+jak1_symbols::FIX_SYM_FUNCTION_TYPE);
  if(type!=module.function_type)throw std::runtime_error("function Type identity mismatch");
  if(module.sha256!=OTTSEL_EXPECTED_GSTATE_SHA256)
    throw std::runtime_error("source identity mismatch");
  u8* code[3]={ottsel_module_gstate_s0_code,nullptr,ottsel_module_gstate_s2_code};
  u8* data[3]={ottsel_module_gstate_s0_data,nullptr,ottsel_module_gstate_s2_data};
  // Check every writable range and signed header before the first mutation.
  for(size_t seg=0;seg<3;++seg) {
    const auto& m=module.segments[seg];if(!m.size)continue;
    const u32 d=checked_goal_pointer(data[seg]);
    if(d<((GLOBAL_HEAP_END-320u)&~0x3fffu) || d+m.size-m.text>GLOBAL_HEAP_END)
      throw std::runtime_error("module data outside reservation");
    for(const auto& slot:m.slots) {
      if(slot.kind==ottsel::a11::ModuleSlot::FunctionTag) {
        u32 header;std::memcpy(&header,code[seg]+slot.offset,4);
        if(header!=type)throw std::runtime_error("immutable header identity mismatch");
      } else if(slot.offset<m.text || slot.offset+4>m.size) {
        throw std::runtime_error("relocation outside mutable data");
      }
    }
  }
  for(size_t seg=0;seg<3;++seg) {
    const auto& m=module.segments[seg];if(!m.size)continue;
    std::memcpy(data[seg],module.bytes.data()+m.base+m.text,m.size-m.text);
    for(const auto& slot:m.slots) {
      using Slot=ottsel::a11::ModuleSlot;
      if(slot.kind==Slot::FunctionTag)continue;
      u32 value;
      if(slot.kind==Slot::TypePointer)value=jak1::intern_type_from_c(slot.name.c_str(),slot.methods).offset;
      else {
        auto symbol=jak1::intern_from_c(slot.name.c_str());
        value=slot.kind==Slot::SymbolAddress?symbol.offset:symbol.offset-s7.offset;
      }
      std::memcpy(data[seg]+slot.offset-m.text,&value,4);
    }
  }
  // Mark before entry: an abnormal top-level must never be blindly replayed.
  activated=true;
  ++*EnableMethodSet;
  call_goal_on_stack(Ptr<Function>(checked_goal_pointer(code[2]+4)),
      reinterpret_cast<u64>(g_ee_main_mem)+EE_MAIN_MEM_SIZE-16,s7.offset,g_ee_main_mem);
  --*EnableMethodSet;
}
static std::string object_directory;
int main(int argc,char** argv) try {
  if(argc!=2)throw std::runtime_error("expected genuine object directory");
  object_directory=argv[1];
  setvbuf(stdout,nullptr,_IONBF,0);
  lg::set_stdout_level(lg::level::debug); lg::initialize();
  prepare_mixed_dependency_arena();
  g_ee_main_mem=ottsel_module_arena;
  const uintptr_t data_offset=ottsel_module_gstate_s0_data-g_ee_main_mem;
  check(data_offset==((GLOBAL_HEAP_END-320u)&~0x3fffu),"linked data reservation matches actual heap bound");
  check(ottsel_module_gstate_s0_code>g_ee_main_mem &&
      uintptr_t(ottsel_module_gstate_s2_code-g_ee_main_mem)<UINT32_MAX,"signed code lies inside GOAL pointer window");
  fileio_init_globals(); kmalloc_init_globals_common(); jak1::kboot_init_globals();
  kdgo_init_globals(); jak1::kdgo_init_globals(); klink_init_globals();
  jak1::kscheme_init_globals(); klisten_init_globals(); kmemcard_init_globals();
  MasterDebug=0; MasterUseKernel=0;
  kinitheap(kglobalheap,Ptr<u8>(HEAP_START),data_offset-HEAP_START);
  kdebugheap.offset=0;
  init_output();
  check(jak1::InitHeapAndSymbol()==0,"actual complete bootstrap without kernel auto-load");
  auto actual=*(s7+jak1_symbols::FIX_SYM_FUNCTION_TYPE);
  std::printf("BOOTSTRAP functionType=0x%x expected=0x1bfec4 heapTop=0x%x\n",actual,kglobalheap->top.offset);
  check(actual==0x1bfec4,"actual bootstrap agrees with immutable function tags");
  check(kglobalheap->top.offset<=data_offset,"bootstrap respects reserved module data");
  const char* dependencies[]={"gcommon","gstring-h","gkernel-h","gkernel","pskernel","gstring","dgo-h"};
  auto stage=kmalloc(kglobalheap,512*1024,KMALLOC_TOP|KMALLOC_ALIGN_64,"signed-module-dependency-stage");
  check(stage.offset!=0,"bounded prerequisite object staging allocation");
  ++*EnableMethodSet;
  for(const char* name:dependencies) {
    std::string path=object_directory+"/"+name+".o";
    std::ifstream file(path,std::ios::binary); check(bool(file),"genuine dependency object exists");
    std::vector<u8> bytes{std::istreambuf_iterator<char>(file),{}};
    check(bytes.size()<512*1024,"dependency fits bounded staging");
    std::printf("DEPENDENCY begin %s bytes=%zu\n",name,bytes.size());
    std::memcpy(stage.c(),bytes.data(),bytes.size());
    auto entry=jak1::link_and_exec(stage,name,int32_t(bytes.size()),kglobalheap,LINK_FLAG_EXECUTE,true);
    check(entry.offset!=0,"genuine dependency top-level executed");
    std::printf("DEPENDENCY end %s entry=0x%x\n",name,entry.offset);
  }
  --*EnableMethodSet;
  auto state=jak1::intern_from_c("state")->value;
  check(state && Ptr<jak1::Type>(state)->parent.offset==jak1::intern_from_c("protect-frame")->value,
        "genuine kernel state Type has real protect-frame parent");
  std::ifstream object(object_directory+"/gstate.o",std::ios::binary);
  auto module=ottsel::a11::parse_signed_module(std::vector<u8>{std::istreambuf_iterator<char>(object),{}},0x1bfec4);
  std::vector<u8> code_before(ottsel_module_gstate_s0_code,ottsel_module_gstate_s0_code+32768);
  std::vector<u8> data_before(ottsel_module_gstate_s0_data,ottsel_module_gstate_s0_data+320);
  bool activated=false,rejected=false;
  auto wrong=module;wrong.function_type^=8;
  try{activate_gstate(wrong,activated);}catch(const std::runtime_error& e){rejected=std::string(e.what())=="function Type identity mismatch";}
  check(rejected && !activated && std::memcmp(data_before.data(),ottsel_module_gstate_s0_data,320)==0,
        "wrong Type rejected before any module writes or execution");
  std::printf("SIGNED GSTATE top begin\n");
  activate_gstate(module,activated);
  check(activated,"complete genuine signed Gstate top returned");
  const char* names[]={"inherit-state","enter-state","send-event-function","looping-code"};
  const u32 offsets[]={308,724,2836,3204};  // gstate entries after the .ret guard (2026-09-22)
  for(size_t i=0;i<4;++i) {
    const u32 registered=jak1::intern_from_c(names[i])->value;
    std::printf("SIGNED REGISTRATION %s actual=0x%x expected=0x%x\n",names[i],registered,
        checked_goal_pointer(ottsel_module_gstate_s0_code+offsets[i]));
    check(registered==checked_goal_pointer(ottsel_module_gstate_s0_code+offsets[i]),"top installed exact signed function");
  }
  auto state_type=Ptr<jak1::Type>(state);
  check(state_type->new_method.offset==checked_goal_pointer(ottsel_module_gstate_s0_code+4),
        "real method_set installed signed state.new");
  check(state_type->print_method.offset==checked_goal_pointer(ottsel_module_gstate_s0_code+580),
        "real method_set installed signed state.print");
  // Exact gstate.gc:240 signature: allocation,type,name,code,trans,enter,exit,event.
  // Real global allocator and real 'nothing' functions; no handlers are invoked
  // by this constructor. The signed driver merely passes eight native GOAL args.
  const u32 nothing=*(s7+jak1_symbols::FIX_SYM_NOTHING_FUNC);
  auto name_symbol=jak1::intern_from_c("signed-gstate-fixture");
  const u64 arguments[8]={s7.offset+jak1_symbols::FIX_SYM_GLOBAL_HEAP,state,name_symbol.offset,
                         nothing,nothing,nothing,nothing,nothing};
  std::memcpy(ottsel_method_args,arguments,sizeof(arguments));
  ottsel_method_target=reinterpret_cast<u64>(state_type->new_method.c());
  const u32 heap_before=kglobalheap->current.offset;
  const u64 made=call_goal_on_stack(Ptr<Function>(checked_goal_pointer(reinterpret_cast<void*>(&ottsel_gstate_method_driver))),
      reinterpret_cast<u64>(g_ee_main_mem)+EE_MAIN_MEM_SIZE-16,s7.offset,g_ee_main_mem);
  check(made>=heap_before && made<kglobalheap->current.offset && made<data_offset,
        "typed state.new allocates through the real global heap");
  check(*Ptr<u32>(u32(made)-4)==state,"typed state.new returns actual state Type instance");
  // stack-frame name has explicit physical offset4 (GOAL basic pointer is +4).
  check(*Ptr<u32>(u32(made))==name_symbol.offset,"typed state.new initializes its real name field");
  std::printf("TYPED METHOD state.new result=0x%llx type=0x%x size=%u\n",made,state,state_type->allocated_size);
  data_before.assign(ottsel_module_gstate_s0_data,ottsel_module_gstate_s0_data+320);rejected=false;
  try{activate_gstate(module,activated);}catch(const std::runtime_error& e){rejected=std::string(e.what())=="module already active";}
  check(rejected && std::memcmp(data_before.data(),ottsel_module_gstate_s0_data,320)==0,
        "active reload rejected before data writes or repeated top-level");
  check(std::memcmp(code_before.data(),ottsel_module_gstate_s0_code,32768)==0,"all signed Gstate text and tags immutable");
  check(region(reinterpret_cast<uintptr_t>(ottsel_module_gstate_s0_data),"active-module-data").protection==3,
        "active module data remains RW");
  check(region(reinterpret_cast<uintptr_t>(ottsel_module_gstate_s0_code),"active-module-code").protection==5,
        "active module code remains RX");
  std::puts("SIGNED GSTATE ACTIVATION PASS; genuine mixed-runtime prerequisites, not signed whole game");
  return 0;
} catch(const std::exception& e) { std::fprintf(stderr,"FAIL %s\n",e.what());return 1;}
