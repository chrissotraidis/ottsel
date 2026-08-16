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

int main(int argc, char** argv) {
  const char* path = argc > 1 ? argv[1] : "tfrag.txt";
  Vu1State st;
  int n = load_code(path, st);
  if (n <= 0) {
    return 1;
  }
  printf("loaded %d instructions\n", n);
  // VU data layout (from the live chain's UNPACK imm fields):
  //   mtx-0 at qword 5, mtx-1 at 0x14d, tfrag-data at 0x290,
  //   vertex batch at 0x160, frag batches at 0x381/0x3d4/0x384.
  // Camera matrix rows (identity + a translation so the scene is visible).
  float mtx[16] = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};
  memcpy(&st.data[5 * 4], mtx, 16);
  memcpy(&st.data[0x14d * 4], mtx, 16);
  // tfrag-data at 0x290 (14 qwords): fog, val, ambient, gif tags, scales.
  float fog[4] = {1, 0, 3000, 3072};
  float val[4] = {0.5f, 1.0f, 2048.0f, 0.0f};
  float amb[4] = {1, 1, 1, 1};
  memcpy(&st.data[0x290 * 4], fog, 16);
  memcpy(&st.data[0x291 * 4], val, 16);
  memcpy(&st.data[0x292 * 4], amb, 16);
  // The GIF tag for the output (strgif: tri-strip, tme, nreg=3).
  // The VU builds the GIF header from this; fill with the observed tag words.
  st.data[0x293 * 4 + 0] = 0x00150003;  // gif tag: nreg=3, prim type tri-strip...
  st.data[0x293 * 4 + 1] = 0x00000000;
  st.data[0x293 * 4 + 2] = 0x00000002;  // regs: st, rgbaq, xyzf2
  st.data[0x293 * 4 + 3] = 0x00000421;
  // vertex batch at 0x160: 4 vertices as (x, y, z, w) floats.
  float verts[16] = {
      -100, 0, 0, 1, 100, 0, 0, 1, -100, 100, 0, 1, 100, 100, 0, 1,
  };
  memcpy(&st.data[0x160 * 4], verts, 16);
  // frag list at 0x2a0 (the microcode's hardcoded base vi14).
  // Layout (from L12/L14): word0 >> 16 = frag count (vi02),
  // word1 >> 16 = vertex-list offset relative to vi14 (vi05),
  // qwords +5..+8 = the camera matrix rows.
  st.data[0x2a0 * 4 + 0] = 0x00010000;  // count = 1
  st.data[0x2a0 * 4 + 1] = 0x00b00000;  // vertex list at vi14 + 0xb0 = 0x350
  // the per-frag matrix at vi14+5..+8.
  memcpy(&st.data[0x2a5 * 4], mtx, 16);
  // vertex list at 0x350 (vi01): 8 vertices as (x, y, z, w) ints (upper 16).
  int vx[8] = {0, 100, 0, 100, 0, 100, 0, 100};
  int vy[8] = {0, 0, 100, 100, 0, 0, 100, 100};
  int vz[8] = {0, 0, 0, 0, 0, 0, 0, 0};
  for (int i = 0; i < 8; i++) {
    st.data[0x350 * 4 + i * 4 + 0] = (uint32_t)(int16_t)vx[i] << 16;
    st.data[0x350 * 4 + i * 4 + 1] = (uint32_t)(int16_t)vy[i] << 16;
    st.data[0x350 * 4 + i * 4 + 2] = (uint32_t)(int16_t)vz[i] << 16;
    st.data[0x350 * 4 + i * 4 + 3] = 0x3f800000;  // w = 1.0 (float)
  }
  set_top(0x400);
  st.pc = 8;  // MSCAL imm=8 -> the L3 draw case (bal vi15, L12)
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
