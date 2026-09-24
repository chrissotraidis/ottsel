#include "a11_relocation_validation.h"
#include <fstream>
#include <functional>
#include <iostream>
#include <iterator>
using Bytes = std::vector<uint8_t>;
static Bytes read(const char* path) {
  std::ifstream input(path, std::ios::binary);
  if (!input) throw std::runtime_error(std::string("missing fixture ") + path);
  return Bytes(std::istreambuf_iterator<char>(input), {});
}
static uint32_t get(const Bytes& b, size_t p) { uint32_t v; std::memcpy(&v,b.data()+p,4); return v; }
static void put(Bytes& b, size_t p, uint32_t v) { std::memcpy(b.data()+p,&v,4); }
int main(int argc, char** argv) try {
  if (argc != 3) throw std::runtime_error("expected genuine slice.obj and gstring.o");
  const auto original = read(argv[1]);
  ottsel::a11::validate_slice(original, "genuine slice.obj");
  std::cout << "PASS genuine slice.obj\n";
  auto reject = [](const char* label, const Bytes& b, const char* expected) {
    try { ottsel::a11::validate_slice(b, label); }
    catch (const std::runtime_error& e) {
      if (std::string(e.what()).find(expected) == std::string::npos) throw;
      std::cout << "PASS reject " << e.what() << '\n'; return;
    }
    throw std::runtime_error(std::string("unexpected acceptance: ") + label);
  };
  reject("genuine gstring.o", read(argv[2]), "unsupported symbol");
  const size_t link = 4 + get(original,16), end = link + get(original,20);
  size_t distance = link, type = link;
  while (original[distance] != 4) {
    const auto kind = original[distance++];
    while (original[distance++]) {}
    if (kind == 2) { type = distance-10; ++distance; }
    distance += 4 + 4 * get(original,distance);
  }
  const size_t base = get(original,76) + get(original,40);
  const size_t patch = get(original,distance+10);
  auto check = [&](const char* label, const char* expected, auto mutate) {
    auto b = original; mutate(b); reject(label,b,expected);
  };
  check("short header","truncated header",[](Bytes& b){b.resize(79);});
  check("bad version","version",[](Bytes& b){put(b,8,99);});
  check("bad segment","segment bounds",[](Bytes& b){put(b,44,0xffffffff);});
  check("unaligned layout","layout",[](Bytes& b){put(b,64,0x3fff);});
  check("unknown symbol","unsupported symbol",[&](Bytes& b){b[link+1]='X';});
  check("unterminated name","unterminated",[&](Bytes& b){std::fill(b.begin()+link+1,b.begin()+end,65);});
  check("huge count","count overflow",[&](Bytes& b){put(b,link+7,0xffffffff);});
  check("bad symbol offset","patch offset",[&](Bytes& b){put(b,link+11,0xffffffff);});
  check("unknown type","unsupported type",[&](Bytes& b){b[type+1]='X';});
  check("distance64","kind 3",[&](Bytes& b){b[distance]=3;});
  check("pointer","kind 5",[&](Bytes& b){b[distance]=5;});
  check("unknown kind","kind 99",[&](Bytes& b){b[distance]=99;});
  check("non-main target","target segment",[&](Bytes& b){b[distance+1]=2;});
  check("bad target","distance32 offsets",[&](Bytes& b){put(b,distance+6,0xffffffff);});
  check("different patch","distance32 offsets",[&](Bytes& b){put(b,distance+10,patch+4);});
  check("bad instruction","instruction",[&](Bytes& b){put(b,base+patch,0);});
  check("bad ADRP consumer","consumer",[&](Bytes& b){put(b,base+patch,0x90000000);put(b,base+patch+4,0);});
  check("wrong ADRP base register","consumer",[&](Bytes& b){put(b,base+patch,0x90000004);put(b,base+patch+4,0x910000a7);});
  check("unsorted distances","distance32 offsets",[&](Bytes& b){put(b,distance+16,patch);put(b,distance+24,patch);});
  check("wrong type method count","method count",[&](Bytes& b){b[type+10]=8;});
  {
    auto b = original; put(b,base+patch,0x90000004); put(b,base+patch+4,0x91000087);
    ottsel::a11::validate_slice(b,"synthetic ADRP x4 / ADD x7,x4");
    std::cout << "PASS supported ADRP with different ADD destination/base registers\n";
  }
  check("truncated record","truncated distance32",[&](Bytes& b){put(b,20,distance-link+4);});
  check("missing terminator","missing link terminator",[&](Bytes& b){put(b,20,end-link-1);});
  std::cout << "A11 RELOCATION PASS (main-slice validation; whole-object linking unimplemented)\n";
  return 0;
} catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
