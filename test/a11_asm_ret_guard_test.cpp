// Ottsel A1 regression: the .ret fail-safe select must keep only module code.
//
// IR_AsmRet::do_codegen_arm64 emits a branchless select before `ret`:
//   x16 = incoming x30 (the lowering's continuation), x30 = [sp] (the slot)
//   band 1 (iPad signed arena): x9 = ee + 0x8000000, x10 = ee + 0x8c30000
//   band 2 (macOS no-emit region): x9 = ee + 0x3ebc000, x10 = ee + 0x4ee0000
//   x11 = (slot < lo), x12/x2 = (slot < hi); keep = keep1 + keep2 (0/1), mask = -keep
//   x30 = x16 + (([sp] - x16) & mask)
// A slot holding a GOAL/EE word, module data, an app-image/stub address or a stack
// address must fall back to the incoming link register instead of branching into
// non-code.  Four measured escapes drove this test:
//   0x181674     - the village-cam Symbol address (an EE word)
//   0x50ffffffff - a GOAL frame local at [sp] during the strict oracle serve
//   0x108c3fe10  - a GOAL *stack* address (ee + 0x7fffe10) that the A1.8
//                  high-half-in-[1,8] window still accepted; pc == lr == x30
//                  then left the image at the boot/loader activation
//   the macOS lane - the A1.11 window is empty there (its code lives at
//                  ee + 0x3ebc000..0x4ee0000), so every guarded .ret rejected the
//                  real return value 0x7003ed79b4 and returned through the link
//                  register; that band is why the guard has two windows now.
// This test exercises the same instruction sequence, returning the selected
// value instead of jumping.
#include <cstdint>
#include <cstdio>

extern "C" uint64_t a11_guard_select(uint64_t slot, uint64_t incoming, uint64_t ee)
    asm("_a11_guard_select");

asm(".text\n.balign 4\n"
    ".globl _a11_guard_select\n"
    "_a11_guard_select:\n"
    "  mov x3, x30\n"          // the test double must return to its own caller
    "  mov x16, x1\n"
    "  mov x5, x22\n"          // x22 is callee-saved; the double only borrows it
    "  mov x22, x2\n"          // the offset register (ee)
    "  mov x30, x0\n"
    "  mov x17, x30\n"
    "  mov x9, #0x8000000\n"
    "  add x9, x9, x22\n"
    "  mov x10, #0x8c30000\n"
    "  add x10, x10, x22\n"
    "  mov x11, x17\n"
    "  sub x11, x11, x9\n"
    "  mov x12, x17\n"
    "  sub x12, x12, x10\n"
    "  lsr x11, x11, #63\n"
    "  lsr x12, x12, #63\n"
    "  sub x12, x12, x11\n"
    "  movz x9, #0xc000\n"
    "  movk x9, #0x3eb, lsl #16\n"
    "  add x9, x9, x22\n"
    "  mov x10, #0x4ee0000\n"
    "  add x10, x10, x22\n"
    "  mov x11, x17\n"
    "  sub x11, x11, x9\n"
    "  mov x2, x17\n"
    "  sub x2, x2, x10\n"
    "  lsr x11, x11, #63\n"
    "  lsr x2, x2, #63\n"
    "  sub x2, x2, x11\n"
    "  add x12, x12, x2\n"
    "  mov x11, #0\n"
    "  sub x11, x11, x12\n"
    "  mov x2, x17\n"
    "  sub x2, x2, x16\n"
    "  and x2, x2, x11\n"
    "  mov x30, x16\n"
    "  add x30, x30, x2\n"
    "  mov x0, x30\n"
    "  mov x22, x5\n"          // restore the offset register for the caller
    "  mov x30, x3\n"
    "  ret\n");

static int failures = 0;

static void expect(const char* what, uint64_t got, uint64_t want) {
  if (got != want) {
    std::printf("FAIL: %s got 0x%llx want 0x%llx\n", what,
                static_cast<unsigned long long>(got), static_cast<unsigned long long>(want));
    failures++;
  } else {
    std::printf("ok: %s 0x%llx\n", what, static_cast<unsigned long long>(got));
  }
}

int main() {
  const uint64_t ee = 0x100c40000ull;                    // the measured strict-lane ee
  const uint64_t host_lr = 0x104d706dcull;               // arg_call_arm64+0x5c (C code)
  const uint64_t code_slot = ee + 0x8018000ull;          // gkernel's module entry (iPad band)
  const uint64_t code_slot2 = ee + 0x8810000ull;         // main's module entry (iPad band)
  const uint64_t host_code = ee + 0x3ed0000ull;          // gkernel's macOS segment base
  const uint64_t host_code_hi = ee + 0x4edffffull;       // last word of the macOS region
  const uint64_t host_stack = ee + 0x7fffd90ull;         // the measured macOS kernel stack
  const uint64_t heap_slot = ee + 0x13fd20ull;           // the GOAL heap base
  const uint64_t data_slot = ee + 0x3db9940ull;          // module data (font-h seg0)
  const uint64_t data_top = ee + 0x3eb8000ull;           // the iPad module-data band top
  const uint64_t gap_slot = ee + 0x6000000ull;           // between the two bands
  const uint64_t stack_slot = ee + 0x7fffe10ull;         // the measured escape
  const uint64_t app_slot = 0x10040b220ull;              // intern_type_from_c+0xf8
  const uint64_t ee_slot = 0x181674ull;                  // the village-cam Symbol address
  const uint64_t frame_local = 0x50ffffffffull;          // the strict oracle-serve [sp] word
  expect("iPad module code slot wins (gkernel)", a11_guard_select(code_slot, host_lr, ee),
         code_slot);
  expect("iPad module code slot wins (main)", a11_guard_select(code_slot2, host_lr, ee),
         code_slot2);
  expect("macOS code slot wins (the A1.16 fix)",
         a11_guard_select(host_code, host_lr, ee), host_code);
  expect("macOS code region top wins", a11_guard_select(host_code_hi, host_lr, ee),
         host_code_hi);
  expect("iPad low bound is inclusive", a11_guard_select(ee + 0x8000000ull, host_lr, ee),
         ee + 0x8000000ull);
  expect("iPad high bound is exclusive", a11_guard_select(ee + 0x8c30000ull, host_lr, ee),
         host_lr);
  expect("macOS low bound is inclusive", a11_guard_select(ee + 0x3ebc000ull, host_lr, ee),
         ee + 0x3ebc000ull);
  expect("macOS high bound is exclusive", a11_guard_select(ee + 0x4ee0000ull, host_lr, ee),
         host_lr);
  expect("GOAL stack address falls back (the A1.11 escape)",
         a11_guard_select(stack_slot, host_lr, ee), host_lr);
  expect("macOS kernel stack falls back",
         a11_guard_select(host_stack, host_lr, ee), host_lr);
  expect("a slot between the two bands falls back",
         a11_guard_select(gap_slot, host_lr, ee), host_lr);
  expect("module data slot falls back", a11_guard_select(data_slot, host_lr, ee), host_lr);
  expect("iPad module-data band top falls back",
         a11_guard_select(data_top, host_lr, ee), host_lr);
  expect("GOAL heap slot falls back", a11_guard_select(heap_slot, host_lr, ee), host_lr);
  expect("app-image slot falls back", a11_guard_select(app_slot, host_lr, ee), host_lr);
  expect("EE slot falls back to the link register",
         a11_guard_select(ee_slot, host_lr, ee), host_lr);
  expect("zero slot falls back", a11_guard_select(0, host_lr, ee), host_lr);
  expect("EE slot with a zero link register stays a value (no address invented)",
         a11_guard_select(ee_slot, 0, ee), 0);
  expect("frame local falls back to the link register",
         a11_guard_select(frame_local, host_lr, ee), host_lr);
  expect("frame local with a zero link register invents no address",
         a11_guard_select(frame_local, 0, ee), 0);
  expect("stack slot with a zero link register invents no address",
         a11_guard_select(stack_slot, 0, ee), 0);
  if (failures) {
    std::printf("FAIL: %d guard select cases\n", failures);
    return 1;
  }
  std::printf("PASS: .ret fail-safe select keeps either lane's module code and rejects EE, "
              "data, gap and stack words\n");
  return 0;
}
