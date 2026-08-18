#include "vu1.h"

#include <cmath>
#include <cstdio>

namespace ottsel_vu1 {

namespace {

// S2.2 BOT21d: readlog output hook.  The shell sets this to route the VU
// memory-read trace into the runtime log; the standalone tool keeps it null
// and falls back to printf.
void (*g_readlog_hook)(const char* msg) = nullptr;

// -------------------------------------------------------------------------
// Decode (mirrors decompiler/VuDisasm/VuDisassembler.cpp field extraction).
// -------------------------------------------------------------------------

inline int up_op6(uint32_t in) { return in & 0b111111; }
inline int up_op11(uint32_t in) { return in & 0b11111111111; }
inline int up_dest(uint32_t in) { return 0b1111 & (in >> 21); }
inline int up_ft(uint32_t in) { return 0b11111 & (in >> 16); }
inline int up_fs(uint32_t in) { return 0b11111 & (in >> 11); }
inline int up_fd(uint32_t in) { return 0b11111 & (in >> 6); }
inline int up_bc(uint32_t in) { return 0b11 & in; }
inline int lo_op(uint32_t in) { return in >> 25; }
inline int lo_it(uint32_t in) { return 0b11111 & (in >> 16); }
inline int lo_is(uint32_t in) { return 0b11111 & (in >> 11); }
inline int lo_id(uint32_t in) { return 0b11111 & (in >> 6); }
inline int lo_imm11(uint32_t in) { return (int)(in & 0b11111111111); }
inline int lo_imm5(uint32_t in) {
  // The IADDI immediate lives in bits 6-10 (the id field), sign-extended.
  int v = (int)((in >> 6) & 0b11111);
  if (v & 0b10000) {
    v -= 32;  // sign extend
  }
  return v;
}
inline int lo_imm15(uint32_t in) {
  // The disassembler's upper_imm15_unsigned: bits 0-10 + bits 21-24.
  return (int)((in & 0x7ff) | (((in >> 21) & 0xf) << 11));
}

enum class Op {
  NOP, ADD, ADDi, ADDq, ADDbc, ADDA, ADDAbc, SUB, SUBi, SUBbc, MUL, MULi, MULq,
  MULbc, MULA, MULAq, MULAbc, MADD, MADDq, MADDbc, MADDA, MADDAbc, MSUBbc,
  MSUBAbc, MAX, MAXi, MAXbc, MINI, MINIi, MINIbc, OPMULA, OPMSUB, FTOI0, FTOI4,
  FTOI12, ITOF0, ITOF12, ITOF15, CLIP,
  // lower
  LQ, LQD, LQI, SQ, SQD, SQI, ILW, ISW, ILWR, ISWR, IADD, IADDI, IADDIU, IAND,
  IOR, ISUB, ISUBIU, MOVE, MR32, MFIR, MTIR, DIV, SQRT, RSQRT, WAITQ, WAITP,
  FCAND, FCOR, FCSET, FCGET, FSAND, FMAND, IBEQ, IBNE, IBGEZ, IBGTZ, IBLEZ,
  IBLTZ, B, BAL, JR, JALR, XGKICK, XTOP, MFP, ESADD, ELENG, ERLENG, ESUM,
  INVALID
};

Op up_kind(uint32_t in) {
  int op6 = up_op6(in);
  switch (op6) {
    case 0b000000: case 0b000001: case 0b000010: case 0b000011: return Op::ADDbc;
    case 0b000100: case 0b000101: case 0b000110: case 0b000111: return Op::SUBbc;
    case 0b001000: case 0b001001: case 0b001010: case 0b001011: return Op::MADDbc;
    case 0b001100: case 0b001101: case 0b001110: case 0b001111: return Op::MSUBbc;
    case 0b010000: case 0b010001: case 0b010010: case 0b010011: return Op::MAXbc;
    case 0b010100: case 0b010101: case 0b010110: case 0b010111: return Op::MINIbc;
    case 0b011000: case 0b011001: case 0b011010: case 0b011011: return Op::MULbc;
    case 0b011100: return Op::MULq;
    case 0b011101: return Op::MAXi;
    case 0b011110: return Op::MULi;
    case 0b011111: return Op::MINIi;
    case 0b100000: return Op::ADDq;
    case 0b100001: return Op::MADDq;
    case 0b100010: return Op::ADDi;
    case 0b100110: return Op::SUBi;
    case 0b101000: return Op::ADD;
    case 0b101001: return Op::MADD;
    case 0b101010: return Op::MUL;
    case 0b101011: return Op::MAX;
    case 0b101100: return Op::SUB;
    case 0b101110: return Op::OPMSUB;
    case 0b101111: return Op::MINI;
    case 0b111100: case 0b111101: case 0b111110: case 0b111111: {
      // op11 decode
      int op11 = up_op11(in);
      switch (op11) {
        case 0b00000'1111'00: case 0b00000'1111'01: case 0b00000'1111'10:
        case 0b00000'1111'11: return Op::ADDAbc;
        case 0b00010'1111'00: case 0b00010'1111'01: case 0b00010'1111'10:
        case 0b00010'1111'11: return Op::MADDAbc;
        case 0b00011'1111'00: case 0b00011'1111'01: case 0b00011'1111'10:
        case 0b00011'1111'11: return Op::MSUBAbc;
        case 0b00100'1111'00: return Op::ITOF0;
        case 0b00100'1111'10: return Op::ITOF12;
        case 0b00100'1111'11: return Op::ITOF15;
        case 0b00101'1111'00: return Op::FTOI0;
        case 0b00101'1111'01: return Op::FTOI4;
        case 0b00101'1111'10: return Op::FTOI12;
        case 0b00110'1111'00: case 0b00110'1111'01: case 0b00110'1111'10:
        case 0b00110'1111'11: return Op::MULAbc;
        case 0b00111'1111'00: return Op::MULAq;
        case 0b00111'1111'11: return Op::CLIP;
        case 0b01010'1111'00: return Op::ADDA;
        case 0b01010'1111'01: return Op::MADDA;
        case 0b01010'1111'10: return Op::MULA;
        case 0b01011'1111'10: return Op::OPMULA;
        case 0b01011'1111'11: return Op::NOP;
        default: return Op::INVALID;
      }
    }
    default:
      return Op::INVALID;
  }
}

Op lo_kind(uint32_t in) {
  int op = lo_op(in);
  if (op == 0b1000000) {
    // special
    switch (in & 0b111111) {
      case 0b110010: return Op::IADDI;
      case 0b110101: return Op::IOR;
      case 0b110000: return Op::IADD;
      case 0b110001: return Op::ISUB;
      case 0b110100: return Op::IAND;
    }
    switch (in & 0b11111111111) {
      case 0b01100'1111'00: return Op::MOVE;
      case 0b01100'1111'01: return Op::MR32;
      case 0b01101'1111'00: return Op::LQI;
      case 0b01101'1111'01: return Op::SQI;
      case 0b01101'1111'11: return Op::SQD;
      case 0b01110'1111'00: return Op::DIV;
      case 0b01110'1111'01: return Op::SQRT;
      case 0b01110'1111'10: return Op::RSQRT;
      case 0b01110'1111'11: return Op::WAITQ;
      case 0b01111'1111'00: return Op::MTIR;
      case 0b01111'1111'01: return Op::MFIR;
      case 0b01111'1111'10: return Op::ILWR;
      case 0b01111'1111'11: return Op::ISWR;
      case 0b11001'1111'00: return Op::MFP;
      case 0b11010'1111'00: return Op::XTOP;
      case 0b11011'1111'00: return Op::XGKICK;
      case 0b11100'1111'00: return Op::ESADD;
      case 0b11100'1111'10: return Op::ELENG;
      case 0b11100'1111'11: return Op::ERLENG;
      case 0b11101'1111'10: return Op::ESUM;
      case 0b11110'1111'11: return Op::WAITP;
      default: return Op::INVALID;
    }
  }
  if (in == 0b10000000000000000000000000110000) {
    return Op::NOP;
  }
  switch (op) {
    case 0b000000: return Op::LQ;
    case 0b000001: return Op::SQ;
    case 0b000100: return Op::ILW;
    case 0b000101: return Op::ISW;
    case 0b001000: return Op::IADDIU;
    case 0b001001: return Op::ISUBIU;
    case 0b010001: return Op::FCSET;
    case 0b010010: return Op::FCAND;
    case 0b010011: return Op::FCOR;
    case 0b010110: return Op::FSAND;
    case 0b011010: return Op::FMAND;
    case 0b011100: return Op::FCGET;
    case 0b100000: return Op::B;
    case 0b100001: return Op::BAL;
    case 0b100100: return Op::JR;
    case 0b100101: return Op::JALR;
    case 0b101000: return Op::IBEQ;
    case 0b101001: return Op::IBNE;
    case 0b101100: return Op::IBLTZ;
    case 0b101101: return Op::IBGTZ;
    case 0b101110: return Op::IBLEZ;
    case 0b101111: return Op::IBGEZ;
    default: return Op::INVALID;
  }
}

// VU float helpers: flush denormals to zero (the VU FPU does this).
inline float flush(float x) {
  if (std::fpclassify(x) == FP_SUBNORMAL) {
    return 0.0f;
  }
  return x;
}

inline int32_t to_int(float x) {
  if (std::isnan(x) || std::isinf(x)) {
    return 0;
  }
  return (int32_t)x;  // truncation toward zero
}

inline uint32_t pack_int(int32_t v) {
  return (uint32_t)(v << 16);  // ints live in the upper 16 bits
}

inline int32_t unpack_int(uint32_t w) {
  return (int32_t)(w >> 16);
}

// The VU's vi0 is hardwired to 0; writes to it are ignored.
inline void set_vi(Vu1State& st, int idx, uint16_t val) {
  if (idx != 0) {
    st.vi[idx] = val;
  }
}

void write_vf(VfReg& dst, uint32_t mask, const float* vals) {
  if (mask & 1) dst.f[0] = vals[0];
  if (mask & 2) dst.f[1] = vals[1];
  if (mask & 4) dst.f[2] = vals[2];
  if (mask & 8) dst.f[3] = vals[3];
}

}  // namespace

// The VIF "top" register: the address of the first qword after the microcode
// (the game's data region starts there).  Set by the caller.
static uint32_t g_vu_top = 0x400;
static int g_trace = 0;
static int g_readlog = 0;

void set_top(uint32_t top) { g_vu_top = top; }
void ottsel_vu1_set_trace(int on) { g_trace = on; }
void ottsel_vu1_set_readlog(int on) { g_readlog = on; }
void ottsel_vu1_set_readlog_hook(void (*hook)(const char*)) { g_readlog_hook = hook; }

void execute(Vu1State& st, int max_instructions) {
  int executed = 0;
  st.executed_instructions = 0;
  st.hit_instruction_limit = false;
  st.xgkick_count = 0;
  bool jump_armed = false;  // a branch executed; the next instruction is the delay slot
  bool jump_exec = false;   // the delay slot executed; apply the jump now
  int jump_target = 0;
  // An upper-instruction E bit terminates the VU program after its delay
  // slot.  Without it, a completed microprogram loops through its code until
  // the host safety budget expires.
  bool end_after_delay_slot = false;
  if (g_trace) {
    printf("TRACE: top=0x%x\n", g_vu_top);
  }
  while (st.pc >= 0 && st.pc < st.code_len && executed < max_instructions) {
    executed++;
    if (jump_exec) {
      st.pc = jump_target;
      jump_exec = false;
      jump_armed = false;
    }
    uint64_t raw = st.code[st.pc];
    uint32_t lower = (uint32_t)(raw & 0xffffffff);
    uint32_t upper = (uint32_t)(raw >> 32);
    int this_pc = st.pc;
    st.pc++;
    const bool stop_after_this = end_after_delay_slot;
    const bool has_end_bit = ((upper >> 25) & 0b100000) != 0;

    Op uop = up_kind(upper);
    Op lop = lo_kind(lower);
    if (g_trace && executed < 220) {
      printf("pc=%d u=%d l=%d up=0x%08x lo=0x%08x\n", this_pc, (int)uop, (int)lop, upper, lower);
    }
    if (uop == Op::INVALID || lop == Op::INVALID) {
      std::fprintf(stderr, "VU1: invalid op at pc=%d uop=%d lop=%d up=0x%08x lo=0x%08x\n",
                   this_pc, (int)uop, (int)lop, upper, lower);
      break;
    }
    int udst = up_dest(upper);
    int uft = up_ft(upper);
    int ufs = up_fs(upper);
    int ufd = up_fd(upper);
    int ubc = up_bc(upper);
    int lit = lo_it(lower) & 0xf;
    int lis = lo_is(lower) & 0xf;
    int lid = lo_id(lower) & 0xf;
    int limm11 = lo_imm11(lower);

    // The I register: set by i-type upper ops from the lower word.
    bool i_type = (uop == Op::ADDi || uop == Op::SUBi || uop == Op::MULi ||
                   uop == Op::MAXi || uop == Op::MINIi);
    if (i_type) {
      st.i_reg = flush(*(const float*)(&lower));
    }

    // Upper (FPU) pipe.
    float* vd = st.vf[ufd].f;
    float* vs = st.vf[ufs].f;
    float* vt = st.vf[uft].f;
    switch (uop) {
      case Op::NOP:
        break;
      case Op::ADD: {
        float r[4] = {flush(vs[0] + vt[0]), flush(vs[1] + vt[1]), flush(vs[2] + vt[2]),
                      flush(vs[3] + vt[3])};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::ADDi: {
        float r[4] = {flush(vs[0] + st.i_reg), flush(vs[1] + st.i_reg),
                      flush(vs[2] + st.i_reg), flush(vs[3] + st.i_reg)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::ADDq: {
        float r[4] = {flush(vs[0] + st.q), flush(vs[1] + st.q), flush(vs[2] + st.q),
                      flush(vs[3] + st.q)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::ADDbc: {
        float b = vt[ubc];
        float r[4] = {flush(vs[0] + b), flush(vs[1] + b), flush(vs[2] + b), flush(vs[3] + b)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::SUB: {
        float r[4] = {flush(vs[0] - vt[0]), flush(vs[1] - vt[1]), flush(vs[2] - vt[2]),
                      flush(vs[3] - vt[3])};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::SUBi: {
        float r[4] = {flush(vs[0] - st.i_reg), flush(vs[1] - st.i_reg),
                      flush(vs[2] - st.i_reg), flush(vs[3] - st.i_reg)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::SUBbc: {
        float b = vt[ubc];
        float r[4] = {flush(vs[0] - b), flush(vs[1] - b), flush(vs[2] - b), flush(vs[3] - b)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MUL: {
        float r[4] = {flush(vs[0] * vt[0]), flush(vs[1] * vt[1]), flush(vs[2] * vt[2]),
                      flush(vs[3] * vt[3])};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MULi: {
        float r[4] = {flush(vs[0] * st.i_reg), flush(vs[1] * st.i_reg),
                      flush(vs[2] * st.i_reg), flush(vs[3] * st.i_reg)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MULq: {
        float r[4] = {flush(vs[0] * st.q), flush(vs[1] * st.q), flush(vs[2] * st.q),
                      flush(vs[3] * st.q)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MULbc: {
        float b = vt[ubc];
        float r[4] = {flush(vs[0] * b), flush(vs[1] * b), flush(vs[2] * b), flush(vs[3] * b)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MAX: {
        float r[4] = {std::fmax(vs[0], vt[0]), std::fmax(vs[1], vt[1]),
                      std::fmax(vs[2], vt[2]), std::fmax(vs[3], vt[3])};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MAXi: {
        float r[4] = {std::fmax(vs[0], st.i_reg), std::fmax(vs[1], st.i_reg),
                      std::fmax(vs[2], st.i_reg), std::fmax(vs[3], st.i_reg)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MAXbc: {
        float b = vt[ubc];
        float r[4] = {std::fmax(vs[0], b), std::fmax(vs[1], b), std::fmax(vs[2], b),
                      std::fmax(vs[3], b)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MINI: {
        float r[4] = {std::fmin(vs[0], vt[0]), std::fmin(vs[1], vt[1]),
                      std::fmin(vs[2], vt[2]), std::fmin(vs[3], vt[3])};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MINIi: {
        float r[4] = {std::fmin(vs[0], st.i_reg), std::fmin(vs[1], st.i_reg),
                      std::fmin(vs[2], st.i_reg), std::fmin(vs[3], st.i_reg)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MINIbc: {
        float b = vt[ubc];
        float r[4] = {std::fmin(vs[0], b), std::fmin(vs[1], b), std::fmin(vs[2], b),
                      std::fmin(vs[3], b)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MADD: {
        float r[4] = {flush(st.acc[0] + vs[0] * vt[0]), flush(st.acc[1] + vs[1] * vt[1]),
                      flush(st.acc[2] + vs[2] * vt[2]), flush(st.acc[3] + vs[3] * vt[3])};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MADDq: {
        float r[4] = {flush(st.acc[0] + vs[0] * st.q), flush(st.acc[1] + vs[1] * st.q),
                      flush(st.acc[2] + vs[2] * st.q), flush(st.acc[3] + vs[3] * st.q)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MADDbc: {
        float b = vt[ubc];
        float r[4] = {flush(st.acc[0] + vs[0] * b), flush(st.acc[1] + vs[1] * b),
                      flush(st.acc[2] + vs[2] * b), flush(st.acc[3] + vs[3] * b)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::MSUBbc: {
        float b = vt[ubc];
        float r[4] = {flush(st.acc[0] - vs[0] * b), flush(st.acc[1] - vs[1] * b),
                      flush(st.acc[2] - vs[2] * b), flush(st.acc[3] - vs[3] * b)};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::ADDA: {
        st.acc[0] = flush(vs[0] + vt[0]);
        st.acc[1] = flush(vs[1] + vt[1]);
        st.acc[2] = flush(vs[2] + vt[2]);
        st.acc[3] = flush(vs[3] + vt[3]);
      } break;
      case Op::ADDAbc: {
        float b = vt[ubc];
        st.acc[0] = flush(vs[0] + b);
        st.acc[1] = flush(vs[1] + b);
        st.acc[2] = flush(vs[2] + b);
        st.acc[3] = flush(vs[3] + b);
      } break;
      case Op::MULA: {
        st.acc[0] = flush(vs[0] * vt[0]);
        st.acc[1] = flush(vs[1] * vt[1]);
        st.acc[2] = flush(vs[2] * vt[2]);
        st.acc[3] = flush(vs[3] * vt[3]);
      } break;
      case Op::MULAq: {
        st.acc[0] = flush(vs[0] * st.q);
        st.acc[1] = flush(vs[1] * st.q);
        st.acc[2] = flush(vs[2] * st.q);
        st.acc[3] = flush(vs[3] * st.q);
      } break;
      case Op::MULAbc: {
        float b = vt[ubc];
        st.acc[0] = flush(vs[0] * b);
        st.acc[1] = flush(vs[1] * b);
        st.acc[2] = flush(vs[2] * b);
        st.acc[3] = flush(vs[3] * b);
      } break;
      case Op::MADDA: {
        st.acc[0] = flush(st.acc[0] + vs[0] * vt[0]);
        st.acc[1] = flush(st.acc[1] + vs[1] * vt[1]);
        st.acc[2] = flush(st.acc[2] + vs[2] * vt[2]);
        st.acc[3] = flush(st.acc[3] + vs[3] * vt[3]);
      } break;
      case Op::MADDAbc: {
        float b = vt[ubc];
        st.acc[0] = flush(st.acc[0] + vs[0] * b);
        st.acc[1] = flush(st.acc[1] + vs[1] * b);
        st.acc[2] = flush(st.acc[2] + vs[2] * b);
        st.acc[3] = flush(st.acc[3] + vs[3] * b);
      } break;
      case Op::MSUBAbc: {
        float b = vt[ubc];
        st.acc[0] = flush(st.acc[0] - vs[0] * b);
        st.acc[1] = flush(st.acc[1] - vs[1] * b);
        st.acc[2] = flush(st.acc[2] - vs[2] * b);
        st.acc[3] = flush(st.acc[3] - vs[3] * b);
      } break;
      case Op::OPMULA: {
        st.acc[0] = flush(vs[1] * vt[2] - vs[2] * vt[1]);
        st.acc[1] = flush(vs[2] * vt[0] - vs[0] * vt[2]);
        st.acc[2] = flush(vs[0] * vt[1] - vs[1] * vt[0]);
        st.acc[3] = 0;
      } break;
      case Op::OPMSUB: {
        float r[4] = {flush(st.acc[0] - (vs[1] * vt[2] - vs[2] * vt[1])),
                      flush(st.acc[1] - (vs[2] * vt[0] - vs[0] * vt[2])),
                      flush(st.acc[2] - (vs[0] * vt[1] - vs[1] * vt[0])), 0};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::FTOI0: case Op::FTOI4: case Op::FTOI12: {
        float scale = uop == Op::FTOI4 ? 16.f : (uop == Op::FTOI12 ? 4096.f : 1.f);
        float r[4];
        for (int c = 0; c < 4; c++) {
          uint32_t iv = pack_int(to_int(vs[c] * scale));
          memcpy(&r[c], &iv, 4);
        }
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::ITOF0: case Op::ITOF12: case Op::ITOF15: {
        float scale = uop == Op::ITOF12 ? (1.f / 4096.f) : (uop == Op::ITOF15 ? (1.f / 32768.f) : 1.f);
        float r[4] = {(float)unpack_int(vs[0]) * scale, (float)unpack_int(vs[1]) * scale,
                      (float)unpack_int(vs[2]) * scale, (float)unpack_int(vs[3]) * scale};
        write_vf(st.vf[ufd], udst, r);
      } break;
      case Op::CLIP: {
        // clip flags: compare vt.w against the fs components.
        float w = vt[3];
        uint32_t flags = 0;
        flags |= (vs[0] > w) ? 1 : 0;
        flags |= (vs[0] < -w) ? 2 : 0;
        flags |= (vs[1] > w) ? 4 : 0;
        flags |= (vs[1] < -w) ? 8 : 0;
        flags |= (vs[2] > w) ? 16 : 0;
        flags |= (vs[2] < -w) ? 32 : 0;
        st.status = (st.status & ~0xfff) | (flags << 0);
      } break;
      default:
        break;
    }

    // Lower (integer/memory) pipe.
    int branch_target = -1;
    bool branch = false;
    switch (lop) {
      case Op::NOP:
        break;
      case Op::LQ: {
        uint32_t addr = ((int32_t)(int16_t)st.vi[lis] + limm11) & 0xfff;
        if (g_readlog) {
          char buf[96];
          snprintf(buf, sizeof(buf), "VU1R LQ pc=%d addr=0x%x -> vf%d", st.pc - 1, addr, lit);
          if (g_readlog_hook) {
            g_readlog_hook(buf);
          } else {
            printf("%s\n", buf);
          }
        }
        memcpy(&st.vf[lit].u[0], &st.data[addr * 4], 16);
      } break;
      case Op::LQD: {
        uint32_t addr = ((int32_t)(int16_t)st.vi[lis] - 1) & 0xfff;
        set_vi(st, lis, addr);
        memcpy(&st.vf[lit].u[0], &st.data[addr * 4], 16);
      } break;
      case Op::LQI: {
        uint32_t addr = st.vi[lis] & 0xfff;
        set_vi(st, lis, (st.vi[lis] + 1) & 0xfff);
        if (g_readlog) {
          char buf[96];
          snprintf(buf, sizeof(buf), "VU1R LQI pc=%d addr=0x%x -> vf%d (vi%d)", st.pc - 1, addr,
                   lit, lis);
          if (g_readlog_hook) {
            g_readlog_hook(buf);
          } else {
            printf("%s\n", buf);
          }
        }
        memcpy(&st.vf[lit].u[0], &st.data[addr * 4], 16);
      } break;
      case Op::SQ: {
        uint32_t addr = ((int32_t)(int16_t)st.vi[lis] + limm11) & 0xfff;
        memcpy(&st.data[addr * 4], &st.vf[lit].u[0], 16);
      } break;
      case Op::SQD: {
        uint32_t addr = ((int32_t)(int16_t)st.vi[lis] - 1) & 0xfff;
        set_vi(st, lis, addr);
        memcpy(&st.data[addr * 4], &st.vf[lit].u[0], 16);
      } break;
      case Op::SQI: {
        uint32_t addr = st.vi[lis] & 0xfff;
        set_vi(st, lis, (st.vi[lis] + 1) & 0xfff);
        memcpy(&st.data[addr * 4], &st.vf[lit].u[0], 16);
      } break;
      case Op::ILW: {
        uint32_t addr = ((int32_t)(int16_t)st.vi[lis] + limm11) & 0xfff;
        // The 16-bit component is selected by the dest-mask bits 21-24
        // (reversed: bit0=w, bit1=z, bit2=y, bit3=x).
        uint32_t comp = (lower >> 21) & 0xf;
        uint32_t word = st.data[addr * 4 + (comp >= 0b0010 ? 1 : 0)];
        uint16_t val = (uint16_t)((comp & 0b1) ? (word >> 16) : (word & 0xffff));
        if ((comp & 0b0100) && !(comp & 0b0010)) {  // y: word0 high
          val = (uint16_t)(st.data[addr * 4] >> 16);
        }
        if ((comp & 0b1000)) {  // x: word0 low
          val = (uint16_t)(st.data[addr * 4] & 0xffff);
        }
        if (g_readlog) {
          char buf[96];
          snprintf(buf, sizeof(buf), "VU1R ILW pc=%d addr=0x%x -> vi%d", st.pc - 1, addr, lit);
          if (g_readlog_hook) {
            g_readlog_hook(buf);
          } else {
            printf("%s\n", buf);
          }
        }
        set_vi(st, lit, val);
      } break;
      case Op::ISW: {
        uint32_t addr = ((int32_t)(int16_t)st.vi[lis] + limm11) & 0xfff;
        uint32_t comp = (lower >> 21) & 0xf;
        if (comp & 0b1000) {  // x
          st.data[addr * 4] = (st.data[addr * 4] & 0xffff0000u) | (st.vi[lit] & 0xffff);
        } else if (comp & 0b0100) {  // y
          st.data[addr * 4] = (st.data[addr * 4] & 0xffffu) | ((uint32_t)st.vi[lit] << 16);
        } else if (comp & 0b0010) {  // z
          st.data[addr * 4 + 1] = (st.data[addr * 4 + 1] & 0xffff0000u) | (st.vi[lit] & 0xffff);
        } else {  // w
          st.data[addr * 4 + 1] = (st.data[addr * 4 + 1] & 0xffffu) | ((uint32_t)st.vi[lit] << 16);
        }
      } break;
      case Op::ILWR: {
        uint32_t addr = st.vi[lis] & 0xfff;
        uint32_t comp = (lower >> 21) & 0xf;
        uint32_t word = st.data[addr * 4 + (comp >= 0b0010 ? 1 : 0)];
        uint16_t val = (uint16_t)((comp & 0b1) ? (word >> 16) : (word & 0xffff));
        if ((comp & 0b0100) && !(comp & 0b0010)) {
          val = (uint16_t)(st.data[addr * 4] >> 16);
        }
        if ((comp & 0b1000)) {
          val = (uint16_t)(st.data[addr * 4] & 0xffff);
        }
        if (g_readlog) {
          char buf[96];
          snprintf(buf, sizeof(buf), "VU1R ILWR pc=%d addr=0x%x -> vi%d", st.pc - 1, addr, lit);
          if (g_readlog_hook) {
            g_readlog_hook(buf);
          } else {
            printf("%s\n", buf);
          }
        }
        set_vi(st, lit, val);
      } break;
      case Op::ISWR: {
        uint32_t addr = st.vi[lis] & 0xfff;
        uint32_t comp = (lower >> 21) & 0xf;
        if (comp & 0b1000) {  // x
          st.data[addr * 4] = (st.data[addr * 4] & 0xffff0000u) | (st.vi[lit] & 0xffff);
        } else if (comp & 0b0100) {  // y
          st.data[addr * 4] = (st.data[addr * 4] & 0xffffu) | ((uint32_t)st.vi[lit] << 16);
        } else if (comp & 0b0010) {  // z
          st.data[addr * 4 + 1] = (st.data[addr * 4 + 1] & 0xffff0000u) | (st.vi[lit] & 0xffff);
        } else {  // w
          st.data[addr * 4 + 1] = (st.data[addr * 4 + 1] & 0xffffu) | ((uint32_t)st.vi[lit] << 16);
        }
      } break;
      case Op::IADD:
        set_vi(st, lid, (uint16_t)(st.vi[lis] + st.vi[lit]));
        break;
      case Op::IADDI:
        set_vi(st, lit, (uint16_t)(st.vi[lis] + (int16_t)(lo_imm5(lower) << 11 >> 11)));
        break;
      case Op::IADDIU:
        set_vi(st, lit, (uint16_t)(st.vi[lis] + lo_imm15(lower)));
        break;
      case Op::IAND:
        set_vi(st, lid, st.vi[lis] & st.vi[lit]);
        break;
      case Op::IOR:
        set_vi(st, lid, st.vi[lis] | st.vi[lit]);
        break;
      case Op::ISUB:
        set_vi(st, lid, (uint16_t)(st.vi[lis] - st.vi[lit]));
        break;
      case Op::ISUBIU:
        set_vi(st, lit, (uint16_t)(st.vi[lis] - lo_imm15(lower)));
        break;
      case Op::MOVE:
        memcpy(st.vf[lit].u, st.vf[lis].u, 16);
        break;
      case Op::MR32:
        for (int c = 0; c < 4; c++) {
          st.vf[lit].u[c] = st.vf[lis].u[(c + 1) & 3];
        }
        break;
      case Op::MFIR:
        // MFIR writes each component selected by the lower instruction's
        // destination mask (x=bit 3 through w=bit 0).  TFRAG's setup pass
        // builds its kick pointers with four single-component MFIRs.
        for (int component = 0; component < 4; component++) {
          if (lower & (1u << (21 + component))) {
            st.vf[lit].u[3 - component] = (uint32_t)(int32_t)(int16_t)st.vi[lis];
          }
        }
        break;
      case Op::MTIR:
        // MTIR reads the component encoded in FSF (bits 21-22), whose
        // encoding is x=0, y=1, z=2, w=3.
        set_vi(st, lit, st.vf[lis].u[(lower >> 21) & 0x3] & 0xffff);
        break;
      case Op::DIV: {
        float num = st.vf[lis].f[(lower >> 21) & 3];
        float den = st.vf[lit].f[(lower >> 23) & 3];
        st.q = (den == 0.0f) ? 0.0f : flush(num / den);
      } break;
      case Op::SQRT: {
        float v = st.vf[lit].f[(lower >> 23) & 3];
        st.q = (v <= 0.0f) ? 0.0f : flush(std::sqrt(v));
      } break;
      case Op::RSQRT: {
        float v = st.vf[lit].f[(lower >> 23) & 3];
        st.q = (v <= 0.0f) ? 0.0f : flush(1.0f / std::sqrt(v));
      } break;
      case Op::WAITQ: case Op::WAITP:
        break;
      case Op::XTOP:
        set_vi(st, lit, g_vu_top);
        break;
      case Op::XGKICK: {
        st.xgkick_count++;
        uint32_t addr = st.vi[lis] & 0xfff;
        for (int c = 0; c < 4; c++) {
          st.gif_out.push_back(st.data[addr * 4 + c]);
        }
      } break;
      case Op::FCSET:
        st.status = (st.status & ~0xffffff) | (lower & 0xffffff);
        break;
      case Op::FCAND:
        set_vi(st, lid, (st.status & (lower & 0xffffff)) ? 1 : 0);
        break;
      case Op::FCOR:
        set_vi(st, lid, ((st.status | (lower & 0xffffff)) == 0xffffff) ? 1 : 0);
        break;
      case Op::FSAND:
        set_vi(st, lid, (st.status & (lower & 0xffffff)) ? 1 : 0);
        break;
      case Op::FMAND:
        set_vi(st, lid, (st.vi[lis] & lo_imm15(lower)) ? 1 : 0);
        break;
      case Op::FCGET:
        set_vi(st, lid, st.status & 0xffff);
        break;
      case Op::MFP:
        st.vf[lit].f[0] = st.p;
        break;
      case Op::ESADD: case Op::ELENG: case Op::ERLENG: case Op::ESUM:
        // elementary functions: not used by tfrag; approximate.
        break;
      case Op::B: {
        int32_t off = (int32_t)(limm11 << 21) >> 21;
        branch_target = (this_pc + 1 + off) & 0x7ff;
        branch = true;
      } break;
      case Op::BAL: {
        int32_t off = (int32_t)(limm11 << 21) >> 21;
        set_vi(st, lid, (uint16_t)((this_pc + 1) & 0xffff));
        branch_target = (this_pc + 1 + off) & 0x7ff;
        branch = true;
      } break;
      case Op::JR:
        branch_target = st.vi[lis] & 0x7ff;
        branch = true;
        break;
      case Op::JALR:
        set_vi(st, lid, (uint16_t)((this_pc + 1) & 0xffff));
        branch_target = st.vi[lis] & 0x7ff;
        branch = true;
        break;
      case Op::IBEQ: {
        if (g_trace) {
          printf("IBEQ pc=%d vi%d vs vi%d (vals %d %d) tgt=%d\n", this_pc, lis, lit, st.vi[lis],
                 st.vi[lit], (this_pc + 1 + (int)(limm11 << 21 >> 21)) & 0x7ff);
        }
        if (st.vi[lis] == st.vi[lit]) {
          int32_t off = (int32_t)(limm11 << 21) >> 21;
          branch_target = (this_pc + 1 + off) & 0x7ff;
          branch = true;
        }
      } break;
      case Op::IBNE: {
        if (st.vi[lis] != st.vi[lit]) {
          int32_t off = (int32_t)(limm11 << 21) >> 21;
          branch_target = (this_pc + 1 + off) & 0x7ff;
          branch = true;
        }
      } break;
      case Op::IBLTZ: {
        if ((int16_t)st.vi[lis] < 0) {
          int32_t off = (int32_t)(limm11 << 21) >> 21;
          branch_target = (this_pc + 1 + off) & 0x7ff;
          branch = true;
        }
      } break;
      case Op::IBGTZ: {
        if ((int16_t)st.vi[lis] > 0) {
          int32_t off = (int32_t)(limm11 << 21) >> 21;
          branch_target = (this_pc + 1 + off) & 0x7ff;
          branch = true;
        }
      } break;
      case Op::IBLEZ: {
        if ((int16_t)st.vi[lis] <= 0) {
          int32_t off = (int32_t)(limm11 << 21) >> 21;
          branch_target = (this_pc + 1 + off) & 0x7ff;
          branch = true;
        }
      } break;
      case Op::IBGEZ: {
        if ((int16_t)st.vi[lis] >= 0) {
          int32_t off = (int32_t)(limm11 << 21) >> 21;
          branch_target = (this_pc + 1 + off) & 0x7ff;
          branch = true;
        }
      } break;
      default:
        break;
    }

    // Branch handling: the instruction after the branch (the delay slot)
    // executes before the jump takes effect.
    if (jump_armed) {
      jump_exec = true;  // the delay slot ran; apply the jump next iteration
    }
    if (branch) {
      jump_armed = true;
      jump_target = branch_target;
    }
    if (stop_after_this) {
      break;
    }
    if (has_end_bit) {
      end_after_delay_slot = true;
    }
  }
  st.executed_instructions = executed;
  st.hit_instruction_limit = executed == max_instructions && st.pc >= 0 && st.pc < st.code_len;
}

}  // namespace ottsel_vu1
