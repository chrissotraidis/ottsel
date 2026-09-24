// Ottsel A1.1 regression: the C->GOAL bridges must establish the GOAL synthetic
// return slot that IR_AsmRet-style asm-funcs read.
//
// GOAL asm-funcs (.ret) end with 'ldr x30, [sp]; ret' (see
// IR_AsmRet::do_codegen_arm64): they take their return address from the GOAL
// stack, not from x30.  The compiler's GOAL->GOAL call lowering pushes that slot
// (push x30; adr x17, post-blr; push x17; blr; pop x17; pop x30).  A C->GOAL
// entry did not, so an asm-func entered from C read whatever happened to be at
// [sp] -- in this app a spilled C argument (the observed jump to the
// village-cam Symbol address 0x181674 from the strict signed-GAME oracle
// serve) -- and returned into it.
//
// This test calls the real _call_goal_asm_arm64 bridge with a target that
// mimics IR_AsmRet.  Before the fix the bridge never returns here; after it the
// target's return value must survive.
#include <csignal>
#include <csetjmp>
#include <cstdint>
#include <cstdio>
#include <cstdlib>

// The assembly file defines the Mach-O symbol _call_goal_asm_arm64, which is the
// C name call_goal_asm_arm64; kscheme.cpp binds it through an explicit asm label.
extern "C" uint64_t a11_bridge(uint64_t a0, uint64_t a1, uint64_t a2, void* fptr, void* st,
                               void* off) asm("_call_goal_asm_arm64");
extern "C" uint64_t a11_asm_ret_target() asm("_a11_asm_ret_target");

// Mimics IR_AsmRet::do_codegen_arm64: read the synthetic slot, then ret.
asm(".text\n.balign 4\n"
    ".globl _a11_asm_ret_target\n"
    "_a11_asm_ret_target:\n"
    "  mov x0, #0x11\n"
    "  ldr x30, [sp]\n"
    "  ret\n"
    "  mov x0, #0xdead\n");

static sigjmp_buf g_jump;

static void on_signal(int sig) {
  std::printf("FAIL: the bridge returned into non-code (signal %d): an asm-func read [sp] "
              "with no synthetic return slot\n", sig);
  std::fflush(stdout);
  siglongjmp(g_jump, 1);
}

int main() {
  struct sigaction action{};
  action.sa_handler = on_signal;
  sigaction(SIGSEGV, &action, nullptr);
  sigaction(SIGBUS, &action, nullptr);
  // st and off are moved verbatim into x21/x22; keep them non-address values so
  // a bad return is an immediate fault rather than a hang.
  if (sigsetjmp(g_jump, 1) != 0) {
    return 1;
  }
  const uint64_t result = a11_bridge(0, 0, 0, reinterpret_cast<void*>(&a11_asm_ret_target),
                                     reinterpret_cast<void*>(uintptr_t{0x18fe04}),
                                     reinterpret_cast<void*>(uintptr_t{0x70000000}));
  std::printf("bridge returned 0x%llx\n", static_cast<unsigned long long>(result));
  if (result != 0x11) {
    std::printf("FAIL: asm-func return value 0x%llx != 0x11\n",
                static_cast<unsigned long long>(result));
    return 1;
  }
  std::printf("PASS: C->GOAL bridge preserves an IR_AsmRet-style return\n");
  return 0;
}

// Storage for the GOAL->C++ boundary diagnostic counters that
// game/kernel/asm_funcs_arm64.s writes (see src/shell/ios_boot.cpp).  The product
// shell defines these; this harness links the assembly without the shell.
extern "C" {
volatile unsigned long long ottsel_cbridge_calls;
volatile unsigned long long ottsel_cbridge_in;
volatile unsigned long long ottsel_cbridge_out;
volatile unsigned long long ottsel_cbridge_target;
volatile unsigned long long ottsel_cbridge_leaks;
volatile unsigned long long ottsel_cbridge_leak_in;
volatile unsigned long long ottsel_cbridge_leak_out;
volatile unsigned long long ottsel_cbridge_leak_target;
}
