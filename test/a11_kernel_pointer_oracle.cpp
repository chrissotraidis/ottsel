// Execute the actual mutable linker's kind5 function with real Ptr/header types.
// Only sparse ordinary host RW memory is touched; no emitted GOAL is executed.
// Each record names its own segment base: a data record's base is the split
// signed data address minus the source text size, and a code record's base is
// the module's signed code address. The runtime stores base+target, which the
// actual linker reproduces because it adds the same base to patch and target.
#include "game/kernel/common/klink.h"
#include <sys/mman.h>
#include <cstdio>
#include <fstream>
#include <stdexcept>
u8* g_ee_main_mem = nullptr;
#include "actual-ptr-link.inc"
int main(int argc,char**argv) try {
 if(argc!=2)throw std::runtime_error("expected genuine pointer records");
 g_ee_main_mem=static_cast<u8*>(mmap(nullptr,128u*1024*1024,PROT_READ|PROT_WRITE,MAP_PRIVATE|MAP_ANON,-1,0));
 if(g_ee_main_mem==MAP_FAILED)throw std::runtime_error("host arena allocation failed");
 // The fixture hosts the whole 128 MiB arena, so the code base sits in the
 // arena's top quarter and the data bases are real reserved offsets below it.
 const uint32_t code_base=112u*1024*1024, word=1024;
 auto run=[&](const char* kind,uint32_t base,uint32_t patch,uint32_t target,uint32_t expected) {
  ObjectFileHeader header{};header.code_infos[0].offset=base;
  const uint32_t record[2]={patch,target};std::memcpy(g_ee_main_mem+word,record,sizeof(record));
  const uintptr_t address=base+patch;
  if(address<20 || address+24>=128u*1024*1024)throw std::runtime_error("fixture address out of bounds");
  std::memset(g_ee_main_mem+address-16,0xA5,36);
  if(ptr_link_v3(Ptr<u8>(word),&header,0)!=8)throw std::runtime_error("unexpected consumed record length");
  uint32_t actual;std::memcpy(&actual,g_ee_main_mem+address,4);
  if(actual!=expected || (actual&7)!=(target&7))
   throw std::runtime_error("actual linker disagrees with signed pointer value/tag");
  for(unsigned i=0;i<12;++i)
   if(g_ee_main_mem[address-16+i]!=0xA5 || g_ee_main_mem[address+4+i]!=0xA5)
    throw std::runtime_error("pointer write escaped its u32 slot");
  std::printf("PASS actual ptr_link_v3 %s base=%u patch=%u target=%u value=0x%x lowtag=%u\n",
              kind,base,patch,target,actual,actual&7u);
 };
 std::ifstream input(argv[1]);std::string kind;uint32_t base,patch,target,value;unsigned data=0,code_count=0;
 while(input>>kind>>base>>patch>>target>>value) {
 // The linker stores one same-segment address from the record's own base. A
 // data record keeps the reserved arena offset the runtime reproduces, while a
 // code record is checked against that same base plus the raw target.
 if(kind=="data") {
   if(base>=code_base)throw std::runtime_error("invalid data fixture base");
   run("data",base,patch,target,value);++data;
 } else if(kind=="code") {
   if(base!=code_base)throw std::runtime_error("invalid code fixture base");
   run("code",base,patch,target,uint32_t(code_base)+target);++code_count;
  } else throw std::runtime_error("invalid pointer record kind");
 }
 if(!data)throw std::runtime_error("expected genuine Gkernel pointer records");
 if(!code_count)throw std::runtime_error("expected a synthetic code-target control");
 munmap(g_ee_main_mem,128u*1024*1024);
 std::printf("PASS %u data and %u code signed pointer values agree with the independent actual-linker oracle\n",data,code_count);
 return 0;
} catch(const std::exception&e){std::fprintf(stderr,"FAIL %s\n",e.what());return 1;}
