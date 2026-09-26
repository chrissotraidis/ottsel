#ifdef OTTSEL_SIGNED_EXPORT_BANKS
#include "game/kernel/common/ottsel_signed_exports.h"
#endif
#if defined(OTTSEL_SIGNED_EXPORT_BANKS) || defined(OTTSEL_SIGNED_GAMEDATA_TEST)
#include "game/mips2c/mips2c_table.h"
#endif
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
#include <functional>
#include <sys/wait.h>
#include "game/kernel/common/ottsel_signed_gstate.h"
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
#ifdef OTTSEL_SIGNED_GSTRING_TEST
extern "C" u8 ottsel_module_gstring_s0_code[], ottsel_module_gstring_s0_data[];
static u8 rejection_gstring_data[528];
#endif
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
static std::string object_directory;
static Ptr<u8> gstate_stage;
static void prepare_mixed_dependency_arena() { ottsel::signed_gstate::prepare_arena(); }
static u8 rejection_data[320];
#ifdef OTTSEL_SIGNED_GCOMMON_TEST
static std::vector<u8> rejection_gcommon_data;
#endif
#if defined(OTTSEL_SIGNED_KERNEL_TEST) || defined(OTTSEL_SIGNED_ORDERED_TEST)
static std::vector<std::vector<u8>> rejection_kernel_data;
static size_t rejection_loaded_count;
#endif
static u32 rejection_heap_current, rejection_heap_top;
static void rejection_abort(int) {
#if defined(OTTSEL_SIGNED_KERNEL_TEST) || defined(OTTSEL_SIGNED_ORDERED_TEST)
  size_t index=0;
  for(size_t m=0;m<ottsel::signed_gstate::module_count;++m)
    for(const auto& seg:ottsel::signed_gstate::modules[m]->segments) {
      const auto& bytes=rejection_kernel_data[index++];
      if(seg.data_size && std::memcmp(seg.data,bytes.data(),seg.data_size))_exit(206);
    }
  if(ottsel::signed_gstate::loaded_count()!=rejection_loaded_count)_exit(207);
#endif
#ifdef OTTSEL_SIGNED_GCOMMON_TEST
  const auto& common=*ottsel::signed_gstate::modules[0];
  for(size_t i=0;i<rejection_gcommon_data.size();++i)
    if(g_ee_main_mem[common.reservation_begin+i]!=rejection_gcommon_data[i])_exit(204);
#endif
  // Check in the child before exit: parent COW bytes cannot prove no mutation.
  for(size_t i=0;i<sizeof(rejection_data);++i)
    if(ottsel_module_gstate_s0_data[i]!=rejection_data[i])_exit(201);
#ifdef OTTSEL_SIGNED_GSTRING_TEST
  for(size_t i=0;i<sizeof(rejection_gstring_data);++i)
    if(ottsel_module_gstring_s0_data[i]!=rejection_gstring_data[i])_exit(203);
#endif
  if(kglobalheap->current.offset!=rejection_heap_current || kglobalheap->top.offset!=rejection_heap_top)_exit(202);
  _exit(200);
}
static void rejected_child(const char* label, const std::function<void()>& fn) {
#if defined(OTTSEL_SIGNED_KERNEL_TEST) || defined(OTTSEL_SIGNED_ORDERED_TEST)
  rejection_kernel_data.clear();
  for(size_t m=0;m<ottsel::signed_gstate::module_count;++m)
    for(const auto& seg:ottsel::signed_gstate::modules[m]->segments)
      rejection_kernel_data.emplace_back(seg.data,seg.data+seg.data_size);
  rejection_loaded_count=ottsel::signed_gstate::loaded_count();
#endif
#ifdef OTTSEL_SIGNED_GCOMMON_TEST
  const auto& common=*ottsel::signed_gstate::modules[0];
  rejection_gcommon_data.assign(g_ee_main_mem+common.reservation_begin,
                                g_ee_main_mem+common.reservation_begin+common.data_span_size);
#endif
  std::memcpy(rejection_data,ottsel_module_gstate_s0_data,sizeof(rejection_data));
#ifdef OTTSEL_SIGNED_GSTRING_TEST
  std::memcpy(rejection_gstring_data,ottsel_module_gstring_s0_data,sizeof(rejection_gstring_data));
#endif
  rejection_heap_current=kglobalheap->current.offset;rejection_heap_top=kglobalheap->top.offset;
  pid_t child=fork(); check(child>=0,"fork negative control");
  if(!child){signal(SIGABRT,rejection_abort);fn();_exit(0);} int status=0;waitpid(child,&status,0);
  check(WIFEXITED(status)&&WEXITSTATUS(status)==200,label);
}
static u32 checked_goal_pointer(const void* pointer) {
  uintptr_t address=reinterpret_cast<uintptr_t>(pointer),base=reinterpret_cast<uintptr_t>(g_ee_main_mem);
  if(address<base || address-base>UINT32_MAX)throw std::runtime_error("invalid GOAL pointer");
  return u32(address-base);
}
static u64 signed_link_begin(Ptr<u8> data,const char* name,int32_t size,Ptr<kheapinfo> heap,u32 flags) {
  const u64 name_s=jak1::make_string_from_c(name);
  // GOAL passes (-> string data), not the String object pointer.
  u64 args[5]={data.offset,name_s+sizeof(u32),u64(size),heap.offset,flags};
  return jak1::link_begin(args);
}
static void activate_gstate(const ottsel::a11::SignedModule& module,bool& activated) {
  std::memcpy(gstate_stage.c(),module.bytes.data(),module.bytes.size());
  u32 entry=jak1::link_and_exec(gstate_stage,"gstate",module.bytes.size(),kglobalheap,
      LINK_FLAG_EXECUTE|LINK_FLAG_OUTPUT_LOAD|LINK_FLAG_PRINT_LOGIN,true).offset;
  check(entry==checked_goal_pointer(ottsel_module_gstate_s2_code+4),"existing-loader consumed exact signed Gstate top");
  check(ottsel::signed_gstate::valid_function(entry),"signed top exact-entry validity");
  check(!ottsel::signed_gstate::valid_function(entry+4),"interior instruction is not a function");
  activated=true;
}
#ifdef OTTSEL_SIGNED_EXPORT_BANKS
extern "C" u8 ottsel_export_bank_begin[], ottsel_export_bank_end[];
extern "C" uintptr_t ottsel_export_bank_targets[279][2];
static std::vector<u8> bank_before;
static uintptr_t descriptors_before[279][2];
static std::array<uint32_t,6> usage_before;
static void bank_abort(int) {
  if(std::memcmp(descriptors_before,ottsel_export_bank_targets,sizeof(descriptors_before)))_exit(203);
  if(ottsel::signed_exports::usage()!=usage_before)_exit(204);
  if(std::memcmp(bank_before.data(),ottsel_export_bank_begin,bank_before.size()))_exit(205);
  _exit(200);
}
static void bank_rejected(const char* label,const std::function<void()>& fn) {
  std::memcpy(descriptors_before,ottsel_export_bank_targets,sizeof(descriptors_before));
  usage_before=ottsel::signed_exports::usage();
  pid_t child=fork();check(child>=0,"fork bank rejection control");
  if(!child){signal(SIGABRT,bank_abort);fn();_exit(0);}
  int status=0;waitpid(child,&status,0);
  check(WIFEXITED(status)&&WEXITSTATUS(status)==200,label);
}
#endif
int main(int argc,char** argv) try {
  if(argc!=2)throw std::runtime_error("expected genuine object directory");
  object_directory=argv[1];
  setvbuf(stdout,nullptr,_IONBF,0);
  lg::set_stdout_level(lg::level::debug); lg::initialize();
#ifdef OTTSEL_SIGNED_EXPORT_BANKS
  bank_before.assign(ottsel_export_bank_begin,ottsel_export_bank_end);
#endif
  prepare_mixed_dependency_arena();
  g_ee_main_mem=ottsel_module_arena;
  const uintptr_t data_offset=ottsel_module_gstate_s0_data-g_ee_main_mem;
#ifdef OTTSEL_SIGNED_AGGREGATE_TEST
#ifdef OTTSEL_SIGNED_ORDERED_TEST
  {
    size_t lowest=ottsel::signed_gstate::modules[0]->reservation_begin,released=0;
    for(size_t m=0;m<ottsel::signed_gstate::module_count;++m) {
      const auto& entry=*ottsel::signed_gstate::modules[m];
      if(entry.reservation_begin<lowest)lowest=entry.reservation_begin;
      released+=entry.release_debug;
      std::ifstream member(object_directory+"/"+std::string(entry.name)+".o",std::ios::binary);
      check(bool(member),"generated registry member object exists");
      std::vector<u8> bytes{std::istreambuf_iterator<char>(member),{}};
      check(bytes.size()>=72,"generated registry member object complete");
      u32 debug_text;std::memcpy(&debug_text,bytes.data()+68,4);
      check(entry.release_debug==(debug_text!=0),"module release policy follows its own object debug segment");
    }
    check(ottsel::signed_gstate::heap_end()==lowest && data_offset>=ottsel::signed_gstate::heap_end(),
          "generated registry order reserves every module span before bootstrap");
    check(released>0 && released<ottsel::signed_gstate::module_count,
          "generated registry mixes release and debug policies");
  }
#elif defined(OTTSEL_SIGNED_GCOMMON_TEST)
  check(ottsel::signed_gstate::module_count==
#ifdef OTTSEL_SIGNED_KERNEL_TEST
        8 &&
#else
        3 &&
#endif
        ottsel::signed_gstate::heap_end()==ottsel::signed_gstate::modules[0]->reservation_begin &&
        data_offset>=ottsel::signed_gstate::heap_end(),"shared reservation precedes all selected modules");
  const auto& signed_common=*ottsel::signed_gstate::modules[0];
  check(signed_common.release_debug && !signed_common.segments[1].loaded &&
        signed_common.segments[1].source_size>0 && signed_common.segments[1].text_size==0,
        "genuine Gcommon source debug present but loaded debug absent");
#else
  check(data_offset==((GLOBAL_HEAP_END-848u)&~0x3fffu),"aggregate data begins at actual shared heap bound");
  check(ottsel::signed_gstate::module_count==2 && GLOBAL_HEAP_END-ottsel::signed_gstate::heap_end()==17120,
        "both module spans reserved before bootstrap");
#endif
  std::vector<std::vector<u8>> aggregate_text_before;
  for (size_t m=0;m<ottsel::signed_gstate::module_count;++m)
    for (const auto& segment:ottsel::signed_gstate::modules[m]->segments)
      aggregate_text_before.emplace_back(segment.code,segment.code+segment.text_size);
#ifdef OTTSEL_SIGNED_GSTRING_TEST
  std::vector<u8> gstring_code_before(ottsel_module_gstring_s0_code,ottsel_module_gstring_s0_code+16384);
  check(!ottsel::signed_gstate::valid_function(checked_goal_pointer(ottsel_module_gstring_s0_code+4)),
        "unloaded signed Gstring functions are not callable registrations");
#endif
#else
  check(data_offset==((GLOBAL_HEAP_END-320u)&~0x3fffu),"linked data reservation matches actual heap bound");
  check(ottsel::signed_gstate::manifest.data_span_size==320 &&
        GLOBAL_HEAP_END-ottsel::signed_gstate::heap_end()==736,
        "320-byte data span lies within explicit 736-byte heap reservation");
#endif
  check(ottsel_module_gstate_s0_code>g_ee_main_mem &&
      uintptr_t(ottsel_module_gstate_s2_code-g_ee_main_mem)<UINT32_MAX,"signed code lies inside GOAL pointer window");
  fileio_init_globals(); kmalloc_init_globals_common(); jak1::kboot_init_globals();
  kdgo_init_globals(); jak1::kdgo_init_globals(); klink_init_globals();
  jak1::kscheme_init_globals(); klisten_init_globals(); kmemcard_init_globals();
  MasterDebug=0; MasterUseKernel=0;
  kinitheap(kglobalheap,Ptr<u8>(HEAP_START),ottsel::signed_gstate::heap_end()-HEAP_START);
  kdebugheap.offset=0;
  init_output();
  check(jak1::InitHeapAndSymbol()==0,"actual complete bootstrap without kernel auto-load");
#ifdef OTTSEL_SIGNED_EXPORT_BANKS
  using namespace ottsel::signed_exports;
  check(usage()==std::array<uint32_t,6>{177,3,4,0,1,1},"signed banks account for all 186 real bootstrap exports");
  const u32 rpc=jak1::intern_from_c("rpc-call")->value;
  const uintptr_t bank_base=reinterpret_cast<uintptr_t>(ottsel_export_bank_begin)-reinterpret_cast<uintptr_t>(g_ee_main_mem);
  const u32 rpc_slot=(rpc-u32(bank_base)-4)/stride;
  check(rpc_slot>=180 && rpc_slot<184 &&
        ottsel_export_bank_targets[rpc_slot][0]==reinterpret_cast<uintptr_t>(&RpcCall_wrapper),
        "rpc-call keeps intentional stack-wrapper replacement");
  unsigned normal_rpc=0;
  for(unsigned i=0;i<177;++i)normal_rpc+=ottsel_export_bank_targets[i][0]==reinterpret_cast<uintptr_t>(&RpcCall_wrapper);
  check(normal_rpc==1,"original rpc-call normal slot stays allocated without rebinding");
  bank_rejected("normal bank exhaustion leaves descriptors, counters and text unchanged",[]{bind(Kind::Normal,1);});
  bank_rejected("second bootstrap generation rejected before mutation",[]{begin_generation();});
  bank_rejected("legacy writable stub allocation rejected",[]{jak1::ottsel_stub_alloc(64);});
  bank_rejected("invalid Mips2C stack rejected before allocation",[]{bind(Kind::Mips2C,1,3);});
#endif
  auto actual=*(s7+jak1_symbols::FIX_SYM_FUNCTION_TYPE);
  std::printf("BOOTSTRAP functionType=0x%x expected=0x1bfec4 heapTop=0x%x\n",actual,kglobalheap->top.offset);
  check(actual==0x1bfec4,"actual bootstrap agrees with immutable function tags");
  check(kglobalheap->top.offset<=data_offset,"bootstrap respects reserved module data");
#ifdef OTTSEL_SIGNED_ORDERED_TEST
  // The generated registry order is the dependency and load order.
  std::vector<std::string> dependencies;
  size_t load_n=ottsel::signed_gstate::module_count;
  if(load_n && !std::strcmp(ottsel::signed_gstate::modules[load_n-1]->name,"gstate")) --load_n;
  for(size_t m=0;m<load_n;++m)
    dependencies.emplace_back(ottsel::signed_gstate::modules[m]->name);
#else
  std::vector<std::string> dependencies{"gcommon","gstring-h","gkernel-h","gkernel","pskernel","gstring","dgo-h"};
#endif
  auto stage=kmalloc(kglobalheap,512*1024,KMALLOC_TOP|KMALLOC_ALIGN_64,"signed-module-dependency-stage");
  gstate_stage=stage;
  check(stage.offset!=0,"bounded prerequisite object staging allocation");
#ifdef OTTSEL_SIGNED_AGGREGATE_TEST
  rejected_child("Gstate before Gstring rejects without fallback/mutation",[&]{
    std::ifstream f(object_directory+"/gstate.o",std::ios::binary);
    std::vector<u8> bytes{std::istreambuf_iterator<char>(f),{}};
    std::memcpy(stage.c(),bytes.data(),bytes.size());
    jak1::link_and_exec(stage,"gstate",bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
  });
#endif
#ifdef OTTSEL_SIGNED_ORDERED_TEST
  rejected_child("second registry member before the first rejects without fallback/mutation",[&]{
    std::ifstream f(object_directory+"/"+std::string(ottsel::signed_gstate::modules[1]->name)+".o",std::ios::binary);
    std::vector<u8> bytes{std::istreambuf_iterator<char>(f),{}};
    std::memcpy(stage.c(),bytes.data(),bytes.size());
    jak1::link_and_exec(stage,ottsel::signed_gstate::modules[1]->name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
  });
  // The guard checks the named predecessor, so a later member is rejected even
  // though its index is valid; this is not an index-1 special case.
  if(ottsel::signed_gstate::module_count>=3)rejected_child("third registry member before the second rejects without fallback/mutation",[&]{
    std::ifstream f(object_directory+"/"+std::string(ottsel::signed_gstate::modules[2]->name)+".o",std::ios::binary);
    std::vector<u8> bytes{std::istreambuf_iterator<char>(f),{}};
    std::memcpy(stage.c(),bytes.data(),bytes.size());
    jak1::link_and_exec(stage,ottsel::signed_gstate::modules[2]->name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
  });
#endif
#ifdef OTTSEL_SIGNED_GCOMMON_TEST
  rejected_child("Gstring before Gcommon rejects without fallback/mutation",[&]{
    std::ifstream f(object_directory+"/gstring.o",std::ios::binary);
    std::vector<u8> bytes{std::istreambuf_iterator<char>(f),{}};
    std::memcpy(stage.c(),bytes.data(),bytes.size());
    jak1::link_and_exec(stage,"gstring",bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
  });
#endif
  ++*EnableMethodSet;
#ifdef OTTSEL_SIGNED_GAMEDATA_TEST
  // Real boot registers the Mips2C stub table before any member links
  // (kboot.cpp:115); a genuine GAME member's init path calls __pc-get-mips2c.
  Mips2C::register_all_jak1();
  check(Mips2C::gLinkedFunctionTable.get("ocean-interp-wave")&&
        Mips2C::gLinkedFunctionTable.get("ocean-generate-verts"),
        "genuine Mips2C stubs registered before the GAME member links");
#endif
  size_t dependency_index=0;
  for(const auto& dependency:dependencies) {
    const char* name=dependency.c_str();
    std::string path=object_directory+"/"+name+".o";
    std::ifstream file(path,std::ios::binary); check(bool(file),"genuine dependency object exists");
    std::vector<u8> bytes{std::istreambuf_iterator<char>(file),{}};
    check(bytes.size()<512*1024,"dependency fits bounded staging");
    std::printf("DEPENDENCY begin %s bytes=%zu\n",name,bytes.size());
    std::memcpy(stage.c(),bytes.data(),bytes.size());
#ifdef OTTSEL_SIGNED_GSTRING_TEST
    if(!std::strcmp(name,"gstring")) {
      rejected_child("Gstring source SHA mismatch rejects before writes",[&]{
        stage.c()[bytes.size()-1]^=1;
        jak1::link_and_exec(stage,name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
      });
      rejected_child("Gstring size mismatch rejects before writes",[&]{
        jak1::link_and_exec(stage,name,bytes.size()-1,kglobalheap,LINK_FLAG_EXECUTE,true);
      });
      rejected_child("Gstring bootstrap Type mismatch rejects before writes",[&]{
        *(s7+jak1_symbols::FIX_SYM_FUNCTION_TYPE)^=8;
        jak1::link_and_exec(stage,name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
      });
      rejected_child("Gstring RX protection mismatch rejects before writes",[&]{
        uintptr_t page=uintptr_t(ottsel_module_gstring_s0_code)&~(uintptr_t(sysconf(_SC_PAGESIZE))-1);
        check(mprotect(reinterpret_cast<void*>(page),sysconf(_SC_PAGESIZE),PROT_READ)==0,"make Gstring child nonexecutable");
        jak1::link_and_exec(stage,name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
      });
    }
#endif
#ifdef OTTSEL_SIGNED_GCOMMON_TEST
    if(!std::strcmp(name,"gcommon")) {
      rejected_child("Gcommon original source SHA mismatch rejects before writes",[&]{
        stage.c()[bytes.size()-1]^=1;
        jak1::link_and_exec(stage,name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
      });
      rejected_child("Gcommon original source size mismatch rejects before writes",[&]{
        jak1::link_and_exec(stage,name,bytes.size()-1,kglobalheap,LINK_FLAG_EXECUTE,true);
      });
      rejected_child("Gcommon debug-enabled runtime rejects release module",[&]{
        DebugSegment=1;
        jak1::link_and_exec(stage,name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
      });
      rejected_child("Gcommon bootstrap Type mismatch rejects before writes",[&]{
        *(s7+jak1_symbols::FIX_SYM_FUNCTION_TYPE)^=8;
        jak1::link_and_exec(stage,name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
      });
      rejected_child("Gcommon RX mismatch rejects before writes",[&]{
        uintptr_t page=uintptr_t(signed_common.segments[0].code)&~(uintptr_t(sysconf(_SC_PAGESIZE))-1);
        check(mprotect(reinterpret_cast<void*>(page),sysconf(_SC_PAGESIZE),PROT_READ)==0,"make Gcommon child nonexecutable");
        jak1::link_and_exec(stage,name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
      });
    }
#endif
#ifdef OTTSEL_SIGNED_KERNEL_TEST
    const auto& selected=*ottsel::signed_gstate::modules[dependency_index];
    check(!std::strcmp(selected.name,name),"canonical KERNEL object order agrees with selected registry");
    rejected_child("selected KERNEL SHA mismatch rejects before writes",[&]{
      stage.c()[bytes.size()-1]^=1;
      jak1::link_and_exec(stage,name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
    });
    rejected_child("selected KERNEL size mismatch rejects before writes",[&]{
      jak1::link_and_exec(stage,name,bytes.size()-1,kglobalheap,LINK_FLAG_EXECUTE,true);
    });
#endif
    Ptr<u8> entry;
#ifdef OTTSEL_SIGNED_GAMEDATA_TEST
    check(signed_link_begin(stage,name,int32_t(bytes.size()),kglobalheap,LINK_FLAG_EXECUTE)==1,
          "signed streamed link-begin finished without ordinary resume");
    const auto& streamed=*ottsel::signed_gstate::modules[dependency_index];
    check(!std::strcmp(streamed.name,name),"streamed link-begin name matches registry order");
    entry=Ptr<u8>(checked_goal_pointer(streamed.segments[2].code+4));
#else
    entry=jak1::link_and_exec(stage,name,int32_t(bytes.size()),kglobalheap,LINK_FLAG_EXECUTE,true);
#endif
#ifdef OTTSEL_SIGNED_KERNEL_TEST
    check(entry.offset==checked_goal_pointer(selected.segments[2].code+4) &&
          ottsel::signed_gstate::valid_function(entry.offset) &&
          ottsel::signed_gstate::loaded_count()==dependency_index+1,
          "KERNEL prerequisite executes exact signed top with zero ordinary fallback");
    for(const auto& seg:selected.segments) {
      for(size_t i=0;i<seg.pointer_count;++i) {
        const auto& pointer=seg.pointers[i]; u32 actual_pointer;
        std::memcpy(&actual_pointer,seg.data+pointer.patch-seg.text_size,4);
        // The kept mutable linker stores one same-segment address: the recorded
        // arena offset for a data target, or the signed code base plus the raw
        // target for a code target. The record's own low bits survive both forms.
        const u32 expected=pointer.code
            ?u32(checked_goal_pointer(seg.code+pointer.value))
            :pointer.value;
        check(actual_pointer==expected && (pointer.code ? (actual_pointer&7)==4 : (actual_pointer&7)==2),
              "real signed Gkernel activation preserves same-segment RW pointers");
      }
      for(size_t i=0;i<seg.slot_count;++i) {
        const auto& slot=seg.slots[i];
        if(slot.kind==ottsel::signed_gstate::SlotKind::TypePointer) {
          u32 actual_type;std::memcpy(&actual_type,seg.data+slot.offset-seg.text_size,4);
          check(actual_type==jak1::intern_from_c(slot.name)->value,
                "loaded writable Type slot uses actual kernel bootstrap identity");
        }
      }
    }
    rejected_child("selected KERNEL reload rejects without mutation",[&]{
      jak1::link_and_exec(stage,name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
    });
#endif
    ++dependency_index;
#ifdef OTTSEL_SIGNED_GCOMMON_TEST
    if(!std::strcmp(name,"gcommon")) {
      check(entry.offset==checked_goal_pointer(signed_common.segments[2].code+4) &&
            ottsel::signed_gstate::valid_function(entry.offset),"genuine Gcommon prerequisite executed exact signed top");
      const u32 predicate=jak1::intern_from_c("valid?")->value;
      check(ottsel::signed_gstate::valid_function(predicate) && predicate>=checked_goal_pointer(signed_common.segments[0].code) &&
            predicate<checked_goal_pointer(signed_common.segments[0].code+signed_common.segments[0].text_size),
            "Gcommon top registered valid? inside its exact signed main entries");
      rejected_child("Gcommon duplicate load rejects without fallback/mutation",[&]{
        jak1::link_and_exec(stage,name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
      });
    }
#endif
#ifdef OTTSEL_SIGNED_GSTRING_TEST
    if(!std::strcmp(name,"gstring")) {
      check(ottsel::signed_gstate::valid_function(entry.offset),"Gstring dependency used signed loader entry");
      auto string_type=Ptr<jak1::Type>(*(s7+jak1_symbols::FIX_SYM_STRING_TYPE));
      check(string_type->length_method.offset==checked_goal_pointer(ottsel_module_gstring_s0_code+4),
            "Gstring top registers exact signed string.length");
      check(string_type->new_method.offset==checked_goal_pointer(ottsel_module_gstring_s0_code+820),
            "Gstring top registers exact signed string.new");
      auto equality=jak1::intern_from_c("string=")->value;
      check(equality==checked_goal_pointer(ottsel_module_gstring_s0_code+1332),
            "Gstring top registers exact signed string= function");
      auto invoke=[&](u32 function,u64 a,u64 b) {
        std::memset(ottsel_method_args,0,sizeof(ottsel_method_args));
        ottsel_method_args[0]=a;ottsel_method_args[1]=b;
        ottsel_method_target=reinterpret_cast<u64>(Ptr<Function>(function).c());
        return call_goal_on_stack(Ptr<Function>(checked_goal_pointer(reinterpret_cast<void*>(&ottsel_gstate_method_driver))),
            reinterpret_cast<u64>(g_ee_main_mem)+EE_MAIN_MEM_SIZE-16,s7.offset,g_ee_main_mem);
      };
      auto first=jak1::make_string_from_c("signed-gstring"), equal=jak1::make_string_from_c("signed-gstring"),
           different=jak1::make_string_from_c("signed-gstate");
      check(invoke(string_type->length_method.offset,first,0)==14,"real signed string.length returns14");
      check(invoke(equality,first,equal)!=s7.offset,"real signed string= recognizes equal strings");
      check(invoke(equality,first,different)==s7.offset,"real signed string= rejects unequal strings");
      check(ottsel::signed_gstate::valid_function(equality) && !ottsel::signed_gstate::valid_function(equality+4),
            "only exact loaded Gstring tag entries classify as signed functions");
      rejected_child("Gstring duplicate load rejects without fallback/mutation",[&]{
        jak1::link_and_exec(stage,name,bytes.size(),kglobalheap,LINK_FLAG_EXECUTE,true);
      });
      check(std::memcmp(gstring_code_before.data(),ottsel_module_gstring_s0_code,16384)==0,
            "all Gstring text/tags immutable after real operations");
    }
#endif
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
  bool activated=false;
  std::memcpy(gstate_stage.c(),module.bytes.data(),module.bytes.size());
  rejected_child("wrong bootstrap Type rejected by production loader",[&]{
    *(s7+jak1_symbols::FIX_SYM_FUNCTION_TYPE)^=8;activate_gstate(module,activated);});
  rejected_child("wrong SHA rejected by production loader",[&]{
    auto changed=module;changed.bytes.back()^=1;activate_gstate(changed,activated);});
  rejected_child("non-writable module data rejected before writes",[&]{
    uintptr_t page=uintptr_t(ottsel_module_gstate_s0_data)&~(uintptr_t(sysconf(_SC_PAGESIZE))-1);
    check(mprotect((void*)page,sysconf(_SC_PAGESIZE),PROT_READ)==0,"make child data read-only");
    activate_gstate(module,activated);});
  rejected_child("non-executable signed text rejected before call",[&]{
    check(mprotect(ottsel_module_gstate_s0_code,16384,PROT_READ)==0,"make child text non-executable");
    activate_gstate(module,activated);});
  check(std::memcmp(data_before.data(),ottsel_module_gstate_s0_data,320)==0,"negative children preserved module data");
  std::printf("SIGNED GSTATE top begin\n");
  const bool gstate_already=ottsel::signed_gstate::valid_function(jak1::intern_from_c("enter-state")->value);
  if(gstate_already) activated=true;
  else activate_gstate(module,activated);
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
  rejected_child("duplicate load rejected by production loader",[&]{activate_gstate(module,activated);});
  check(ottsel::signed_gstate::valid_function(state_type->new_method.offset),"registered state.new valid");
  check(!ottsel::signed_gstate::valid_function(state_type->new_method.offset+4),"state.new interior rejected");
  // Execute the actual regenerated GOAL valid? using its declared five arguments.
  auto goal_valid = [&](u64 candidate,u32 expected) {
    const u64 args[8]={candidate,expected,s7.offset,s7.offset,0,0,0,0};
    std::memcpy(ottsel_method_args,args,sizeof(args));
    ottsel_method_target=reinterpret_cast<u64>(Ptr<Function>(jak1::intern_from_c("valid?")->value).c());
    return call_goal_on_stack(Ptr<Function>(checked_goal_pointer(reinterpret_cast<void*>(&ottsel_gstate_method_driver))),
      reinterpret_cast<u64>(g_ee_main_mem)+EE_MAIN_MEM_SIZE-16,s7.offset,g_ee_main_mem)!=s7.offset;
  };
  const u32 signed_new=state_type->new_method.offset;
  for(int expected:{jak1_symbols::FIX_SYM_FUNCTION_TYPE,jak1_symbols::FIX_SYM_BASIC_TYPE}) {
    check(goal_valid(signed_new,*(s7+expected)),"compiled valid? accepts signed function with compatible Type");
    check(!goal_valid(signed_new+4,*(s7+expected)),"compiled valid? rejects signed interior with compatible Type");
  }
  const u32 object_type=*(s7+jak1_symbols::FIX_SYM_OBJECT_TYPE);
  check(!goal_valid(jak1::intern_from_c("valid?")->value,object_type),"compiled valid? preserves ordinary function expected object rejection");
  check(!goal_valid(signed_new,object_type),"compiled valid? preserves signed function expected object rejection");
  check(goal_valid(signed_new,s7.offset),"compiled valid? accepts exact signed function with expected #f");
  check(!goal_valid(signed_new+4,s7.offset),"compiled valid? rejects aligned signed interior with expected #f");
  check(!goal_valid(signed_new,*(s7+jak1_symbols::FIX_SYM_SYMBOL_TYPE)),"compiled valid? rejects wrong expected symbol Type");
  check(goal_valid(u32(made),state),"compiled valid? preserves real heap object Type acceptance");
  check(goal_valid(u32(made),s7.offset),"compiled valid? preserves real heap object untyped acceptance");
  check(!goal_valid((u64(1)<<32)|signed_new,s7.offset),"compiled valid? rejects 64-bit alias of signed entry");
  check(!goal_valid(0x8000000+16000,s7.offset),"compiled valid? rejects unregistered aligned signed-region address");
#ifdef OTTSEL_SIGNED_ORDERED_TEST
  check(ottsel::signed_gstate::loaded_count()==ottsel::signed_gstate::module_count,
        "every generated registry member consumed by the signed loader");
#endif
#ifdef OTTSEL_SIGNED_KERNEL_TEST
  check(ottsel::signed_gstate::loaded_count()==8,"all eight KERNEL objects consumed by signed loader");
  size_t tags=0,pointers=0;
  for(size_t m=0;m<ottsel::signed_gstate::module_count;++m)
    for(const auto& seg:ottsel::signed_gstate::modules[m]->segments) {
      pointers+=seg.pointer_count;
      for(size_t i=0;i<seg.slot_count;++i) if(seg.slots[i].kind==ottsel::signed_gstate::SlotKind::FunctionTag) {
        ++tags;check(ottsel::signed_gstate::valid_function(checked_goal_pointer(seg.code+seg.slots[i].offset+4)),
                     "every retained exact KERNEL function entry is registered");
      }
    }
  check(tags==205 && pointers==6,"full KERNEL retains 205 tags and six tagged pointer relocations");
  auto invoke_kernel=[&](u32 function,u64 a,u64 b,u64 c,u64 d=0) {
    check(ottsel::signed_gstate::valid_function(function),"process operation resolves to signed exact entry");
    const u64 args[8]={a,b,c,d,0,0,0,0};std::memcpy(ottsel_method_args,args,sizeof(args));
    ottsel_method_target=reinterpret_cast<u64>(Ptr<Function>(function).c());
    return u32(call_goal_on_stack(Ptr<Function>(checked_goal_pointer(reinterpret_cast<void*>(&ottsel_gstate_method_driver))),
        reinterpret_cast<u64>(g_ee_main_mem)+EE_MAIN_MEM_SIZE-16,s7.offset,g_ee_main_mem));
  };
  const u32 tree_type=jak1::intern_from_c("process-tree")->value,process_type=jak1::intern_from_c("process")->value;
  const u32 allocation=s7.offset+jak1_symbols::FIX_SYM_GLOBAL_HEAP;
  const u32 tree_new=Ptr<jak1::Type>(tree_type)->new_method.offset;
  const u32 left=invoke_kernel(tree_new,allocation,tree_type,jak1::intern_from_c("signed-parent-left").offset);
  const u32 right=invoke_kernel(tree_new,allocation,tree_type,jak1::intern_from_c("signed-parent-right").offset);
  const u32 child=invoke_kernel(Ptr<jak1::Type>(process_type)->new_method.offset,allocation,process_type,
                              jak1::intern_from_c("signed-child").offset,4096);
  check(*Ptr<u32>(left-4)==tree_type && *Ptr<u32>(right-4)==tree_type && *Ptr<u32>(child-4)==process_type,
        "real signed constructors create two process trees and a typed process");
  // gkernel-h.gc process-tree fields: basic+0 name, +4 mask, +8 parent,
  // +12 brother, +16 child, +20 ppointer, +24 self (32-byte physical Type).
  auto field=[](u32 object,u32 byte_offset)->u32&{return *Ptr<u32>(object+byte_offset);};
  check(field(child,24)==child && field(child,20)==child+24 && field(child,8)==s7.offset,
        "real process constructor initializes self, ppointer and detached parent");
  const u32 reparent=jak1::intern_from_c("change-parent")->value;
  check(invoke_kernel(reparent,child,left,0)==child && field(child,8)==field(left,20) &&
        field(left,16)==field(child,20),"signed change-parent attaches real process to first tree");
  check(invoke_kernel(reparent,child,right,0)==child && field(left,16)==s7.offset &&
        field(child,8)==field(right,20) && field(right,16)==field(child,20),
        "signed change-parent moves process and repairs old/new parent links");
  check(goal_valid(child,process_type),"compiled signed valid? accepts actual constructed process");
  std::puts("SIGNED KERNEL process-tree transition complete; dispatcher scheduling remains unexecuted");
#endif
  jak1::print_object(state_type->new_method.offset);
  jak1::inspect_object(state_type->new_method.offset);
#ifdef OTTSEL_SIGNED_AGGREGATE_TEST
#ifdef OTTSEL_SIGNED_GSTRING_TEST
  check(std::memcmp(gstring_code_before.data(),ottsel_module_gstring_s0_code,16384)==0,
        "Gstate activation preserves Gstring main text/tags");
#endif
  size_t snapshot=0;
  for (size_t m=0;m<ottsel::signed_gstate::module_count;++m) {
    for (const auto& segment:ottsel::signed_gstate::modules[m]->segments) {
      const auto& bytes=aggregate_text_before[snapshot++];
      check(!segment.text_size || std::memcmp(bytes.data(),segment.code,segment.text_size)==0,
            "every segment of every module preserves exact signed text/tags");
    }
  }
#endif
  check(std::memcmp(code_before.data(),ottsel_module_gstate_s0_code,32768)==0,"all signed Gstate text and tags immutable");
  check(region(reinterpret_cast<uintptr_t>(ottsel_module_gstate_s0_data),"active-module-data").protection==3,
        "active module data remains RW");
  check(region(reinterpret_cast<uintptr_t>(ottsel_module_gstate_s0_code),"active-module-code").protection==5,
        "active module code remains RX");
#ifdef OTTSEL_SIGNED_EXPORT_BANKS
  Mips2C::register_all_jak1();
  check(usage()==capacities,"all 93 reachable real Mips2C registrations fill their signed bank");
  std::memcpy(descriptors_before,ottsel_export_bank_targets,sizeof(descriptors_before));
  Mips2C::register_all_jak1();
  check(usage()==capacities && !std::memcmp(descriptors_before,ottsel_export_bank_targets,sizeof(descriptors_before)),
        "repeated real link callbacks preserve existing targets and slot identities");
  bank_rejected("Mips2C bank exhaustion leaves descriptors, counters and text unchanged",[]{bind(Kind::Mips2C,1,16);});
  bank_rejected("second complete bootstrap rejected before registry reset",[]{jak1::InitHeapAndSymbol();});
  const u32 native_test=jak1::intern_from_c("test-function")->value;
  const u64 native_args[8]={1,2,3,4,0,0,0,0};
  std::memcpy(ottsel_method_args,native_args,sizeof(native_args));
  ottsel_method_target=reinterpret_cast<u64>(Ptr<Function>(native_test).c());
  check(call_goal_on_stack(Ptr<Function>(checked_goal_pointer(reinterpret_cast<void*>(&ottsel_gstate_method_driver))),
        reinterpret_cast<u64>(g_ee_main_mem)+EE_MAIN_MEM_SIZE-16,s7.offset,g_ee_main_mem)==30,
        "actual bootstrap native function executes through signed bank ABI");
  check(goal_valid(native_test,s7.offset) && !goal_valid(native_test+8,s7.offset),
        "actual regenerated valid? accepts exact export and rejects its interior");
  check(!std::memcmp(bank_before.data(),ottsel_export_bank_begin,bank_before.size()),"all 279 signed bank slots unchanged after bootstrap and callbacks");
  std::puts("SIGNED EXPORT BANKS PASS; mixed prerequisite code remains runtime loaded");
#endif
  std::puts("SIGNED GSTATE ACTIVATION PASS; genuine mixed-runtime prerequisites, not signed whole game");
  return 0;
} catch(const std::exception& e) { std::fprintf(stderr,"FAIL %s\n",e.what());return 1;}
