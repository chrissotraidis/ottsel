#pragma once

// Minimal PS2 VU1 interpreter for the Ottsel renderer (S2.2).
// Implements the instruction set used by the game's tfrag/sprite VU
// microprograms so the DMA frag data can be processed on the host.
// VU1 state: 32 VF registers (4x f32), 16 VI registers (u16), ACC, Q, P, I,
// a 4096-qword data memory, and a 2048-instruction code memory.
// The GIF path (XGKICK) writes into the caller's output buffer.

#include <cstdint>
#include <vector>

namespace ottsel_vu1 {

constexpr int kVifRegs = 32;
constexpr int kVviRegs = 16;
constexpr int kDataQwords = 4096;
constexpr int kCodeWords = 2048;

union VfReg {
  float f[4];
  uint32_t u[4];
};

struct Vu1State {
  VfReg vf[kVifRegs] = {};
  uint16_t vi[kVviRegs] = {};
  float acc[4] = {0, 0, 0, 0};
  float q = 0;
  float p = 0;
  float i_reg = 0;
  uint32_t data[kDataQwords * 4] = {};
  uint64_t code[kCodeWords] = {};
  int code_len = 0;
  uint32_t status = 0;
  int pc = 0;
  std::vector<uint32_t> gif_out;
  bool in_delay = false;
  int next_pc = 0;
};

// Set the VIF "top" register (the first qword after the microcode).
void set_top(uint32_t top);
void ottsel_vu1_set_trace(int on);
void ottsel_vu1_set_readlog(int on);
void ottsel_vu1_set_readlog_hook(void (*hook)(const char* msg));
void execute(Vu1State& st, int max_instructions = 400000);

}  // namespace ottsel_vu1
