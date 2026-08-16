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
    // The init (mtx-0/1, tfrag-data at 5/0x14d/0x290) is absolute; the
    // per-draw batches land at the VIF base + imm (base = TOP = 0x2a0).
    uint32_t dest = imm;
    if (imm == 0x5 || imm == 0x14d || imm == 0x290) {
      dest = imm;
    } else {
      dest = 0x2a0 + (imm & 0x3ff);
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
  // The L3 draw case (pc=8, `b L3`) has the delay slot `xtop vi14`: the frag
  // base = the VIF TOP register.  With TOP = 0x2a0 the per-draw batches land
  // at TOP + imm (vertex list at 0x400).  Craft the frag-list header at TOP.
  set_top(0x2a0);
  st.pc = 8;
  // Frag list at vi14 = 0x2a0: word0>>16 = count, word1>>16 = vertex offset.
  st.data[0x2a0 * 4 + 0] = 0x00010000;  // count = 1
  st.data[0x2a1 * 4 + 0] = 0x01600000;  // vertex list at 0x2a0 + 0x160 = 0x400
  // Fan path pointers (L26 reads vi14+2/+3/+4 as vertex/page pointers).
  st.data[0x2a2 * 4 + 0] = 0x04000000;
  st.data[0x2a3 * 4 + 0] = 0x04000000;
  st.data[0x2a4 * 4 + 0] = 0x04000000;
  // Per-frag matrix at vi14+5..+8 (identity, w = 1).
  float mtx[16] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  memcpy(&st.data[0x2a5 * 4], mtx, 16);
  // A real vertex quad at 0x400 (the base+0x160 vertex list).
  float verts[16] = {-100, 0, -100, 1, 100, 0, -100, 1,
                     -100, 0, 100,  1, 100, 0, 100,  1};
  memcpy(&st.data[0x400 * 4], verts, 16);
  ottsel_vu1_set_readlog(1);
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
