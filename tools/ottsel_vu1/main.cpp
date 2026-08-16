#include "vu1.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

using namespace ottsel_vu1;

// Load a .word microcode listing (pairs: lower, upper) into the code memory.
static int load_code(const char* path, Vu1State& st) {
  FILE* f = fopen(path, "rb");
  if (!f) {
    fprintf(stderr, "cannot open %s\n", path);
    return -1;
  }
  char line[256];
  std::vector<uint32_t> words;
  while (fgets(line, sizeof(line), f)) {
    const char* p = strstr(line, "0x");
    if (!p) {
      continue;
    }
    unsigned v = 0;
    sscanf(p, "0x%x", &v);
    words.push_back(v);
  }
  fclose(f);
  int n = (int)(words.size() / 2);
  for (int i = 0; i < n && i < kCodeWords; i++) {
    st.code[i] = ((uint64_t)words[i * 2 + 1] << 32) | words[i * 2];
  }
  st.code_len = n;
  return n;
}

// Load the app's tfrag-vu-data.bin dump (records: {imm,num,size,0}+payload,
// 0xffffffff = MSCAL/MSCALF marker) and run the interpreter over one frame.
static int load_dump(const char* path, Vu1State& st, std::vector<int>& mscals) {
  FILE* f = fopen(path, "rb");
  if (!f) {
    fprintf(stderr, "cannot open %s\n", path);
    return -1;
  }
  fseek(f, 0, SEEK_END);
  long sz = ftell(f);
  fseek(f, 0, SEEK_SET);
  std::vector<uint8_t> buf(sz);
  fread(buf.data(), 1, sz, f);
  fclose(f);
  size_t off = 8;
  int recs = 0;
  bool init_seen = false;  // records after the init use the VIF offset base
  while (off + 16 <= buf.size()) {
    uint32_t imm, num, size, z;
    memcpy(&imm, buf.data() + off, 4);
    memcpy(&num, buf.data() + off + 4, 4);
    memcpy(&size, buf.data() + off + 8, 4);
    memcpy(&z, buf.data() + off + 12, 4);
    off += 16;
    if (imm == 0xffffffff) {
      mscals.push_back((int)num);
      continue;
    }
    if (off + size > buf.size()) {
      break;
    }
    // The init (mtx-0=5, mtx-1=0x14d, tfrag-data=0x290) uses absolute
    // addresses; the per-draw unpacks are offsets from the VIF data base
    // (TOP - OFST = 0x2a0, the microcode's vi14).
    uint32_t dest = imm;  // absolute
    if (imm == 0x381) {
      // the per-draw block also mirrors at the frag base (vi14 = 0x2a0)
      memcpy(&st.data[0x2a0 * 4], buf.data() + off, size);
    }
    if (dest < kDataQwords && num <= 256 && size <= (kDataQwords - (int)dest) * 16) {
      memcpy(&st.data[dest * 4], buf.data() + off, size);
    }
    off += size;
    recs++;
    if (recs > 5000) {
      break;
    }
  }
  return recs;
}

int main(int argc, char** argv) {
  const char* path = argc > 1 ? argv[1] : "tfrag.txt";
  const char* dump = argc > 2 ? argv[2] : nullptr;
  Vu1State st;
  int n = load_code(path, st);
  if (n <= 0) {
    return 1;
  }
  printf("loaded %d instructions\n", n);
  std::vector<int> mscals;
  if (dump) {
    int recs = load_dump(dump, st, mscals);
    printf("loaded %d dump records; %zu mscals\n", recs, mscals.size());
  } else {
    printf("no dump; synthetic data only\n");
    mscals.push_back(0);
  }
  set_top(0x400);
  st.pc = 8;  // L3 draw case: bal vi15, L12
  execute(st, 200000);
  printf("executed; pc=%d gif_out_words=%zu\n", st.pc, st.gif_out.size());
  for (size_t i = 0; i < st.gif_out.size() && i < 64; i++) {
    printf("%08x ", st.gif_out[i]);
    if ((i & 3) == 3) {
      printf("\n");
    }
  }
  printf("\n");
  return 0;
}
