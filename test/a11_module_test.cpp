#include "a11_module_emitter.h"
#include "module_layout.h"
#include <iostream>
#include <functional>
using namespace ottsel::a11;
static void require(bool value, const char* text) {
  if (!value) throw std::runtime_error(text);
  std::cout << "PASS " << text << '\n';
}
static std::vector<uint8_t> read(const char* path) {
  std::ifstream f(path, std::ios::binary);
  if (!f) throw std::runtime_error("missing source fixture");
  return {std::istreambuf_iterator<char>(f), {}};
}
static void put(std::vector<uint8_t>& b, size_t p, uint32_t value) {
  std::memcpy(b.data() + p, &value, 4);
}
int main(int argc, char** argv) try {
  if (argc != 6) throw std::runtime_error("expected gstate.o gstring.o output merc-vu1.o ocean-vu0.o");
  auto original = read(argv[1]); auto module = parse_signed_module(original, 0x1bfec4);
  require(module.bytes == original, "complete original object retained");
  require(module.segments[0].text == 16384 && module.segments[0].size == 16664 &&
          module.segments[1].size == 0 && module.segments[2].text == 16384 &&
          module.segments[2].size == 16416, "genuine main/debug/top bounds");
  unsigned tags = 0, slots = 0, cross = 0, distances = 0;
  for (size_t s = 0; s < 3; ++s) {
    for (const auto& slot : module.segments[s].slots) {
      tags += slot.kind == ModuleSlot::FunctionTag;
      slots += slot.kind != ModuleSlot::FunctionTag;
    }
    for (const auto& r : module.segments[s].distances) { ++distances; cross += r.target_segment != s; }
  }
  require(tags == 7 && cross == 6 && distances == 39 && slots == 33,
          "all seven function tags and all writable/cross-segment records inventoried");
  emit_signed_module(module, "gstate", argv[3], kModuleDataOffset);
  require(kModuleDataOffset >= HEAP_START && kModuleDataOffset + 320u <= GLOBAL_HEAP_END,
          "module data explicitly carved from actual global heap tail");
  {
    std::ofstream layout(std::filesystem::path(argv[3]) / "allocator-reservation.json");
    layout << "{\"heap_start\":" << HEAP_START << ",\"old_heap_end\":" << GLOBAL_HEAP_END
           << ",\"required_new_heap_end\":" << kModuleDataOffset << "}\n";
  }
  auto reject = [&](const char* label, const char* reason, auto mutate) {
    auto b = original; mutate(b);
    try { parse_signed_module(std::move(b), 0x1bfec4); }
    catch (const std::runtime_error& e) {
      if (std::string(e.what()).find(reason) == std::string::npos) throw;
      std::cout << "PASS reject " << label << '\n'; return;
    }
    throw std::runtime_error(std::string("accepted invalid ") + label);
  };
  const size_t main_link = 4 + module_word(original, 16), top_link = 4 + module_word(original, 32);
  const auto first = module.segments[0].distances.front();
  size_t distance_link = main_link;
  while (original[distance_link] != 4) {
    auto kind = original[distance_link++];
    while (original[distance_link++]) {}
    if (kind == 2) ++distance_link;
    auto n = module_word(original, distance_link); distance_link += 4 + n * 4;
  }
  reject("short header", "truncated header", [](auto& b) { b.resize(79); });
  reject("bad version", "version", [](auto& b) { put(b, 8, 4); });
  reject("overlapping links", "overlapping link", [&](auto& b) { put(b, 32, uint32_t(main_link - 4)); });
  reject("overlapping segments", "overlapping segments", [&](auto& b) { put(b, 56, module_word(b, 40)); });
  reject("bad text split", "bounds/layout", [](auto& b) { put(b, 64, 16383); });
  reject("distance64", "kind 3", [&](auto& b) { b[distance_link] = 3; });
  reject("malformed pointer in text", "pointer patch in signed text", [&](auto& b) { b[distance_link] = 5; });
  reject("bad target segment", "offsets/target", [&](auto& b) { b[distance_link + 1] = 3; });
  reject("absent debug target", "offsets/target", [&](auto& b) { b[distance_link + 1] = 1; });
  reject("bad target bound", "offsets/target", [&](auto& b) { put(b, distance_link + 6, UINT32_MAX); });
  reject("bad patch origin", "offsets/target", [&](auto& b) { put(b, distance_link + 2, first.patch + 4); });
  reject("wrong ADD base", "instruction pair", [&](auto& b) { put(b, module.segments[0].base + first.patch + 4, 0x910003ff); });
  reject("top unknown relocation", "kind 99", [&](auto& b) { b[top_link] = 99; });
  reject("top unterminated symbol", "name", [&](auto& b) { std::fill(b.begin()+top_link+1, b.begin()+top_link+module_word(b,36), 'A'); });
  reject("top invalid slot count", "count overflow", [&](auto& b) { put(b, top_link + 13, UINT32_MAX); });
  reject("symbol in signed code", "symbol relocation in signed text", [&](auto& b) {
    auto p = main_link + 1; while (b[p++]) {} put(b, p + 4, 4);
  });
  reject("slot outside segment", "patch bounds", [&](auto& b) {
    auto p = main_link + 1; while (b[p++]) {} put(b, p + 4, UINT32_MAX - 3);
  });
  // A kind-2 record is a load-time (name, methods) lookup, not a fixed tag
  // index, so a data-side type carries the object's own name and count. The
  // text side stays function-only, which this rename still rejects.
  reject("non-function type in signed text", "non-function type in signed text", [&](auto& b) {
    auto p = main_link;
    while (b[p] != 2) { ++p; while (b[p++]) {} auto n = module_word(b, p); p += 4 + n * 4; }
    b[p + 1] = 'X';
  });
  {
    auto renamed = original;
    size_t p = main_link;
    for (;;) {
      if (renamed[p] == 0) throw std::runtime_error("no data-side type record in gstate");
      while (renamed[p] != 2) { ++p; while (renamed[p++]) {} auto n = module_word(renamed, p); p += 4 + n * 4; }
      auto q = p + 1; while (renamed[q]) ++q;
      // After name\0 the kind-2 layout is [methods:1][count:4][patches], so
      // the first patch is at q+6 and the record is advanced by count at q+2.
      if (module_word(renamed, q + 6) >= module.segments[0].text) break;
      p = q + 6 + 4 * module_word(renamed, q + 2);
    }
    renamed[p + 1] = 'X';
    auto relaxed = parse_signed_module(renamed, 0x1bfec4);
    bool kept = false;
    for (const auto& s : relaxed.segments[0].slots) if (s.name.front() == 'X') kept = true;
    require(kept, "data-side type name carries the object's own identity");
    std::cout << "PASS data-side type name and count accepted verbatim\n";
  }
  reject("duplicate distance patch", "overlapping relocations", [&](auto& b) {
    put(b, distance_link + 16, module_word(b, distance_link + 2));
    put(b, distance_link + 24, module_word(b, distance_link + 10));
  });
  auto odd = original; put(odd, 64, 16380);
  auto unaligned = parse_signed_module(odd, 0x1bfec4);
  emit_signed_module(unaligned, "gstate_unaligned", argv[3], kModuleDataOffset);
  require(unaligned.segments[0].text == 16380, "non-page-aligned code/data split accepted and emitted");
  auto arbitrary = original; arbitrary[main_link+1] = 'X';
  require(parse_signed_module(arbitrary,0x1bfec4).segments[0].slots[0].name.front() == 'X',
          "general interned symbols retained explicitly in manifest");
  auto address = original;
  put(address, module.segments[0].base + module.segments[0].slots[0].offset, UINT32_MAX);
  require(parse_signed_module(address,0x1bfec4).segments[0].slots[0].kind == ModuleSlot::SymbolAddress,
          "address sentinel distinguished from ST offset");
  auto gstring_bytes=read(argv[2]);
  auto gstring=parse_signed_module(gstring_bytes,0x1bfec4);
  size_t loads=0, references=0;
  for(const auto& seg:gstring.segments) for(const auto& r:seg.distances) {
    ++references;
    if((module_word(gstring_bytes,seg.base+r.patch+4)&0xffc00000)==0xbd400000)++loads;
  }
  require(loads==4 && references==167,"genuine gstring has four scalar LDR consumers among167 references");
  const auto& gs=gstring.segments[0];
  auto load=std::find_if(gs.distances.begin(),gs.distances.end(),[&](const auto& r){
    return (module_word(gstring_bytes,gs.base+r.patch+4)&0xffc00000)==0xbd400000;
  });
  require(load!=gs.distances.end(),"genuine scalar relocation found");
  std::vector<uint8_t> record(14);record[0]=4;record[1]=load->target_segment;
  put(record,2,load->patch);put(record,6,load->target);put(record,10,load->patch);
  auto where=std::search(gstring_bytes.begin(),gstring_bytes.end(),record.begin(),record.end());
  require(where!=gstring_bytes.end(),"actual scalar relocation record found");
  size_t record_offset=where-gstring_bytes.begin();
  auto reject_load=[&](const char* label,const char* reason,auto mutate) {
    auto b=gstring_bytes;mutate(b);
    try {parse_signed_module(std::move(b),0x1bfec4);}
    catch(const std::runtime_error& e){
      if(std::string(e.what()).find(reason)==std::string::npos)throw;
      std::cout<<"PASS reject "<<label<<'\n';return;
    }
    throw std::runtime_error(std::string("accepted invalid ")+label);
  };
  const size_t instruction=gs.base+load->patch+4;
  const uint32_t ldr=module_word(gstring_bytes,instruction);
  reject_load("STR S consumer","instruction pair",[&](auto& b){put(b,instruction,ldr&~0x00400000u);});
  // size=11/opc=01 is the genuine LDR D class, which the emitter does not
  // consume: real objects carry LDR S and LDR Q consumers only.
  reject_load("LDR D class unsupported","instruction pair",[&](auto& b){put(b,instruction,ldr|0x40000000u);});
  reject_load("LDR wrong base","instruction pair",[&](auto& b){put(b,instruction,ldr^(1u<<5));});
  reject_load("LDR unaligned target","scalar LDR target",[&](auto& b){put(b,record_offset+6,load->target+1);});
  reject_load("LDR signed-text target","scalar LDR target",[&](auto& b){put(b,record_offset+6,4);});
  auto v31=gstring_bytes;put(v31,instruction,(ldr&~31u)|31u);
  require(parse_signed_module(v31,0x1bfec4).segments[0].distances.size()==gs.distances.size(),
          "SIMD destination31 is a valid register, not SP");
  // The same ADRP + unsigned-immediate SIMD&FP record with size=00/opc=11 is a
  // 128-bit LDR Q. The assembler scales its imm12 by sixteen, so a genuine quad
  // must be sixteen-aligned in the section the record already resolves and fit
  // entirely inside the destination static data. Emitting it as LDR D would
  // reassemble with different operation bits and a sixteen-times short offset.
  auto quad=std::find_if(gs.distances.begin(),gs.distances.end(),[&](const auto& r){
    return (module_word(gstring_bytes,gs.base+r.patch+4)&0xffc00000)==0xbd400000&&!(r.target&15u);
  });
  require(quad!=gs.distances.end(),"genuine gstring has a sixteen-aligned scalar consumer");
  auto ldr_q=[&](uint32_t target){
    auto b=gstring_bytes;put(b,record_offset+6,target);
    put(b,instruction,0x3dc00000u|(((ldr>>5)&31u)<<5)|(ldr&31u));
    return b;
  };
  auto quad_module=parse_signed_module(ldr_q(quad->target),0x1bfec4);
  require(quad_module.segments[0].distances.size()==gs.distances.size(),
          "genuine LDR Q consumer accepted");
  std::cout<<"PASS accept genuine LDR Q consumer\n";
  // Both negative controls must really be LDR Q. Flipping only the record target
  // would leave the genuine scalar LDR S in place, and that accepts any 4-aligned
  // target, so the parser would legitimately accept the mutation.
  reject_load("LDR Q unaligned target","LDR Q target",
              [&](auto& b){b=ldr_q(quad->target+4);});
  // A complete quad must also fit inside static data. The genuine gstring data
  // segment ends four bytes past its last sixteen-aligned slot, so that slot is
  // a valid sixteen-aligned target whose sixteen bytes run past the end.
  const uint32_t data_size=gstring.segments[quad->target_segment].size;
  require((data_size&15)==12,"genuine gstring data segment ends in a twelve-byte tail");
  reject_load("LDR Q target past data","LDR Q target",
              [&](auto& b){b=ldr_q(data_size&~15u);});
  // Emit the same object carrying that one quad consumer so the linked fixture
  // proves the assembler writes LDR Q and the oracle resolves a scale-16 offset.
  emit_signed_module(quad_module,"gstring_quad",argv[3],kModuleDataOffset);
  emit_signed_module(gstring,"gstring",argv[3],kModuleDataOffset);
  // A declaration-only object keeps its static data in a textless main segment
  // and its code in segment 2. The emitter must load that data template whole,
  // keep every record on the data side and never invent a tag or a text slot.
  auto vu1_bytes = read(argv[4]);
  auto vu1 = parse_signed_module(vu1_bytes, 0x1bfec4);
  require(vu1.segments[0].text == 0 && vu1.segments[0].size == 12 &&
          vu1.segments[1].size == 0 && vu1.segments[2].text == 16384 &&
          vu1.segments[2].size == 16388, "genuine textless main segment bounds");
  require(vu1.segments[0].slots.empty() && vu1.segments[0].distances.empty() &&
          vu1.segments[0].pointers.empty(),
          "data-only main segment carries no text-side record");
  emit_signed_module(vu1, "merc-vu1", argv[3], kModuleDataOffset);
  // ocean-vu0 has the same shape with a 253-byte, non-sixteen-multiple main
  // segment and one genuine data-side type record, so it also covers the
  // sixteen-byte placement of an unaligned data-only template.
  auto vu0_bytes = read(argv[5]);
  auto vu0 = parse_signed_module(vu0_bytes, 0x1bfec4);
  require(vu0.segments[0].text == 0 && vu0.segments[0].size == 253 &&
          vu0.segments[0].slots.size() == 2 && vu0.segments[0].distances.empty() &&
          vu0.segments[0].pointers.empty(),
          "unaligned data-only main segment keeps its data-side records");
  unsigned data_type_records = 0;
  for (const auto& slot : vu0.segments[0].slots)
    data_type_records += slot.kind == ModuleSlot::TypePointer &&
                         slot.name == "string" && slot.methods == 9;
  require(data_type_records == 2, "data-only type records are data-side name+count");
  emit_signed_module(vu0, "ocean-vu0", argv[3], kModuleDataOffset);
  // A textless segment cannot carry an instruction-pair rewrite: flipping the
  // genuine first record to kind 4 must fail closed before any bounds read.
  auto textless = vu0_bytes;
  textless[4 + module_word(vu0_bytes, 16)] = 4;
  bool textless_rejected = false;
  try { parse_signed_module(std::move(textless), 0x1bfec4); }
  catch (const std::runtime_error& e) {
    textless_rejected =
        std::string(e.what()).find("distance record in textless segment") != std::string::npos;
  }
  require(textless_rejected, "distance record in a textless segment rejected");
  std::cout << "COMPLETE GSTATE/GSTRING/DATA-ONLY MODULE PASS; emission only, no loader execution\n";
  return 0;
} catch (const std::exception& e) { std::cerr << "FAIL " << e.what() << '\n'; return 1; }
