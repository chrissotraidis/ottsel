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
    // S2.2 BOT18c: the VIF UNPACK dest = (imm & 0x8000 ? TOPS : 0) +
    // (imm & 0x3ff); all observed imms have bit15 = 0, so every destination
    // is ABSOLUTE VU data memory (5, 0x14d, 0x290, 0x160, 0x381, 0x384,
    // 0x3d4).  The earlier 0x2a0 + (imm & 0x3ff) mapping misplaced every
    // per-draw batch and left the frag-list area empty.
    uint32_t dest = imm;
    dest = imm & 0x3ff;
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
  set_top(0x2a0);
  st.pc = 8;
  // S2.2 (2026-08-15): with a real dump, use the REAL frag-list header at
  // TOP (vi14 = 0x2a0) instead of the synthetic one, so the XGKICK output is
  // produced from the village's actual tfrag batches.
  if (dump) {
    printf("real frag list at 0x2a0..0x2a8:\n");
    for (int i = 0; i < 12; i++) {
      printf("  [0x%x] = 0x%08x\n", 0x2a0 + i, st.data[(0x2a0 + i) * 4]);
    }
    printf("page batches at 0x674/0x624 (frag ptrs +0x148):\n");
    for (int i = 0; i < 16; i++) {
      printf("  [0x674+%d] = 0x%08x\n", i, st.data[(0x674 + i) * 4]);
    }
  } else {
    // Synthetic fallback: frag list count=1, vertex list at 0x400, identity
    // matrix, and a real vertex quad.
    st.data[0x2a0 * 4 + 0] = 0x00010000;  // count = 1
    st.data[0x2a1 * 4 + 0] = 0x01600000;  // vertex list at 0x2a0 + 0x160 = 0x400
    st.data[0x2a2 * 4 + 0] = 0x052c0000;  // 0x52c + 0x148 = 0x674
    st.data[0x2a3 * 4 + 0] = 0x04dc0000;  // 0x4dc + 0x148 = 0x624
    st.data[0x2a4 * 4 + 0] = 0x04dc0000;
    float mtx[16] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
    memcpy(&st.data[0x2a5 * 4], mtx, 16);
    float verts[16] = {-100, 0, -100, 1, 100, 0, -100, 1,
                       -100, 0, 100,  1, 100, 0, 100,  1};
    memcpy(&st.data[0x400 * 4], verts, 16);
  }
  ottsel_vu1_set_readlog(0);
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
